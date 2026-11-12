import Foundation
import Observation
import OSLog
import ThermalCore

@MainActor @Observable
final class AppModel {
    static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.thermaldeck.local", category: "monitoring")

    private let source: any TelemetrySource
    private let defaults: UserDefaults
    private let archive: HistoryArchive?
    @ObservationIgnored private var polling: Task<Void, Never>?
    @ObservationIgnored private var expiryCheck: Task<Void, Never>?
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var archiveRevision = 0
    @ObservationIgnored private var lastArchiveWrite: ContinuousClock.Instant?
    @ObservationIgnored private var loadingArchive = false
    @ObservationIgnored private var alertPolicy = AlertPolicy()
    @ObservationIgnored private var visible = false

    private(set) var snapshot: Snapshot
    private(set) var history = HistoryBuffer()
    private(set) var preferencesNotice: String?
    private(set) var historyNotice: String?

    var preferences: Preferences {
        didSet {
            preferences.normalize()
            if !source.simulated, preferencesNotice == nil, let data = try? JSONEncoder().encode(preferences) {
                defaults.set(data, forKey: "preferences")
            }
            if oldValue.interval != preferences.interval { restart() }
            if oldValue.retention != preferences.retention {
                history.trim(at: .now, retention: preferences.retention)
                lastArchiveWrite = nil
                writeHistoryIfDue(now: .now)
            }
            if oldValue.persistHistory != preferences.persistHistory {
                if preferences.persistHistory {
                    lastArchiveWrite = nil
                    writeHistoryIfDue(now: .now)
                } else {
                    removeArchive()
                }
            }
            if oldValue.thresholdCelsius != preferences.thresholdCelsius { alertPolicy.resetTemperature() }
        }
    }

    init(source: any TelemetrySource, defaults: UserDefaults = .standard) {
        self.source = source
        self.defaults = defaults
        snapshot = Snapshot(machine: source.machine, health: .waiting, simulated: source.simulated)
        if !source.simulated, let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let folder = Bundle.main.bundleIdentifier ?? "org.thermaldeck.local"
            archive = HistoryArchive(url: root.appending(path: folder).appending(path: "History.json"))
        } else {
            archive = nil
        }
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
        if preferences.persistHistory { loadArchive() }
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
        let validity = Duration.seconds(interval * 3)
        polling = Task { [weak self, source] in
            if reset { await source.reset() }
            while !Task.isCancelled {
                let started = ContinuousClock.now
                let sample = await source.sample(validity: validity)
                guard !Task.isCancelled, let self, self.revision == current else { return }
                self.accept(sample, expires: started.advanced(by: validity))
                // Schedule from the end of the call when a slow read consumed the entire interval.
                let next = max(started.advanced(by: .seconds(interval)), .now.advanced(by: .milliseconds(100)))
                try? await ContinuousClock().sleep(until: next, tolerance: .milliseconds(100))
            }
        }
    }

    func clearHistory() {
        history = HistoryBuffer()
        removeArchive()
    }

    func temperature(_ value: Double?) -> String {
        guard let value else { return "—" }
        return preferences.unit.displayValue(value).formatted(.number.precision(.fractionLength(0...1))) + " " + preferences.unit.symbol
    }

    func rpm(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0))) + " RPM"
    }

    private func accept(_ sample: Snapshot, expires: ContinuousClock.Instant) {
        let now = ContinuousClock.now
        if snapshot.health != sample.health {
            Self.log.info("Monitoring state: \(sample.health.label, privacy: .public)")
        }
        snapshot = sample
        if preferences.collectHistory {
            history.append(HistoryRecord(snapshot: sample, now: now), retention: preferences.retention)
            writeHistoryIfDue(now: now)
        } else {
            history.trim(at: sample.timestamp, retention: preferences.retention)
        }
        evaluateAlerts()
        expiryCheck?.cancel()
        if sample.health == .live || sample.health == .partial {
            expiryCheck = Task { [weak self] in
                do {
                    try await ContinuousClock().sleep(until: expires, tolerance: .milliseconds(50))
                    guard let self else { return }
                    self.snapshot = Snapshot(machine: sample.machine, temperatures: sample.temperatures, fans: sample.fans,
                                             fanCount: sample.fanCount,
                                             health: .unavailable("The latest measurements expired."),
                                             simulated: sample.simulated)
                    self.evaluateAlerts()
                    try await ContinuousClock().sleep(for: .seconds(12))
                    self.evaluateAlerts()
                } catch is CancellationError {} catch {
                    Self.log.error("Measurement expiry check failed")
                }
            }
        }
    }

    private func evaluateAlerts() {
        guard preferences.alerts, !source.simulated else { return }
        let peak = snapshot.peak()
        let actions = alertPolicy.evaluate(peak: peak, health: snapshot.health, threshold: preferences.thresholdCelsius)
        for action in actions {
            let detail = action == .highTemperature ?
                "A mapped CPU or GPU zone reached \(temperature(peak))." :
                "Fresh temperature and fan telemetry could not be confirmed."
            Task { await LocalAlerts.deliver(action, detail: detail) }
        }
    }

    private func loadArchive() {
        guard let archive else { return }
        loadingArchive = true
        let revision = archiveRevision
        Task {
            do {
                let saved = try await archive.load()
                if archiveRevision == revision, preferences.persistHistory {
                    history.restore(saved, at: .now, retention: preferences.retention)
                }
            } catch {
                historyNotice = "The saved history file could not be read."
                Self.log.error("History load failed")
            }
            loadingArchive = false
        }
    }

    private func writeHistoryIfDue(now: ContinuousClock.Instant) {
        guard let archive, preferences.collectHistory, preferences.persistHistory, !loadingArchive,
              !history.records.isEmpty,
              lastArchiveWrite.map({ $0.duration(to: now) >= .seconds(30) }) ?? true else { return }
        lastArchiveWrite = now
        archiveRevision += 1
        let revision = archiveRevision
        let records = history.archiveRecords()
        Task {
            do {
                try await archive.save(records, revision: revision)
                if archiveRevision == revision { historyNotice = nil }
            } catch {
                if archiveRevision == revision { historyNotice = "The local history file could not be saved." }
                Self.log.error("History save failed")
            }
        }
    }

    private func removeArchive() {
        guard let archive else { return }
        archiveRevision += 1
        let revision = archiveRevision
        Task {
            do {
                try await archive.clear(revision: revision)
                if archiveRevision == revision { historyNotice = nil }
            } catch {
                if archiveRevision == revision { historyNotice = "The local history file could not be cleared." }
                Self.log.error("History removal failed")
            }
        }
    }
}
