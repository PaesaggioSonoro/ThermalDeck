import Foundation

public enum SeriesKey: Hashable, Codable, Sendable {
    case cpu, gpu, battery
    case sensor(SensorID)
    case fan(FanID), target(FanID)

    public var label: String {
        switch self {
        case .cpu: "CPU zones"
        case .gpu: "GPU zones"
        case .battery: "Battery peak"
        case .sensor(let id): id.rawValue
        case .fan(let id): id.name
        case .target(let id): id.name + " target"
        }
    }

    public var isTemperature: Bool {
        switch self {
        case .cpu, .gpu, .battery, .sensor: true
        case .fan, .target: false
        }
    }

    func validates(_ value: Double) -> Bool {
        switch self {
        case .cpu, .gpu, .battery: return (5...125).contains(value)
        case .sensor(let id): return Self.validSensorID(id) && (5...125).contains(value)
        case .fan(let id), .target(let id): return (0...9).contains(id.rawValue) && (0...20_000).contains(value)
        }
    }

    static func validSensorID(_ id: SensorID) -> Bool {
        (1...32).contains(id.rawValue.utf8.count) && id.rawValue.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) ||
                $0 == 45 || $0 == 46 || $0 == 95
        }
    }
}

public struct HistoryRecord: Codable, Sendable {
    public let date: Date
    public let values: [SeriesKey: Double]

    public init(date: Date, values: [SeriesKey: Double]) {
        self.date = date
        self.values = values
    }

    public init(snapshot: Snapshot, selectedSensors: [SensorID] = [], now: ContinuousClock.Instant = .now) {
        var values: [SeriesKey: Double] = [
            .cpu: snapshot.peak(.cpu, at: now),
            .gpu: snapshot.peak(.gpu, at: now),
            .battery: snapshot.peak(.battery, at: now)
        ].compactMapValues { $0 }
        let tracked = Set(selectedSensors.prefix(Preferences.historySensorLimit))
        for sensor in snapshot.temperatures where sensor.group != .other && tracked.contains(sensor.id) {
            values[.sensor(sensor.id)] = sensor.reading.freshValue(at: now)
        }
        for fan in snapshot.fans {
            values[.fan(fan.id)] = fan.speed.freshValue(at: now)
            if !fan.speed.hasExpired(at: now) { values[.target(fan.id)] = fan.target }
        }
        self.init(date: snapshot.timestamp, values: values)
    }
}

public struct PlotPoint: Identifiable, Sendable {
    public let date: Date
    public let value: Double
    public let key: SeriesKey
    public let segment: Int
    public var line: String { key.label + " " + String(segment) }
    public var id: String { line + " " + String(date.timeIntervalSinceReferenceDate) }
}

public struct HistoryBuffer: Sendable {
    public static let limit = 7_200
    public private(set) var records: [HistoryRecord] = []

    public init() {}

    public mutating func append(_ record: HistoryRecord, retention: Int) {
        guard record.date.timeIntervalSinceReferenceDate.isFinite else { return }
        if let last = records.last, record.date <= last.date {
            // A wall-clock correction can invalidate the ordering of the previous series.
            guard last.date.timeIntervalSince(record.date) > 1 else { return }
            records.removeAll()
        }
        var values = record.values.filter { $0.key.validates($0.value) }
        let sensors = values.keys.compactMap { key -> SensorID? in
            if case .sensor(let id) = key { return id }
            return nil
        }.sorted { $0.rawValue < $1.rawValue }
        for id in sensors.dropFirst(Preferences.historySensorLimit) { values.removeValue(forKey: .sensor(id)) }
        records.append(HistoryRecord(date: record.date, values: values))
        trim(at: record.date, retention: retention)
    }

    public mutating func trim(at now: Date, retention: Int) {
        let start = now.addingTimeInterval(-Double(max(0, min(3_600, retention))))
        let expired = records.prefix(while: { $0.date < start }).count
        records.removeFirst(max(expired, records.count - Self.limit))
    }

