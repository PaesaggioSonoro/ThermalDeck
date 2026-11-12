import Charts
import SwiftUI
import ThermalCore

struct ProfilesView: View {
    let model: AppModel
    @State private var editing = false

    var body: some View {
        GroupBox("Cooling profiles") {
            row("Automatic", "Active", detail: "ThermalDeck leaves cooling to the system.", icon: "checkmark.circle.fill")
            Divider()
            row("Quiet", "Unavailable", detail: "Safe quieter-than-system behavior has not been verified.", icon: "lock")
            Divider()
            row("Balanced", "Unavailable", detail: "Requires a verified control pathway.", icon: "lock")
            Divider()
            row("Performance", "Unavailable", detail: "Requires a verified control pathway.", icon: "lock")
            Divider()
            HStack(alignment: .center) {
                row("Custom", "Offline preview", detail: "Design a curve with simulated inputs.", icon: "chart.xyaxis.line")
                Button(editing ? "Hide Editor" : "Edit Curve…") { editing.toggle() }
            }
        }
        if editing { CurveEditor(model: model) }
    }

    private func row(_ title: String, _ status: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(title == "Automatic" ? Color.teal : .secondary)
                .frame(width: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.body.weight(.medium))
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

private struct CurveEditor: View {
    let model: AppModel
    @State private var points: [CurvePoint]
    @State private var selectedX: Double?
    @State private var previewCelsius = 65.0

    init(model: AppModel) {
        self.model = model
        _points = State(initialValue: model.preferences.storedCurve?.points ?? [
            .init(celsius: 45, rpm: 1700), .init(celsius: 65, rpm: 3000), .init(celsius: 85, rpm: 4800)
        ])
    }

    var body: some View {
        let unit = model.preferences.unit
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        let curve = try? FanCurve(points: points)
        GroupBox("Curve preview") {
            Chart {
                if let curve {
                    ForEach(curve.points.indices, id: \.self) { index in
                        let point = curve.points[index]
                        LineMark(x: .value("Temperature", unit.displayValue(point.celsius)), y: .value("RPM", point.rpm))
                            .foregroundStyle(.teal)
                        PointMark(x: .value("Temperature", unit.displayValue(point.celsius)), y: .value("RPM", point.rpm))
                            .foregroundStyle(.teal)
                    }
                    if let rpm = curve.target(for: previewCelsius) {
                        RuleMark(x: .value("Simulated temperature", unit.displayValue(previewCelsius)))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        PointMark(x: .value("Temperature", unit.displayValue(previewCelsius)), y: .value("RPM", rpm))
                            .foregroundStyle(.orange)
                            .symbolSize(65)
                    }
                }
            }
            .chartXSelection(value: $selectedX)
            .chartXScale(domain: unit.displayValue(20)...unit.displayValue(115))
            .chartYScale(domain: 0...max(6000, points.map(\.rpm).filter { (0...20_000).contains($0) }.max() ?? 0))
            .chartXAxisLabel(unit.symbol)
            .chartYAxisLabel("RPM")
            .frame(height: 180)
            .onChange(of: selectedX) {
                if let selectedX { previewCelsius = min(115, max(20, unit.celsiusValue(selectedX))) }
            }
            Slider(value: $previewCelsius, in: 20...115, step: 1) {
                Text("Simulated temperature")
            }
            LabeledContent(model.temperature(previewCelsius), value: model.rpm(curve?.target(for: previewCelsius)))
                .monospacedDigit()
            Divider().padding(.vertical, 5)
            ForEach(points.indices, id: \.self) { index in
                let displayed = Binding(get: { unit.displayValue(points[index].celsius) },
                                        set: { points[index].celsius = unit.celsiusValue($0) })
                HStack {
                    Text("Point \(index + 1)").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    TextField("Temperature for point \(index + 1)", value: displayed, format: format)
                        .labelsHidden().frame(width: 76)
                    Text(unit.symbol).frame(width: 24, alignment: .leading)
                    TextField("RPM for point \(index + 1)", value: $points[index].rpm, format: format)
                        .labelsHidden().frame(width: 84)
                    Text("RPM")
                    Button { points.remove(at: index) } label: {
                        Image(systemName: "minus.circle").accessibilityLabel("Remove point \(index + 1)")
                    }
                    .buttonStyle(.borderless).disabled(points.count <= 2)
                }
            }
            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
            HStack {
                Button("Add Point") {
                    guard let last = points.last else { return }
                    points.append(.init(celsius: min(115, last.celsius + 5), rpm: last.rpm))
                }
                .disabled(points.count >= 12)
                Spacer()
                Button("Save Curve") {
                    if let curve { model.preferences.storedCurve = curve }
                }
                .disabled(curve == nil || curve == model.preferences.storedCurve)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 7)
        }
    }

    private var validationMessage: String? {
        do {
            _ = try FanCurve(points: points)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
