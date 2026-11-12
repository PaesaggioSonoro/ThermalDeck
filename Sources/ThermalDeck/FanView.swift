import SwiftUI
import ThermalCore

struct FanView: View {
    let model: AppModel

    var body: some View {
        if model.snapshot.fans.isEmpty {
            ContentUnavailableView(model.snapshot.fanCount == 0 ? "No fans reported" : "Fan data unavailable",
                                   systemImage: "fan", description: Text(model.snapshot.health.label))
        } else {
            ForEach(model.snapshot.fans) { fan in
                GroupBox {
                    LabeledContent("Measured speed", value: model.rpm(fan.speed.freshValue()))
                    Divider()
                    LabeledContent("Reported target", value: model.rpm(fresh(fan.target, for: fan)))
                    LabeledContent("Reported minimum", value: model.rpm(fresh(fan.minimum, for: fan)))
                    LabeledContent("Reported maximum", value: model.rpm(fresh(fan.maximum, for: fan)))
                    Divider()
                    LabeledContent("Reported mode", value: fan.speed.hasExpired() ? "Unavailable" : fan.mode.rawValue)
                    LabeledContent("Measurement", value: fan.speed.health().rawValue)
                } label: {
                    Label(fan.id.name, systemImage: "fan")
                }
            }
        }
        Label("ThermalDeck fan control is unavailable on this build.", systemImage: "lock")
            .font(.callout).foregroundStyle(.secondary)
    }

    private func fresh(_ value: Double?, for fan: Fan) -> Double? {
        fan.speed.hasExpired() ? nil : value
    }
}
