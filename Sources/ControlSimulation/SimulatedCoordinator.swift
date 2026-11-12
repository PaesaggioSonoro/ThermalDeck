import ThermalCore

/// Deterministic virtual time models a supervisor independent of its client.
struct SimulatedCoordinator {
    enum Fault: Equatable {
        case unverified, telemetry, fanRead, limitsChanged, writeFailed, settleTimeout, leaseExpired
        case disconnected, lostState, lifecycle, pendingCommand, interference, unauthorized
    }

    enum State: Equatable {
        case systemManaged, unsupported, preparing, manualActive, curveActive, restoringSystem
        case faulted(Fault), recoveryRequired(Set<FanID>)
    }

    struct Input {
        var temperature: Double
        var sampledAt: Duration
    }

    var backend: SimulatedBackend
    var authorized = true
    private let trustedSensors: Set<SensorID>
    private(set) var state: State = .systemManaged
    private var owned: [FanID: ClosedRange<Double>] = [:]
    private var expected: [FanID: Double] = [:]
    private var pendingUntil: Duration?
    private var leaseUntil: Duration?
    private var activeCurve: FanCurve?
    private var curveResponses: [FanID: CurveResponse] = [:]
    private var lastStep: Duration = .zero

    init(backend: SimulatedBackend, trustedSensors: Set<SensorID>) {
        self.backend = backend
        self.trustedSensors = trustedSensors
    }

    mutating func start(
        targets: [FanID: Double], curve: FanCurve? = nil, temperatures: [SensorID: Input], at now: Duration
    ) -> Bool {
        if case .recoveryRequired = state { return false }
        if !owned.isEmpty {
            let inFlight = pendingUntil != nil
            restore(fault: inFlight ? .pendingCommand : nil, at: now)
            guard !inFlight, state == .systemManaged else { return false }
        }
        guard backend.modelIsValidated else { state = .unsupported; return false }
        guard authorized else { state = .faulted(.unauthorized); return false }
        guard let temperature = freshPeak(temperatures, at: now) else { state = .faulted(.telemetry); return false }
        guard let fans = backend.read(at: now) else { state = .faulted(.fanRead); return false }
        guard !targets.isEmpty, targets.allSatisfy({ id, rpm in
            guard let fan = fans[id] else { return false }
            return fan.mode == .system && allowed(rpm, for: fan) &&
                (curve?.points.allSatisfy { allowed($0.rpm, for: fan) } ?? true)
        }) else { state = .faulted(.unverified); return false }

        state = .preparing
        for id in targets.keys { owned[id] = fans[id]?.limits }
        activeCurve = curve
        lastStep = now
        var initial = targets
        if let curve {
            for (id, baseline) in targets {
                var response = CurveResponse()
                initial[id] = response.step(curve: curve, celsius: temperature, elapsed: .zero, baseline: baseline)
                curveResponses[id] = response
            }
        }
        guard apply(initial, at: now) else { return false }
        leaseUntil = now + .seconds(8)
        return true
    }

    mutating func heartbeat(at now: Duration) {
        guard let leaseUntil, now < leaseUntil else { return }
        self.leaseUntil = now + .seconds(8)
    }

    mutating func tick(temperatures: [SensorID: Input], at now: Duration) {
        guard !owned.isEmpty, let leaseUntil else { return }
        guard now < leaseUntil else { restore(fault: .leaseExpired, at: now); return }
        guard authorized else { restore(fault: .unauthorized, at: now); return }
        guard backend.modelIsValidated else { restore(fault: .unverified, at: now); return }
        guard let peak = freshPeak(temperatures, at: now) else { restore(fault: .telemetry, at: now); return }
        guard let fans = backend.read(at: now) else { restore(fault: .fanRead, at: now); return }

        for (id, limits) in owned {
            guard let fan = fans[id], fan.limits == limits else { restore(fault: .limitsChanged, at: now); return }
            guard fan.mode == .manual, fan.target == expected[id] else { restore(fault: .interference, at: now); return }
            guard let target = expected[id], allowed(target, for: fan) else {
                restore(fault: .limitsChanged, at: now)
                return
            }
        }

        if let deadline = pendingUntil {
            if now <= deadline, expected.allSatisfy({ id, rpm in fans[id].map { abs($0.actual - rpm) <= 100 } ?? false }) {
                pendingUntil = nil
                state = activeCurve == nil ? .manualActive : .curveActive
            } else if now >= deadline {
                restore(fault: .settleTimeout, at: now)
            }
            return
        }

        guard let curve = activeCurve, now - lastStep >= .seconds(1) else { return }
        var updated: [FanID: Double] = [:]
        for (id, rpm) in expected {
            guard let target = curveResponses[id]?.step(curve: curve, celsius: peak, elapsed: now - lastStep, baseline: rpm),
                  let fan = fans[id], allowed(target, for: fan) else {
                restore(fault: .telemetry, at: now)
                return
            }
            if abs(target - rpm) >= 10 { updated[id] = target }
        }
        lastStep = now
        if !updated.isEmpty { _ = apply(updated, at: now) }
    }

    mutating func disconnect(at now: Duration) { restore(fault: .disconnected, at: now) }
    mutating func lostServiceState(at now: Duration) { restore(fault: .lostState, at: now) }
    mutating func lifecycleEnds(at now: Duration) { restore(fault: .lifecycle, at: now) }
    mutating func automatic(at now: Duration) { restore(fault: nil, at: now) }

    private mutating func apply(_ targets: [FanID: Double], at now: Duration) -> Bool {
        for id in targets.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let target = targets[id], backend.apply(target, to: id, at: now) else {
                restore(fault: .writeFailed, at: now)
                return false
            }
            expected[id] = target
        }
        pendingUntil = now + .seconds(5)
        state = .preparing
        return true
    }

    private mutating func restore(fault: Fault?, at now: Duration) {
        state = .restoringSystem
        let allOwned = Set(owned.keys)
        var failures: Set<FanID> = []
        for id in allOwned where !backend.restore(id) { failures.insert(id) }
        if !allOwned.isEmpty {
            if let observed = backend.read(at: now) {
                for id in allOwned where observed[id]?.mode != .system { failures.insert(id) }
            } else {
                failures = allOwned
            }
        }
        owned = owned.filter { failures.contains($0.key) }
        expected = [:]
        pendingUntil = nil
        leaseUntil = nil
        activeCurve = nil
        curveResponses = [:]
        if !failures.isEmpty {
            state = .recoveryRequired(failures)
        } else if let fault {
            state = .faulted(fault)
        } else {
            state = .systemManaged
        }
    }

    private func allowed(_ rpm: Double, for fan: SimulatedBackend.Fan) -> Bool {
        (1...20_000).contains(fan.limits.lowerBound) && (1...20_000).contains(fan.limits.upperBound) &&
            (0...20_000).contains(fan.automaticDemand) &&
            fan.limits.contains(rpm) && rpm >= fan.automaticDemand
    }

    private func freshPeak(_ temperatures: [SensorID: Input], at now: Duration) -> Double? {
        guard !trustedSensors.isEmpty else { return nil }
        var peak = -Double.infinity
        for id in trustedSensors {
            guard let input = temperatures[id], (5...125).contains(input.temperature),
                  input.sampledAt <= now, now - input.sampledAt < .seconds(3) else { return nil }
            peak = max(peak, input.temperature)
        }
        return peak
    }
}
