import AppKit
import UserNotifications

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var menuBar: MenuBarStatusController?
    private weak var model: AppModel?

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
        return .terminateNow
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
