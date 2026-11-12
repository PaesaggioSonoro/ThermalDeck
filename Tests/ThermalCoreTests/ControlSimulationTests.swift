import Foundation
import Testing
@testable import ControlSimulation
import ThermalCore

private let first = FanID(rawValue: 0)
private let second = FanID(rawValue: 1)
private let cpu = SensorID(rawValue: "fixture.cpu")
private let gpu = SensorID(rawValue: "fixture.gpu")
private let setpoints = [first: 2400.0, second: 2300.0]

private func rig() -> SimulatedCoordinator {
    var backend = SimulatedBackend()
    backend.fans[first] = .init(limits: 1500...6000, automaticDemand: 1600, actual: 1600)
    backend.fans[second] = .init(limits: 1200...5500, automaticDemand: 1500, actual: 1500)
    return SimulatedCoordinator(backend: backend, trustedSensors: [cpu, gpu])
}

private func frame(_ t: Duration, cpuValue: Double = 55) -> [SensorID: SimulatedCoordinator.Input] {
    [cpu: .init(temperature: cpuValue, sampledAt: t), gpu: .init(temperature: 47, sampledAt: t)]
}

private enum StartFailure: CaseIterable {
    case invalid, missing, stale, future, outside, noFan, unexpectedLimits, unsupported, unauthorized, mode, write
}

@Test(arguments: StartFailure.allCases)
private func startRejectsUnverifiedInputsOrRestoresPartialWrite(_ failure: StartFailure) {
    var sim = rig()
    var input = frame(.zero)
    var targets = setpoints
    var expected: SimulatedCoordinator.State = .faulted(.unverified)
    switch failure {
    case .invalid: input[cpu]?.temperature = .nan; expected = .faulted(.telemetry)
    case .missing: input.removeValue(forKey: gpu); expected = .faulted(.telemetry)
    case .stale: input[cpu]?.sampledAt = .seconds(-3); expected = .faulted(.telemetry)
    case .future: input[cpu]?.sampledAt = .seconds(1); expected = .faulted(.telemetry)
    case .outside: targets[first] = 6001
    case .noFan: sim.backend.fans = [:]
    case .unexpectedLimits: sim.backend.fans[first]?.limits = 0...6000
    case .unsupported: sim.backend.modelIsValidated = false; expected = .unsupported
    case .unauthorized: sim.authorized = false; expected = .faulted(.unauthorized)
    case .mode: sim.backend.modeWriteFails = [second]; expected = .faulted(.writeFailed)
    case .write: sim.backend.targetWriteFails = [second]; expected = .faulted(.writeFailed)
    }
    let outcome1 = sim.start(targets: targets, temperatures: input, at: .zero)
    #expect(!outcome1)
    #expect(sim.state == expected)
    #expect(sim.backend.fans.values.allSatisfy { $0.mode == .system && $0.target == nil })
}

private enum ActiveFailure: CaseIterable {
    case stale, invalid, read, write, limits, missingFan, lease, disconnect, lostState, exit
    case clientCrash, sleep, wake, interference, revoked, changedModel, partialRestore
}

@Test(arguments: ActiveFailure.allCases)
private func activeControlFaultsRestoreOrExposeUnverifiedFans(_ failure: ActiveFailure) throws {
    var sim = rig()
    let curve = try FanCurve(points: [.init(celsius: 45, rpm: 1800), .init(celsius: 85, rpm: 4200)])
    let mode = failure == .write ? curve : nil
    let outcome2 = sim.start(targets: setpoints, curve: mode, temperatures: frame(.zero), at: .zero)
    #expect(outcome2)
    sim.tick(temperatures: frame(.seconds(2)), at: .seconds(2))
    #expect(sim.state == (mode == nil ? .manualActive : .curveActive))
    let next = Duration.seconds(3)
    var expected: SimulatedCoordinator.State = .faulted(.lifecycle)
    switch failure {
    case .stale:
        sim.tick(temperatures: frame(.zero), at: next); expected = .faulted(.telemetry)
    case .invalid:
        sim.tick(temperatures: frame(next, cpuValue: 999), at: next); expected = .faulted(.telemetry)
    case .read:
        sim.backend.readFails = true
        sim.tick(temperatures: frame(next), at: next); expected = .recoveryRequired([first, second])
    case .write:
        sim.backend.targetWriteFails = [first]
        sim.tick(temperatures: frame(next, cpuValue: 100), at: next); expected = .faulted(.writeFailed)
    case .limits:
        sim.backend.fans[first]?.limits = 1700...6000
        sim.tick(temperatures: frame(next), at: next); expected = .faulted(.limitsChanged)
    case .missingFan:
        sim.backend.fans.removeValue(forKey: second)
        sim.tick(temperatures: frame(next), at: next); expected = .recoveryRequired([second])
    case .lease, .clientCrash:
        sim.heartbeat(at: .seconds(8))
        sim.tick(temperatures: frame(.seconds(8)), at: .seconds(8)); expected = .faulted(.leaseExpired)
    case .disconnect:
        sim.disconnect(at: next); expected = .faulted(.disconnected)
    case .lostState:
        sim.lostServiceState(at: next); expected = .faulted(.lostState)
    case .exit, .sleep:
        sim.lifecycleEnds(at: next)
    case .wake:
        sim.lifecycleEnds(at: next)
        sim.tick(temperatures: frame(.seconds(60)), at: .seconds(60))
    case .interference:
        sim.backend.fans[second]?.mode = .external
        sim.tick(temperatures: frame(next), at: next); expected = .recoveryRequired([second])
    case .revoked:
        sim.authorized = false
        sim.tick(temperatures: frame(next), at: next); expected = .faulted(.unauthorized)
    case .changedModel:
        sim.backend.modelIsValidated = false
        sim.tick(temperatures: frame(next), at: next); expected = .faulted(.unverified)
    case .partialRestore:
        sim.backend.restoreFails = [second]
        sim.lifecycleEnds(at: next); expected = .recoveryRequired([second])
    }
    #expect(sim.state == expected)
    #expect(sim.backend.fans[first]?.mode == .system)
    if case let .recoveryRequired(fans) = sim.state {
        #expect(!fans.isEmpty)
        let outcome3 = sim.start(targets: setpoints, temperatures: frame(next), at: next)
        #expect(!outcome3)
    } else {
        #expect(sim.backend.fans[second]?.mode == .system)
    }
}

