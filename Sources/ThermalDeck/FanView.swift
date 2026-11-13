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
                    readout("Measured speed", model.rpm(fan.speed.freshValue()))
                    Divider()
                    readout("Reported target", model.rpm(fresh(fan.target, for: fan)))
                    readout("Reported minimum", model.rpm(fresh(fan.minimum, for: fan)))
                    readout("Reported maximum", model.rpm(fresh(fan.maximum, for: fan)))
                    Divider()
                    readout("Reported mode", fan.speed.hasExpired() ? "Unavailable" : fan.mode.rawValue)
                    readout("Measurement", fan.speed.health().rawValue)
                } label: {
                    Label(fan.id.name, systemImage: "fan")
                }
            }
        }
        if let message = model.liveCooling?.availability.message {
            Label(message, systemImage: "lock")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func readout(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func fresh(_ value: Double?, for fan: Fan) -> Double? {
        fan.speed.hasExpired() ? nil : value
    }
}
