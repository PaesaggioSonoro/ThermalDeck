import ThermalCore

/// Drives the in-memory fan plant for the explicitly requested demo session.
public struct DemoCooling {
    public enum Mode: String {
        case automatic = "Automatic"
        case custom = "Custom Curve"
        case maximum = "Maximum"
        case unconfirmed = "Automatic unconfirmed"
    }

    private enum Profile {
        case automatic, custom(PercentFanCurve)
    }

    private static let sensorIDs: Set<SensorID> = [.init(rawValue: "DEMO-CPU"), .init(rawValue: "DEMO-GPU")]
    private static let fanIDs: Set<FanID> = [.init(rawValue: 0), .init(rawValue: 1)]

    private let origin: ContinuousClock.Instant
    private var coordinator = SimulatedCoordinator(backend: SimulatedBackend(), trustedSensors: sensorIDs)
    private var latest: Snapshot?
    private var sampledAt: Duration = .zero
    private var profile: Profile = .automatic
    private var maximum = false
    public private(set) var notice: String?

    public init(startingAt origin: ContinuousClock.Instant = .now) { self.origin = origin }

    public var mode: Mode {
        if case .recoveryRequired = coordinator.state { return .unconfirmed }
        if maximum { return .maximum }
        if case .custom = profile { return .custom }
        return .automatic
    }

    public var previousMode: Mode? {
        guard maximum else { return nil }
        if case .custom = profile { return .custom }
        return .automatic
    }

    public var applying: Bool { coordinator.state == .preparing }

    public mutating func update(_ snapshot: Snapshot, at now: ContinuousClock.Instant = .now) -> Snapshot {
        guard snapshot.simulated else { return snapshot }
        latest = snapshot
        sampledAt = origin.duration(to: now)
        updatePlant(snapshot, at: now)
        if maximum || mode == .custom {
            coordinator.heartbeat(at: sampledAt)
            coordinator.tick(temperatures: inputs(at: now), at: sampledAt)
            switch coordinator.state {
            case .preparing, .manualActive, .curveActive: break
            case .recoveryRequired:
                profile = .automatic
                maximum = false
                notice = "Automatic cooling could not be confirmed for both demo fans."
            default:
                profile = .automatic
                maximum = false
                notice = "Demo cooling stopped and returned to Automatic."
            }
        }
        return presentedSnapshot(at: now) ?? snapshot
    }

    public func canStart(at now: ContinuousClock.Instant = .now) -> Bool {
        mode != .unconfirmed && Set(coordinator.backend.fans.keys) == Self.fanIDs &&
            inputs(at: now).count == Self.sensorIDs.count
    }

    public mutating func toggleMaximum(at now: ContinuousClock.Instant = .now) {
        let elapsed = origin.duration(to: now)
        if maximum {
            // Restore system mode even if the previous curve can no longer be safely reapplied.
            let previous = profile
            restoreAutomatic(at: now)
            if case let .custom(curve) = previous {
                activateCustom(curve, at: now)
            }
            return
        }
        guard canStart(at: now) else { return }
        let previous = profile
        restoreAutomatic(at: now)
        guard mode == .automatic else { return }
        if coordinator.startMaximum(temperatures: inputs(at: now), at: elapsed) {
            profile = previous
            maximum = true
        } else {
            notice = "Maximum speed could not be applied. Demo cooling is Automatic."
        }
    }

    public mutating func activateCustom(_ curve: PercentFanCurve, at now: ContinuousClock.Instant = .now) {
        restoreAutomatic(at: now)
        guard mode == .automatic else { return }
        if coordinator.start(sharedCurve: curve, temperatures: inputs(at: now), at: origin.duration(to: now)) {
            profile = .custom(curve)
        } else {
            notice = "The curve could not be applied. Check that it meets the automatic cooling demand for both demo fans."
        }
    }

    public mutating func restoreAutomatic(at now: ContinuousClock.Instant = .now) {
        coordinator.automatic(at: origin.duration(to: now))
        profile = .automatic
        maximum = false
        notice = mode == .unconfirmed ? "Automatic cooling could not be confirmed for both demo fans." : nil
    }

    public mutating func suspend(at now: ContinuousClock.Instant = .now) {
        restoreAutomatic(at: now)
        latest = nil
        coordinator.backend.fans.removeAll()
    }

    public func presentedSnapshot(at now: ContinuousClock.Instant = .now) -> Snapshot? {
        guard let latest, mode != .automatic else { return latest }
        let fans = latest.fans.map { fan in
            guard let simulated = coordinator.backend.fans[fan.id], simulated.mode == .manual,
                  !fan.speed.hasExpired(at: now) else { return fan }
            return Fan(
                id: fan.id, speed: Reading(simulated.actual, within: 0...20_000, at: fan.speed.timestamp,
                                           sampledAt: now, validity: now.duration(to: fan.speed.expiresAt)),
                minimum: fan.minimum, maximum: fan.maximum, target: simulated.target, mode: .manual
            )
        }
        return Snapshot(machine: latest.machine, temperatures: latest.temperatures, fans: fans,
                        fanCount: latest.fanCount, battery: latest.battery, health: latest.health,
                        timestamp: latest.timestamp, simulated: true)
    }

    private func inputs(at now: ContinuousClock.Instant) -> [SensorID: SimulatedCoordinator.Input] {
        var result: [SensorID: SimulatedCoordinator.Input] = [:]
        for sensor in latest?.temperatures ?? [] where Self.sensorIDs.contains(sensor.id) {
            if let temperature = sensor.reading.freshValue(at: now) {
                result[sensor.id] = .init(temperature: temperature, sampledAt: sampledAt)
            }
        }
        return result
    }

    private mutating func updatePlant(_ sample: Snapshot, at now: ContinuousClock.Instant) {
        var fans: [FanID: SimulatedBackend.Fan] = [:]
        for fan in sample.fans where Self.fanIDs.contains(fan.id) {
            guard let rpm = fan.speed.freshValue(at: now),
                  let minimum = fan.minimum, let maximum = fan.maximum,
                  minimum.isFinite, maximum.isFinite, minimum <= maximum else { continue }
            var plantFan = coordinator.backend.fans[fan.id]
                ?? .init(limits: minimum...maximum, automaticDemand: rpm, actual: rpm)
            plantFan.limits = minimum...maximum
            plantFan.automaticDemand = rpm
            if plantFan.mode == .system { plantFan.actual = rpm }
            fans[fan.id] = plantFan
        }
        coordinator.backend.fans = fans
    }
}
