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
    }

    public nonisolated let machine: Machine
    public nonisolated let simulated = false
    private let queue = DispatchSerialQueue(label: "ThermalDeck AppleSMC", qos: .utility)
    public nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
    private let includeUnclassified: Bool
    private var connection: SMCConnection?
    private var sensors: [Sensor] = []
    private var nextDiscovery: ContinuousClock.Instant = .now
    private static let log = Logger(subsystem: "org.thermaldeck.local", category: "hardware")
    private static let thermalFormats: Set<String> = ["flt ", "sp78"]
    private static let temperatureRange = 5.0...125.0
    // Tp keys on this model have returned ambient-inconsistent values near 2–4.
    private static let cpuKeys: Set<String> = ["Te05", "Te0S"]
    private static let gpuKeys: Set<String> = ["Tg1U", "Tg1k", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k"]
    private static let batteryKeys: Set<String> = ["TB1T", "TB2T"]
    private static let memoryKeys: Set<String> = ["Tm0p", "Tm1p", "Tm2p"]

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
    }

    public func reset() {
        connection = nil
        sensors.removeAll()
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
            nextDiscovery = started.advanced(by: .seconds(sensors.isEmpty ? 30 : 300))
            Self.log.info("Discovered \(self.sensors.count, privacy: .public) temperature keys")
        }

        let temperatures = sensors.map { sensor in
            Temperature(id: sensor.id, group: sensor.group,
                        reading: Reading(connection.number(sensor.key, formats: Self.thermalFormats),
                                         within: sensor.group == .other ? 1...125 : Self.temperatureRange,
                                         at: date, sampledAt: started, validity: validity),
                        format: sensor.format)
        }
        let fanCount = connection.number("FNum", formats: Self.integerFormats).flatMap(Self.validFanCount)
        let fans = (0..<(fanCount ?? 0)).map {
            readFan($0, connection: connection, at: date, started: started, validity: validity)
        }
        let freshTemperatures = temperatures.filter { $0.reading.freshValue() != nil }.count
        let freshFans = fans.filter { $0.speed.freshValue() != nil }.count
        let health: MonitorHealth
        if freshTemperatures == 0 && freshFans == 0 {
            health = .unavailable("AppleSMC returned no usable mapped temperatures or fan speeds.")
            self.connection = nil
            nextDiscovery = started.advanced(by: .seconds(sensors.isEmpty && fans.isEmpty ? 30 : 5))
        } else if freshTemperatures == 0 || fanCount == nil ||
                    freshTemperatures != temperatures.count || freshFans != fans.count {
            health = .partial
        } else {
            health = .live
        }
        return Snapshot(machine: machine, temperatures: temperatures, fans: fans, fanCount: fanCount,
                        battery: battery, health: health, timestamp: date)
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
        let hasMap = machine.model == "Mac16,7" && machine.chip == "Apple M4 Pro"
        let known = hasMap ? Self.cpuKeys.union(Self.gpuKeys).union(Self.memoryKeys).union(Self.batteryKeys) : []
        let catalog = includeUnclassified ? connection.keys() : []
        let keys = Set(catalog).union(known.compactMap(SMCCodec.fourCC))

        return keys.compactMap { key in
            guard let name = SMCCodec.name(key), name.hasPrefix("T"),
                  let info = connection.describe(key), Self.thermalFormats.contains(info.format) else { return nil }
            let group: SensorGroup
            if hasMap && Self.cpuKeys.contains(name) {
                group = .cpu
            } else if hasMap && Self.gpuKeys.contains(name) {
                group = .gpu
            } else if hasMap && Self.batteryKeys.contains(name) {
                group = .battery
            } else if hasMap && Self.memoryKeys.contains(name) {
                group = .memory
            } else {
                guard let value = connection.number(key, formats: Self.thermalFormats),
                      (1...125).contains(value) else { return nil }
                group = .other
            }
            return Sensor(key: key, id: SensorID(rawValue: name), group: group, format: info.format)
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
