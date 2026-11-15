import Darwin
import Dispatch
import Foundation
import OSLog
import ThermalCore

public actor AppleSMCSource: TelemetrySource {
    private struct Sensor {
        let key: UInt32
        let id: SensorID
        let group: SensorGroup
        let format: String
        let label: String?
        let canPark: Bool
        let alternate: UInt32?
    }

    public nonisolated let machine: Machine
    public nonisolated let simulated = false
    private let queue = DispatchSerialQueue(label: "ThermalDeck AppleSMC", qos: .utility)
    public nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
    private let includeUnclassified: Bool
    private let temperatureCatalog: [String: M4ProTemperatureCatalog.Entry]
    private var connection: SMCConnection?
    private var sensors: [Sensor] = []
    private var hidTemperatures: HIDTemperatures?
    private var nextDiscovery: ContinuousClock.Instant = .now
    private static let log = Logger(subsystem: "org.thermaldeck.local", category: "hardware")
    private static let thermalFormats: Set<String> = ["flt ", "sp78", "ioft"]
    private static let temperatureRange = 5.0...125.0

    public init(includeUnclassified: Bool = false) {
        self.includeUnclassified = includeUnclassified
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let build = Self.sysctlString("kern.osversion")
        machine = Machine(
            model: Self.sysctlString("hw.model") ?? "Unknown model",
            chip: Self.sysctlString("machdep.cpu.brand_string") ?? "Unknown chip",
            os: "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)" +
                (build.map { " (\($0))" } ?? "")
        )
        temperatureCatalog = M4ProTemperatureCatalog.entries(for: machine, diagnostics: includeUnclassified)
    }

    public func reset() {
        connection = nil
        sensors.removeAll()
        hidTemperatures = nil
        nextDiscovery = .now
    }

    public func sample(validity: Duration) -> Snapshot {
        let date = Date()
        let started = ContinuousClock.now
        #if !arch(arm64)
        return Snapshot(machine: machine, health: .unavailable("Live telemetry requires native Apple Silicon."), timestamp: date)
        #else
        let battery = BatteryReader.read()
        if connection == nil, started >= nextDiscovery {
            do {
                connection = try SMCConnection()
            } catch {
                Self.log.error("AppleSMC open failed: \(String(describing: error), privacy: .public)")
                nextDiscovery = started.advanced(by: .seconds(30))
            }
        }
        guard let connection else {
            return Snapshot(machine: machine, battery: battery,
                            health: .unavailable("The read-only AppleSMC connection could not be opened."),
                            timestamp: date)
        }

        if started >= nextDiscovery {
            sensors = discover(connection)
            if !temperatureCatalog.isEmpty { hidTemperatures = HIDTemperatures(diagnostics: includeUnclassified) }
            nextDiscovery = started.advanced(by: .seconds(sensors.isEmpty ? 30 : 300))
            Self.log.info("Discovered \(self.sensors.count, privacy: .public) temperature keys")
        }

        let smcTemperatures = sensors.map { sensor in
            let range = sensor.group == .other ? 1...125 : Self.temperatureRange
            let primary = connection.number(sensor.key, formats: Self.thermalFormats)
            let value: Double?
            if let alternate = sensor.alternate {
                value = M4ProTemperatureCatalog.Entry.activeValue(primary) ??
                    M4ProTemperatureCatalog.Entry.activeValue(connection.number(alternate, formats: Self.thermalFormats))
            } else {
                value = primary
            }
            return Temperature(id: sensor.id, label: sensor.label, group: sensor.group,
                        reading: Reading(value, within: range,
                                         at: date, sampledAt: started, validity: validity),
                        format: sensor.format)
        }
        let temperatures = smcTemperatures +
            M4ProTemperatureCatalog.derivedTemperatures(from: smcTemperatures, at: date, started: started, validity: validity) +
            (hidTemperatures?.sample(at: date, started: started, validity: validity) ?? [])
        // Retain the die hotspot for existing CPU peak monitoring and temperature alerts.
        let cpuHotspot = temperatureCatalog.isEmpty ? nil :
            Reading(connection.number("TCMz", formats: Self.thermalFormats), within: Self.temperatureRange,
                    at: date, sampledAt: started, validity: validity)
        let fanCount = connection.number("FNum", formats: Self.integerFormats).flatMap(Self.validFanCount)
        let fans = (0..<(fanCount ?? 0)).map {
            readFan($0, connection: connection, at: date, started: started, validity: validity)
        }
        let hasTemperature = temperatures.contains { $0.group != .other && $0.reading.freshValue() != nil }
        let missingSMC = zip(sensors, smcTemperatures).contains { sensor, temperature in
            sensor.group != .other && !sensor.canPark && temperature.reading.freshValue() == nil
        }
        let freshFans = fans.filter { $0.speed.freshValue() != nil }.count
        let health: MonitorHealth
        if !hasTemperature && freshFans == 0 {
            health = .unavailable("AppleSMC returned no usable mapped temperatures or fan speeds.")
            self.connection = nil
            nextDiscovery = started.advanced(by: .seconds(sensors.isEmpty && fans.isEmpty ? 30 : 5))
        } else if !hasTemperature || fanCount == nil || missingSMC || freshFans != fans.count {
            health = .partial
        } else {
            health = .live
        }
        return Snapshot(machine: machine, temperatures: temperatures, fans: fans, fanCount: fanCount,
                        battery: battery, cpuHotspot: cpuHotspot, health: health, timestamp: date)
        #endif
    }

    private static let integerFormats: Set<String> = ["ui8 ", "ui16", "ui32"]
    private static let rpmFormats: Set<String> = ["flt ", "fpe2", "ui16"]
    private static let rpmRange = 0.0...20_000.0

    static func validFanCount(_ value: Double) -> Int? {
        guard (0...10).contains(value) else { return nil }
        return Int(exactly: value)
    }

    private func readFan(
        _ index: Int, connection: SMCConnection, at date: Date,
        started: ContinuousClock.Instant, validity: Duration
    ) -> Fan {
        let prefix = "F\(index)"
        func rpm(_ suffix: String) -> Double? {
            connection.number(prefix + suffix, formats: Self.rpmFormats)
        }
        func validRPM(_ suffix: String) -> Double? {
            guard let value = rpm(suffix), Self.rpmRange.contains(value) else { return nil }
            return value
        }
        let min = validRPM("Mn")
        let max = validRPM("Mx").flatMap { $0 > 0 ? $0 : nil }
        let ordered = min.flatMap { lower in max.map { lower <= $0 } } ?? true
        let modeValue = connection.number(prefix + "Md", formats: Self.integerFormats) ??
            connection.number(prefix + "md", formats: Self.integerFormats)
        let mode: FanMode = switch modeValue {
        case 0: .automatic
        case 1: .manual
        case 3: .system
        default: .unknown
        }

        return Fan(id: FanID(rawValue: index),
                   speed: Reading(rpm("Ac"), within: Self.rpmRange, at: date, sampledAt: started, validity: validity),
                   minimum: ordered ? min : nil, maximum: ordered ? max : nil,
                   target: validRPM("Tg"), mode: mode)
    }

    private func discover(_ connection: SMCConnection) -> [Sensor] {
        let catalog = includeUnclassified ? connection.keys() : []
        let alternateKeys = Set(temperatureCatalog.values.compactMap { $0.alternate.flatMap(SMCCodec.fourCC) })
        let keys = Set(catalog).subtracting(alternateKeys).union(temperatureCatalog.keys.compactMap(SMCCodec.fourCC))

        return keys.compactMap { key in
            guard let name = SMCCodec.name(key), name.hasPrefix("T") else { return nil }
            let entry = temperatureCatalog[name]
            let alternate = entry?.alternate.flatMap(SMCCodec.fourCC)
            let info = connection.describe(key) ?? alternate.flatMap(connection.describe)
            guard let info, Self.thermalFormats.contains(info.format) else { return nil }
            if entry == nil {
                guard let value = connection.number(key, formats: Self.thermalFormats),
                      (1...125).contains(value) else { return nil }
            }
            return Sensor(key: key, id: SensorID(rawValue: name), group: entry?.group ?? .other,
                          format: info.format, label: entry?.label, canPark: entry?.canPark ?? false, alternate: alternate)
        }.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private nonisolated static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, (1...1_024).contains(size) else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        let status = bytes.withUnsafeMutableBytes { buffer in
            sysctlbyname(name, buffer.baseAddress, &size, nil, 0)
        }
        guard status == 0 else { return nil }
        return String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8)
    }
}
