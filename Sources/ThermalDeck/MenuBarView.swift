import SwiftUI
import ThermalCore

struct MenuBarView: View {
    @Bindable var model: AppModel

    var body: some View {
        GroupBox("Values") {
            VStack(alignment: .leading, spacing: 14) {
                picker("First value", selection: $model.preferences.menuBar.first,
                       excluding: model.preferences.menuBar.second)
                picker("Second value", selection: $model.preferences.menuBar.second,
                       excluding: model.preferences.menuBar.first)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        GroupBox("Preview") {
            HStack {
                if let text = model.menuBarTitle {
                    Text(text).monospacedDigit()
                } else {
                    Label("Icon only", systemImage: "thermometer.medium")
                }
                Spacer()
            }
            .padding(8)
        }
    }

    private var options: [MenuBarReadout] {
        [.highestTemperature, .cpuHighest, .gpuHighest]
            + model.snapshot.temperatures.sorted(by: SensorPresentation.byName).map { .sensor($0.id) }
            + model.snapshot.fans.map { .fan($0.id) }
    }

    private func picker(
        _ title: String, selection: Binding<MenuBarReadout?>, excluding other: MenuBarReadout?
    ) -> some View {
        let available = options
        return Picker(title, selection: selection) {
            Text("None").tag(nil as MenuBarReadout?)
            if let saved = selection.wrappedValue, !available.contains(saved) {
                Text(saved.label(in: model.snapshot)).tag(Optional(saved))
            }
            ForEach(available.filter { $0 != other || $0 == selection.wrappedValue }, id: \.self) { option in
                Text(option.label(in: model.snapshot)).tag(Optional(option))
            }
        }
    }
}