    public mutating func restore(_ saved: [HistoryRecord], at now: Date, retention: Int) {
        let live = records
        records.removeAll(keepingCapacity: true)
        let end = live.first?.date ?? now
        for record in saved.suffix(Self.limit).sorted(by: { $0.date < $1.date }) where record.date < end {
            append(record, retention: retention)
        }
        for record in live { append(record, retention: retention) }
        trim(at: now, retention: retention)
    }

    public func plot(_ keys: [SeriesKey], from start: Date, through end: Date) -> [PlotPoint] {
        let span = max(1, end.timeIntervalSince(start))
        let bucket = max(1, ceil(span / 180))
        let selected = records.suffix(whileDateAtLeast: start)
        return keys.flatMap { key in
            var result: [PlotPoint] = []
            var previous: Date?
            var segment = 0
            var previousBucket: Double?
            for record in selected where record.date <= end {
                guard let value = record.values[key] else {
                    previous = nil
                    continue
                }
                if previous.map({ record.date.timeIntervalSince($0) > 16 }) ?? true {
                    segment += 1
                    previousBucket = nil
                }
                let index = floor(record.date.timeIntervalSinceReferenceDate / bucket)
                let point = PlotPoint(date: record.date, value: value, key: key, segment: segment)
                if index == previousBucket, let last = result.last {
                    if value >= last.value { result[result.count - 1] = point }
                } else {
                    result.append(point)
                }
                previous = record.date
                previousBucket = index
            }
            return result
        }
    }

    public func archiveRecords() -> [HistoryRecord] {
        // Preserve the peak per series and retain any series gaps in a five-second bucket.
        var result: [HistoryRecord] = []
        for record in records {
            if let last = result.last,
               floor(last.date.timeIntervalSinceReferenceDate / 5) == floor(record.date.timeIntervalSinceReferenceDate / 5) {
                var aggregate: [SeriesKey: Double] = [:]
                for (key, previous) in last.values {
                    if let current = record.values[key] { aggregate[key] = max(previous, current) }
                }
                result[result.count - 1] = HistoryRecord(date: record.date, values: aggregate)
            } else {
                result.append(record)
            }
        }
        return result
    }
}

private extension Array where Element == HistoryRecord {
    func suffix(whileDateAtLeast start: Date) -> ArraySlice<HistoryRecord> {
        var lower = startIndex
        var upper = endIndex
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if self[middle].date < start { lower = middle + 1 } else { upper = middle }
        }
        return self[lower...]
    }
}

public actor HistoryArchive {
    private struct Envelope: Codable {
        let version: Int
        let records: [HistoryRecord]
    }

    private let url: URL
    private var lastRevision = 0
    private static let byteLimit = 2_000_000

    public init(url: URL) { self.url = url }

    public func load() throws -> [HistoryRecord] {
        let file = FileManager.default
        guard file.fileExists(atPath: url.path) else { return [] }
        let attributes = try file.attributesOfItem(atPath: url.path)
        guard let bytes = attributes[.size] as? NSNumber, bytes.intValue <= Self.byteLimit else {
            throw ArchiveError.invalid
        }
        let data = try Data(contentsOf: url)
        guard data.count <= Self.byteLimit else { throw ArchiveError.invalid }
        let saved = try JSONDecoder().decode(Envelope.self, from: data)
        guard saved.version == 1, saved.records.count <= 721 else { throw ArchiveError.invalid }
        return saved.records
    }

    public func save(_ records: [HistoryRecord], revision: Int) throws {
        guard revision > lastRevision else { return }
        lastRevision = revision
        guard records.count <= 721 else { throw ArchiveError.invalid }
        let data = try JSONEncoder().encode(Envelope(version: 1, records: records))
        guard data.count <= Self.byteLimit else { throw ArchiveError.invalid }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    public func clear(revision: Int) throws {
        guard revision > lastRevision else { return }
        lastRevision = revision
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    private enum ArchiveError: Error { case invalid }
}
