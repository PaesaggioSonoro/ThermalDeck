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
    for index in 0..<4_000 {
        history.append(HistoryRecord(date: start.addingTimeInterval(Double(index) / 2),
                                     values: [.cpu: .infinity, .gpu: 51]), retention: 3_600)
    }
    #expect(history.records.count == HistoryBuffer.limit)
    #expect(history.records.last?.values[.cpu] == nil)
    #expect(history.archiveRecords().count <= 721)
    history.trim(at: start.addingTimeInterval(2200), retention: 300)
    #expect(history.records.first?.date == start.addingTimeInterval(1900))
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
