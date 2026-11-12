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
            snapshot.temperatures.first { $0.id == id }.map {
                $0.label == id.rawValue ? $0.label : "\($0.label) (\(id.rawValue))"
            } ?? id.rawValue
        case .highestTemperature: "Highest temperature"
        case .cpuHighest: "CPU highest"
        case .gpuHighest: "GPU highest"
        case .fan(let id): "\(id.name) speed"
        case .cpuGPUHighest: "CPU/GPU peak"
        }
    }

    public func value(in snapshot: Snapshot, at now: ContinuousClock.Instant = .now) -> Double? {
        switch self {
        case .sensor(let id): snapshot.temperatures.first { $0.id == id }?.reading.freshValue(at: now)
        case .highestTemperature: snapshot.highestTemperature(at: now)
        case .cpuHighest: snapshot.peak(.cpu, at: now)
        case .gpuHighest: snapshot.peak(.gpu, at: now)
        case .fan(let id): snapshot.fans.first { $0.id == id }?.speed.freshValue(at: now)
        case .cpuGPUHighest: snapshot.peak(at: now)
        }
    }
}

public struct MenuBarSelection: Codable, Equatable, Sendable {
    public var first: MenuBarReadout?
    public var second: MenuBarReadout?

    public init(first: MenuBarReadout? = nil, second: MenuBarReadout? = nil) {
        self.first = first
        self.second = second
    }

    public var readouts: [MenuBarReadout] {
        [first, second == first ? nil : second].compactMap { $0 }
    }
}
