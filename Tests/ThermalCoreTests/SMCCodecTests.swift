import Testing
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
}
