import SwiftUI
import ThermalCore

struct CompatibilityReport: Identifiable {
    let text: String
    var id: String { text }

    init(snapshot: Snapshot, version: String) {
        text = """
        ThermalDeck \(version)
        Mode: \(snapshot.simulated ? "Simulation" : "Live hardware")
        Model: \(snapshot.machine.model)
        Chip: \(snapshot.machine.chip)
        OS: \(snapshot.machine.os)
        Monitoring: \(snapshot.health.label)
        Mapped temperature zones: \(snapshot.temperatures.count)
        Fans reported: \(snapshot.fanCount.map(String.init) ?? "Unavailable")
        Battery power flow: \(snapshot.battery?.flowWatts == nil ? "Unavailable" : "Available")
        """
    }
}

struct CompatibilityReportView: View {
    let report: CompatibilityReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compatibility Report").font(.headline)
            Text("Review and copy the fields you want to share.")
                .foregroundStyle(.secondary)
            ScrollView {
                Text(report.text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 490, height: 330)
    }
}
