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
        case count, pointRange, temperatureOrder, speedOrder

        public var errorDescription: String? {
            switch self {
            case .count: "A curve needs 2 to 12 points."
            case .pointRange: "Use temperatures from 20 to 115 °C and speeds from 0 to 20,000 RPM."
            case .temperatureOrder: "Each temperature must exceed the previous point."
            case .speedOrder: "Fan speed must stay level or rise as temperature increases."
            }
        }
    }

    public let points: [CurvePoint]

    public init(points: [CurvePoint]) throws {
        guard (2...12).contains(points.count) else { throw ValidationError.count }
        guard points.allSatisfy({ (20...115).contains($0.celsius) && (0...20_000).contains($0.rpm) }) else {
            throw ValidationError.pointRange
        }
        for (lower, upper) in zip(points, points.dropFirst()) {
            guard lower.celsius < upper.celsius else { throw ValidationError.temperatureOrder }
            guard lower.rpm <= upper.rpm else { throw ValidationError.speedOrder }
        }
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
        guard celsius.isFinite else { return nil }
        guard let first = points.first, let last = points.last else { return nil }
        if celsius <= first.celsius { return first.rpm }
        if celsius >= last.celsius { return last.rpm }
        for (lower, upper) in zip(points, points.dropFirst()) where celsius <= upper.celsius {
            let fraction = (celsius - lower.celsius) / (upper.celsius - lower.celsius)
            return lower.rpm + fraction * (upper.rpm - lower.rpm)
        }
        return nil
    }
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
