import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import ThermalCore

enum BatteryReader {
    static func read() -> BatteryTelemetry? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let handles = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        let batteries = handles.compactMap { handle in
            IOPSGetPowerSourceDescription(info, handle)?.takeUnretainedValue() as? [String: Any]
        }.filter {
            $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType &&
                boolean($0[kIOPSIsPresentKey]) == true
        }
        guard batteries.count == 1, let fields = batteries.first else { return nil }

        let source: BatteryTelemetry.Source? = switch fields[kIOPSPowerSourceStateKey] as? String {
        case kIOPSACPowerValue: .adapter
        case kIOPSBatteryPowerValue: .battery
        default: nil
        }
        return BatteryTelemetry(
            source: source, isCharging: boolean(fields[kIOPSIsChargingKey]),
            chargePercent: chargePercent(current: integer(fields[kIOPSCurrentCapacityKey]),
                                         maximum: integer(fields[kIOPSMaxCapacityKey])),
            flowWatts: readBatteryFlow()
        )
    }

    private static func readBatteryFlow() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMPowerSource"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        func property(_ key: String) -> CFTypeRef? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        guard boolean(property(kIOPMPSBatteryInstalledKey)) == true else { return nil }
        return flowWatts(voltage: integer(property(kIOPMPSVoltageKey)),
                         amperage: integer(property(kIOPMPSAmperageKey)))
    }

    static func chargePercent(current: Int?, maximum: Int?) -> Double? {
        guard let current, let maximum, maximum > 0, (0...maximum).contains(current) else { return nil }
        return Double(current) / Double(maximum) * 100
    }

    static func flowWatts(voltage: Int?, amperage: Int?) -> Double? {
        guard let voltage, (1_000...50_000).contains(voltage), let amperage else { return nil }
        // The registry can bridge the signed 32-bit current as unsigned bits.
        guard let current = Int32(exactly: amperage) ??
                UInt32(exactly: amperage).map(Int32.init(bitPattern:)),
              (-50_000...50_000).contains(current) else { return nil }
        return Double(voltage) * Double(current) / 1_000_000
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFNumberGetTypeID() else { return nil }
        return Int(exactly: number.doubleValue)
    }

    private static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
}
