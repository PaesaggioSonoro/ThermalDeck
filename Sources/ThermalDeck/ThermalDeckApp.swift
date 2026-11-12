import AppKit
import HardwareAccess
import SwiftUI
import ThermalCore

@main
struct ThermalDeckApp: App {
    @NSApplicationDelegateAdaptor(AlertDelegate.self) private var alertDelegate
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

        MenuBarExtra {
            if model.snapshot.simulated { Text("Simulation") }
            Text(model.snapshot.health.label)
            ForEach(model.preferences.menuBar.readouts, id: \.self) { readout in
                Text(readout.label(in: model.snapshot) + "  " + model.menuBarValue(readout))
            }
            Divider()
            Label("Automatic", systemImage: "checkmark")
            Text("ThermalDeck leaves cooling to macOS.")
            Button("Open Dashboard", action: showDashboard)
            Button("Settings…") {
                openSettings()
                NSApp.activate()
            }
            Divider()
            Button("Quit " + Self.displayName) { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            if let title = model.menuBarTitle {
                Text(title).monospacedDigit()
            } else {
                Image(systemName: "thermometer.medium").accessibilityLabel(Self.displayName)
            }
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
