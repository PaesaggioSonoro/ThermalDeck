import Foundation
import HardwareAccess
import ThermalCore

let source = AppleSMCSource(includeUnclassified: CommandLine.arguments.contains("--catalog"))
let started = ContinuousClock.now
let sample = await source.sample(validity: .seconds(15))
let elapsed = started.duration(to: .now)
print("\(sample.machine.model) · \(sample.machine.chip) · \(sample.machine.os)")
print("\(sample.health.label) · \(sample.temperatures.count) temperature readings or candidates · \(elapsed.formatted())")
for group in SensorGroup.allCases {
    let values = sample.temperatures.filter { $0.group == group }
    if !values.isEmpty { print(group.rawValue) }
    let format = group == .other ? "%.2f (units unverified)" : "%.2f °C"
    for value in values {
        let reading = value.reading.freshValue().map { String(format: format, $0) } ?? value.reading.health().rawValue
        print("  \(value.id.rawValue) [\(value.format)] \(reading)")
    }
}

print("Reported fans: " + (sample.fanCount.map(String.init) ?? "Unavailable"))
for fan in sample.fans {
    func rpm(_ value: Double?) -> String {
        value.map { String(format: "%.1f RPM", $0) } ?? "Unavailable"
    }
    print("  F\(fan.id.rawValue) · measured \(rpm(fan.speed.freshValue())) · minimum \(rpm(fan.minimum)) · maximum \(rpm(fan.maximum)) · target \(rpm(fan.target)) · \(fan.mode.rawValue)")
}
