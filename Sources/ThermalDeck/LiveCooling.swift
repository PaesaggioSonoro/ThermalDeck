import Foundation
import HardwareAccess
import Observation
import ServiceManagement
import ThermalCore

@MainActor @Observable
final class LiveCooling {
    enum Availability: Equatable {
        case unsupported, needsSignedBuild, missingHelper, needsSetup, needsApproval, ready

        var message: String? {
            switch self {
            case .unsupported: "Live fan control is unavailable for this Mac or macOS build."
            case .needsSignedBuild: "Live fan control needs a signed ThermalDeck build."
            case .missingHelper: "This build does not include the fan control helper."
            case .needsSetup: "Set up the fan control helper to use Max Fans."
            case .needsApproval: "Approve the fan control helper in System Settings."
            case .ready: nil
            }
        }
    }

    private enum Command { case status, maximum, automatic }

    private let machine: Machine
    private let service: SMAppService
    private let serviceName: String
    private let hasHelper: Bool
    private let requirement: String?
    @ObservationIgnored private var connection: NSXPCConnection?
    @ObservationIgnored private var connectionID: UUID?
    @ObservationIgnored private var pending: [UUID: CheckedContinuation<FanControlResult, Never>] = [:]
    @ObservationIgnored private var watch: Task<Void, Never>?
    @ObservationIgnored private var restoration: Task<Bool, Never>?
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var lastCheck: ContinuousClock.Instant?

    private(set) var availability: Availability
    private(set) var state: FanControlResult = .unavailable
    private(set) var changing = false
    private(set) var needsRestoration = false
    private(set) var notice: String?

    init(machine: Machine) {
        self.machine = machine
        let identifier = Bundle.main.bundleIdentifier ?? "org.thermaldeck.local"
        serviceName = identifier + FanControlServiceIdentity.helperSuffix
        service = SMAppService.daemon(plistName: serviceName + ".plist")
        let contents = Bundle.main.bundleURL.appending(path: "Contents")
        hasHelper = FileManager.default.isExecutableFile(atPath: contents.appending(path: "MacOS/thermal-fan-helper").path) &&
            FileManager.default.fileExists(atPath: contents.appending(path: "Library/LaunchDaemons/\(serviceName).plist").path)
        let signing = FanControlServiceIdentity.current()
        requirement = signing?.identifier == identifier ? signing?.peerRequirement(identifier: serviceName) : nil
        availability = .unsupported
        refreshAvailability()
    }

    var coolingLabel: String {
        if changing { return needsRestoration ? "Changing fan control…" : "Checking fan control…" }
        return switch state {
        case .maximum: "Maximum"
        case .external, .busy: "Controlled by another app"
        case .unconfirmed: "Automatic unconfirmed"
        default: "Automatic"
        }
    }

    var canToggle: Bool {
        !changing && (needsRestoration ||
            (availability == .ready && [.automatic, .failed, .stopped, .thermalPressure].contains(state)))
    }

    func refresh() {
        guard !changing, watch == nil,
              lastCheck.map({ $0.duration(to: .now) >= .seconds(2) }) ?? true else { return }
        lastCheck = .now
        refreshAvailability()
        guard availability == .ready else { return }
        let requestRevision = revision
        watch = Task { [weak self] in
            guard let self else { return }
            let result = await send(.status)
            watch = nil
            guard revision == requestRevision, !changing else { return }
            if result == .unavailable && needsRestoration {
                state = .unconfirmed
                notice = "System control could not be confirmed. Choose Restore Automatic to retry."
                return
            }
            apply(result)
        }
    }

    func setUp() {
        refreshAvailability()
        if availability == .needsApproval {
            SMAppService.openSystemSettingsLoginItems()
        } else if availability == .needsSetup {
            do {
                try service.register()
                notice = nil
            } catch {
                notice = "Could not register the fan control helper."
            }
            refreshAvailability()
        }
    }

