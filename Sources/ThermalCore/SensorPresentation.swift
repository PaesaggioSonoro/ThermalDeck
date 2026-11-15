import Foundation

public struct SensorPresentation: Codable, Equatable, Sendable {
    public enum Sort: String, CaseIterable, Codable, Sendable {
        case name = "Name"
        case temperature = "Temperature"
    }

    public var sort = Sort.name
    public var groupByZone = true
    public var hiddenSensors: Set<SensorID> = []

    public init() {}

    public struct Section: Identifiable, Sendable {
        public var id: SensorGroup? { group }
        public let group: SensorGroup?
        public let sensors: [Temperature]
    }

    public func sections(
        for sensors: [Temperature], at now: ContinuousClock.Instant = .now
    ) -> [Section] {
        let visible = sensors.filter { !hiddenSensors.contains($0.id) }.sorted { left, right in
            if sort == .temperature {
                let lhs = left.reading.freshValue(at: now) ?? -.infinity
                let rhs = right.reading.freshValue(at: now) ?? -.infinity
                if lhs != rhs { return lhs > rhs }
            }
            return Self.byName(left, right)
        }
        guard !visible.isEmpty else { return [] }
        if !groupByZone { return [Section(group: nil, sensors: visible)] }
        return SensorGroup.allCases.compactMap { group in
            let members = visible.filter { $0.group == group }
            return members.isEmpty ? nil : Section(group: group, sensors: members)
        }
    }

    public static func byName(_ left: Temperature, _ right: Temperature) -> Bool {
        let order = left.displayName.localizedStandardCompare(right.displayName)
        if order != .orderedSame { return order == .orderedAscending }
        return left.id.rawValue < right.id.rawValue
    }
}
