import Foundation
import Testing
import ThermalCore

@Test func sensorSortingKeepsZoneOrderAndVisibilityIsPanelOnly() {
    let sensors = [
        sensor("CPU10", "CPU 10", .cpu, 50),
        sensor("CPU2", "CPU 2", .cpu, 40),
        sensor("GPU1", "GPU 1", .gpu, 75),
        sensor("BAT", "Battery", .battery, nil)
    ]
    var presentation = SensorPresentation()
    #expect(presentation.sections(for: sensors).first?.sensors.map(\.id.rawValue) == ["CPU2", "CPU10"])

    presentation.sort = .temperature
    let grouped = presentation.sections(for: sensors)
    #expect(grouped.map(\.group) == [.cpu, .gpu, .battery])
    #expect(grouped.first?.sensors.map(\.id.rawValue) == ["CPU10", "CPU2"])

    presentation.groupByZone = false
    presentation.hiddenSensors = [sensors[2].id]
    #expect(presentation.sections(for: sensors).first?.sensors.map(\.id.rawValue) == ["CPU10", "CPU2", "BAT"])
    let snapshot = Snapshot(machine: Machine(model: "Test", chip: "Test", os: "Test"),
                            temperatures: sensors, health: .live)
    #expect(MenuBarReadout.sensor(sensors[2].id).value(in: snapshot) == 75)
    #expect(MenuBarReadout.sensor(sensors[2].id).label(in: snapshot) == "GPU 1")
    #expect(MenuBarReadout.sensor(SensorID(rawValue: "Tg1k")).label(in: snapshot) == "Unavailable sensor")
    #expect(MenuBarReadout.cpuHighest.value(in: snapshot) == 50)
}

@Test func menuReadoutsPreserveLegacySelectionsAndChooseFreshMappedValues() throws {
    var preferences = Preferences()
    preferences.menuIndicator = .temperatureAndFan
    preferences.menuFanIndex = 1
    let secondFan = MenuBarReadout.fan(FanID(rawValue: 1))
    #expect(preferences.menuBar.readouts == [.cpuGPUHighest, secondFan])
    preferences.menuBar = MenuBarSelection(first: .highestTemperature, second: secondFan)
    preferences.interval = 0.5
    let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
    #expect(restored.menuBar.readouts == [.highestTemperature, secondFan])
    #expect(restored.menuBarTemperatureDecimals)
    preferences.menuBarTemperatureDecimals = false
    preferences.menuBar = MenuBarSelection(first: .fastestFan, second: secondFan)
    let rounded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
    #expect(!rounded.menuBarTemperatureDecimals)
    #expect(rounded.menuBar.readouts == [.fastestFan, secondFan])
    #expect(restored.pollingInterval(dashboardActive: true) == 0.5)
    #expect(restored.pollingInterval(dashboardActive: false) == 1)
    #expect(MenuBarSelection(first: .cpuHighest, second: .cpuHighest).readouts == [.cpuHighest])

    let now = ContinuousClock.now
    let sensors = [sensor("BAT", "Battery", .battery, 50),
                   sensor("CPU", "CPU", .cpu, 40),
                   sensor("RAW", "Raw", .other, 110)]
    let snapshot = Snapshot(machine: Machine(model: "Test", chip: "Test", os: "Test"),
                            temperatures: sensors, health: .live)
    #expect(MenuBarReadout.highestTemperature.value(in: snapshot, at: now) == 50)
    #expect(MenuBarReadout.highestTemperature.value(in: snapshot, at: now.advanced(by: .seconds(30))) == nil)
}

@Test func fastestMenuBarFanUsesFreshMeasuredSpeedAndAcceptsStoppedFans() {
    let now = ContinuousClock.now
    func fan(_ index: Int, rpm: Double, age: Duration = .zero, validity: Duration = .seconds(10)) -> Fan {
        Fan(id: FanID(rawValue: index),
            speed: Reading(rpm, within: 0...10_000, at: .now, sampledAt: now - age, validity: validity),
            minimum: nil, maximum: nil, target: 6_000, mode: .system)
    }
    let stopped = fan(0, rpm: 0, validity: .seconds(15))
    let running = fan(1, rpm: 1_234)
    let stale = fan(2, rpm: 5_000, age: .seconds(30))
    let snapshot = Snapshot(machine: Machine(model: "Test", chip: "Test", os: "Test"),
                            fans: [stopped, running, stale], health: .live)
    #expect(MenuBarReadout.fastestFan.fanSource(in: snapshot, at: now)?.id == running.id)
    #expect(MenuBarReadout.fastestFan.value(in: snapshot, at: now) == 1_234)
    #expect(MenuBarReadout.fastestFan.value(in: snapshot, at: now.advanced(by: .seconds(10))) == 0)
    #expect(MenuBarReadout.fastestFan.value(in: snapshot, at: now.advanced(by: .seconds(20))) == nil)
}

