import ThermalCore

enum M4ProTemperatureCatalog {
    struct Entry {
        let label: String
        let group: SensorGroup
        let alternate: String?
        var canPark: Bool { alternate != nil }

        static func activeValue(_ raw: Double?) -> Double? {
            guard let raw, raw >= 10, raw <= 125, raw != 40 else { return nil }
            return raw
        }
    }

    static func entries(for machine: Machine) -> [String: Entry] {
        machine.model == "Mac16,7" && machine.chip == "Apple M4 Pro" ? entries : [:]
    }

    private static let entries: [String: Entry] = {
        var result: [String: Entry] = [:]
        func add(_ key: String, _ label: String, _ group: SensorGroup, alternate: String? = nil) {
            result[key] = Entry(label: label, group: group, alternate: alternate)
        }
        func addCPUProbes(_ keys: [[String]], _ component: String, alternate: [[String]] = []) {
            for (index, probes) in keys.enumerated() {
                let label = "CPU \(component) \(index + 1)"
                for (probe, key) in probes.enumerated() {
                    let name = probe == 0 ? label : "\(label) Probe \(probe)"
                    add(key, name, .cpu, alternate: alternate.isEmpty ? nil : alternate[index][probe])
                }
            }
        }

        addCPUProbes([
            ["Te05", "Te04", "Te06"], ["Te0S", "Te0R", "Te0T"]
        ], "Efficiency Core")
        addCPUProbes([["Tex0", "Tex1"], ["Tex2", "Tex3"]], "Efficiency Cluster Die")
        // The firmware alternates between these two banks. Parked probes return small
        // placeholders or exactly 40 °C. Keep one stable identity per probe across banks.
        addCPUProbes([
            ["Tp1j", "Tp1i", "Tp1k"], ["Tp1n", "Tp1m", "Tp1o"], ["Tp1t", "Tp1q", "Tp1u"],
            ["Tp1w", "Tp1v", "Tp1x"], ["Tp1z", "Tp1y", "Tp20"], ["Tp22", "Tp21", "Tp23"],
            ["Tp25", "Tp24", "Tp26"], ["Tp28", "Tp27", "Tp29"], ["Tp2B", "Tp2A", "Tp2C"],
            ["Tp2E", "Tp2D", "Tp2G"]
        ], "Performance Core", alternate: [
            ["Tp01", "Tp00", "Tp02"], ["Tp05", "Tp04", "Tp06"], ["Tp09", "Tp08", "Tp0A"],
            ["Tp0D", "Tp0C", "Tp0E"], ["Tp0H", "Tp0G", "Tp0I"], ["Tp0L", "Tp0K", "Tp0M"],
            ["Tp0P", "Tp0O", "Tp0Q"], ["Tp0T", "Tp0S", "Tp0U"], ["Tp0X", "Tp0W", "Tp0Y"],
            ["Tp0b", "Tp0a", "Tp0c"]
        ])
        addCPUProbes([
            ["Tp2J", "Tp2I", "Tp2K"], ["Tp2M", "Tp2L", "Tp2N"], ["Tp2Q", "Tp2O", "Tp2R"],
            ["Tp2T", "Tp2S", "Tp2U"], ["Tp2W", "Tp2V", "Tp2X"]
        ], "Performance Fabric", alternate: [
            ["Tp0e", "Tp0d", "Tp0f"], ["Tp0i", "Tp0g", "Tp0k"], ["Tp0m", "Tp0l", "Tp0n"],
            ["Tp0q", "Tp0o", "Tp0t"], ["Tp0v", "Tp0u", "Tp0w"]
        ])
        addCPUProbes([["Tpx8", "Tpx9"], ["TpxA", "TpxB"], ["TpxC", "TpxD"]],
                     "Performance Cluster Die", alternate: [["Tpx0", "Tpx1"], ["Tpx2", "Tpx3"], ["Tpx4", "Tpx5"]])
        add("TCMb", "CPU Die Average", .cpu)
        add("TCMz", "CPU Die Hotspot", .cpu)
        add("TCHP", "CPU Heatpipe", .system)

        let gpuKeys = ["Tg1U", "Tg1k", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k",
                       "Tg04", "Tg05", "Tg0R", "Tg0S", "Tg0X", "Tg0Y", "Tg0y", "Tg0z",
                       "Tg1E", "Tg1F", "Tg1V", "Tg1c", "Tg1d", "Tg1l"]
        for (index, key) in gpuKeys.enumerated() { add(key, "GPU Sensor \(index + 1)", .gpu) }
        for index in 0..<5 { add("TfC\(index)", "GPU Fabric \(index + 1)", .gpu) }

        add("TB0T", "Battery", .battery)
        add("TB1T", "Battery 1", .battery)
        add("TB2T", "Battery 2", .battery)
        add("TW0P", "Airport Proximity", .system)
        add("TAOL", "Lid Ambient", .system)
        add("TDBP", "Battery Board Proximity", .system)
        add("TDeL", "Left Board Edge", .system)
        add("TDeR", "Right Board Edge", .system)
        add("TIOP", "I/O Processor", .system)
        add("TSCD", "System Controller", .system)
        add("TPMP", "Power Manager Proximity", .system)
        add("TPSP", "Power Supply Proximity", .system)
        add("TMVR", "Memory Voltage Regulator", .memory)
        add("TVmS", "Memory Temperature Summary", .memory)
        add("TH0x", "NAND Flash", .storage)
        add("Ts1P", "SSD Controller Proximity", .storage)
        add("TF2S", "SoC Fabric Sensor", .system)

        for (index, digit) in "0123456789abcdef".enumerated() {
            add("TPD\(digit)", "Power Delivery Sensor \(index + 1)", .system)
            add("TRD\(digit)", "Radio Frequency Delivery Sensor \(index + 1)", .system)
            add("TUD\(digit)", "Uncore Die \(index + 1)", .system)
        }
        return result
    }()
}
