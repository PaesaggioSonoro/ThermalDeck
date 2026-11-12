import AppKit
import HardwareAccess
import SwiftUI
import ThermalCore

@main
struct ThermalDeckApp: App {
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
                .onAppear { model.dashboardVisible(true) }
                .onDisappear { model.dashboardVisible(false) }
        }
        .defaultSize(width: 1060, height: 730)

        Settings {
            SettingsView(model: model)
                .preferredColorScheme(model.preferences.appearance.colorScheme)
                .frame(width: 530, height: 570)
        }

        MenuBarExtra {
            if model.snapshot.simulated { Text("Simulation") }
            Text(model.snapshot.health.label)
            Text("CPU  " + model.temperature(model.snapshot.peak(.cpu)))
            Text("GPU  " + model.temperature(model.snapshot.peak(.gpu)))
            if let fan = model.snapshot.fans.first {
                Text(fan.id.name + "  " + model.rpm(fan.speed.freshValue()))
            }
            Divider()
            Label("Automatic", systemImage: "checkmark")
            Text("ThermalDeck leaves cooling to macOS.")
            Button("Open Dashboard") {
                openWindow(id: "dashboard")
                NSApp.activate()
            }
            Button("Settings…") {
                openSettings()
                NSApp.activate()
            }
            Divider()
            Button("Quit " + Self.displayName) { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            let snapshot = model.snapshot
            let fan = model.rpm(snapshot.fans.first?.speed.freshValue())
            switch model.preferences.menuIndicator {
            case .cpu: Label(model.temperature(snapshot.peak(.cpu)), systemImage: "thermometer.medium")
            case .gpu: Label(model.temperature(snapshot.peak(.gpu)), systemImage: "thermometer.medium")
            case .peak: Label(model.temperature(snapshot.peak()), systemImage: "thermometer.medium")
            case .fan: Label(fan, systemImage: "fan")
            case .temperatureAndFan: Label(model.temperature(snapshot.peak()) + " · " + fan, systemImage: "thermometer.medium")
            case .icon: Image(systemName: "thermometer.medium").accessibilityLabel(Self.displayName)
            }
        }
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
