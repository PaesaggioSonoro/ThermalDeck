import SwiftUI
import ThermalCore

struct MenuBarView: View {
    let model: AppModel

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
        .padding(16)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary) }
    }

    private var options: [MenuBarReadout] {
        [.highestTemperature, .cpuHighest, .gpuHighest]
            + model.snapshot.temperatures.sorted(by: SensorPresentation.byName).map { .sensor($0.id) }
            + model.snapshot.fans.map { .fan($0.id) }
    }

    private func valuePicker(
        _ title: String, selection: Binding<MenuBarReadout?>, excluding other: MenuBarReadout?, enabled: Bool = true
    ) -> some View {
        let available = options
        return VStack(alignment: .leading, spacing: 8) {
            Text(title).fontWeight(.medium)
                .accessibilityHidden(true)
            Picker(title, selection: selection) {
                Text("None").tag(nil as MenuBarReadout?)
                if let saved = selection.wrappedValue, !available.contains(saved) {
                    Text(saved.label(in: model.snapshot)).tag(Optional(saved))
                }
                ForEach(available.filter { $0 != other }, id: \.self) { option in
                    Text(option.label(in: model.snapshot)).tag(Optional(option))
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
