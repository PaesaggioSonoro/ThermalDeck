# Hardware compatibility

| Model | Chip | OS tested | Temperatures | Fan RPM | Manual / curves |
| --- | --- | --- | --- | --- | --- |
| Mac16,7 | Apple M4 Pro | macOS 26.6.2 (25G83) | 26 entries from AppleSMC, HID, and averages | Physical read-only probe and live history, stopped and spinning | Max Fans and Auto restoration verified. Curves in Demo |
| Other Apple Silicon | Varies | Untested | Discovery planned | Untested | Disabled |
| Intel | Varies | Untested | Outside current scope | Outside current scope | Disabled |

See [research](research.md) for upstream evidence.

## Mac16,7 temperature evidence

The Mac16,7 list follows the 26 labels requested from Macs Fan Control's MacBookPro21,4 display. The available CPU Core Average and GPU Cluster Average entries are arithmetic means of the available displayed cores and clusters. The CPU die hotspot continues to contribute to peak monitoring and alerts. [Macs Fan Control release notes](https://crystalidea.com/macs-fan-control/release-notes)

Across 210 read-only samples, the alternate key banks supplied plausible individual performance probe readings at different times. An inactive bank returned small placeholders or exactly 40 °C. ThermalDeck accepts an active value from either bank and shows a dash when both values are unavailable. `thermal-probe --catalog` lists the additional discovery probes and scans for plausible values in supported numeric formats. These mappings are for monitoring. [iSMC Apple Silicon sensor map](https://github.com/dkorunic/iSMC/blob/master/smc/sensors.go) · [Macs Fan Control release notes](https://crystalidea.com/macs-fan-control/release-notes)

The public MacBookPro21,4 reference map assigns `Te05` to efficiency cores 1 and 2 and `Te0S` to cores 3 and 4. Live readings confirmed that the reference app showed identical values within each pair. GPU Clusters 1–5 map to `Tg05`, `Tg0S`, `Tg0Y`, `Tg0k`, and `Tg0z`. Airport Proximity, Battery, and Power Supply Proximity map to `TW0P`, `TB0T`, and `TPMP`. Live sampled values matched the corresponding reference readings within the apps' sampling and rounding differences. [Public AppleSMC reference map](https://github.com/localhost-copilot/macs-fan-control-re/blob/main/Sources/FanCore/Resources/smcSensors-appleSilicon.xml#L210)

Battery Gas Gauge comes from HID. Power Manager Die Average uses the available HID die channels 1, 2, and 4–8. ThermalDeck uses the highest valid reading across duplicate HID services for each channel. [Public HID reference map](https://github.com/localhost-copilot/macs-fan-control-re/blob/main/Sources/FanCore/Resources/iokitSensors.xml#L33)

## Mac16,7 fan evidence

`FNum` returned 2. At idle, both `F0Ac` and `F1Ac` reported 0 RPM. Both fans reported 1,350 RPM minimum, 5,777 RPM maximum, 0 RPM target, and firmware mode 3 (system managed). The app uses firmware ordering and neutral names. A stopped fan is a valid measured zero. The reported minimum is a firmware characteristic and does not describe the minimum observed speed or a safe cooling target.

Live history exports from ordinary use on the same Mac captured nonzero measurements for both fans. Fan 1 peaked at about 5,831 RPM and Fan 2 at about 5,766 RPM, with reported targets up to 5,777 RPM. The reported maximum is a separate firmware value and did not cap the displayed measurements. Max Fans reached the rated speed on both fans. Restore Automatic and normal Quit returned control to macOS. Safe lower manual targets and exact fan placement remain unverified. [Fan control evidence](../safety/fan-control.md#physical-verification)

Macs Fan Control showed both fans in Auto with the same 1,350–5,777 RPM bounds and 0 RPM while stopped. During ordinary use, ThermalDeck read about 1,342 and 1,485 RPM, and Macs Fan Control showed about 1,355 and 1,449 RPM shortly afterward. These samples corroborate stopped and spinning telemetry. The installed reference copy identifies itself as modified.

## Mac16,7 battery evidence

An unprivileged read returned 90% battery charge, external power, and no active charging. The registry reported 12,626 mV and 0 mA, which produced 0 W of battery flow. On hardware that exposes both values, the app multiplies millivolts by signed milliamps and divides by one million. Physical charging and discharging readings remain unverified. [Apple power source descriptions](https://developer.apple.com/documentation/iokit/iopowersources_h) · [Apple IOPMPowerSource fields](https://developer.apple.com/documentation/kernel/iopmpowersource)
