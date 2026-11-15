import Foundation
import Testing
import ThermalCore
@testable import HardwareAccess

@Test func fourCCRequiresFourPrintableASCIIBytes() {
    #expect(SMCCodec.fourCC("F0Ac") == 0x46304163)
    #expect(SMCCodec.name(0x666C7420) == "flt ")
    #expect(SMCCodec.fourCC("Té!") == nil)
    #expect(SMCCodec.name(0x00000000) == nil)
}

@Test func readsExactWireWidthsAndEndianness() {
    #expect(SMCCodec.numeric([0, 0, 72, 66], format: "flt ") == 50)
    #expect(SMCCodec.numeric([0xFF, 0x80], format: "sp78") == -0.5)
    #expect(SMCCodec.numeric([0x18, 0xA0], format: "fpe2") == 1576)
    #expect(SMCCodec.numeric([0, 0, 0x12, 0x34], format: "ui32") == 4660)
    #expect(SMCCodec.numeric([0, 1, 2], format: "flt ") == nil)
    #expect(SMCCodec.numeric([1, 2], format: "ui8 ") == nil)
    #expect(SMCCodec.numeric([0, 0, 0xC0, 0x7F], format: "flt ")?.isNaN == true)
    #expect(SMCCodec.numeric([50, 0], format: "ch8*") == nil)
    #expect(SMCCodec.numeric([0, 0x80, 43, 0, 0, 0, 0, 0], format: "ioft") == 43.5)
    #expect(SMCCodec.numeric([0, 0x80, 0xEA, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF], format: "ioft") == -21.5)
    #expect(SMCCodec.numeric([0, 0x80, 43, 0], format: "ioft") == nil)
}

@Test func m4ProCatalogPreservesSensorIdentityAndNamesTenPerformanceCores() {
    let machine = Machine(model: "Mac16,7", chip: "Apple M4 Pro", os: "Test")
    let entries = M4ProTemperatureCatalog.entries(for: machine)
    for (index, id) in ["Tp1j", "Tp1n", "Tp1t", "Tp1w", "Tp1z", "Tp22", "Tp25", "Tp28", "Tp2B", "Tp2E"].enumerated() {
        #expect(entries[id]?.label == "CPU Performance Core \(index + 1)")
        #expect(entries[id]?.group == .cpu)
        #expect(entries[id]?.canPark == true)
    }
    #expect(entries["Te05"]?.label == "CPU Efficiency Core 1")
    #expect(entries["Te0S"]?.label == "CPU Efficiency Core 3")
    #expect(entries["Tg0z"]?.label == "GPU Cluster 5")
    #expect(entries["TPMP"]?.label == "Power Supply Proximity")
    #expect(entries["TCMz"] == nil)
    #expect(M4ProTemperatureCatalog.entries(for: machine, diagnostics: true)["TCMz"]?.label == "CPU Die Hotspot")
    #expect(entries.count == 20)
    #expect(entries["Tp1j"]?.alternate == "Tp01")
    #expect(entries["Tp2E"]?.alternate == "Tp0b")
    #expect(M4ProTemperatureCatalog.Entry.activeValue(40) == nil)
    #expect(M4ProTemperatureCatalog.Entry.activeValue(5.2) == nil)
    #expect(M4ProTemperatureCatalog.Entry.activeValue(40.015625) == 40.015625)
    #expect(Set(entries.values.map(\.label)).count == entries.count)
    #expect(M4ProTemperatureCatalog.entries(for: Machine(model: "Mac16,7", chip: "Apple M4 Max", os: "Test")).isEmpty)
}

@Test func m4ProAveragesUseTheCuratedRowsAndSkipUnavailableReadings() {
    let now = ContinuousClock.now
    let date = Date()
    func sensor(_ key: String, _ group: SensorGroup, _ value: Double?, offset: Duration = .zero) -> Temperature {
        Temperature(id: SensorID(rawValue: key), group: group,
                    reading: Reading(value, within: 5...125, at: date, sampledAt: now.advanced(by: offset)),
                    format: "flt ")
    }
    let readings = [
        sensor("Te05", .cpu, 40), sensor("Te0S", .cpu, 46), sensor("Tp1j", .cpu, 58),
        sensor("Tp1n", .cpu, nil), sensor("TCMz", .cpu, 100),
        sensor("Tg05", .gpu, 40), sensor("Tg0S", .gpu, 50),
        sensor("Tg0Y", .gpu, 80, offset: .seconds(-20)), sensor("TfC0", .gpu, 70)
    ]
    let derived = M4ProTemperatureCatalog.derivedTemperatures(from: readings, at: date, started: now, validity: .seconds(5))
    let values = Dictionary(uniqueKeysWithValues: derived.map { ($0.displayName, $0.reading.freshValue(at: now)) })
    #expect(values == ["CPU Efficiency Core 2": 40, "CPU Efficiency Core 4": 46,
                       "CPU Core Average": 46, "GPU Cluster Average": 45])

    let snapshot = Snapshot(machine: Machine(model: "Mac16,7", chip: "Apple M4 Pro", os: "Test"),
                            temperatures: derived, cpuHotspot: readings[4].reading, health: .live)
    #expect(snapshot.peak(.cpu, at: now) == 100)
    #expect(snapshot.highestTemperature(at: now) == 100)
    #expect(snapshot.peak(.gpu, at: now) == 45)
    #expect(snapshot.zoneAverage(.cpu, at: now) == 46)
    #expect(snapshot.zoneAverage(.gpu, at: now) == 45)
}

@Test func fanCountMustFitTheFirmwareKeyIndexAndBeIntegral() {
    #expect(AppleSMCSource.validFanCount(0) == 0)
    #expect(AppleSMCSource.validFanCount(2) == 2)
    #expect(AppleSMCSource.validFanCount(11) == nil)
    #expect(AppleSMCSource.validFanCount(1.5) == nil)
    #expect(AppleSMCSource.validFanCount(.infinity) == nil)
}
