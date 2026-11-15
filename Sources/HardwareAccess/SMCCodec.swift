import Foundation

enum SMCCodec {
    static func fourCC(_ string: String) -> UInt32? {
        let bytes = Array(string.utf8)
        guard bytes.count == 4, bytes.allSatisfy({ (32...126).contains($0) }) else { return nil }
        return bytes.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    static func name(_ code: UInt32) -> String? {
        let bytes = withUnsafeBytes(of: code.bigEndian) { Array($0) }
        guard bytes.allSatisfy({ (32...126).contains($0) }) else { return nil }
        return String(bytes: bytes, encoding: .ascii)
    }

    static func numeric(_ bytes: some Collection<UInt8>, format: String) -> Double? {
        let length: Int
        switch format {
        case "ui8 ": length = 1
        case "ui16", "fpe2", "sp78": length = 2
        case "ui32", "flt ": length = 4
        case "ioft": length = 8
        default: return nil
        }
        guard bytes.count == length else { return nil }

        if format == "flt " {
            let bits = bytes.reversed().reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            return Double(Float(bitPattern: bits))
        }
        if format == "ioft" {
            let bits = bytes.reversed().reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            return Double(Int64(bitPattern: bits)) / 65_536
        }

        let unsigned = bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        switch format {
        case "fpe2": return Double(unsigned) / 4
        case "sp78": return Double(Int16(bitPattern: UInt16(unsigned))) / 256
        default: return Double(unsigned)
        }
    }
}
