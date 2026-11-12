import SwiftUI
import ThermalCore

struct SettingsView: View {
    @Bindable var model: AppModel

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
            if let notice = model.preferencesNotice {
                Text(notice).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }
}
