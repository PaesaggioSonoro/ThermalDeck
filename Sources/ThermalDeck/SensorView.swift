import SwiftUI
import ThermalCore

struct SensorView: View {
    let model: AppModel

    var body: some View {
        if model.snapshot.temperatures.isEmpty {
            ContentUnavailableView("No mapped temperature readings", systemImage: "thermometer.medium",
                                   description: Text(model.snapshot.health.label))
        } else {
            ForEach(SensorGroup.allCases, id: \.self) { group in
                let sensors = model.snapshot.temperatures.filter { $0.group == group }
                if !sensors.isEmpty {
                    GroupBox(group.rawValue) {
                        ForEach(sensors) { sensor in
                            HStack(spacing: 12) {
                                Text(sensor.id.rawValue).font(.system(.body, design: .monospaced))
                                Text(sensor.format).font(.caption.monospaced()).foregroundStyle(.secondary)
                                Spacer()
                                Text(sensor.reading.health().rawValue)
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(model.temperature(sensor.reading.freshValue()))
                                    .monospacedDigit()
                                    .frame(minWidth: 82, alignment: .trailing)
                                    .accessibilityLabel(sensor.reading.freshValue() == nil ? "Unavailable" :
                                                        model.temperature(sensor.reading.freshValue()))
                            }
                            .accessibilityElement(children: .combine)
                            .padding(.vertical, 5)
                            if sensor.id != sensors.last?.id { Divider() }
                        }
                    }
                }
            }
            Text("Zones use firmware identifiers. They do not identify individual physical cores.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
