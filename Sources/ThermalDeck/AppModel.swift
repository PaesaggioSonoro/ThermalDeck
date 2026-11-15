import AppKit
import Combine
import ControlSimulation
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
    @ObservationIgnored private var preserveUnreadableArchive = false
    @ObservationIgnored private var alertPolicy = AlertPolicy()
    @ObservationIgnored private var visible = false
    @ObservationIgnored private var sleeping = false
    @ObservationIgnored private var lifecycle: [AnyCancellable] = []

    private(set) var snapshot: Snapshot
    private(set) var history = HistoryBuffer()
    private(set) var preferencesNotice: String?
    private(set) var historyNotice: String?
    private(set) var demoCooling: DemoCooling?
    let liveCooling: LiveCooling?

    private var storedPreferences: Preferences

    var preferences: Preferences {
        get { storedPreferences }
        set {
            var normalized = newValue
            normalized.normalize()
            let oldValue = storedPreferences
            guard normalized != oldValue else { return }
            storedPreferences = normalized
            if !source.simulated, preferencesNotice == nil, let data = try? JSONEncoder().encode(normalized) {
                defaults.set(data, forKey: "preferences")
            }
            if oldValue.interval != normalized.interval { restart() }
            if oldValue.retention != normalized.retention {
                history.trim(at: .now, retention: normalized.retention)
                lastArchiveWrite = nil
                writeHistoryIfDue(now: .now)
            }
            if oldValue.persistHistory != normalized.persistHistory {
                if normalized.persistHistory {
                    lastArchiveWrite = nil
                    writeHistoryIfDue(now: .now)
                } else {
                    removeArchive()
                }
            }
            if oldValue.thresholdCelsius != normalized.thresholdCelsius { alertPolicy.resetTemperature() }
        }
    }

    init(source: any TelemetrySource, defaults: UserDefaults = .standard,
         workspace: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.source = source
        self.defaults = defaults
        demoCooling = source is DemoSource ? DemoCooling() : nil
        liveCooling = source.simulated ? nil : LiveCooling(machine: source.machine)
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
                storedPreferences = saved
            } else {
                storedPreferences = Preferences()
                preferencesNotice = "Saved settings could not be read. Defaults are active for this session."
            }
        } else {
            storedPreferences = Preferences()
        }
        liveCooling?.reportIssue = { [weak self] issue in
            self?.evaluateFanControlAlert(issue)
        }
        if preferences.persistHistory { loadArchive() }
        lifecycle = [
            workspace.publisher(for: NSWorkspace.willSleepNotification).receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.suspend() },
            workspace.publisher(for: NSWorkspace.didWakeNotification).receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.wake() }
        ]
        restart()
    }

    func dashboardVisible(_ value: Bool) {
        guard visible != value else { return }
        visible = value
        restart()
    }

    func restart(reset: Bool = false) {
        guard !sleeping else { return }
        polling?.cancel()
        revision += 1
        let current = revision
        let interval = preferences.pollingInterval(dashboardActive: visible)
        Self.log.info("Polling cadence: \(interval, privacy: .public) seconds")
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

    private func suspend() {
        sleeping = true
        demoCooling?.suspend()
        if let liveCooling, liveCooling.needsRestoration { Task { await liveCooling.restore() } }
        polling?.cancel()
        expiryCheck?.cancel()
        revision += 1
        snapshot = Snapshot(machine: source.machine, health: .paused, simulated: source.simulated)
        if preferences.collectHistory {
            history.append(HistoryRecord(snapshot: snapshot), retention: preferences.retention)
        }
        evaluateAlerts()
        Self.log.info("Monitoring paused for sleep")
    }

    private func wake() {
        sleeping = false
        snapshot = Snapshot(machine: source.machine, health: .waiting, simulated: source.simulated)
        restart(reset: true)
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

    var menuBarValues: [String] {
        preferences.menuBar.readouts.map(menuBarValue)
    }

    var coolingLabel: String {
        guard let demoCooling else { return liveCooling?.coolingLabel ?? "Automatic" }
        return demoCooling.applying ? "Applying " + demoCooling.mode.rawValue + "…" : demoCooling.mode.rawValue
    }

    var canStartMaximumFans: Bool {
        if let demoCooling { return demoCooling.previousMode == nil && demoCooling.canStart() }
        return liveCooling?.needsRestoration == false && liveCooling?.canToggle == true
    }

    var canUseAutomaticCooling: Bool {
        if let demoCooling { return demoCooling.mode != .automatic }
        return liveCooling?.needsRestoration == true && liveCooling?.changing == false
    }

    func useAutomaticCooling() {
        guard canUseAutomaticCooling else { return }
        if let liveCooling {
            Task { await liveCooling.restore() }
        } else {
            restoreAutomaticCooling()
        }
    }

    func toggleMaximumFans() {
        if demoCooling != nil {
            demoCooling?.toggleMaximum()
            showDemoFanState()
        } else {
            liveCooling?.toggle()
        }
    }

    func activateDemoCurve() {
        guard let curve = preferences.storedPercentCurve else { return }
        demoCooling?.activateCustom(curve)
        showDemoFanState()
    }

    func restoreAutomaticCooling() {
        demoCooling?.restoreAutomatic()
        showDemoFanState()
    }

    private func showDemoFanState() {
        guard snapshot.health == .live || snapshot.health == .partial else { return }
        if let presented = demoCooling?.presentedSnapshot() { snapshot = presented }
    }

    func menuBarValue(_ readout: MenuBarReadout) -> String {
        let value = readout.value(in: snapshot)
        if case .fan = readout { return rpm(value) }
        guard let value else { return "—" }
        return preferences.unit.displayValue(value).formatted(.number.precision(.fractionLength(0))) + preferences.unit.symbol
    }

    private func accept(_ sample: Snapshot, expires: ContinuousClock.Instant) {
        let now = ContinuousClock.now
        let sample = demoCooling?.update(sample, at: now) ?? sample
        if snapshot.health != sample.health {
            Self.log.info("Monitoring state: \(sample.health.label, privacy: .public)")
        }
        snapshot = sample
        liveCooling?.refresh()
        if preferences.collectHistory {
            history.append(HistoryRecord(snapshot: sample, selectedSensors: preferences.historySensors, now: now),
                           retention: preferences.retention)
            writeHistoryIfDue(now: now)
        } else {
            let count = history.records.count
            history.trim(at: sample.timestamp, retention: preferences.retention)
            if history.records.count != count {
                lastArchiveWrite = nil
                writeHistoryIfDue(now: now)
            }
        }
        evaluateAlerts()
        expiryCheck?.cancel()
        if sample.health == .live || sample.health == .partial {
            let sampleExpiry = (sample.temperatures.map { $0.reading.expiresAt } + sample.fans.map { $0.speed.expiresAt }).min() ?? expires
            expiryCheck = Task { [weak self] in
                do {
                    try await ContinuousClock().sleep(until: sampleExpiry, tolerance: .milliseconds(50))
                    guard let self else { return }
                    self.restoreAutomaticCooling()
                    let last = self.snapshot
                    self.snapshot = Snapshot(machine: last.machine, temperatures: last.temperatures, fans: last.fans,
                                             fanCount: last.fanCount,
                                             health: .unavailable("The latest measurements expired."),
                                             simulated: last.simulated)
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

    private func evaluateFanControlAlert(_ issue: MonitorAlert?) {
        guard preferences.alerts,
              let alert = alertPolicy.evaluateFanControl(issue) else { return }
        let detail: String
        switch alert {
        case .fanControlStopped: detail = "The helper ended Max Fans and confirmed macOS has control."
        case .fanControlDisconnected: detail = "Open ThermalDeck and use Restore Automatic to check who controls the fans."
        case .fanRestoreUnconfirmed: detail = "Open ThermalDeck and retry Restore Automatic."
        default: return
        }
        Task { await LocalAlerts.deliver(alert, detail: detail) }
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
                    if !saved.isEmpty {
                        loadingArchive = false
                        writeHistoryIfDue(now: .now)
                    }
                }
            } catch {
                if archiveRevision == revision {
                    preserveUnreadableArchive = true
                    historyNotice = "The saved history file could not be read. Clear History to start a new archive."
                }
                Self.log.error("History load failed")
            }
            loadingArchive = false
        }
    }

    private func writeHistoryIfDue(now: ContinuousClock.Instant) {
        guard let archive, preferences.persistHistory, !loadingArchive, !preserveUnreadableArchive,
              lastArchiveWrite.map({ $0.duration(to: now) >= .seconds(30) }) ?? true else { return }
        guard !history.records.isEmpty else {
            removeArchive()
            return
        }
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
        preserveUnreadableArchive = false
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
