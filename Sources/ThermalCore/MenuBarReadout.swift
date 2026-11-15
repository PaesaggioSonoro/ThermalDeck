public enum MenuBarReadout: Hashable, Codable, Sendable {
    case sensor(SensorID)
    case highestTemperature
    case cpuHighest
    case gpuHighest
    case fan(FanID)
    // Preserves the existing CPU/GPU peak selection from older preferences.
    case cpuGPUHighest

    public func label(in snapshot: Snapshot) -> String {
        switch self {
        case .sensor(let id):
            snapshot.temperatures.first { $0.id == id }?.displayName ?? "Unavailable sensor"
        case .highestTemperature: "Highest temperature"
        case .cpuHighest: "CPU highest"
        case .gpuHighest: "GPU highest"
        case .fan(let id): "\(id.name) speed"
        case .cpuGPUHighest: "CPU/GPU peak"
        }
    }

    public func value(
        in snapshot: Snapshot, hiding hidden: Set<SensorID> = [], at now: ContinuousClock.Instant = .now
    ) -> Double? {
        if case .fan(let id) = self {
            return snapshot.fans.first { $0.id == id }?.speed.freshValue(at: now)
        }
        return temperatureSensor(in: snapshot, hiding: hidden, at: now)?.reading.freshValue(at: now)
    }

    public func temperatureSensor(
        in snapshot: Snapshot, hiding hidden: Set<SensorID> = [], at now: ContinuousClock.Instant = .now
    ) -> Temperature? {
        let groups: Set<SensorGroup>
        switch self {
        case .sensor(let id): return snapshot.temperatures.first { $0.id == id }
        case .fan: return nil
        case .highestTemperature: groups = Set(SensorGroup.allCases).subtracting([.other])
        case .cpuHighest: groups = [.cpu]
        case .gpuHighest: groups = [.gpu]
        case .cpuGPUHighest: groups = [.cpu, .gpu]
        }
        return snapshot.temperatures.lazy
            .filter { groups.contains($0.group) && !hidden.contains($0.id) }
            .compactMap { sensor in sensor.reading.freshValue(at: now).map { (sensor: sensor, value: $0) } }
            .max { $0.value < $1.value }?.sensor
    }
}

public struct MenuBarSelection: Codable, Equatable, Sendable {
    public private(set) var first: MenuBarReadout?
    public private(set) var second: MenuBarReadout?

    public init(first: MenuBarReadout? = nil, second: MenuBarReadout? = nil) {
        self.first = first ?? second
        self.second = first != nil && second != first ? second : nil
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(first: try container.decodeIfPresent(MenuBarReadout.self, forKey: .first),
                  second: try container.decodeIfPresent(MenuBarReadout.self, forKey: .second))
    }

    public mutating func selectFirst(_ readout: MenuBarReadout?) {
        first = readout
        if readout == nil || readout == second { second = nil }
    }

    public mutating func selectSecond(_ readout: MenuBarReadout?) {
        guard let first, readout != first else { return }
        second = readout
    }

    public var readouts: [MenuBarReadout] {
        [first, second].compactMap { $0 }
    }

    private enum CodingKeys: String, CodingKey { case first, second }
}
