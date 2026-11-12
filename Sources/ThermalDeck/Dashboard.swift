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
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                MetricTile(title: "CPU peak", value: model.temperature(model.snapshot.peak(.cpu)), icon: "cpu")
                MetricTile(title: "GPU peak", value: model.temperature(model.snapshot.peak(.gpu)), icon: "gpu")
                MetricTile(title: "CPU / GPU peak", value: model.temperature(model.snapshot.peak()), icon: "thermometer.medium")
            }
            if !model.snapshot.fans.isEmpty {
                GroupBox("Fan speeds") {
                    ForEach(model.snapshot.fans) { fan in
                        LabeledContent(fan.id.name, value: model.rpm(fan.speed.freshValue()))
                    }
                }
            }
            if model.preferences.collectHistory {
                let end = model.snapshot.timestamp
                let start = end.addingTimeInterval(-300)
                HistoryChart(title: "Temperature · last 5 min", unit: model.preferences.unit.symbol,
                             points: model.history.plot([.cpu, .gpu], from: start, through: end),
                             range: start...end, temperatureUnit: model.preferences.unit)
            }
            GroupBox {
                LabeledContent("Monitoring", value: model.snapshot.health.label)
                Divider()
                LabeledContent("ThermalDeck profile", value: "Automatic")
                if case let .unavailable(reason) = model.snapshot.health {
                    Text(reason).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var compatibility: some View {
        GroupBox("This Mac") {
            LabeledContent("Model", value: model.snapshot.machine.model)
            Divider()
            LabeledContent("Chip", value: model.snapshot.machine.chip)
            Divider()
            LabeledContent("macOS", value: model.snapshot.machine.os)
            Divider()
            LabeledContent("Fan control", value: "Unavailable")
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
