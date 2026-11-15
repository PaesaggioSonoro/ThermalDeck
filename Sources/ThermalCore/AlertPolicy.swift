import Foundation

public enum MonitorAlert: Hashable, Sendable {
    case highTemperature
    case unavailable
    case fanControlStopped
    case fanControlDisconnected
    case fanRestoreUnconfirmed
}

public struct AlertPolicy: Sendable {
    private var aboveThreshold = false
    private var unavailableSince: ContinuousClock.Instant?
    private var reportedOutage = false
    private var lastFanControlIssue: MonitorAlert?
    private var lastSent: [MonitorAlert: ContinuousClock.Instant] = [:]

    public init() {}

    public mutating func evaluate(
        peak: Double?, health: MonitorHealth, threshold: Double, now: ContinuousClock.Instant = .now
    ) -> [MonitorAlert] {
        var alerts: [MonitorAlert] = []
        if let peak, peak.isFinite {
            if peak <= threshold - 3 { aboveThreshold = false }
            if peak >= threshold && !aboveThreshold && permit(.highTemperature, now: now) {
                aboveThreshold = true
                alerts.append(.highTemperature)
            }
        }

        if case .unavailable = health {
            if unavailableSince == nil { unavailableSince = now }
            if let since = unavailableSince, since.duration(to: now) >= .seconds(12),
               !reportedOutage && permit(.unavailable, now: now) {
                reportedOutage = true
                alerts.append(.unavailable)
            }
        } else {
            unavailableSince = nil
            reportedOutage = false
        }
        return alerts
    }

    public mutating func resetTemperature() { aboveThreshold = false }

    public mutating func evaluateFanControl(
        _ issue: MonitorAlert?, now: ContinuousClock.Instant = .now
    ) -> MonitorAlert? {
        guard issue != lastFanControlIssue else { return nil }
        lastFanControlIssue = issue
        guard let issue, permit(issue, now: now) else { return nil }
        return issue
    }

    private mutating func permit(_ alert: MonitorAlert, now: ContinuousClock.Instant) -> Bool {
        if let last = lastSent[alert], last.duration(to: now) < .seconds(300) { return false }
        lastSent[alert] = now
        return true
    }
}
