import Charts
import SwiftUI
import ThermalCore

struct HistoryView: View {
    let model: AppModel
    @State private var minutes = 5
    @State private var targets = false
    @State private var battery = false

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

            let temperature: [SeriesKey] = battery ? [.cpu, .gpu, .battery] : [.cpu, .gpu]
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
                         range: start...end, temperatureUnit: model.preferences.unit)
            HistoryChart(title: "Fan speed", unit: "RPM",
                         points: model.history.plot(fanKeys, from: start, through: end),
                         range: start...end, temperatureUnit: nil)
        }
    }
}

struct HistoryChart: View {
    let title: String
    let unit: String
    let points: [PlotPoint]
    let range: ClosedRange<Date>
    let temperatureUnit: TemperatureUnit?
    private let palette: [Color] = [.teal, .orange, .purple, .blue, .pink, .indigo, .green, .brown]

    var body: some View {
        GroupBox {
            if points.isEmpty {
                ContentUnavailableView("Waiting for samples", systemImage: "chart.xyaxis.line")
                    .frame(maxWidth: .infinity, minHeight: 125)
            } else {
                let labels = Set(points.map { $0.key.label }).sorted()
                Chart(points) { point in
                    let value = temperatureUnit?.displayValue(point.value) ?? point.value
                    LineMark(x: .value("Time", point.date), y: .value(unit, value),
                             series: .value("Continuous series", point.line))
                        .foregroundStyle(by: .value("Reading", point.key.label))
                    PointMark(x: .value("Time", point.date), y: .value(unit, value))
                        .foregroundStyle(by: .value("Reading", point.key.label))
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

    private var yRange: ClosedRange<Double> {
        let upper = points.map(\.value).max() ?? 0
        guard let temperatureUnit else { return 0...max(1_000, (upper * 1.08).rounded(.up)) }
        let lower = points.map(\.value).min() ?? upper
        return temperatureUnit.displayValue(lower - 1)...temperatureUnit.displayValue(upper + 1)
    }

}
