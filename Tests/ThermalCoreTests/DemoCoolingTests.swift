import Foundation
import Testing
import ThermalCore
import ControlSimulation

private func demoSample(at time: ContinuousClock.Instant, demand: Double = 1_600) -> Snapshot {
    let machine = Machine(model: "Demo", chip: "Demo", os: "Demo")
    let date = Date()
    let temperatures = [("DEMO-CPU", SensorGroup.cpu), ("DEMO-GPU", .gpu)].map { id, group in
        Temperature(id: .init(rawValue: id), group: group,
                    reading: Reading(60, within: 0...125, at: date, sampledAt: time), format: "Demo")
    }
    let fans = [6_000.0, 5_500].enumerated().map { id, maximum in
        Fan(id: .init(rawValue: id), speed: Reading(demand, within: 0...20_000, at: date, sampledAt: time),
            minimum: 1_500, maximum: maximum, target: nil, mode: .system)
    }
    return Snapshot(machine: machine, temperatures: temperatures, fans: fans, fanCount: 2,
                    health: .live, timestamp: date, simulated: true)
}

@Test func maxFansUsesBothIndividualLimitsAndReturnsToAutomatic() {
    let start = ContinuousClock.now
    var cooling = DemoCooling(startingAt: start)
    _ = cooling.update(demoSample(at: start), at: start)
    cooling.toggleMaximum(at: start)
    #expect(cooling.previousMode == .automatic)
    #expect(cooling.applying)
    #expect(cooling.presentedSnapshot(at: start)?.fans.map(\.target) == [6_000, 5_500])
    let settled = start.advanced(by: .seconds(2))
    let active = cooling.update(demoSample(at: settled), at: settled)
    #expect(cooling.mode == .maximum)
    #expect(!cooling.applying)
    #expect(active.fans.map { $0.speed.freshValue(at: settled) } == [6_000, 5_500])
    cooling.toggleMaximum(at: settled)
    #expect(cooling.mode == .automatic)
    #expect(cooling.presentedSnapshot(at: settled)?.fans.map(\.mode) == [.system, .system])
}

@Test func maxFansRestoresThePriorCurveEvenWhenToggledDuringSpinUp() throws {
    let start = ContinuousClock.now
    let curve = try PercentFanCurve(points: [.init(celsius: 40, percent: 50), .init(celsius: 80, percent: 90)])
    var cooling = DemoCooling(startingAt: start)
    _ = cooling.update(demoSample(at: start), at: start)
    cooling.activateCustom(curve, at: start)
    let initialTargets = cooling.presentedSnapshot(at: start)?.fans.map(\.target)
    #expect(initialTargets == [4_200, 3_850])
    cooling.toggleMaximum(at: start)
    #expect(cooling.previousMode == .custom)
    cooling.toggleMaximum(at: start)
    #expect(cooling.mode == .custom)
    #expect(cooling.presentedSnapshot(at: start)?.fans.map(\.target) == initialTargets)
    cooling.toggleMaximum(at: start)
    cooling.restoreAutomatic(at: start) // Normal Quit uses this path instead of resuming the curve.
    #expect(cooling.mode == .automatic)
    #expect(cooling.previousMode == nil)
    #expect(cooling.presentedSnapshot(at: start)?.fans.map(\.mode) == [.system, .system])
}

@Test func maxFansFallsBackToAutomaticIfPriorCurveIsNoLongerSafe() throws {
    let start = ContinuousClock.now
    let curve = try PercentFanCurve(points: [.init(celsius: 40, percent: 50), .init(celsius: 80, percent: 90)])
    var cooling = DemoCooling(startingAt: start)
    _ = cooling.update(demoSample(at: start), at: start)
    cooling.activateCustom(curve, at: start)
    cooling.toggleMaximum(at: start)
    let later = start.advanced(by: .seconds(2))
    _ = cooling.update(demoSample(at: later, demand: 3_500), at: later)
    cooling.toggleMaximum(at: later)
    #expect(cooling.mode == .automatic)
    #expect(cooling.notice != nil)
    #expect(cooling.presentedSnapshot(at: later)?.fans.map(\.mode) == [.system, .system])
}
