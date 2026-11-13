import Darwin
import Foundation
import HardwareAccess
import SystemConfiguration

private final class Helper: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "org.thermaldeck.fan-control")
    private let controller = MaximumFanController()
    private var owner: UUID?
    private var ownerUID: uid_t?
    private var ownerDisconnected = false
    private var lastStoppedOwner: UUID?
    private var monitor: DispatchSourceTimer?
    private var termination: DispatchSourceSignal?

    func startMonitoring() {
        let monitor = DispatchSource.makeTimerSource(queue: queue)
        monitor.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
        monitor.setEventHandler { [weak self] in self?.checkOwner() }
        self.monitor = monitor
        monitor.activate()

        signal(SIGTERM, SIG_IGN)
        let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: queue)
        termination.setEventHandler { [weak self] in
            let success = self?.controller.map { !$0.needsRestoration || $0.restore() == .automatic } ?? true
            exit(success ? EXIT_SUCCESS : EXIT_FAILURE)
        }
        self.termination = termination
        termination.activate()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let uid = connection.effectiveUserIdentifier
        guard Self.isConsoleUser(uid) else { return false }
        let id = UUID()
        connection.exportedInterface = NSXPCInterface(with: FanControlService.self)
        connection.exportedObject = Session(helper: self, id: id, uid: uid)
        connection.invalidationHandler = { [weak self] in self?.disconnect(id: id) }
        connection.resume()
        return true
    }

    private static func isConsoleUser(_ uid: uid_t) -> Bool {
        var consoleUID = uid_t.max
        return uid != 0 && SCDynamicStoreCopyConsoleUser(nil, &consoleUID, nil) != nil && uid == consoleUID
    }

    enum Command: Sendable { case status, maximum, automatic }

    func perform(_ command: Command, id: UUID, uid: uid_t, reply: @escaping @Sendable (Int) -> Void) {
        queue.async {
            let result = self.perform(command, id: id, uid: uid)
            reply(result.rawValue)
        }
    }

    private func perform(_ command: Command, id: UUID, uid: uid_t) -> FanControlResult {
        guard Self.isConsoleUser(uid) else { return .unavailable }
        guard let controller else { return .unsupported }
        if let owner, owner != id { return .busy }
        var result: FanControlResult
        switch command {
        case .status:
            result = controller.status()
            if result == .automatic && lastStoppedOwner == id {
                lastStoppedOwner = nil
                result = .stopped
            }
        case .maximum:
            lastStoppedOwner = nil
            result = controller.start()
        case .automatic:
            if lastStoppedOwner == id { lastStoppedOwner = nil }
            result = controller.restore()
        }
        if controller.needsRestoration {
            owner = id
            ownerUID = uid
        } else {
            owner = nil
            ownerUID = nil
            ownerDisconnected = false
        }
        return result
    }

    private func checkOwner() {
        guard let owner, let uid = ownerUID, let controller else { return }
        _ = !ownerDisconnected && Self.isConsoleUser(uid) ? controller.status() : controller.restore()
        if !controller.needsRestoration {
            if !ownerDisconnected { lastStoppedOwner = owner }
            self.owner = nil
            ownerUID = nil
            ownerDisconnected = false
        }
    }

    private func disconnect(id: UUID) {
        queue.async {
            guard self.owner == id, let controller = self.controller else { return }
            self.ownerDisconnected = true
            _ = controller.restore()
            // Preserve ownership on failure and allow the next timer tick to retry.
            if !controller.needsRestoration {
                self.owner = nil
                self.ownerUID = nil
                self.ownerDisconnected = false
            }
        }
    }
}

private final class Session: NSObject, FanControlService {
    private let helper: Helper
    private let id: UUID
    private let uid: uid_t

    init(helper: Helper, id: UUID, uid: uid_t) {
        self.helper = helper
        self.id = id
        self.uid = uid
    }

    func status(reply: @escaping @Sendable (Int) -> Void) {
        helper.perform(.status, id: id, uid: uid, reply: reply)
    }

    func maximum(reply: @escaping @Sendable (Int) -> Void) {
        helper.perform(.maximum, id: id, uid: uid, reply: reply)
    }

    func automatic(reply: @escaping @Sendable (Int) -> Void) {
        helper.perform(.automatic, id: id, uid: uid, reply: reply)
    }
}

private func clientRequirement(for signing: FanControlServiceIdentity.SigningIdentity) -> String? {
    let suffix = FanControlServiceIdentity.helperSuffix
    guard signing.identifier.hasSuffix(suffix) else { return nil }
    if signing.team != nil {
        return signing.peerRequirement(identifier: String(signing.identifier.dropLast(suffix.count)))
    }
    guard signing.identifier == FanControlServiceIdentity.localHelper,
          let install = FanControlServiceIdentity.LocalInstallation.read(),
          install.helperCDHash == signing.cdHash else { return nil }
    return FanControlServiceIdentity.exactRequirement(identifier: FanControlServiceIdentity.localApp, cdHash: install.appCDHash)
}

guard geteuid() == 0, let signing = FanControlServiceIdentity.current(),
      let requirement = clientRequirement(for: signing) else {
    FileHandle.standardError.write(Data("The fan helper requires a valid root installation.\n".utf8))
    exit(EX_NOPERM)
}

private let helper = Helper()
let listener = NSXPCListener(machServiceName: signing.identifier)
listener.setConnectionCodeSigningRequirement(requirement)
listener.delegate = helper
helper.startMonitoring()
listener.activate()
dispatchMain()
