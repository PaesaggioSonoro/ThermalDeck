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
    #expect(entries["Tp1j"]?.alternate == "Tp01")
    #expect(entries["Tp2E"]?.alternate == "Tp0b")
    #expect(M4ProTemperatureCatalog.Entry.activeValue(40) == nil)
    #expect(M4ProTemperatureCatalog.Entry.activeValue(5.2) == nil)
    #expect(M4ProTemperatureCatalog.Entry.activeValue(40.015625) == 40.015625)
    #expect(Set(entries.values.map(\.label)).count == entries.count)
    #expect(M4ProTemperatureCatalog.entries(for: Machine(model: "Mac16,7", chip: "Apple M4 Max", os: "Test")).isEmpty)
}

@Test func fanCountMustFitTheFirmwareKeyIndexAndBeIntegral() {
    #expect(AppleSMCSource.validFanCount(0) == 0)
    #expect(AppleSMCSource.validFanCount(2) == 2)
    #expect(AppleSMCSource.validFanCount(11) == nil)
    #expect(AppleSMCSource.validFanCount(1.5) == nil)
    #expect(AppleSMCSource.validFanCount(.infinity) == nil)
}
