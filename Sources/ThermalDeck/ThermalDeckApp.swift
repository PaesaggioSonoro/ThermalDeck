import AppKit
import HardwareAccess
import SwiftUI
import ThermalCore

@main
struct ThermalDeckApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var appDelegate
    @State private var model = AppModel(source:
        CommandLine.arguments.contains("--demo") ? DemoSource() : AppleSMCSource())
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "ThermalDeck"
    }

    var body: some Scene {
        Window(Self.displayName, id: "dashboard") {
            Dashboard(model: model)
                .preferredColorScheme(model.preferences.appearance.colorScheme)
                .frame(minWidth: 680, minHeight: 450)
                .background(DashboardVisibility(change: model.dashboardVisible))
                .onAppear {
                    appDelegate.installMenuBar(model: model, showDashboard: { [openWindow] in
                        openWindow(id: "dashboard")
                        NSApp.activate()
                    }, showSettings: { [openSettings] in
                        NSApp.activate()
                        openSettings()
                    })
                }
        }
        .defaultSize(width: 1060, height: 730)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Open Dashboard", action: showDashboard)
                    .keyboardShortcut("0")
            }
        }

        Settings {
            SettingsView(model: model)
                .preferredColorScheme(model.preferences.appearance.colorScheme)
                .frame(width: 530, height: 570)
        }
    }

    private func showDashboard() {
        openWindow(id: "dashboard")
        NSApp.activate()
    }
}

private extension Appearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
