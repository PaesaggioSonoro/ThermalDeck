import SwiftUI
import ThermalCore

enum DashboardPage: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case sensors = "Sensors"
    case fans = "Fans"
    case history = "History"
    case profiles = "Profiles"
    case menuBar = "Menu Bar"
    case compatibility = "Compatibility"

    var id: Self { self }
    var icon: String {
        switch self {
        case .overview: "gauge.with.dots.needle.50percent"
        case .sensors: "thermometer.medium"
        case .fans: "fan"
        case .history: "chart.xyaxis.line"
        case .profiles: "slider.horizontal.3"
        case .menuBar: "menubar.rectangle"
        case .compatibility: "desktopcomputer"
        }
    }
}

struct Dashboard: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings
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
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.snapshot.machine.chip).font(.callout.weight(.medium))
                            Text(model.snapshot.machine.model).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button { openSettings() } label: {
                            Label("Settings", systemImage: "gearshape").labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .help("Open Settings")
                    }
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
                    case .menuBar: MenuBarView(model: model)
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
            if !model.snapshot.fans.isEmpty {
                overviewFans
            }
            cooling
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { overviewTemperatures }
                VStack(spacing: 12) { overviewTemperatures }
            }
            if model.preferences.collectHistory && model.preferences.showOverviewChart != false {
                let end = model.snapshot.timestamp
                let start = end.addingTimeInterval(-300)
                HistoryChart(title: "Temperature · last 5 min", unit: model.preferences.unit.symbol,
                             points: model.history.plot([.cpu, .gpu], from: start, through: end),
                             range: start...end, temperatureUnit: model.preferences.unit)
            }
        }
    }

    private var overviewFans: some View {
        let fans = model.snapshot.fans
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: min(fans.count, 2))
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(fans) { fan in
                VStack(alignment: .leading, spacing: 8) {
                    Label(fan.id.name, systemImage: "fan")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    OverviewReading(value: model.rpm(fan.speed.freshValue()), size: 38)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary) }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private var overviewTemperatures: some View {
        temperatureCard("CPU", icon: "cpu", group: .cpu)
        temperatureCard("GPU", icon: "display", group: .gpu)
    }

    private func temperatureCard(_ title: String, icon: String, group: SensorGroup) -> some View {
        let now = ContinuousClock.now
        return GroupBox {
            HStack(spacing: 12) {
                temperatureMetric("Zone peak", value: model.snapshot.peak(group, at: now))
                Divider()
                temperatureMetric("Average", value: model.snapshot.zoneAverage(group, at: now))
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
        } label: {
            Label(title, systemImage: icon)
        }
        .frame(minWidth: 220, maxWidth: .infinity)
    }

    private func temperatureMetric(_ title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            OverviewReading(value: model.temperature(value), size: 25)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var cooling: some View {
        let previousMode = model.demoCooling?.previousMode
        let live = model.liveCooling
        let canToggle = previousMode != nil || model.demoCooling?.canStart() == true || live?.canToggle == true
        let isRestoring = previousMode != nil || live?.needsRestoration == true
        let title = previousMode.map { "Restore " + $0.rawValue } ??
            (isRestoring ? "Restore Automatic" : "Max Fans")
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Cooling", systemImage: "fan").foregroundStyle(.secondary)
                    Text(model.coolingLabel).fontWeight(.medium)
                    Spacer()
                    Button(action: model.toggleMaximumFans) {
                        Label(title, systemImage: isRestoring ? "arrow.uturn.backward" : "fan.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canToggle)
                    .help(isRestoring ? title : "Set both fans to their own maximum speeds")
                }
                if let live, let message = live.availability.message {
                    HStack {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                        if live.availability == .needsSetup || live.availability == .needsApproval {
                            Button(live.availability == .needsApproval ? "Open System Settings" : "Set Up Fan Control",
                                   action: live.setUp)
                        }
                    }
                }
                if let notice = model.demoCooling?.notice ?? live?.notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                }
                if case let .unavailable(reason) = model.snapshot.health {
                    Text(reason).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            LabeledContent("Fan control", value: model.liveCooling?.availability == .ready ? model.coolingLabel :
                           (model.demoCooling == nil ? "Unavailable" : "Demo"))
            if let message = model.liveCooling?.availability.message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
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

private struct OverviewReading: View {
    let value: String
    let size: CGFloat

    var body: some View {
        Text(value)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .accessibilityLabel(value == "—" ? "Unavailable" : value)
    }
}
