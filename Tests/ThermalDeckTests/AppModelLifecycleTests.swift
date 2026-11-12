import AppKit
import Observation
import Testing
import ThermalCore
@testable import ThermalDeck

@MainActor @Test func workspaceSleepClearsTelemetryAndWakeResetsTheSource() async throws {
    let workspace = NotificationCenter()
    let model = AppModel(source: LifecycleSource(), workspace: workspace)
    try await waitForSnapshot(model) { $0.peak() == 40 }

    workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
    try await waitForSnapshot(model) { $0.health == .paused }
    #expect(model.snapshot.peak() == nil)
    #expect(model.history.records.last?.values.isEmpty == true)

    workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
    try await waitForSnapshot(model) { $0.peak() == 45 }
    #expect(model.snapshot.health == .live)
}

@MainActor @Test func demoFanOverrideReachesBothLiveReadoutsAndDoesNotResumeAfterWake() async throws {
    let workspace = NotificationCenter()
    let model = AppModel(source: DemoSource(), workspace: workspace)
    model.preferences.interval = 0.5
    model.dashboardVisible(true)
    try await waitForSnapshot(model) { $0.fans.count == 2 }

    model.toggleMaximumFans()
    try await waitForSnapshot(model, timeout: .seconds(5)) { snapshot in
        snapshot.fans.count == 2 && snapshot.fans.allSatisfy {
            $0.mode == .manual && $0.speed.freshValue() == $0.maximum
        }
    }
    #expect(model.coolingLabel == "Maximum")
    model.toggleMaximumFans()
    #expect(model.coolingLabel == "Automatic")
    #expect(model.snapshot.fans.map(\.mode) == [.system, .system])

    model.toggleMaximumFans()
    workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
    try await waitForSnapshot(model) { $0.health == .paused }
    workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
    try await waitForSnapshot(model) { $0.fans.count == 2 }
    #expect(model.coolingLabel == "Automatic")
    #expect(model.snapshot.fans.map(\.mode) == [.system, .system])
}

@MainActor
private func waitForSnapshot(
    _ model: AppModel, timeout: Duration = .seconds(3), matching predicate: @escaping @Sendable (Snapshot) -> Bool
) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            try await observeSnapshots(model, matching: predicate)
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw SnapshotTimeout()
        }
        defer { group.cancelAll() }
        _ = try await group.next()
    }
}

@MainActor
private func observeSnapshots(_ model: AppModel, matching predicate: (Snapshot) -> Bool) async throws {
    while !predicate(model.snapshot) {
        let (updates, continuation) = AsyncStream<Void>.makeStream()
        withObservationTracking { _ = model.snapshot } onChange: {
            continuation.finish()
        }
        for await _ in updates {}
        try Task.checkCancellation()
    }
}

private struct SnapshotTimeout: Error {}

private actor LifecycleSource: TelemetrySource {
    nonisolated let machine = Machine(model: "Fixture", chip: "Fixture", os: "Fixture")
    nonisolated let simulated = true
    private var temperature = 40.0

    func sample(validity: Duration) -> Snapshot {
        let sensor = Temperature(id: SensorID(rawValue: "TEST"), group: .cpu,
                                 reading: Reading(temperature, within: 1...125, at: .now, validity: validity),
                                 format: "Fixture")
        return Snapshot(machine: machine, temperatures: [sensor], health: .live, simulated: simulated)
    }

    func reset() { temperature += 5 }
}
