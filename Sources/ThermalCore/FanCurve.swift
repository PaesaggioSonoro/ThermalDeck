import Foundation

public struct CurvePoint: Codable, Equatable, Sendable {
    public var celsius: Double
    public var rpm: Double

    public init(celsius: Double, rpm: Double) {
        self.celsius = celsius
        self.rpm = rpm
    }
}

public struct FanCurve: Codable, Equatable, Sendable {
    public enum ValidationError: LocalizedError {
        case count, pointRange, percentPointRange, temperatureOrder, speedOrder

        public var errorDescription: String? {
            switch self {
            case .count: "A curve needs 2 to 12 points."
            case .pointRange: "Use temperatures from 20 to 115 °C and speeds from 0 to 20,000 RPM."
            case .percentPointRange: "Use temperatures from 20 to 115 °C and speeds from 0% to 100%."
            case .temperatureOrder: "Each temperature must exceed the previous point."
            case .speedOrder: "Fan speed must stay level or rise as temperature increases."
            }
        }
    }

    public let points: [CurvePoint]

    public init(points: [CurvePoint]) throws {
        try validateCurve(points, temperature: \.celsius, speed: \.rpm, maximum: 20_000, rangeError: .pointRange)
        self.points = points
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(points: container.decode([CurvePoint].self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(points)
    }

    public func target(for celsius: Double) -> Double? {
        curveTarget(points, at: celsius, temperature: \.celsius, speed: \.rpm)
    }
}

public struct PercentCurvePoint: Codable, Equatable, Sendable {
    public var celsius: Double
    public var percent: Double

    public init(celsius: Double, percent: Double) {
        self.celsius = celsius
        self.percent = percent
    }
}

public struct PercentFanCurve: Codable, Equatable, Sendable {
    public let points: [PercentCurvePoint]

    public init(points: [PercentCurvePoint]) throws {
        try validateCurve(points, temperature: \.celsius, speed: \.percent, maximum: 100, rangeError: .percentPointRange)
        self.points = points
    }

    public init?(converting legacy: FanCurve, fanMaxima: [Double?]) {
        // A shared percentage preserves the old RPM targets only with equal known maxima.
        guard fanMaxima.count == 2, let maximum = Self.rpm(for: 100, maximum: fanMaxima[0]),
              fanMaxima[1] == maximum,
              legacy.points.allSatisfy({ $0.rpm <= maximum }) else { return nil }
        try? self.init(points: legacy.points.map { PercentCurvePoint(celsius: $0.celsius, percent: $0.rpm / maximum * 100) })
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(points: container.decode([PercentCurvePoint].self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(points)
    }

    public func target(for celsius: Double) -> Double? {
        curveTarget(points, at: celsius, temperature: \.celsius, speed: \.percent)
    }

    public static func rpm(for percent: Double, maximum: Double?) -> Double? {
        guard (0...100).contains(percent), let maximum, (1...20_000).contains(maximum) else { return nil }
        return maximum * (percent / 100)
    }
}

private func validateCurve<Point>(
    _ points: [Point], temperature: KeyPath<Point, Double>, speed: KeyPath<Point, Double>,
    maximum: Double, rangeError: FanCurve.ValidationError
) throws {
    guard (2...12).contains(points.count) else { throw FanCurve.ValidationError.count }
    guard points.allSatisfy({ (20...115).contains($0[keyPath: temperature]) && (0...maximum).contains($0[keyPath: speed]) }) else {
        throw rangeError
    }
    for (lower, upper) in zip(points, points.dropFirst()) {
        guard lower[keyPath: temperature] < upper[keyPath: temperature] else { throw FanCurve.ValidationError.temperatureOrder }
        guard lower[keyPath: speed] <= upper[keyPath: speed] else { throw FanCurve.ValidationError.speedOrder }
    }
}

private func curveTarget<Point>(
    _ points: [Point], at celsius: Double, temperature: KeyPath<Point, Double>, speed: KeyPath<Point, Double>
) -> Double? {
    guard celsius.isFinite, let first = points.first, let last = points.last else { return nil }
    if celsius <= first[keyPath: temperature] { return first[keyPath: speed] }
    if celsius >= last[keyPath: temperature] { return last[keyPath: speed] }
    for (lower, upper) in zip(points, points.dropFirst()) where celsius <= upper[keyPath: temperature] {
        let lowerTemperature = lower[keyPath: temperature]
        let fraction = (celsius - lowerTemperature) / (upper[keyPath: temperature] - lowerTemperature)
        return lower[keyPath: speed] + fraction * (upper[keyPath: speed] - lower[keyPath: speed])
    }
    return nil
}

public struct CurveResponse: Sendable {
    private var lastTemperature: Double?
    private var lastRPM: Double?

    public init() {}

    public mutating func step(
        curve: FanCurve, celsius: Double?, elapsed: Duration, baseline: Double
    ) -> Double? {
        guard let celsius, (5...125).contains(celsius), (0...20_000).contains(baseline), elapsed >= .zero else {
            self = CurveResponse()
            return nil
        }
        if let previous = lastTemperature, celsius < previous, previous - celsius < 2 {
            // Hold small declines to prevent oscillation around a setpoint.
        } else {
            lastTemperature = celsius
        }
        guard let target = curve.target(for: lastTemperature ?? celsius) else { return nil }
        let previous = lastRPM ?? baseline
        let elapsedSeconds = elapsed.components.seconds
        let seconds = min(5, Double(elapsedSeconds) + Double(elapsed.components.attoseconds) / 1e18)
        let result = min(previous + 500 * seconds, max(previous - 200 * seconds, target))
        lastRPM = result
        return result
    }
}