@Test func pendingProfileChangesAndSlowMechanicalReadbackAreRecovered() {
    var sim = rig()
    sim.backend.settleDelay = .seconds(10)
    let outcome4 = sim.start(targets: setpoints, temperatures: frame(.zero), at: .zero)
    #expect(outcome4)
    #expect(sim.state == .preparing)
    let outcome5 = sim.start(targets: setpoints, temperatures: frame(.seconds(1)), at: .seconds(1))
    #expect(!outcome5)
    #expect(sim.state == .faulted(.pendingCommand))
    #expect(sim.backend.fans.values.allSatisfy { $0.mode == .system })
    let outcome6 = sim.start(targets: setpoints, temperatures: frame(.seconds(2)), at: .seconds(2))
    #expect(outcome6)
    sim.tick(temperatures: frame(.seconds(7)), at: .seconds(7))
    #expect(sim.state == .faulted(.settleTimeout))
    sim.automatic(at: .seconds(8))
    #expect(sim.state == .systemManaged)
}

@Test func fanCurveValidatesDecodingAndInterpolatesWithClamping() throws {
    let curve = try FanCurve(points: [.init(celsius: 40, rpm: 1500), .init(celsius: 80, rpm: 4500)])
    #expect(curve.target(for: 30) == 1500)
    #expect(curve.target(for: 60) == 3000)
    #expect(curve.target(for: 90) == 4500)
    #expect(curve.target(for: .nan) == nil)
    let encoded = try JSONEncoder().encode(curve)
    #expect(try JSONDecoder().decode(FanCurve.self, from: encoded) == curve)
    let invalid = Data(#"[{"celsius":80,"rpm":2000},{"celsius":80,"rpm":3000}]"#.utf8)
    #expect(throws: FanCurve.ValidationError.self) { try JSONDecoder().decode(FanCurve.self, from: invalid) }
    #expect(throws: FanCurve.ValidationError.self) {
        try FanCurve(points: [.init(celsius: 40, rpm: 3000), .init(celsius: 80, rpm: 2000)])
    }
}

@Test func sharedCurveScalesBothFansAndRejectsTargetsBelowTheCoolingFloor() throws {
    var sim = rig()
    let startFrame = frame(.zero, cpuValue: 60)
    let tooLow = try PercentFanCurve(points: [.init(celsius: 40, percent: 0), .init(celsius: 80, percent: 100)])
    let rejected = sim.start(sharedCurve: tooLow, temperatures: startFrame, at: .zero)
    #expect(!rejected)
    #expect(sim.backend.fans[first]?.mode == .system)
    #expect(sim.backend.fans[second]?.mode == .system)

    let shared = try PercentFanCurve(points: [.init(celsius: 40, percent: 50), .init(celsius: 80, percent: 100)])
    let accepted = sim.start(sharedCurve: shared, temperatures: startFrame, at: .zero)
    #expect(accepted)
    #expect(sim.backend.fans[first]?.target == 4_500)
    #expect(sim.backend.fans[second]?.target == 4_125)
    sim.tick(temperatures: frame(.seconds(2), cpuValue: 60), at: .seconds(2))
    #expect(sim.state == .curveActive)
    sim.tick(temperatures: frame(.seconds(3), cpuValue: 80), at: .seconds(3))
    #expect(sim.backend.fans[first]?.target == 6_000)
    #expect(sim.backend.fans[second]?.target == 5_500)
}

@Test func fanCurveHoldsSmallDeclinesAndBoundsItsRamp() throws {
    let curve = try FanCurve(points: [.init(celsius: 40, rpm: 1500), .init(celsius: 80, rpm: 4500)])
    var response = CurveResponse()
    let outcome7 = response.step(curve: curve, celsius: 80, elapsed: .seconds(1), baseline: 1500)
    #expect(outcome7 == 2000)
    let outcome8 = response.step(curve: curve, celsius: 79, elapsed: .seconds(1), baseline: 1500)
    #expect(outcome8 == 2500)
    let outcome9 = response.step(curve: curve, celsius: 40, elapsed: .seconds(1), baseline: 1500)
    #expect(outcome9 == 2300)
    let outcome10 = response.step(curve: curve, celsius: nil, elapsed: .seconds(1), baseline: 1500)
    #expect(outcome10 == nil)
    let outcome11 = response.step(curve: curve, celsius: 50, elapsed: .zero, baseline: 1500)
    #expect(outcome11 == 1500)
}
