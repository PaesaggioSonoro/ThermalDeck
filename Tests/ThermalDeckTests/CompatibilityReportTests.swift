import Testing
import ThermalCore
@testable import ThermalDeck

@Test func compatibilityReportIncludesAvailabilityWithoutRawReadings() {
    let sensor = Temperature(id: SensorID(rawValue: "RAW_SENSOR_KEY"), group: .cpu,
                             reading: Reading(76.25, within: 1...125, at: .now), format: "Fixture")
    let snapshot = Snapshot(machine: Machine(model: "Mac16,7", chip: "Apple M4 Pro", os: "macOS 26"),
                            temperatures: [sensor], fanCount: 2,
                            battery: BatteryTelemetry(source: .adapter, isCharging: true,
                                                      chargePercent: 89, flowWatts: 18.25),
                            health: .unavailable("PRIVATE_FAILURE_DETAIL"), simulated: true)
    let report = CompatibilityReport(snapshot: snapshot, version: "test").text
    #expect(report.contains("Model: Mac16,7"))
    #expect(report.contains("Mode: Simulation"))
    #expect(report.contains("Mapped temperature zones: 1"))
    #expect(report.contains("Battery power flow: Available"))
    #expect(!report.contains("RAW_SENSOR_KEY"))
    #expect(!report.contains("PRIVATE_FAILURE_DETAIL"))
    #expect(!report.contains("76.25"))
    #expect(!report.contains("18.25"))
}
