import Charts
import SwiftUI
import ThermalCore

struct ProfilesView: View {
    let model: AppModel
    @State private var editing = false

    var body: some View {
        GroupBox("Cooling profiles") {
            HStack {
                row("Automatic", model.demoCooling?.mode == .automatic || model.coolingLabel == "Automatic" ? "Active" : "",
                    detail: "Leave cooling to the system.", icon: "checkmark.circle.fill")
                if model.canUseAutomaticCooling {
                    Button("Use Automatic", action: model.useAutomaticCooling)
                }
            }
            Divider()
            row("Quiet", "Unavailable", detail: "Safe quieter-than-system behavior has not been verified.", icon: "lock")
            Divider()
            row("Balanced", "Unavailable", detail: "Requires a verified minimum cooling speed under load.", icon: "lock")
            Divider()
            row("Performance", "Unavailable", detail: "A temperature-based boost still needs validation. Max Fans is available in Overview on supported Macs.", icon: "lock")
            Divider()
            HStack(alignment: .center) {
                row("Custom", model.demoCooling?.mode == .custom ? "Active in Demo" : "Offline preview",
                    detail: "Design a curve with simulated inputs.", icon: "chart.xyaxis.line")
                if let cooling = model.demoCooling {
                    Button("Run Saved Curve in Demo", action: model.activateDemoCurve)
                        .disabled(model.preferences.storedPercentCurve == nil || !cooling.canStart())
                }
                Button(editing ? "Hide Editor" : "Edit Curve…") { editing.toggle() }
            }
            if let notice = model.demoCooling?.notice ?? model.liveCooling?.notice {
                Text(notice).font(.caption).foregroundStyle(.secondary)
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
    private struct DraftPoint: Identifiable {
        let id = UUID()
        var value: PercentCurvePoint
    }

    @State private var draft: [DraftPoint]
    @State private var selectedX: Double?
    @State private var previewCelsius = 65.0
    private let legacyNotice: String?

    init(model: AppModel) {
        self.model = model
        let saved = model.preferences.storedPercentCurve
        let legacy = model.preferences.storedCurve
        let converted = legacy.flatMap {
            PercentFanCurve(converting: $0, fanMaxima: model.snapshot.fans.map(\.maximum))
        }
        if saved == nil, legacy != nil {
            legacyNotice = converted == nil ?
                "The earlier RPM draft is preserved. Conversion requires two matching fan maximums and speeds within that range." :
                "The earlier RPM draft was converted using the two matching fan maximums. Save to keep the percentage draft."
        } else {
            legacyNotice = nil
        }
        let initial = (saved ?? converted)?.points ?? [
            .init(celsius: 45, percent: model.demoCooling == nil ? 30 : 50),
            .init(celsius: 65, percent: model.demoCooling == nil ? 50 : 65),
            .init(celsius: 85, percent: 85)
        ]
        _draft = State(initialValue: initial.map { DraftPoint(value: $0) })
    }

    var body: some View {
        let unit = model.preferences.unit
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        let curve = try? PercentFanCurve(points: points)
        GroupBox("Shared fan curve") {
            Text("Both fans use this percentage. 0% is stopped and 100% is each fan’s reported maximum.")
                .font(.callout).foregroundStyle(.secondary)
            if let legacyNotice {
                Text(legacyNotice).font(.callout).foregroundStyle(.secondary)
            }
            Chart {
                if let curve {
                    ForEach(curve.points.indices, id: \.self) { index in
                        let point = curve.points[index]
                        LineMark(x: .value("Temperature", unit.displayValue(point.celsius)), y: .value("Fan speed (%)", point.percent))
                            .foregroundStyle(.teal)
                        PointMark(x: .value("Temperature", unit.displayValue(point.celsius)), y: .value("Fan speed (%)", point.percent))
                            .foregroundStyle(.teal)
                    }
                    if let percent = curve.target(for: previewCelsius) {
                        RuleMark(x: .value("Simulated temperature", unit.displayValue(previewCelsius)))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        PointMark(x: .value("Temperature", unit.displayValue(previewCelsius)), y: .value("Fan speed (%)", percent))
                            .foregroundStyle(.orange)
                            .symbolSize(65)
                    }
                }
            }
            .chartXSelection(value: $selectedX)
            .chartXScale(domain: unit.displayValue(20)...unit.displayValue(115))
            .chartYScale(domain: 0.0...100.0)
            .chartXAxisLabel(unit.symbol)
            .chartYAxisLabel("%")
            .frame(height: 180)
            .onChange(of: selectedX) {
                if let selectedX { previewCelsius = min(115, max(20, unit.celsiusValue(selectedX))) }
            }
            Slider(value: $previewCelsius, in: 20...115, step: 1) {
                Text("Simulated temperature")
            }
            LabeledContent(model.temperature(previewCelsius), value: curve?.target(for: previewCelsius).map { $0.formatted(format) + "%" } ?? "—")
                .monospacedDigit()
            Divider().padding(.vertical, 5)
            ForEach(Array(draft.enumerated()), id: \.element.id) { index, entry in
                let temperature = field(entry, \.celsius)
                let displayed = Binding(get: { unit.displayValue(temperature.wrappedValue) },
                                        set: { temperature.wrappedValue = unit.celsiusValue($0) })
                HStack {
                    Text("Point \(index + 1)").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    TextField("Temperature for point \(index + 1)", value: displayed, format: format)
                        .labelsHidden().frame(width: 76)
                    Text(unit.symbol).frame(width: 24, alignment: .leading)
                    TextField("Fan speed percent for point \(index + 1)", value: field(entry, \.percent), format: format)
                        .labelsHidden().frame(width: 84)
                    Text("%")
                    Button { draft.removeAll { $0.id == entry.id } } label: {
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
                    draft.append(DraftPoint(value: .init(celsius: min(115, last.celsius + 5), percent: last.percent)))
                }
                .disabled(points.count >= 12)
                Spacer()
                Button("Save Curve") {
                    if let curve { model.preferences.storedPercentCurve = curve }
                }
                .disabled(curve == nil || curve == model.preferences.storedPercentCurve)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 7)
        }
    }

    private var points: [PercentCurvePoint] { draft.map(\.value) }

    private func field(_ entry: DraftPoint, _ path: WritableKeyPath<PercentCurvePoint, Double>) -> Binding<Double> {
        Binding(
            get: { (draft.first { $0.id == entry.id }?.value ?? entry.value)[keyPath: path] },
            set: { newValue in
                if let index = draft.firstIndex(where: { $0.id == entry.id }) {
                    draft[index].value[keyPath: path] = newValue
                }
            }
        )
    }

    private var validationMessage: String? {
        do {
            _ = try PercentFanCurve(points: points)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
