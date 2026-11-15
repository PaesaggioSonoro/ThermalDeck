# Hardware compatibility

| Model | Chip | OS tested | Temperatures | Fan RPM | Manual / curves |
| --- | --- | --- | --- | --- | --- |
| Mac16,7 | Apple M4 Pro | macOS 26.6.2 (25G83) | Physical read-only probe, partial mapped coverage | Physical read-only probe and live history, stopped and spinning | Max Fans and Auto restoration verified. Curves in Demo |
| Other Apple Silicon | Varies | Untested | Discovery planned | Untested | Disabled |
| Intel | Varies | Untested | Outside current scope | Outside current scope | Disabled |

See [research](research.md) for upstream evidence.

## Mac16,7 temperature evidence

Unprivileged reads on macOS 26.6.2 (25G83) returned 12 mapped floating-point readings. The included CPU zones `Te05` and `Te0S` were approximately 50–52 °C, eight GPU zones were approximately 43–51 °C, and battery keys `TB1T` and `TB2T` were approximately 29–30 °C during normal desktop work. No physical core assignment, absolute calibration, or suitability for control has been established.

Several upstream CPU-mapped `Tp*` keys returned values around 2–4 or briefly exactly 40. Their semantics on this machine are uncertain, so they are excluded from the live CPU aggregate. `thermal-probe --catalog` can enumerate plausible numeric candidates with unverified units for further investigation. The app polls only explicitly mapped keys. Neither the diagnostic catalog nor these limited zone aggregates establishes overall SoC temperature or thermal safety.

Macs Fan Control 1.5.21 displayed names without firmware keys. Its CPU Efficiency Core 1 and 2 labels align with the generation-specific Stats map for `Te05` and `Te0S`. ThermalDeck uses those aliases alongside the keys. For the eight GPU keys and two battery keys, ThermalDeck uses numbered sensor labels based on the available mapping. The reference app's five GPU cluster rows and its battery labels could not be matched key by key. Its vendor also documents later M4 temperature corrections. [Stats sensor map](https://github.com/exelban/stats/blob/f2f99e51a2bfd86176a357dd296486d3a41212c3/Modules/Sensors/values.swift) · [Macs Fan Control release notes](https://crystalidea.com/macs-fan-control/release-notes)

## Mac16,7 fan evidence

`FNum` returned 2. At idle, both `F0Ac` and `F1Ac` reported 0 RPM. Both fans reported 1,350 RPM minimum, 5,777 RPM maximum, 0 RPM target, and firmware mode 3 (system managed). The app uses firmware ordering and neutral names. A stopped fan is a valid measured zero. The reported minimum is a firmware characteristic and does not describe the minimum observed speed or a safe cooling target.

Live history exports from ordinary use on the same Mac captured nonzero measurements for both fans. Fan 1 peaked at about 5,831 RPM and Fan 2 at about 5,766 RPM, with reported targets up to 5,777 RPM. The reported maximum is a separate firmware value and did not cap the displayed measurements. Max Fans reached the rated speed on both fans. Restore Automatic and normal Quit returned control to macOS. Safe lower manual targets and exact fan placement remain unverified. [Fan control evidence](../safety/fan-control.md#physical-verification)

Macs Fan Control showed both fans in Auto with the same 1,350–5,777 RPM bounds and 0 RPM while stopped. During ordinary use, ThermalDeck read about 1,342 and 1,485 RPM, and Macs Fan Control showed about 1,355 and 1,449 RPM shortly afterward. These samples corroborate stopped and spinning telemetry. The installed reference copy identifies itself as modified.

## Mac16,7 battery evidence

An unprivileged read returned 90% battery charge, external power, and no active charging. The registry reported 12,626 mV and 0 mA, which produced 0 W of battery flow. On hardware that exposes both values, the app multiplies millivolts by signed milliamps and divides by one million. Physical charging and discharging readings remain unverified. [Apple power source descriptions](https://developer.apple.com/documentation/iokit/iopowersources_h) · [Apple IOPMPowerSource fields](https://developer.apple.com/documentation/kernel/iopmpowersource)
