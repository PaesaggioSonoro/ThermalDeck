import AppKit
import UserNotifications

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var menuBar: MenuBarStatusController?
    private weak var model: AppModel?
    private var restoringForQuit = false

    func installMenuBar(model: AppModel, showDashboard: @escaping () -> Void, showSettings: @escaping () -> Void) {
        guard menuBar == nil else { return }
        self.model = model
        menuBar = MenuBarStatusController(model: model, showDashboard: showDashboard, showSettings: showSettings)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model?.restoreAutomaticCooling()
        guard let cooling = model?.liveCooling, cooling.needsRestoration else { return .terminateNow }
        guard !restoringForQuit else { return .terminateLater }
        restoringForQuit = true
        Task {
            let restored = await cooling.restore()
            restoringForQuit = false
            sender.reply(toApplicationShouldTerminate: restored)
            if !restored {
                NSApp.activate()
                let alert = NSAlert()
                alert.messageText = "Automatic fan control could not be confirmed."
                alert.informativeText = "ThermalDeck is still open. Choose Restore Automatic in Overview to retry."
                alert.runModal()
            }
        }
        return .terminateLater
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
