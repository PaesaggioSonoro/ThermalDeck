import Foundation
import SMCRead
import ThermalCore

final class HIDTemperatures {
    private static let referencePowerManagerChannels: Set<Int> = [1, 2, 4, 5, 6, 7, 8]

    private enum Channel: Hashable {
        case batteryGasGauge, nand, powerManager(Int)

        init?(product: String) {
            if product == "gas gauge battery" {
                self = .batteryGasGauge
            } else if product == "NAND CH0 temp" {
                self = .nand
            } else if product.hasPrefix("PMU tdie"), let index = Int(product.dropFirst(8)), (1...14).contains(index) {
                self = .powerManager(index)
            } else {
                return nil
            }
        }

        var identity: (id: String, label: String, group: SensorGroup) {
            switch self {
            case .batteryGasGauge: ("hid-gas-gauge", "Battery Gas Gauge", .battery)
            case .nand: ("hid-nand-0", "NAND Channel 0", .storage)
            case .powerManager(let index): ("hid-pmu-\(index)", "Power Manager Die \(index)", .system)
            }
        }
    }

    private let source: OpaquePointer
    private let diagnostics: Bool
    private let channels: [(channel: Channel, indices: [Int])]
    private static let range = 5.0...125.0

    init?(diagnostics: Bool) {
        guard let source = td_hid_temperatures_open() else { return nil }
        self.source = source
        self.diagnostics = diagnostics
        var byChannel: [Channel: [Int]] = [:]
        var name = [CChar](repeating: 0, count: 64)
        for index in 0..<min(td_hid_temperatures_count(source), 128) {
            let product: String? = name.withUnsafeMutableBufferPointer { buffer in
                guard let address = buffer.baseAddress,
                      td_hid_temperature_name(source, index, address, buffer.count) != 0 else { return nil }
                return String(validatingCString: address)
            }
            guard let product, let channel = Channel(product: product) else { continue }
            if !diagnostics {
                switch channel {
                case .nand: continue
                case .powerManager(let index) where !Self.referencePowerManagerChannels.contains(index): continue
                default: break
                }
            }
            byChannel[channel, default: []].append(index)
        }
        channels = byChannel.map { (channel: $0.key, indices: $0.value) }
            .sorted { $0.channel.identity.id < $1.channel.identity.id }
    }

    deinit { td_hid_temperatures_close(source) }

    func sample(at date: Date, started: ContinuousClock.Instant, validity: Duration) -> [Temperature] {
        func make(_ id: String, _ label: String, _ group: SensorGroup, _ value: Double?) -> Temperature {
            Temperature(id: SensorID(rawValue: id), label: label, group: group,
                        reading: Reading(value, within: Self.range, at: date, sampledAt: started, validity: validity),
                        format: "hid")
        }
        var readings: [Temperature] = []
        var powerManagerReadings: [Double] = []
        var hasPowerManagerChannels = false
        for (channel, indices) in channels {
            // The same named channel can be exposed by several services.
            let value = indices.lazy.map { td_hid_temperature_read(self.source, $0) }
                .filter { Self.range.contains($0) }.max()
            if diagnostics || channel == .batteryGasGauge {
                let (id, label, group) = channel.identity
                readings.append(make(id, label, group, value))
            }
            if case .powerManager(let index) = channel, Self.referencePowerManagerChannels.contains(index) {
                hasPowerManagerChannels = true
                if let value { powerManagerReadings.append(value) }
            }
        }
        if hasPowerManagerChannels {
            let average = powerManagerReadings.isEmpty ? nil :
                powerManagerReadings.reduce(0, +) / Double(powerManagerReadings.count)
            readings.append(make("hid-pmu-average", "Power Manager Die Average", .system, average))
        }
        return readings
    }
}
