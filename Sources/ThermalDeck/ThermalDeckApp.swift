import AppKit
import SwiftUI
import ThermalCore

private enum WaitingSource: TelemetrySource {
    case initial
    var machine: Machine { Machine(model: "Mac", chip: "Apple Silicon", os: ProcessInfo.processInfo.operatingSystemVersionString) }
    var simulated: Bool { false }

    func sample(validity: Duration) async -> Snapshot {
        Snapshot(machine: machine, health: .unavailable("Hardware discovery is pending."))
    }
    func reset() async {}
}

@main
struct ThermalDeckApp: App {
    @State private var model = AppModel(source:
        CommandLine.arguments.contains("--demo") ? DemoSource() : WaitingSource.initial)
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
                .frame(width: 520)
        }

        MenuBarExtra {
            if model.snapshot.simulated { Text("Simulation") }
            Text(model.snapshot.health.label)
            Text("CPU  " + model.temperature(model.snapshot.peak(.cpu)))
            Text("GPU  " + model.temperature(model.snapshot.peak(.gpu)))
            Divider()
            Text("Profile: Automatic")
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
