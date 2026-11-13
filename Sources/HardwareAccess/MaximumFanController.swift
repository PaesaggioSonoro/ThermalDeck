import Foundation
import OSLog
import ThermalCore

struct MaximumFanReadback {
    let override: Double
    let fans: [Fan]

    struct Fan {
        let mode: Double
        let minimum: Double
        let maximum: Double
        let target: Double
        let actual: Double
    }

    var systemManaged: Bool { override == 0 && fans.count == 2 && fans.allSatisfy { $0.mode == 3 } }
}

protocol MaximumFanRegisters {
    func read() -> MaximumFanReadback?
    func setOverride(_ enabled: Bool) -> Bool
    func setManual(_ enabled: Bool, fan: UInt8) -> Bool
    func setMaximum(_ rpm: Double, fan: UInt8) -> Bool
}

extension SMCConnection: MaximumFanRegisters {
    func read() -> MaximumFanReadback? {
        guard number("FNum") == 2, let override = number("Ftst", formats: ["ui8 "]),
              [0, 1].contains(override) else { return nil }
        var fans: [MaximumFanReadback.Fan] = []
        for index in 0..<2 {
            let prefix = "F\(index)"
            guard let mode = number(prefix + "Md", formats: ["ui8 "]), [0, 1, 3].contains(mode),
                  let minimum = number(prefix + "Mn", formats: ["flt "]), (500...10_000).contains(minimum),
                  let maximum = number(prefix + "Mx", formats: ["flt "]), (1_000...10_000).contains(maximum),
                  minimum < maximum,
                  let target = number(prefix + "Tg", formats: ["flt "]), (0...20_000).contains(target),
                  let actual = number(prefix + "Ac", formats: ["flt "]), (0...20_000).contains(actual) else { return nil }
            fans.append(.init(mode: mode, minimum: minimum, maximum: maximum, target: target, actual: actual))
        }
        return .init(override: override, fans: fans)
    }

    func setOverride(_ enabled: Bool) -> Bool { setFanOverride(enabled) }
    func setManual(_ enabled: Bool, fan: UInt8) -> Bool { setFanManual(enabled, fan: fan) }
    func setMaximum(_ rpm: Double, fan: UInt8) -> Bool { setFanMaximum(rpm, fan: fan) }
}

/// Access this controller from one serial queue. No controller state is persisted.
public final class MaximumFanController {
    private static let log = Logger(subsystem: "org.thermaldeck.local", category: "fan-control")
    private let registers: any MaximumFanRegisters
    private let wait: (TimeInterval) -> Void
    private let now: () -> ContinuousClock.Instant
    private let canOverride: () -> Bool
    private var ownsOverride = false
    private var touchedFans: Set<UInt8> = []
    private var expected: [Double] = []

    public static func supports(_ machine: Machine) -> Bool {
        machine.model == "Mac16,7" && machine.chip == "Apple M4 Pro" &&
            machine.os == "macOS 26.6.2 (25G83)"
    }

    public convenience init?() {
        guard MaximumFanController.supports(AppleSMCSource().machine),
              let connection = try? SMCConnection() else { return nil }
        self.init(registers: connection, canOverride: {
            let thermalState = ProcessInfo.processInfo.thermalState
            return thermalState == .nominal || thermalState == .fair
        })
    }

    init(registers: any MaximumFanRegisters, wait: @escaping (TimeInterval) -> Void = Thread.sleep,
         now: @escaping () -> ContinuousClock.Instant = { .now },
         canOverride: @escaping () -> Bool = { true }) {
        self.registers = registers
        self.wait = wait
        self.now = now
        self.canOverride = canOverride
    }

    public var needsRestoration: Bool { ownsOverride || !touchedFans.isEmpty }

    public func status() -> FanControlResult {
        if needsRestoration {
            if canOverride() && atMaximum(registers.read()) { return .maximum }
            return restore() == .automatic ? .stopped : .unconfirmed
        }
        guard let reading = registers.read() else { return .unavailable }
        return reading.systemManaged ? .automatic : .external
    }

