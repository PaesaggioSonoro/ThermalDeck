import Foundation

public enum HistoryExport {
    public enum Format: String, Sendable { case csv, json }

    private struct ExportSample: Codable {
        let timestampUTC: String
        let metric: String
        let unit: String
        let value: Double
    }

    private struct ExportEnvelope: Codable {
        let version: Int
        let simulated: Bool
        let samples: [ExportSample]
    }

    public static func encode(_ records: [HistoryRecord], simulated: Bool, format: Format) throws -> Data {
        let dateFormat = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let samples = records.flatMap { record -> [ExportSample] in
            guard record.date.timeIntervalSinceReferenceDate.isFinite else { return [] }
            return record.values.sorted { $0.key.exportName < $1.key.exportName }.compactMap { key, value in
                guard key.validates(value) else { return nil }
                return ExportSample(timestampUTC: record.date.formatted(dateFormat), metric: key.exportName,
                                    unit: key.isTemperature ? "celsius" : "rpm", value: value)
            }
        }
        switch format {
        case .csv:
            let header = "timestamp_utc,metric,unit,value,simulated"
            let lines = samples.map { "\($0.timestampUTC),\($0.metric),\($0.unit),\($0.value),\(simulated)" }
            return Data(([header] + lines).joined(separator: "\n").appending("\n").utf8)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(ExportEnvelope(version: 1, simulated: simulated, samples: samples))
        }
    }
}

private extension SeriesKey {
    var exportName: String {
        switch self {
        case .cpu: "cpu_zone_peak"
        case .gpu: "gpu_zone_peak"
        case .battery: "battery_peak"
        case .sensor(let id): "sensor_" + id.rawValue
        case .fan(let id): "fan_\(id.rawValue)_measured"
        case .target(let id): "fan_\(id.rawValue)_target"
        }
    }
}
