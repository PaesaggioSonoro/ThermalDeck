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
        content.title = switch alert {
        case .highTemperature: "Temperature threshold reached"
        case .unavailable: "Thermal monitoring interrupted"
        case .fanControlStopped: "Fan override ended"
        case .fanControlDisconnected: "Fan control helper disconnected"
        case .fanRestoreUnconfirmed: "Automatic fan control unconfirmed"
        }
        content.body = detail
        do {
            try await center.add(UNNotificationRequest(identifier: "thermaldeck-\(alert)", content: content, trigger: nil))
        } catch {
            AppModel.log.error("Local notification delivery failed")
        }
    }
}
