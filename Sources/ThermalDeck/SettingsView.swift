import SwiftUI
import ThermalCore

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var permission = "Checking…"
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section("General") {
                Picker("Temperature unit", selection: $model.preferences.unit) {
                    ForEach(TemperatureUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Appearance", selection: $model.preferences.appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Dashboard interval", selection: $model.preferences.interval) {
                    ForEach(Preferences.intervals, id: \.self) { Text("\($0) s").tag($0) }
                }
            }
            Section("Menu Bar") {
                Picker("Show", selection: $model.preferences.menuIndicator) {
                    ForEach(MenuIndicator.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
            Section("History") {
                Toggle("Collect history", isOn: $model.preferences.collectHistory)
                Picker("Keep history for", selection: $model.preferences.retention) {
                    ForEach(Preferences.retentions, id: \.self) { Text("\($0 / 60) min").tag($0) }
                }
                Toggle("Save history across launches", isOn: $model.preferences.persistHistory)
                    .disabled(model.snapshot.simulated)
                Button("Clear History…") { confirmClear = true }
                if let notice = model.historyNotice {
                    Text(notice).foregroundStyle(.secondary)
                }
            }
            Section("Alerts") {
                Toggle("Local notifications", isOn: $model.preferences.alerts)
                    .disabled(model.snapshot.simulated)
                if model.preferences.alerts {
                    LabeledContent("Notifications", value: permission)
                    if permission == "Permission required" {
                        Button("Request Permission") {
                            Task {
                                await LocalAlerts.request()
                                permission = await LocalAlerts.permission()
                            }
                        }
                    }
                    let unit = model.preferences.unit
                    let bounds = unit.displayValue(40)...unit.displayValue(115)
                    let threshold = Binding(get: { unit.displayValue(model.preferences.thresholdCelsius) },
                                            set: { model.preferences.thresholdCelsius = unit.celsiusValue($0) })
                    Slider(value: threshold, in: bounds, step: 1) {
                        Text("High temperature")
                    } minimumValueLabel: {
                        Text(model.temperature(40))
                    } maximumValueLabel: {
                        Text(model.temperature(115))
                    }
                    LabeledContent("Alert threshold", value: model.temperature(model.preferences.thresholdCelsius))
                    Text("This threshold is a personal alert preference.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let notice = model.preferencesNotice {
                Text(notice).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .task(id: model.preferences.alerts) {
            if model.preferences.alerts { permission = await LocalAlerts.permission() }
        }
        .confirmationDialog("Clear history?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { model.clearHistory() }
        } message: {
            Text("This clears the live charts and any local history file.")
        }
    }
}
