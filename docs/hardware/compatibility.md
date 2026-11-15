# Hardware compatibility

| Model | Chip | OS tested | Temperatures | Fan RPM | Manual / curves |
| --- | --- | --- | --- | --- | --- |
| Mac16,7 | Apple M4 Pro | macOS 26.6.2 (25G83) | 171 named readings found through AppleSMC and HID | Physical read-only probe and live history, stopped and spinning | Max Fans and Auto restoration verified. Curves in Demo |
| Other Apple Silicon | Varies | Untested | Discovery planned | Untested | Disabled |
| Intel | Varies | Untested | Outside current scope | Outside current scope | Disabled |

See [research](research.md) for upstream evidence.

## Mac16,7 temperature evidence

Unprivileged reads found 171 named readings through AppleSMC and HID. These include ten performance-core names with multiple probes per core, efficiency probes, CPU die and fabric readings, GPU probes and fabric, battery, memory, storage, and system temperatures. HID exposed a battery gas gauge, a NAND channel and 14 power manager die channels. ThermalDeck takes the highest valid reading across duplicate HID services for each named channel and averages the available power manager die channels for the Power Manager Die Average row.

Across 210 read-only samples, the alternate key banks supplied plausible individual performance probe readings at different times. An inactive bank returned small placeholders or exactly 40 °C. ThermalDeck accepts an active value from either bank for each probe, preserves one identity and shows a dash when both are unavailable. `thermal-probe --catalog` scans the full bounded AppleSMC key list for plausible values in supported numeric formats and labels uncertain candidates separately. An example run found 94 unclassified candidates after merging aliases. The mappings are for monitoring and have yet to be qualified as inputs for live fan curves. [iSMC Apple Silicon sensor map](https://github.com/dkorunic/iSMC/blob/master/smc/sensors.go) · [Macs Fan Control release notes](https://crystalidea.com/macs-fan-control/release-notes)

Macs Fan Control 1.5.21 showed four efficiency-core names and five GPU cluster names. Two of the efficiency-core keys in published M4 maps were absent on this Mac. The proposed replacements in a similar machine's report matched the existing cluster die peaks in our sampled data. ThermalDeck keeps their probe labels. The app uses sensor and fabric names for the GPU keys. Matching them to all five reference cluster rows still needs evidence. CrystalIDEA subsequently corrected the reference app's idle, performance-core and GPU-cluster readings. [M4 Pro efficiency key report](https://github.com/exelban/stats/issues/3270) · [Macs Fan Control release notes](https://crystalidea.com/macs-fan-control/release-notes)

## Mac16,7 fan evidence

`FNum` returned 2. At idle, both `F0Ac` and `F1Ac` reported 0 RPM. Both fans reported 1,350 RPM minimum, 5,777 RPM maximum, 0 RPM target, and firmware mode 3 (system managed). The app uses firmware ordering and neutral names. A stopped fan is a valid measured zero. The reported minimum is a firmware characteristic and does not describe the minimum observed speed or a safe cooling target.

Live history exports from ordinary use on the same Mac captured nonzero measurements for both fans. Fan 1 peaked at about 5,831 RPM and Fan 2 at about 5,766 RPM, with reported targets up to 5,777 RPM. The reported maximum is a separate firmware value and did not cap the displayed measurements. Max Fans reached the rated speed on both fans. Restore Automatic and normal Quit returned control to macOS. Safe lower manual targets and exact fan placement remain unverified. [Fan control evidence](../safety/fan-control.md#physical-verification)

Macs Fan Control showed both fans in Auto with the same 1,350–5,777 RPM bounds and 0 RPM while stopped. During ordinary use, ThermalDeck read about 1,342 and 1,485 RPM, and Macs Fan Control showed about 1,355 and 1,449 RPM shortly afterward. These samples corroborate stopped and spinning telemetry. The installed reference copy identifies itself as modified.

## Mac16,7 battery evidence

An unprivileged read returned 90% battery charge, external power, and no active charging. The registry reported 12,626 mV and 0 mA, which produced 0 W of battery flow. On hardware that exposes both values, the app multiplies millivolts by signed milliamps and divides by one million. Physical charging and discharging readings remain unverified. [Apple power source descriptions](https://developer.apple.com/documentation/iokit/iopowersources_h) · [Apple IOPMPowerSource fields](https://developer.apple.com/documentation/kernel/iopmpowersource)
