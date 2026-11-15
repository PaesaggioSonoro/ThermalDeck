import AppKit
import Foundation
import HardwareAccess
import Observation
import OSLog
import ServiceManagement
import ThermalCore

@MainActor @Observable
final class LiveCooling {
    enum Availability: Equatable {
        case unsupported, needsSignedBuild, needsLocalInstall, needsLocalUpdate, missingHelper, needsSetup, needsApproval, ready

        var message: String? {
            switch self {
            case .unsupported: "Live fan control is unavailable for this Mac or macOS build."
            case .needsSignedBuild: "Live fan control needs a signed ThermalDeck build."
            case .needsLocalInstall: "Install the local fan helper to use Max Fans."
            case .needsLocalUpdate: "Reinstall the local fan helper for this ThermalDeck build."
            case .missingHelper: "This build does not include the fan control helper."
            case .needsSetup: "Set up the fan control helper to use Max Fans."
            case .needsApproval: "Approve the fan control helper in System Settings."
            case .ready: nil
            }
        }

        var setupTitle: String? {
            switch self {
            case .needsLocalInstall: "Install Fan Helper…"
            case .needsLocalUpdate: "Update Fan Helper…"
            case .needsSetup: "Set Up Fan Control"
            case .needsApproval: "Open System Settings"
            default: nil
            }
        }
    }

    private enum Command { case status, maximum, automatic }

    private let machine: Machine
    private let service: SMAppService
    private let serviceName: String
    private let hasHelper: Bool
    private let signing: FanControlServiceIdentity.SigningIdentity?
    private let identifier: String
    private var requirement: String?
    @ObservationIgnored private var connection: NSXPCConnection?
    @ObservationIgnored private var connectionID: UUID?
    @ObservationIgnored private var pending: [UUID: CheckedContinuation<FanControlResult, Never>] = [:]
    @ObservationIgnored private var watch: Task<Void, Never>?
    @ObservationIgnored private var restoration: Task<Bool, Never>?
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var lastCheck: ContinuousClock.Instant?
    @ObservationIgnored private var localInstallerPackage: URL?
    @ObservationIgnored var reportIssue: ((MonitorAlert?) -> Void)?
    private static let installerLog = Logger(subsystem: "org.thermaldeck.local", category: "fan-helper-installer")

    private(set) var availability: Availability
    private(set) var state: FanControlResult = .unavailable
    private(set) var changing = false
    private(set) var needsRestoration = false
    private(set) var notice: String?
    private(set) var preparingInstaller = false

    init(machine: Machine) {
        self.machine = machine
        identifier = Bundle.main.bundleIdentifier ?? FanControlServiceIdentity.localApp
        serviceName = identifier + FanControlServiceIdentity.helperSuffix
        service = SMAppService.daemon(plistName: serviceName + ".plist")
        let contents = Bundle.main.bundleURL.appending(path: "Contents")
        hasHelper = FileManager.default.isExecutableFile(atPath: contents.appending(path: "MacOS/thermal-fan-helper").path) &&
            FileManager.default.fileExists(atPath: contents.appending(path: "Library/LaunchDaemons/\(serviceName).plist").path)
        signing = FanControlServiceIdentity.current()
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
        guard availability == .ready else {
            if needsRestoration { connectionLost() }
            return
        }
        let requestRevision = revision
        watch = Task { [weak self] in
            guard let self else { return }
            let result = await send(.status)
            watch = nil
            guard revision == requestRevision, !changing else { return }
            if result == .unavailable && needsRestoration {
                connectionLost()
                return
            }
            if needsRestoration && (result == .busy || result == .external || result == .unsupported) {
                state = .unconfirmed
                notice = "System control could not be confirmed. Choose Restore Automatic to retry."
                reportIssue?(.fanRestoreUnconfirmed)
                return
            }
            apply(result)
        }
    }