    public func start() -> FanControlResult {
        if needsRestoration { return status() }
        guard canOverride() else { return .thermalPressure }
        guard let baseline = registers.read() else { return .unavailable }
        guard baseline.systemManaged else { return .external }

        // Record intent before each command. A failed call does not prove it changed nothing.
        ownsOverride = true
        guard registers.setOverride(true),
              poll(for: .seconds(7), while: canOverride, until: { reading in
                  reading.override == 1 && reading.fans.count == 2 && reading.fans.allSatisfy { $0.mode == 0 }
              }) else { return failedStart("Firmware did not yield both fans") }

        for (index, fan) in baseline.fans.enumerated() {
            let id = UInt8(index)
            touchedFans.insert(id)
            guard configureMaximum(fan: id, rpm: fan.maximum) else {
                return failedStart("Could not confirm manual mode and target for fan \(id + 1)")
            }
        }
        expected = baseline.fans.map(\.maximum)
        guard poll(for: .seconds(12), while: canOverride, until: { atMaximum($0) }) else {
            return failedStart("Both fans did not reach maximum speed")
        }
        return .maximum
    }

    public func restore() -> FanControlResult {
        guard needsRestoration else {
            guard let reading = registers.read() else { return .unavailable }
            return reading.systemManaged ? .automatic : .external
        }
        expected = []
        if registers.read()?.systemManaged == true {
            clearOwnership()
            return .automatic
        }
        // Restore each fan this session touched, then release the global flag it acquired.
        for id in touchedFans.sorted() {
            guard let current = registers.read(), current.override == 1,
                  current.fans.dropFirst(Int(id)).first?.mode == 1 else { continue }
            _ = registers.setManual(false, fan: id)
        }
        if ownsOverride, registers.read()?.override != 0 { _ = registers.setOverride(false) }
        guard poll(for: .seconds(8), until: { $0.systemManaged }) else { return .unconfirmed }
        clearOwnership()
        return .automatic
    }

    private func configureMaximum(fan id: UInt8, rpm: Double) -> Bool {
        let deadline = now().advanced(by: .seconds(4))
        var attempts = 0
        var accepted = false
        repeat {
            guard canOverride(), let reading = registers.read(), reading.override == 1,
                  reading.fans.indices.contains(Int(id)) else { return false }
            let fan = reading.fans[Int(id)]
            if fan.mode == 1 && abs(fan.target - rpm) <= 1 { return true }
            if fan.mode == 0 {
                accepted = registers.setManual(true, fan: id)
            } else if fan.mode == 1 {
                accepted = registers.setMaximum(rpm, fan: id)
            } else {
                return false
            }
            attempts += 1
            wait(0.15)
        } while now() < deadline
        let final = registers.read()?.fans.dropFirst(Int(id)).first
        Self.log.error("Fan \(id + 1) setup timed out after \(attempts) writes, last accepted: \(accepted), mode: \(final?.mode ?? -1), target: \(final?.target ?? -1)")
        return false
    }

    private func failedStart(_ reason: String) -> FanControlResult {
        Self.log.error("\(reason, privacy: .public)")
        return restore() == .automatic ? .failed : .unconfirmed
    }

    private func clearOwnership() {
        expected = []
        touchedFans.removeAll()
        ownsOverride = false
    }

    private func atMaximum(_ reading: MaximumFanReadback?) -> Bool {
        guard let reading, reading.override == 1, expected.count == 2, reading.fans.count == expected.count
        else { return false }
        return zip(reading.fans, expected).allSatisfy { fan, rpm in
            fan.mode == 1 && fan.maximum == rpm &&
                abs(fan.target - rpm) <= 1 && abs(fan.actual - rpm) <= 250
        }
    }

    private func poll(for duration: Duration, while allowed: () -> Bool = { true },
                      until matches: (MaximumFanReadback) -> Bool) -> Bool {
        let deadline = now().advanced(by: duration)
        repeat {
            guard allowed() else { return false }
            if let reading = registers.read(), matches(reading) { return true }
            wait(0.15)
        } while now() < deadline
        return false
    }
}
