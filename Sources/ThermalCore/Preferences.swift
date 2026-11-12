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

    public var label: String {
        switch self {
        case .fan: "Fan RPM"
        case .temperatureAndFan: "Peak and fan"
        default: rawValue
        }
    }
}

public struct Preferences: Codable, Equatable, Sendable {
    public static let schema = 1
    public static let intervals = [1, 2, 5]
    public static let retentions = [300, 900, 3600]

    public var version = schema
    public var unit = TemperatureUnit.celsius
    public var appearance = Appearance.system
    public var interval = 1
    public var retention = 900
    public var collectHistory = true
    public var persistHistory = false
    public var alerts = false
    public var thresholdCelsius = 90.0
    public var menuIndicator = MenuIndicator.peak
    public var storedCurve: FanCurve?
    public var menuFanIndex: Int?
    public var showOverviewChart: Bool?

    public init() {}

    public mutating func normalize() {
        if !Self.intervals.contains(interval) { interval = 1 }
        if !Self.retentions.contains(retention) { retention = 900 }
        if let menuFanIndex, !(0...9).contains(menuFanIndex) { self.menuFanIndex = nil }
        if !thresholdCelsius.isFinite || !(40...115).contains(thresholdCelsius) { thresholdCelsius = 90 }
    }
}
