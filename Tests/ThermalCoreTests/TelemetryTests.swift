import Foundation
import Testing
@testable import ThermalCore

@Test func readingDistinguishesZeroInvalidUnavailableAndStale() {
    let now = ContinuousClock.now
    let zero = Reading(0, within: 0...10_000, at: .now, sampledAt: now, validity: .seconds(2))
    #expect(zero.freshValue(at: now) == 0)
    #expect(zero.health(at: now.advanced(by: .seconds(2))) == .stale)
    #expect(Reading(.nan, within: 1...125, at: .now).health() == .invalid)
    #expect(Reading(nil, within: 1...125, at: .now).health() == .unavailable)
}

@Test func demoIsExplicitAndUsesBothFans() async {
    let sample = await DemoSource().sample(validity: .seconds(2))
    #expect(sample.simulated)
    #expect(sample.fanCount == 2)
    #expect(sample.peak(.cpu) != nil)
}
