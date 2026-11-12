import Testing
@testable import HardwareAccess

@Test func batteryCapacityRejectsMissingOrInvalidScales() {
    #expect(BatteryReader.chargePercent(current: 45, maximum: 50) == 90)
    #expect(BatteryReader.chargePercent(current: 0, maximum: 50) == 0)
    #expect(BatteryReader.chargePercent(current: 51, maximum: 50) == nil)
    #expect(BatteryReader.chargePercent(current: 0, maximum: 0) == nil)
    #expect(BatteryReader.chargePercent(current: nil, maximum: 50) == nil)
}

@Test func batteryPowerUsesSignedCurrentAndPreservesZero() {
    #expect(BatteryReader.flowWatts(voltage: 12_000, amperage: 500) == 6)
    #expect(BatteryReader.flowWatts(voltage: 12_000, amperage: -500) == -6)
    #expect(BatteryReader.flowWatts(voltage: 12_000, amperage: 4_294_966_796) == -6)
    #expect(BatteryReader.flowWatts(voltage: 12_000, amperage: 0) == 0)
    #expect(BatteryReader.flowWatts(voltage: 12_000, amperage: nil) == nil)
    #expect(BatteryReader.flowWatts(voltage: 0, amperage: 500) == nil)
    #expect(BatteryReader.flowWatts(voltage: 12_000, amperage: 50_001) == nil)
}