    func toggle() {
        guard canToggle else { return }
        if needsRestoration {
            Task { await restore() }
            return
        }
        changing = true
        needsRestoration = true
        revision += 1
        let requestRevision = revision
        notice = nil
        Task {
            guard revision == requestRevision else { return }
            let result = await send(.maximum)
            guard revision == requestRevision else { return }
            changing = false
            if result == .unavailable {
                state = .unconfirmed
                notice = "The helper connection was lost. Choose Restore Automatic to verify system control."
                return
            }
            apply(result)
        }
    }

    @discardableResult
    func restore() async -> Bool {
        if let restoration { return await restoration.value }
        guard needsRestoration else { return true }
        revision += 1
        changing = true
        let task = Task { await performRestoration() }
        restoration = task
        return await task.value
    }

    private func performRestoration() async -> Bool {
        let result = await send(.automatic)
        restoration = nil
        changing = false
        if result == .automatic {
            notice = nil
            apply(result)
            return true
        }
        state = .unconfirmed
        notice = "System control could not be confirmed. Choose Restore Automatic to retry."
        return false
    }

    private func refreshAvailability() {
        if !MaximumFanController.supports(machine) {
            availability = .unsupported
        } else if requirement == nil {
            availability = .needsSignedBuild
        } else if !hasHelper {
            availability = .missingHelper
        } else {
            availability = switch service.status {
            case .enabled: .ready
            case .requiresApproval: .needsApproval
            default: .needsSetup
            }
        }
    }

    private func apply(_ result: FanControlResult) {
        if result == .automatic && [.failed, .stopped, .thermalPressure].contains(state) { return }
        state = result
        needsRestoration = result == .maximum || result == .unconfirmed
        notice = switch result {
        case .failed: "Maximum speed could not be verified. The fans returned to Automatic."
        case .stopped: "The override ended and the fans returned to Automatic."
        case .unavailable: "The fan control helper could not be reached."
        case .unsupported: "The fan control helper could not verify this Mac."
        case .unconfirmed: "System control could not be confirmed. Choose Restore Automatic to retry."
        case .thermalPressure: "Try Max Fans again after macOS thermal pressure drops."
        default: nil
        }
    }

    private func send(_ command: Command) async -> FanControlResult {
        guard let requirement, service.status == .enabled else { return .unavailable }
        let link: NSXPCConnection
        if let connection {
            link = connection
        } else {
            let id = UUID()
            link = NSXPCConnection(machServiceName: serviceName, options: .privileged)
            link.setCodeSigningRequirement(requirement)
            link.remoteObjectInterface = NSXPCInterface(with: FanControlService.self)
            link.invalidationHandler = { [weak self] in
                Task { @MainActor in
                    guard let self, self.connectionID == id else { return }
                    self.connection = nil
                    self.connectionID = nil
                    let outstanding = self.pending
                    self.pending.removeAll()
                    for reply in outstanding.values { reply.resume(returning: .unavailable) }
                }
            }
            link.interruptionHandler = { [weak self] in
                Task { @MainActor in
                    guard let self, self.connectionID == id else { return }
                    self.connection?.invalidate()
                }
            }
            connection = link
            connectionID = id
            link.resume()
        }

        let id = UUID()
        return await withCheckedContinuation { continuation in
            pending[id] = continuation
            let reply: @Sendable (Int) -> Void = { [weak self] value in
                Task { @MainActor in
                    self?.pending.removeValue(forKey: id)?.resume(returning: FanControlResult(rawValue: value) ?? .unavailable)
                }
            }
            let proxy = link.remoteObjectProxyWithErrorHandler { _ in reply(FanControlResult.unavailable.rawValue) }
            guard let service = proxy as? FanControlService else {
                reply(FanControlResult.unavailable.rawValue)
                return
            }
            switch command {
            case .status: service.status(reply: reply)
            case .maximum: service.maximum(reply: reply)
            case .automatic: service.automatic(reply: reply)
            }
            Task { [weak self] in
                // Quit can queue behind a start that is already rolling back.
                try? await Task.sleep(for: .seconds(45))
                self?.pending.removeValue(forKey: id)?.resume(returning: .unavailable)
            }
        }
    }
}
