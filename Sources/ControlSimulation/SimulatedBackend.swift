import ThermalCore

/// An in-memory plant for exercising control policy. It has no system interfaces.
struct SimulatedBackend {
    enum Mode { case system, manual, external }

    struct Fan {
        var limits: ClosedRange<Double>
        var automaticDemand: Double
        var target: Double?
        var actual: Double
        var mode: Mode = .system
        var settlesAt: Duration?
    }

    var fans: [FanID: Fan] = [:]
    var modelIsValidated = true
    var readFails = false
    var targetWriteFails: Set<FanID> = []
    var modeWriteFails: Set<FanID> = []
    var restoreFails: Set<FanID> = []
    var settleDelay: Duration = .seconds(2)

    mutating func read(at now: Duration) -> [FanID: Fan]? {
        guard !readFails else { return nil }
        for id in Array(fans.keys) {
            guard let fan = fans[id], let deadline = fan.settlesAt, now >= deadline else { continue }
            fans[id]?.actual = fan.target ?? fan.automaticDemand
            fans[id]?.settlesAt = nil
        }
        return fans
    }

    mutating func apply(_ rpm: Double, to id: FanID, at now: Duration) -> Bool {
        guard let fan = fans[id], fan.mode != .external, !modeWriteFails.contains(id) else { return false }
        fans[id]?.mode = .manual
        guard !targetWriteFails.contains(id) else { return false }
        fans[id]?.target = rpm
        fans[id]?.settlesAt = now + settleDelay
        return true
    }

    mutating func restore(_ id: FanID) -> Bool {
        guard let fan = fans[id], fan.mode != .external, !restoreFails.contains(id) else { return false }
        fans[id]?.mode = .system
        fans[id]?.target = nil
        fans[id]?.settlesAt = nil
        fans[id]?.actual = fan.automaticDemand
        return true
    }
}
