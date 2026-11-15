import SwiftUI
import ThermalCore

struct MenuBarView: View {
    @Bindable var model: AppModel

    private struct OptionGroup: Identifiable {
        let id: String
        let options: [MenuBarReadout]
    }

    var body: some View {
        let selection = model.preferences.menuBar
        let values = model.menuBarValues
        VStack(alignment: .leading, spacing: 12) {
            Text("Menu Bar Preview").font(.headline)
            HStack {
                Spacer()
                Image(nsImage: MenuBarArtwork.image(values: values))
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.background, in: Capsule())
                    .overlay { Capsule().strokeBorder(.quaternary) }
                    .accessibilityLabel(Text((["ThermalDeck logo"] + values).joined(separator: ", ")))
                Spacer()
            }
            .frame(height: 70)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        }

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                valuePicker("First value", selection: Binding(
                    get: { model.preferences.menuBar.first },
                    set: { model.preferences.menuBar.selectFirst($0) }
                ), excluding: selection.second)
                valuePicker("Second value", selection: Binding(
                    get: { model.preferences.menuBar.second },
                    set: { model.preferences.menuBar.selectSecond($0) }
                ), excluding: selection.first, enabled: selection.first != nil)
            }
            Toggle("Show temperature decimals", isOn: $model.preferences.menuBarTemperatureDecimals)
        }
        .padding(16)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary) }
    }

    private var optionGroups: [OptionGroup] {
        let temperatures = model.snapshot.temperatures.sorted(by: SensorPresentation.byName)
        let cpu = temperatures.filter { $0.group == .cpu }
        let gpu = temperatures.filter { $0.group == .gpu }
        let system = temperatures.filter { $0.group != .cpu && $0.group != .gpu && $0.group != .other }
        return [
            OptionGroup(id: "General", options: [.highestTemperature, .fastestFan]),
            OptionGroup(id: "CPU", options: [.cpuHighest] + cpu.map { .sensor($0.id) }),
            OptionGroup(id: "GPU", options: [.gpuHighest] + gpu.map { .sensor($0.id) }),
            OptionGroup(id: "System", options: system.map { .sensor($0.id) }),
            OptionGroup(id: "Fans", options: model.snapshot.fans.map { .fan($0.id) })
        ]
    }

    private func valuePicker(
        _ title: String, selection: Binding<MenuBarReadout?>, excluding other: MenuBarReadout?, enabled: Bool = true
    ) -> some View {
        let groups = optionGroups
        return VStack(alignment: .leading, spacing: 8) {
            Text(title).fontWeight(.medium)
                .accessibilityHidden(true)
            Picker(title, selection: selection) {
                Text("None").tag(nil as MenuBarReadout?)
                if let saved = selection.wrappedValue, !groups.contains(where: { $0.options.contains(saved) }) {
                    Text(saved.label(in: model.snapshot)).tag(Optional(saved))
                }
                ForEach(groups) { group in
                    let options = group.options.filter { $0 != other }
                    if !options.isEmpty {
                        Section(group.id) {
                            ForEach(options, id: \.self) { option in
                                Text(option.label(in: model.snapshot)).tag(Optional(option))
                            }
                        }
                    }
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(!enabled)
            if !enabled {
                Text("Choose a first value to enable this slot.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
