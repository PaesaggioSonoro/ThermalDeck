import Foundation

public struct Machine: Equatable, Sendable {
    public let model: String
    public let chip: String
    public let os: String

    public init(model: String, chip: String, os: String) {
        self.model = model
        self.chip = chip
        self.os = os
    }
}

public struct SensorID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public enum SensorGroup: String, CaseIterable, Sendable {
    case cpu = "CPU zones"
    case gpu = "GPU zones"
    case battery = "Battery"
    case memory = "Memory proximity"
    case other = "Unclassified"
}

public enum ReadingHealth: String, Sendable {
    case fresh = "Live"
    case stale = "Stale"
    case unavailable = "Unavailable"
    case invalid = "Invalid"
}

public struct Reading: Sendable {
    public let value: Double?
    public let timestamp: Date
    public let expiresAt: ContinuousClock.Instant
    private let initialHealth: ReadingHealth

    public init(
        _ raw: Double?, within range: ClosedRange<Double>, at timestamp: Date,
        sampledAt: ContinuousClock.Instant = .now, validity: Duration = .seconds(10)
    ) {
        self.timestamp = timestamp
        expiresAt = sampledAt.advanced(by: validity)
        if let raw, raw.isFinite, range.contains(raw) {
            value = raw
            initialHealth = .fresh
        } else {
            value = nil
            initialHealth = raw == nil ? .unavailable : .invalid
        }
    }

    public func hasExpired(at now: ContinuousClock.Instant = .now) -> Bool { now >= expiresAt }

    public func health(at now: ContinuousClock.Instant = .now) -> ReadingHealth {
        initialHealth == .fresh && hasExpired(at: now) ? .stale : initialHealth
    }

    public func freshValue(at now: ContinuousClock.Instant = .now) -> Double? {
        health(at: now) == .fresh ? value : nil
    }
}

public struct Temperature: Identifiable, Sendable {
    public let id: SensorID
    public let group: SensorGroup
    public let reading: Reading
    public let format: String

    public init(id: SensorID, group: SensorGroup, reading: Reading, format: String) {
        self.id = id
        self.group = group
        self.reading = reading
        self.format = format
    }
}

public struct FanID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public var name: String { "Fan \(rawValue == Int.max ? rawValue : rawValue + 1)" }
}

public enum FanMode: String, Sendable {
    case automatic = "Automatic"
    case system = "System managed"
    case manual = "Manual reported"
    case unknown = "Unknown"
}

public struct Fan: Identifiable, Sendable {
    public let id: FanID
    public let speed: Reading
    public let minimum: Double?
    public let maximum: Double?
    public let target: Double?
    public let mode: FanMode

    public init(id: FanID, speed: Reading, minimum: Double?, maximum: Double?, target: Double?, mode: FanMode) {
        self.id = id
        self.speed = speed
        self.minimum = minimum
        self.maximum = maximum
        self.target = target
        self.mode = mode
    }
}

public enum MonitorHealth: Equatable, Sendable {
    case waiting
    case live
    case partial
    case paused
    case unavailable(String)

    public var label: String {
        switch self {
        case .waiting: "Discovering hardware"
        case .live: "Live monitoring"
        case .partial: "Partial telemetry"
        case .paused: "Monitoring paused"
        case .unavailable: "Monitoring unavailable"
        }
    }
}

public struct Snapshot: Sendable {
    public let machine: Machine
    public let temperatures: [Temperature]
    public let fans: [Fan]
    public let fanCount: Int?
    public let health: MonitorHealth
    public let timestamp: Date
    public let simulated: Bool

    public init(
        machine: Machine, temperatures: [Temperature] = [], fans: [Fan] = [], fanCount: Int? = nil,
        health: MonitorHealth, timestamp: Date = .now, simulated: Bool = false
    ) {
        self.machine = machine
        self.temperatures = temperatures
        self.fans = fans
        self.fanCount = fanCount
        self.health = health
        self.timestamp = timestamp
        self.simulated = simulated
    }

    public func peak(_ group: SensorGroup? = nil, at now: ContinuousClock.Instant = .now) -> Double? {
        temperatures.lazy.filter { sensor in
            if let group { return sensor.group == group }
            return sensor.group == .cpu || sensor.group == .gpu
        }.compactMap { $0.reading.freshValue(at: now) }.max()
    }
}

public protocol TelemetrySource: Sendable {
    var machine: Machine { get }
    var simulated: Bool { get }
    func sample(validity: Duration) async -> Snapshot
    func reset() async
}

public actor DemoSource: TelemetrySource {
    public nonisolated let machine = Machine(model: "Simulated Mac", chip: "Simulated chip", os: "Preview data")
    public nonisolated let simulated = true
    private var phase = 0.0

    public init() {}

    public func sample(validity: Duration) -> Snapshot {
        phase += 0.32
        let date = Date()
        let cpu = Temperature(id: SensorID(rawValue: "DEMO-CPU"), group: .cpu,
                              reading: Reading(54 + 9 * sin(phase), within: 1...125, at: date, validity: validity),
                              format: "Demo")
        let gpu = Temperature(id: SensorID(rawValue: "DEMO-GPU"), group: .gpu,
                              reading: Reading(47 + 5 * cos(phase), within: 1...125, at: date, validity: validity),
                              format: "Demo")
        let fans = (0..<2).map { index in
            let rpm = index == 0 ? 2300 + 500 * sin(phase) : 1900 + 300 * cos(phase)
            return Fan(id: FanID(rawValue: index), speed: Reading(rpm, within: 0...10_000, at: date, validity: validity),
                       minimum: 1500, maximum: 6500, target: nil, mode: .system)
        }
        return Snapshot(machine: machine, temperatures: [cpu, gpu], fans: fans, fanCount: fans.count,
                        health: .live, timestamp: date, simulated: true)
    }

    public func reset() { phase = 0 }
}
