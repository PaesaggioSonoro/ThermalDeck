import Foundation
import Observation
import OSLog
import ThermalCore

@MainActor @Observable
final class AppModel {
    static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.thermaldeck.local", category: "monitoring")

    private let source: any TelemetrySource
    private let defaults: UserDefaults
    private var polling: Task<Void, Never>?
    private var revision = 0
    private var visible = false

    private(set) var snapshot: Snapshot
    private(set) var preferencesNotice: String?
    var preferences: Preferences {
        didSet {
            preferences.normalize()
            if !source.simulated, preferencesNotice == nil, let data = try? JSONEncoder().encode(preferences) {
                defaults.set(data, forKey: "preferences")
            }
            if oldValue.interval != preferences.interval { restart() }
        }
    }

    init(source: any TelemetrySource, defaults: UserDefaults = .standard) {
        self.source = source
        self.defaults = defaults
        snapshot = Snapshot(machine: source.machine, health: .waiting, simulated: source.simulated)
        if !source.simulated, let data = defaults.data(forKey: "preferences") {
            if var saved = try? JSONDecoder().decode(Preferences.self, from: data), saved.version == Preferences.schema {
                saved.normalize()
                preferences = saved
            } else {
                preferences = Preferences()
                preferencesNotice = "Saved settings could not be read. Defaults are active for this session."
            }
        } else {
            preferences = Preferences()
        }
        restart()
    }

    func dashboardVisible(_ value: Bool) {
        guard visible != value else { return }
        visible = value
        restart()
    }

    func restart(reset: Bool = false) {
        polling?.cancel()
        revision += 1
        let current = revision
        let interval = visible ? preferences.interval : max(5, preferences.interval)
        polling = Task { [weak self, source] in
            if reset { await source.reset() }
            while !Task.isCancelled {
                let next = ContinuousClock.now.advanced(by: .seconds(interval))
                let sample = await source.sample(validity: .seconds(interval * 3))
                guard !Task.isCancelled, let self, self.revision == current else { return }
                if self.snapshot.health != sample.health {
                    Self.log.info("Monitoring state: \(sample.health.label, privacy: .public)")
                }
                self.snapshot = sample
                try? await ContinuousClock().sleep(until: next, tolerance: .milliseconds(100))
            }
        }
    }

    func temperature(_ value: Double?) -> String {
        guard let value else { return "—" }
        return preferences.unit.displayValue(value).formatted(.number.precision(.fractionLength(0...1))) + " " + preferences.unit.symbol
    }

    func rpm(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0))) + " RPM"
    }
}
