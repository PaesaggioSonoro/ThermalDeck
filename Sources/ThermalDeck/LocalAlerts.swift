import AppKit
import UserNotifications
import ThermalCore

@MainActor
enum LocalAlerts {
    static func permission() async -> String {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .provisional: "Allowed"
        case .denied: "Blocked in System Settings"
        case .notDetermined: "Permission required"
        @unknown default: "Permission unknown"
        }
    }

    static func request() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
        } catch {
            AppModel.log.error("Notification authorization failed")
        }
    }

    static func deliver(_ alert: MonitorAlert, detail: String) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = alert == .highTemperature ? "Temperature threshold reached" : "Thermal monitoring interrupted"
        content.body = detail
        do {
            try await center.add(UNNotificationRequest(identifier: "thermaldeck-\(alert)", content: content, trigger: nil))
        } catch {
            AppModel.log.error("Local notification delivery failed")
        }
    }
}

@MainActor
final class AlertDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
