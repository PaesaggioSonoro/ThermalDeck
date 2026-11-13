import Testing
@testable import HardwareAccess

private final class FanRegisters: MaximumFanRegisters {
    var flag: Double = 0
    var modes: [Double] = [3, 3]
    var actual: [Double] = [0, 0]
    var targets: [Double] = [0, 0]
    let maxima: [Double] = [5_777, 5_600]
    var rejectSecondTarget = false
    var remainingModeRejections = 0
    var remainingIgnoredTargets = 0
    var refuseRelease = false
    var holdMeasuredSpeed = false
    var thermalPressure = false
    var writes = 0
    var time = ContinuousClock.now

    func read() -> MaximumFanReadback? {
        .init(override: flag, fans: modes.indices.map { index in
            .init(mode: modes[index], minimum: 1_350, maximum: maxima[index],
                  target: targets[index], actual: actual[index])
        })
    }

    func setOverride(_ enabled: Bool) -> Bool {
        writes += 1
        if !enabled && refuseRelease { return false }
        flag = enabled ? 1 : 0
        modes = enabled ? [0, 0] : [3, 3]
        if !enabled { targets = [0, 0] }
        return true
    }

    func setManual(_ enabled: Bool, fan: UInt8) -> Bool {
        writes += 1
        if enabled && remainingModeRejections > 0 {
            remainingModeRejections -= 1
            return false
        }
        modes[Int(fan)] = enabled ? 1 : 0
        return true
    }

    func setMaximum(_ rpm: Double, fan: UInt8) -> Bool {
        writes += 1
        if fan == 1 && rejectSecondTarget { return false }
        if remainingIgnoredTargets > 0 {
            remainingIgnoredTargets -= 1
            return true
        }
        targets[Int(fan)] = rpm
        if !holdMeasuredSpeed { actual[Int(fan)] = rpm }
        return true
    }

    func controller() -> MaximumFanController {
        .init(registers: self, wait: { [self] delay in time += .seconds(delay) },
              now: { [self] in time }, canOverride: { [self] in !thermalPressure })
    }
}

@Test func liveMaximumUsesBothLimitsAndConfirmsSystemModeOnRestore() {
    let registers = FanRegisters()
    let control = registers.controller()
    #expect(control.status() == .automatic)
    #expect(control.start() == .maximum)
    #expect(registers.targets == registers.maxima)
    #expect(control.restore() == .automatic)
    #expect(registers.flag == 0)
    #expect(registers.modes == [3, 3])
    #expect(!control.needsRestoration)
}

@Test func liveMaximumRejectsAnotherControllerWithoutWriting() {
    let registers = FanRegisters()
    registers.flag = 1
    registers.modes = [1, 1]
    let control = registers.controller()
    #expect(control.start() == .external)
    #expect(control.restore() == .external)
    #expect(registers.writes == 0)
}

@Test func liveMaximumRetriesRejectedModeWritesAndUnappliedTargets() {
    let registers = FanRegisters()
    registers.remainingModeRejections = 2
    registers.remainingIgnoredTargets = 2
    let control = registers.controller()
    #expect(control.start() == .maximum)
    #expect(registers.targets == registers.maxima)
    #expect(control.restore() == .automatic)
}

@Test func liveMaximumRollsBackPartialWritesAndKeepsUnconfirmedOwnership() {
    let registers = FanRegisters()
    registers.rejectSecondTarget = true
    registers.refuseRelease = true
    let control = registers.controller()
    #expect(control.start() == .unconfirmed)
    #expect(control.needsRestoration)
    #expect(registers.modes == [0, 0])
    registers.refuseRelease = false
    #expect(control.restore() == .automatic)
    #expect(!control.needsRestoration)
}

@Test func liveMaximumRequiresMeasuredSpeedAndRollsBackIfTheFansDoNotSettle() {
    let registers = FanRegisters()
    registers.holdMeasuredSpeed = true
    let control = registers.controller()
    #expect(control.start() == .failed)
    #expect(registers.flag == 0)
    #expect(registers.modes == [3, 3])
}

@Test func liveMaximumHandsCoolingBackWhenThermalPressureRises() {
    let registers = FanRegisters()
    let control = registers.controller()
    #expect(control.start() == .maximum)
    registers.thermalPressure = true
    #expect(control.status() == .stopped)
    #expect(registers.flag == 0)
    #expect(registers.modes == [3, 3])
}
