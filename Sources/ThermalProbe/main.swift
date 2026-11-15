import Darwin
import Foundation
import HardwareAccess
import ThermalCore

let arguments = Array(CommandLine.arguments.dropFirst())
let includeCatalog = arguments.contains("--catalog")
if let argument = arguments.first, argument == "--timing" {
    guard arguments.count == 2, let count = Int(arguments[1]), (1...300).contains(count) else {
        print("Usage: thermal-probe [--catalog | --timing SAMPLES (1–300)]")
        exit(64)
    }
    let source = AppleSMCSource()
    var durations: [Double] = []
    var valid = 0
    for index in 0..<count {
        let start = ContinuousClock.now
        let snapshot = await source.sample(validity: .seconds(3))
        let elapsed = start.duration(to: .now).components
        durations.append(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15)
        if snapshot.health == .live || snapshot.health == .partial { valid += 1 }
        if index + 1 < count { try await ContinuousClock().sleep(until: start.advanced(by: .seconds(1))) }
    }
    let warm = Array(durations.dropFirst()).sorted()
    let cold = durations.first ?? 0
    print("\(source.machine.model) · \(source.machine.os) · \(valid)/\(count) usable snapshots")
    print(String(format: "Cold %.3f ms", cold))
    if !warm.isEmpty {
        let p95 = warm[max(0, Int(ceil(0.95 * Double(warm.count))) - 1)]
        print(String(format: "Warm median %.3f ms · p95 %.3f ms · peak %.3f ms", warm[warm.count / 2], p95, warm.last ?? 0))
    }
    exit(0)
}
guard arguments.isEmpty || arguments == ["--catalog"] else {
    print("Usage: thermal-probe [--catalog | --timing SAMPLES (1–300)]")
    exit(64)
}
let source = AppleSMCSource(includeUnclassified: includeCatalog)
let started = ContinuousClock.now
let sample = await source.sample(validity: .seconds(15))
let elapsed = started.duration(to: .now)
print("\(sample.machine.model) · \(sample.machine.chip) · \(sample.machine.os)")
let unclassified = sample.temperatures.count { $0.group == .other }
let mapped = sample.temperatures.count - unclassified
print("\(sample.health.label) · \(mapped) named temperature sensors · \(unclassified) unclassified candidates · \(elapsed.formatted())")
for group in SensorGroup.allCases {
    let values = sample.temperatures.filter { $0.group == group }
    if !values.isEmpty { print(group.rawValue) }
    let format = group == .other ? "%.2f (units unverified)" : "%.2f °C"
    for value in values {
        let reading = value.reading.freshValue().map { String(format: format, $0) } ?? value.reading.health().rawValue
        let name = group == .other ? "" : "\(value.displayName) · "
        print("  \(name)\(value.id.rawValue) [\(value.format)] \(reading)")
    }
}

print("Reported fans: " + (sample.fanCount.map(String.init) ?? "Unavailable"))
for fan in sample.fans {
    func rpm(_ value: Double?) -> String {
        value.map { String(format: "%.1f RPM", $0) } ?? "Unavailable"
    }
    print("  F\(fan.id.rawValue) · measured \(rpm(fan.speed.freshValue())) · minimum \(rpm(fan.minimum)) · maximum \(rpm(fan.maximum)) · target \(rpm(fan.target)) · \(fan.mode.rawValue)")
}
if let battery = sample.battery {
    let charge = battery.chargePercent.map { String(format: "%.1f%%", $0) } ?? "Unavailable"
    let flow = battery.flowWatts.map { String(format: "%.2f W", $0) } ?? "Unavailable"
    let charging = battery.isCharging.map { $0 ? "Yes" : "No" } ?? "Unavailable"
    print("Battery: \(charge) · source \(battery.source?.rawValue ?? "Unavailable") · charging \(charging) · flow \(flow)")
}
