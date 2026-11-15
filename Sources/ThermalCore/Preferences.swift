import Foundation

public enum TemperatureUnit: String, CaseIterable, Codable, Sendable {
    case celsius = "Celsius"
    case fahrenheit = "Fahrenheit"

    public var symbol: String { self == .celsius ? "°C" : "°F" }
    public func displayValue(_ celsius: Double) -> Double {
        self == .celsius ? celsius : celsius * 9 / 5 + 32
    }
    public func celsiusValue(_ displayed: Double) -> Double {
        self == .celsius ? displayed : (displayed - 32) * 5 / 9
    }
}

public enum Appearance: String, CaseIterable, Codable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

public enum MenuIndicator: String, CaseIterable, Codable, Sendable {
    case cpu = "CPU"
    case gpu = "GPU"
    case peak = "CPU/GPU peak"
    case fan = "Fan 1 RPM"
    case temperatureAndFan = "Peak and fan 1"
    case icon = "Icon only"
}

public struct Preferences: Codable, Equatable, Sendable {
    public static let schema = 1
    public static let intervals: [Double] = [0.5, 1, 2, 5]
    public static let retentions = [300, 900, 3600]
    public static let historySensorLimit = 4

    public var version = schema
    public var unit = TemperatureUnit.celsius
    public var appearance = Appearance.system
    public var interval = 1.0
    public var retention = 900
    public var collectHistory = true
    public var persistHistory = false
    public var alerts = false
    public var thresholdCelsius = 90.0
    public var menuIndicator = MenuIndicator.peak
    public var storedCurve: FanCurve?
    public var menuFanIndex: Int?
    public var showOverviewChart: Bool?
    private var savedSensorPresentation: SensorPresentation?
    private var savedMenuBar: MenuBarSelection?
    public var storedPercentCurve: PercentFanCurve?
    private var savedHistorySensors: [SensorID]?

    public init() {}

    public var sensorPresentation: SensorPresentation {
        get { savedSensorPresentation ?? SensorPresentation() }
        set { savedSensorPresentation = newValue }
    }

    public var menuBar: MenuBarSelection {
        get {
            if let savedMenuBar { return savedMenuBar }
            let fan = MenuBarReadout.fan(FanID(rawValue: menuFanIndex ?? 0))
            return switch menuIndicator {
            case .cpu: MenuBarSelection(first: .cpuHighest)
            case .gpu: MenuBarSelection(first: .gpuHighest)
            case .peak: MenuBarSelection(first: .cpuGPUHighest)
            case .fan: MenuBarSelection(first: fan)
            case .temperatureAndFan: MenuBarSelection(first: .cpuGPUHighest, second: fan)
            case .icon: MenuBarSelection()
            }
        }
        set { savedMenuBar = newValue }
    }

    public var historySensors: [SensorID] { savedHistorySensors ?? [] }

    public mutating func setHistorySensor(_ id: SensorID, tracked: Bool) {
        var selection = historySensors
        if tracked {
            guard selection.count < Self.historySensorLimit, !selection.contains(id),
                  SeriesKey.validSensorID(id) else { return }
            selection.append(id)
        } else {
            selection.removeAll { $0 == id }
        }
        savedHistorySensors = selection.isEmpty ? nil : selection
    }

    public func pollingInterval(dashboardActive: Bool) -> Double {
        dashboardActive ? interval : max(1, interval)
    }

    public mutating func normalize() {
        if !Self.intervals.contains(interval) { interval = 1 }
        if !Self.retentions.contains(retention) { retention = 900 }
        if let menuFanIndex, !(0...9).contains(menuFanIndex) { self.menuFanIndex = nil }
        if !thresholdCelsius.isFinite || !(40...115).contains(thresholdCelsius) { thresholdCelsius = 90 }
        if let savedHistorySensors {
            var seen: Set<SensorID> = []
            self.savedHistorySensors = Array(savedHistorySensors
                .filter { SeriesKey.validSensorID($0) && seen.insert($0).inserted }
                .prefix(Self.historySensorLimit))
        }
    }
}