    func setUp() {
        refreshAvailability()
        if availability == .needsLocalInstall || availability == .needsLocalUpdate {
            openLocalInstaller()
        } else if availability == .needsApproval {
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

    private func openLocalInstaller() {
        guard !preparingInstaller, let signing,
              let requirement = FanControlServiceIdentity.exactRequirement(identifier: identifier, cdHash: signing.cdHash)
        else { return }

        preparingInstaller = true
        notice = nil
        let app = Bundle.main.bundleURL
        Task {
            defer { preparingInstaller = false }
            do {
                let package: URL
                if let cached = localInstallerPackage, FileManager.default.fileExists(atPath: cached.path) {
                    package = cached
                } else {
                    package = try await Task.detached(priority: .userInitiated) {
                        try LocalFanInstaller.prepare(app: app, requirement: requirement)
                    }.value
                    localInstallerPackage = package
                }
                let installer = URL(filePath: "/System/Library/CoreServices/Installer.app")
                _ = try await NSWorkspace.shared.open([package], withApplicationAt: installer,
                                                      configuration: NSWorkspace.OpenConfiguration())
            } catch {
                Self.installerLog.error("Could not open local fan helper installer: \(error.localizedDescription, privacy: .private)")
                notice = "Could not open the fan helper installer. Try again."
            }
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
        reportIssue?(nil)
        Task {
            guard revision == requestRevision else { return }
            let result = await send(.maximum)
            guard revision == requestRevision else { return }
            changing = false
            if result == .unavailable {
                connectionLost()
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
        reportIssue?(.fanRestoreUnconfirmed)
        return false
    }

    private func connectionLost() {
        guard state != .unconfirmed else { return }
        state = .unconfirmed
        notice = "The helper connection was lost. Choose Restore Automatic to verify system control."
        reportIssue?(.fanControlDisconnected)
    }

    private func refreshAvailability() {
        let previousRequirement = requirement
        defer {
            if previousRequirement != requirement { connection?.invalidate() }
        }
        requirement = nil
        if !MaximumFanController.supports(machine) {
            availability = .unsupported
        } else if signing?.identifier != identifier {
            availability = .needsSignedBuild
        } else if !hasHelper {
            availability = .missingHelper
        } else if let signing, signing.team == nil, identifier == FanControlServiceIdentity.localApp {
            guard let install = FanControlServiceIdentity.LocalInstallation.read() else {
                availability = .needsLocalInstall
                return
            }
            guard install.appCDHash == signing.cdHash else {
                availability = .needsLocalUpdate
                return
            }
            requirement = FanControlServiceIdentity.exactRequirement(identifier: serviceName, cdHash: install.helperCDHash)
            availability = requirement == nil ? .needsLocalInstall : .ready
        } else {
            requirement = signing?.peerRequirement(identifier: serviceName)
            guard requirement != nil else {
                availability = .needsSignedBuild
                return
            }
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
        case .unavailable: signing?.team == nil
            ? "The local fan helper could not be reached. Check the installation, then reopen ThermalDeck."
            : "The fan control helper could not be reached."
        case .unsupported: "The fan control helper could not verify this Mac."
        case .unconfirmed: "System control could not be confirmed. Choose Restore Automatic to retry."
        case .thermalPressure: "Try Max Fans again after macOS thermal pressure drops."
        default: nil
        }
        switch result {
        case .stopped: reportIssue?(.fanControlStopped)
        case .unconfirmed: reportIssue?(.fanRestoreUnconfirmed)
        default: reportIssue?(nil)
        }
    }

    private func send(_ command: Command) async -> FanControlResult {
        guard let requirement, signing?.team == nil || service.status == .enabled else { return .unavailable }
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
                // Quit can queue behind spin-up and two bounded restore attempts.
                try? await Task.sleep(for: .seconds(65))
                self?.pending.removeValue(forKey: id)?.resume(returning: .unavailable)
            }
        }
    }
}
