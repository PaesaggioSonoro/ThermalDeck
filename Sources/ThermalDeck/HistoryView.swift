import Charts
import SwiftUI
import ThermalCore

struct HistoryView: View {
    let model: AppModel
    @State private var minutes = 5
    @State private var targets = false
    @State private var battery = false
    @State private var showingTrackedSensors = false

    var body: some View {
        let end = model.snapshot.timestamp
        let availableMinutes = model.preferences.retention / 60
        let start = end.addingTimeInterval(-Double(min(minutes, availableMinutes) * 60))
        if !model.preferences.collectHistory {
            ContentUnavailableView("History collection is off", systemImage: "chart.xyaxis.line",
                                   description: Text("Enable history collection in Settings."))
        } else {
            HStack {
                Picker("Time range", selection: $minutes) {
                    ForEach([5, 15, 60].filter { $0 <= availableMinutes }, id: \.self) {
                        Text("\($0) min").tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                Spacer()
                Toggle("Battery", isOn: $battery)
                Toggle("Targets", isOn: $targets)
                HistoryExportButton(model: model)
            }
            .onChange(of: availableMinutes, initial: true) {
                if minutes > availableMinutes { minutes = availableMinutes }
            }
            sensorSelector

            let temperature: [SeriesKey] = (battery ? [.cpu, .gpu, .battery] : [.cpu, .gpu]) +
                model.preferences.historySensors.map(SeriesKey.sensor)
            let historicalKeys = Set(model.history.records.flatMap { $0.values.keys })
            let fanKeys = historicalKeys.filter { key in
                switch key {
                case .fan: true
                case .target: targets
                default: false
                }
            }.sorted { $0.label < $1.label }
            HistoryChart(title: "Temperature", unit: model.preferences.unit.symbol,
                         points: model.history.plot(temperature, from: start, through: end),
                         range: start...end, temperatureUnit: model.preferences.unit,
                         labelsByKey: Dictionary(uniqueKeysWithValues: model.preferences.historySensors.map {
                             (.sensor($0), sensorLabel($0))
                         }))
            HistoryChart(title: "Fan speed", unit: "RPM",
                         points: model.history.plot(fanKeys, from: start, through: end),
                         range: start...end, temperatureUnit: nil)
        }
    }

    private var sensorSelector: some View {
        let selected = model.preferences.historySensors
        let available = model.snapshot.temperatures.filter { $0.group != .other }.sorted(by: SensorPresentation.byName)
        let availableIDs = Set(available.map(\.id))
        let choices = available.map(\.id) + selected.filter { !availableIDs.contains($0) }
        return DisclosureGroup(isExpanded: $showingTrackedSensors) {
            trackedSensorPicker(choices, selected: selected)
                .padding(.top, 6)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Label("Tracked Sensors", systemImage: "thermometer.medium").fixedSize()
                Text(selected.isEmpty ? "Choose up to \(Preferences.historySensorLimit) sensors to record from now on." :
                        selected.map(sensorLabel).joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(choices.isEmpty)
    }

    private func trackedSensorPicker(_ choices: [SensorID], selected: [SensorID]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(choices, id: \.self) { id in
                    Toggle(sensorLabel(id), isOn: Binding(
                        get: { model.preferences.historySensors.contains(id) },
                        set: { model.preferences.setHistorySensor(id, tracked: $0) }
                    ))
                    .disabled(!selected.contains(id) && selected.count >= Preferences.historySensorLimit)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: 192, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private func sensorLabel(_ id: SensorID) -> String {
        model.snapshot.temperatures.first { $0.id == id }?.displayName ?? "Unavailable sensor"
    }
}

struct HistoryChart: View {
    let title: String
    let unit: String
    let points: [PlotPoint]
    let range: ClosedRange<Date>
    let temperatureUnit: TemperatureUnit?
    var labelsByKey: [SeriesKey: String] = [:]
    private let palette: [Color] = [.teal, .orange, .purple, .blue, .pink, .indigo, .green, .brown]

    var body: some View {
        GroupBox {
            if points.isEmpty {
                ContentUnavailableView("Waiting for samples", systemImage: "chart.xyaxis.line")
                    .frame(maxWidth: .infinity, minHeight: 125)
            } else {
                let labels = Set(points.map { label(for: $0.key) }).sorted()
                Chart(points) { point in
                    let value = temperatureUnit?.displayValue(point.value) ?? point.value
                    LineMark(x: .value("Time", point.date), y: .value(unit, value),
                             series: .value("Continuous series", point.line))
                        .foregroundStyle(by: .value("Reading", label(for: point.key)))
                    PointMark(x: .value("Time", point.date), y: .value(unit, value))
                        .foregroundStyle(by: .value("Reading", label(for: point.key)))
                        .symbolSize(7)
                        .accessibilityHidden(true)
                }
                .chartForegroundStyleScale(domain: labels, range: labels.indices.map { palette[$0 % palette.count] })
                .chartXScale(domain: range)
                .chartYAxisLabel(unit)
                .chartYScale(domain: yRange)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute(), anchor: .trailing)
                    }
                }
                .frame(height: 175)
                .padding(.top, 5)
            }
        } label: {
            Label(title, systemImage: temperatureUnit == nil ? "fan" : "thermometer.medium")
        }
        .transaction { $0.animation = nil }
    }

    private func label(for key: SeriesKey) -> String { labelsByKey[key] ?? key.label }

    private var yRange: ClosedRange<Double> {
        let upper = points.map(\.value).max() ?? 0
        guard let temperatureUnit else { return 0...max(1_000, (upper * 1.08).rounded(.up)) }
        let lower = points.map(\.value).min() ?? upper
        return temperatureUnit.displayValue(lower - 1)...temperatureUnit.displayValue(upper + 1)
    }

}
