import Foundation
import Testing
import ThermalCore
@testable import ThermalDeck

@MainActor @Test func preferenceEditsNormalizeAndPersist() throws {
    let suite = "ThermalDeckTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let source = FixtureSource()
    let model = AppModel(source: source, defaults: defaults)
    model.preferences.appearance = .light
    model.preferences.unit = .fahrenheit
    model.preferences.interval = 2
    model.preferences.interval = 99
    model.preferences.thresholdCelsius = 80
    model.preferences.thresholdCelsius = .infinity

    #expect(model.preferences.appearance == .light)
    #expect(model.preferences.unit == .fahrenheit)
    #expect(model.preferences.interval == 1)
    #expect(model.preferences.thresholdCelsius == 90)

    let saved = try #require(defaults.data(forKey: "preferences"))
    #expect(try JSONDecoder().decode(Preferences.self, from: saved) == model.preferences)
    #expect(AppModel(source: source, defaults: defaults).preferences == model.preferences)
}

private struct FixtureSource: TelemetrySource {
    let machine = Machine(model: "Fixture", chip: "Fixture", os: "Fixture")
    let simulated = false

    func sample(validity: Duration) async -> Snapshot {
        Snapshot(machine: machine, health: .waiting, simulated: simulated)
    }

    func reset() async {}
}
