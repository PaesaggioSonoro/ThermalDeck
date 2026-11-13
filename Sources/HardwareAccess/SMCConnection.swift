import SMCRead

final class SMCConnection {
    struct Metadata {
        let size: UInt32
        let format: String
    }

    private let port: UInt32
    private var metadata: [UInt32: Metadata] = [:]

    init() throws {
        var connection: UInt32 = 0
        let status = td_smc_open(&connection)
        guard status == 0, connection != 0 else { throw ConnectionError.open(status) }
        port = connection
    }

    deinit { td_smc_close(port) }

    func keys(limit: UInt32 = 8_192) -> [UInt32] {
        guard let reported = number("#KEY"), let count = UInt32(exactly: reported), count <= limit else { return [] }
        return (0..<count).compactMap { index in
            var key: UInt32 = 0
            return td_smc_key_at(port, index, &key) == 0 ? key : nil
        }
    }

    func describe(_ key: UInt32) -> Metadata? {
        if let known = metadata[key] { return known }
        var value = TDReadValue()
        guard td_smc_describe(port, key, &value) == 0, let format = SMCCodec.name(value.type) else { return nil }
        let info = Metadata(size: value.size, format: format)
        metadata[key] = info
        return info
    }

    func number(_ key: String, formats: Set<String> = []) -> Double? {
        guard let code = SMCCodec.fourCC(key) else { return nil }
        return number(code, formats: formats)
    }

    func number(_ key: UInt32, formats: Set<String> = []) -> Double? {
        guard let info = describe(key), formats.isEmpty || formats.contains(info.format) else { return nil }
        var value = TDReadValue()
        value.size = info.size
        guard td_smc_read(port, key, &value) == 0 else {
            metadata.removeValue(forKey: key)
            return nil
        }
        return withUnsafeBytes(of: value.bytes) { raw in
            SMCCodec.numeric(raw.prefix(Int(info.size)), format: info.format)
        }
    }

    func setFanOverride(_ value: Bool) -> Bool {
        td_smc_set_fan_override(port, value ? 1 : 0) == 0
    }

    func setFanManual(_ value: Bool, fan: UInt8) -> Bool {
        td_smc_set_fan_mode(port, fan, value ? 1 : 0) == 0
    }

    func setFanMaximum(_ rpm: Double, fan: UInt8) -> Bool {
        td_smc_set_fan_maximum(port, fan, Float(rpm)) == 0
    }
}

enum ConnectionError: Error {
    case open(Int32)
}
