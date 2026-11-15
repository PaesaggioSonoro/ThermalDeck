import Foundation
import Testing
@testable import ThermalCore

@Test func historyKeepsZeroAndSplitsMissingAndDelayedSamples() {
    let start = Date(timeIntervalSinceReferenceDate: 20_000)
    let fan = SeriesKey.fan(FanID(rawValue: 0))
    var history = HistoryBuffer()
    for (offset, values) in [(0, [fan: 0.0]), (1, [fan: 500]), (2, [:]), (3, [fan: 0]), (21, [fan: 1200])] {
        history.append(HistoryRecord(date: start.addingTimeInterval(Double(offset)), values: values), retention: 300)
    }
    let points = history.plot([fan], from: start, through: start.addingTimeInterval(30))
    #expect(points.map(\.value) == [0, 500, 0, 1200])
    #expect(points.map(\.segment) == [1, 1, 2, 3])
}

@Test func historyIsBoundedByTimeAndCountAndRejectsInvalidValues() {
    let start = Date(timeIntervalSinceReferenceDate: 20_000)
    var history = HistoryBuffer()
    for index in 0..<(HistoryBuffer.limit + 400) {
        history.append(HistoryRecord(date: start.addingTimeInterval(Double(index) / 2),
                                     values: [.cpu: .infinity, .gpu: 51]), retention: 3_600)
    }
    #expect(history.records.count == HistoryBuffer.limit)
    #expect(history.records.last?.values[.cpu] == nil)
    #expect(history.archiveRecords().count <= 721)
    history.trim(at: start.addingTimeInterval(4_000), retention: 300)
    #expect(history.records.first?.date == start.addingTimeInterval(3_700))
}

@Test func archiveUsesRevisionToPreventAnOlderWriteAfterClear() async throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let archive = HistoryArchive(url: folder.appending(path: "history.json"))
    let record = HistoryRecord(date: .now, values: [.cpu: 51])
    try await archive.save([record], revision: 1)
    #expect(try await archive.load().first?.values[.cpu] == 51)
    try await archive.clear(revision: 3)
    try await archive.save([record], revision: 2)
    #expect(try await archive.load().isEmpty)
}

@Test func alertsRequireAThresholdTransitionOrSustainedOutage() {
    var policy = AlertPolicy()
    let start = ContinuousClock.now
    func evaluate(_ peak: Double?, _ health: MonitorHealth, _ seconds: Int) -> [MonitorAlert] {
        policy.evaluate(peak: peak, health: health, threshold: 90, now: start.advanced(by: .seconds(seconds)))
    }
    #expect(evaluate(90, .live, 0) == [.highTemperature])
    #expect(evaluate(94, .live, 400).isEmpty)
    #expect(evaluate(85, .live, 401).isEmpty)
    #expect(evaluate(95, .live, 402) == [.highTemperature])
    #expect(evaluate(nil, .unavailable("offline"), 405).isEmpty)
    #expect(evaluate(nil, .unavailable("offline"), 417) == [.unavailable])
    #expect(evaluate(nil, .unavailable("offline"), 800).isEmpty)
}

@Test func fanControlAlertsDeduplicateAndKeepSeparateCooldowns() {
    var policy = AlertPolicy()
    let start = ContinuousClock.now
    #expect(policy.evaluateFanControl(.fanControlDisconnected, now: start) == .fanControlDisconnected)
    #expect(policy.evaluateFanControl(.fanControlDisconnected, now: start.advanced(by: .seconds(400))) == nil)
    #expect(policy.evaluateFanControl(.fanRestoreUnconfirmed, now: start.advanced(by: .seconds(1))) == .fanRestoreUnconfirmed)
    #expect(policy.evaluateFanControl(nil, now: start.advanced(by: .seconds(2))) == nil)
    #expect(policy.evaluateFanControl(.fanControlDisconnected, now: start.advanced(by: .seconds(3))) == nil)
    #expect(policy.evaluateFanControl(nil, now: start.advanced(by: .seconds(301))) == nil)
    #expect(policy.evaluateFanControl(.fanControlDisconnected, now: start.advanced(by: .seconds(302))) == .fanControlDisconnected)
}