@Test func automaticMenuReadoutsUseVisibleTemperaturesInsteadOfTheAlertHotspot() {
    let now = ContinuousClock.now
    let cpu = sensor("CPU", "CPU Performance Core 1", .cpu, 46.7)
    let gpu = sensor("GPU", "GPU Cluster 1", .gpu, 44.5)
    let battery = sensor("BAT", "Battery", .battery, 47.2)
    let hotspot = Reading(61, within: 5...125, at: .now, sampledAt: now)
    let snapshot = Snapshot(machine: Machine(model: "Test", chip: "Test", os: "Test"),
                            temperatures: [cpu, gpu, battery], cpuHotspot: hotspot, health: .live)

    #expect(snapshot.peak(.cpu, at: now) == 61)
    #expect(MenuBarReadout.highestTemperature.temperatureSensor(in: snapshot, at: now)?.id == battery.id)
    #expect(MenuBarReadout.highestTemperature.value(in: snapshot, hiding: [battery.id], at: now) == 46.7)
    #expect(MenuBarReadout.cpuHighest.value(in: snapshot, at: now) == 46.7)
    #expect(MenuBarReadout.cpuHighest.value(in: snapshot, hiding: [cpu.id], at: now) == nil)
    #expect(MenuBarReadout.gpuHighest.value(in: snapshot, at: now) == 44.5)
    #expect(MenuBarReadout.cpuGPUHighest.value(in: snapshot, at: now) == 46.7)
    #expect(MenuBarReadout.sensor(battery.id).value(in: snapshot, hiding: [battery.id], at: now) == 47.2)
}

@Test func menuBarSecondValueDependsOnTheFirstAndLegacyOrphansMoveToFirst() throws {
    let fan = MenuBarReadout.fan(FanID(rawValue: 1))
    var selection = MenuBarSelection()
    selection.selectSecond(fan)
    #expect(selection.readouts.isEmpty)
    selection.selectFirst(.cpuHighest)
    selection.selectSecond(fan)
    #expect(selection.readouts == [.cpuHighest, fan])
    selection.selectFirst(nil)
    selection.selectFirst(.gpuHighest)
    #expect(selection.readouts == [.gpuHighest])
    #expect(selection.second == nil)

    let legacy = try JSONEncoder().encode(["second": fan])
    let migrated = try JSONDecoder().decode(MenuBarSelection.self, from: legacy)
    #expect(migrated.first == fan)
    #expect(migrated.second == nil)
}

@Test func sharedPercentageCurveConvertsForEachMaximumAndPreservesValidLegacyDrafts() throws {
    let curve = try PercentFanCurve(points: [.init(celsius: 40, percent: 0), .init(celsius: 80, percent: 100)])
    #expect(curve.target(for: 60) == 50)
    #expect(PercentFanCurve.rpm(for: 0, maximum: 5_000) == 0)
    #expect(PercentFanCurve.rpm(for: 100, maximum: 5_000) == 5_000)
    #expect(PercentFanCurve.rpm(for: 50, maximum: 6_000) == 3_000)
    #expect(PercentFanCurve.rpm(for: 50, maximum: nil) == nil)
    let old = try FanCurve(points: [.init(celsius: 40, rpm: 0), .init(celsius: 80, rpm: 5_000)])
    #expect(PercentFanCurve(converting: old, fanMaxima: [5_000, 5_000]) == curve)
    #expect(PercentFanCurve(converting: old, fanMaxima: [5_000, 6_000]) == nil)
    #expect(PercentFanCurve(converting: old, fanMaxima: [4_999, 4_999]) == nil)
    #expect(throws: FanCurve.ValidationError.percentPointRange) {
        try PercentFanCurve(points: [.init(celsius: 40, percent: 0), .init(celsius: 80, percent: 101)])
    }
}

private func sensor(_ id: String, _ label: String, _ group: SensorGroup, _ celsius: Double?) -> Temperature {
    Temperature(id: SensorID(rawValue: id), label: label, group: group,
                reading: Reading(celsius, within: 5...125, at: .now), format: "Test")
}
