import Foundation
import Testing
import ThermalCore

@Test func historyExportPreservesUnitsZeroAndSimulationMarker() throws {
    let time = Date(timeIntervalSince1970: 0)
    let record = HistoryRecord(date: time, values: [.cpu: 48.5, .fan(FanID(rawValue: 0)): 0, .gpu: .infinity])
    let csv = String(decoding: try HistoryExport.encode([record], simulated: true, format: .csv), as: UTF8.self)
    #expect(csv.contains("1970-01-01T00:00:00.000Z,cpu_zone_peak,celsius,48.5,true"))
    #expect(csv.contains("fan_0_measured,rpm,0.0,true"))
    #expect(!csv.contains("gpu_zone_peak"))
    let json = try HistoryExport.encode([record], simulated: false, format: .json)
    let object = try #require(JSONSerialization.jsonObject(with: json) as? [String: Any])
    #expect(object["version"] as? Int == 1)
    #expect(object["simulated"] as? Bool == false)
    #expect((object["samples"] as? [[String: Any]])?.count == 2)
}