@Test func trackedSensorHistoryPreservesSelectionAndBreaksOnStaleReadings() throws {
    let clock = ContinuousClock.now
    let date = Date(timeIntervalSinceReferenceDate: 20_000)
    let tracked = SensorID(rawValue: "Te05")
    let stale = SensorID(rawValue: "Te0S")
    let unclassified = SensorID(rawValue: "Tx01")
    let sensors = [
        Temperature(id: tracked, group: .cpu,
                    reading: Reading(45, within: 5...125, at: date, sampledAt: clock), format: "flt "),
        Temperature(id: stale, group: .cpu,
                    reading: Reading(42, within: 5...125, at: date, sampledAt: clock, validity: .zero), format: "flt "),
        Temperature(id: unclassified, group: .other,
                    reading: Reading(47, within: 5...125, at: date, sampledAt: clock), format: "flt ")
    ]
    let snapshot = Snapshot(machine: Machine(model: "Test", chip: "Test", os: "Test"),
                            temperatures: sensors, health: .live, timestamp: date)
    var prefs = Preferences()
    for id in [tracked, stale, unclassified] { prefs.setHistorySensor(id, tracked: true) }
    var restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(prefs))
    restored.normalize()
    #expect(restored.historySensors == [tracked, stale, unclassified])
    let record = HistoryRecord(snapshot: snapshot, selectedSensors: restored.historySensors, now: clock)
    #expect(record.values[.sensor(tracked)] == 45)
    #expect(record.values[.sensor(stale)] == nil)
    #expect(record.values[.sensor(unclassified)] == nil)
    let csv = String(decoding: try HistoryExport.encode([record], simulated: false, format: .csv), as: UTF8.self)
    #expect(csv.contains(",sensor_Te05,celsius,45.0,"))
    #expect(!csv.contains("sensor_Te0S"))
}

@Test func savedHistoryKeepsAnExplicitGapDuringAggregation() {
    let start = Date(timeIntervalSinceReferenceDate: 20_000)
    var history = HistoryBuffer()
    let samples: [[SeriesKey: Double]] = [[.cpu: 55, .gpu: 40], [.gpu: 45], [.cpu: 59, .gpu: 42]]
    for (index, values) in samples.enumerated() {
        history.append(HistoryRecord(date: start.addingTimeInterval(Double(index)), values: values), retention: 300)
    }
    #expect(history.archiveRecords().count == 1)
    #expect(history.archiveRecords().first?.values == [.gpu: 45])
}

@Test func restoresOnlyInRangeArchiveSamplesAndPreservesNewLiveSamples() {
    let now = Date(timeIntervalSinceReferenceDate: 20_000)
    var history = HistoryBuffer()
    history.append(HistoryRecord(date: now, values: [.cpu: 51]), retention: 300)
    let saved = [-301.0, -100.0, 1.0].map {
        HistoryRecord(date: now.addingTimeInterval($0), values: [.cpu: 50])
    }
    history.restore(saved, at: now, retention: 300)
    #expect(history.records.map(\.date) == [now.addingTimeInterval(-100), now])
    #expect(history.records.last?.values[.cpu] == 51)
}

@Test func olderPreferencesLoadAndUnsafeValuesNormalize() throws {
    var original = Preferences()
    original.unit = .fahrenheit
    let data = try JSONEncoder().encode(original)
    var fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    fields.removeValue(forKey: "storedCurve")
    fields["interval"] = -1
    fields["retention"] = 99_000
    fields["thresholdCelsius"] = 155
    let legacy = try JSONSerialization.data(withJSONObject: fields)
    var restored = try JSONDecoder().decode(Preferences.self, from: legacy)
    restored.normalize()
    #expect(restored.unit == .fahrenheit)
    #expect(restored.interval == 1)
    #expect(restored.retention == 900)
    #expect(restored.thresholdCelsius == 90)
    #expect(restored.storedCurve == nil)
}
