import SwiftUI
import ThermalCore

enum DashboardPage: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case sensors = "Sensors"
    case fans = "Fans"
    case history = "History"
    case profiles = "Profiles"
    case compatibility = "Compatibility"

    var id: Self { self }
    var icon: String {
        switch self {
        case .overview: "gauge.with.dots.needle.50percent"
        case .sensors: "thermometer.medium"
        case .fans: "fan"
        case .history: "chart.xyaxis.line"
        case .profiles: "slider.horizontal.3"
        case .compatibility: "desktopcomputer"
        }
    }
}

struct Dashboard: View {
    let model: AppModel
    @State private var page: DashboardPage? = .overview
    @State private var compatibilityReport: CompatibilityReport?

    var body: some View {
        NavigationSplitView {
            List(DashboardPage.allCases, selection: $page) { page in
                Label(page.rawValue, systemImage: page.icon).tag(page)
            }
            .navigationSplitViewColumnWidth(min: 155, ideal: 180, max: 215)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Divider()
                    Text(model.snapshot.machine.chip).font(.callout.weight(.medium))
                    Text(model.snapshot.machine.model).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if model.snapshot.simulated {
                        Label("Simulation · sample data", systemImage: "flask")
                            .font(.callout.weight(.medium)).foregroundStyle(.orange)
                    }
                    switch page ?? .overview {
                    case .overview: overview
                    case .sensors: SensorView(model: model)
                    case .fans: FanView(model: model)
                    case .history: HistoryView(model: model)
                    case .profiles: ProfilesView(model: model)
                    case .compatibility: compatibility
                    }
                }
                .frame(maxWidth: 1040, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle((page ?? .overview).rawValue)
        }
        .sheet(item: $compatibilityReport) { CompatibilityReportView(report: $0) }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(model.snapshot.health.label, systemImage: healthIcon)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(model.snapshot.health == .live ? Color.teal : .secondary)
                Spacer()
                if model.snapshot.health == .live || model.snapshot.health == .partial {
                    Text("Updated " + model.snapshot.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                MetricTile(title: "CPU zone peak", value: model.temperature(model.snapshot.peak(.cpu)), icon: "cpu")
                MetricTile(title: "GPU zone peak", value: model.temperature(model.snapshot.peak(.gpu)), icon: "display")
                MetricTile(title: "Mapped peak", value: model.temperature(model.snapshot.peak()), icon: "thermometer.medium")
            }
            if !model.snapshot.fans.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 8) {
                    ForEach(model.snapshot.fans) { fan in
                        HStack {
                            Label(fan.id.name, systemImage: "fan").foregroundStyle(.secondary)
                            Spacer()
                            Text(model.rpm(fan.speed.freshValue())).monospacedDigit().fontWeight(.medium)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(.quaternary.opacity(0.32), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            if model.preferences.collectHistory && model.preferences.showOverviewChart != false {
                let end = model.snapshot.timestamp
                let start = end.addingTimeInterval(-300)
                HistoryChart(title: "Temperature · last 5 min", unit: model.preferences.unit.symbol,
                             points: model.history.plot([.cpu, .gpu], from: start, through: end),
                             range: start...end, temperatureUnit: model.preferences.unit)
            }
            if let battery = model.snapshot.battery {
                GroupBox("Battery") {
                    LabeledContent("Power source", value: battery.source?.rawValue ?? "Unavailable")
                    if let percent = battery.chargePercent {
                        LabeledContent("Charge", value: (percent / 100).formatted(.percent.precision(.fractionLength(0))))
                    }
                    if let charging = battery.isCharging {
                        LabeledContent("Charging", value: charging ? "Yes" : "No")
                    }
                    if let watts = battery.flowWatts {
                        LabeledContent("Battery power flow",
                                       value: watts.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false))) + " W")
                            .help("Positive values flow into the battery. Negative values flow out.")
                    }
                }
            }
            GroupBox {
                HStack {
                    Label("Cooling", systemImage: "checkmark.circle").foregroundStyle(.secondary)
                    Spacer()
                    Text("Automatic").fontWeight(.medium)
                }
                .accessibilityElement(children: .combine)
                if case let .unavailable(reason) = model.snapshot.health {
                    Text(reason).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var healthIcon: String {
        switch model.snapshot.health {
        case .live: "waveform"
        case .partial: "exclamationmark.circle"
        case .waiting: "ellipsis.circle"
        case .paused: "pause.circle"
        case .unavailable: "exclamationmark.triangle"
        }
    }

    @ViewBuilder
    private var compatibility: some View {
        GroupBox("This Mac") {
            LabeledContent("Model", value: model.snapshot.machine.model)
            Divider()
            LabeledContent("Chip", value: model.snapshot.machine.chip)
            Divider()
            LabeledContent("macOS", value: model.snapshot.machine.os)
            Divider()
            LabeledContent("Mapped temperature zones", value: model.snapshot.temperatures.count.formatted())
            LabeledContent("Fans reported", value: model.snapshot.fanCount?.formatted() ?? "Unavailable")
            Divider()
            LabeledContent("Fan control", value: "Unavailable")
            Text("Independent restoration after a control-process failure has not been verified.")
                .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Button("Review Compatibility Report…") {
                compatibilityReport = CompatibilityReport(
                    snapshot: model.snapshot,
                    version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
                )
            }
        }
        GroupBox("About") {
            LabeledContent(ThermalDeckApp.displayName, value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
            Text("Read-only monitoring uses an undocumented AppleSMC interface and can vary by device or macOS version. This software is provided as is. Manual fan control can alter cooling and may contribute to instability, damage, or data loss. Use at your own risk. ThermalDeck has no affiliation with Apple.")
                .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 29, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .accessibilityLabel(value == "—" ? "Unavailable" : value)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary) }
        .accessibilityElement(children: .combine)
    }
}
