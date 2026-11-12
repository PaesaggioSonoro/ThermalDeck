import AppKit
import ServiceManagement
import SwiftUI

struct LoginItemView: View {
    @State private var status = SMAppService.mainApp.status
    @State private var issue: String?

    var body: some View {
        LabeledContent("Launch at login", value: statusLabel)
        if status == .requiresApproval {
            Button("Open Login Items Settings") { SMAppService.openSystemSettingsLoginItems() }
        } else if status != .notFound {
            Button(status == .enabled ? "Disable Launch at Login" : "Enable Launch at Login") {
                do {
                    if status == .enabled {
                        try SMAppService.mainApp.unregister()
                    } else {
                        try SMAppService.mainApp.register()
                    }
                    issue = nil
                } catch {
                    issue = "macOS could not change the login item. Open the app from a stable location."
                    AppModel.log.error("Login item operation failed")
                }
                status = SMAppService.mainApp.status
            }
        }
        if let issue { Text(issue).font(.callout).foregroundStyle(.secondary) }
        Color.clear.frame(height: 0)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                status = SMAppService.mainApp.status
            }
            .accessibilityHidden(true)
    }

    private var statusLabel: String {
        switch status {
        case .enabled: "Enabled"
        case .notRegistered: "Disabled"
        case .requiresApproval: "Approval required"
        case .notFound: "Unavailable for this bundle"
        @unknown default: "Unknown"
        }
    }
}
