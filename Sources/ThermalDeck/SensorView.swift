import SwiftUI
import ThermalCore

struct SensorView: View {
    @Bindable var model: AppModel
    @State private var showingVisibility = false

    var body: some View {
        let sensors = model.snapshot.temperatures
        let sections = model.preferences.sensorPresentation.sections(for: sensors)
        HStack {
            Picker("Sort by", selection: $model.preferences.sensorPresentation.sort) {
                ForEach(SensorPresentation.Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .fixedSize()
            Toggle("Group by zone", isOn: $model.preferences.sensorPresentation.groupByZone)
                .fixedSize()
            Spacer()
            Button {
                showingVisibility.toggle()
            } label: {
                Label("Sensor Visibility", systemImage: "eye")
            }
            .disabled(sensors.isEmpty)
            .popover(isPresented: $showingVisibility) { visibilityMenu(sensors) }
        }
        if sections.isEmpty {
            ContentUnavailableView(sensors.isEmpty ? "No mapped temperature readings" : "All sensors are hidden",
                                   systemImage: "thermometer.medium",
                                   description: Text(sensors.isEmpty ? model.snapshot.health.label :
                                                     "Use Sensor Visibility to show sensors again."))
        } else {
            ForEach(sections) { section in
                GroupBox(section.group?.rawValue ?? "Temperatures") {
                    ForEach(section.sensors) { sensor in
                        sensorRow(sensor)
                        if sensor.id != section.sensors.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func sensorRow(_ sensor: Temperature) -> some View {
        let temperature = sensor.reading.freshValue()
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sensor.label)
                if sensor.label != sensor.id.rawValue {
                    Text(sensor.id.rawValue).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(sensor.format).font(.caption.monospaced()).foregroundStyle(.secondary)
            Text(sensor.reading.health().rawValue).font(.caption).foregroundStyle(.secondary)
            Text(model.temperature(temperature))
                .monospacedDigit()
                .frame(minWidth: 82, alignment: .trailing)
                .accessibilityLabel(temperature == nil ? "Unavailable" : model.temperature(temperature))
        }
        .accessibilityElement(children: .combine)
        .padding(.vertical, 5)
    }

    private func visibilityMenu(_ sensors: [Temperature]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Show in Sensors").font(.headline)
                Spacer()
                Button("Show All") { model.preferences.sensorPresentation.hiddenSensors.removeAll() }
                    .disabled(model.preferences.sensorPresentation.hiddenSensors.isEmpty)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sensors.sorted(by: SensorPresentation.byName)) { sensor in
                        Toggle(isOn: Binding(
                            get: { !model.preferences.sensorPresentation.hiddenSensors.contains(sensor.id) },
                            set: { visible in
                                if visible {
                                    model.preferences.sensorPresentation.hiddenSensors.remove(sensor.id)
                                } else {
                                    model.preferences.sensorPresentation.hiddenSensors.insert(sensor.id)
                                }
                            }
                        )) {
                            Text(sensor.label == sensor.id.rawValue ? sensor.label : "\(sensor.label) (\(sensor.id.rawValue))")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .frame(width: 330)
    }
}
