# Hardware compatibility

| Model | Chip | OS tested | Temperatures | Fan RPM | Manual / curves |
| --- | --- | --- | --- | --- | --- |
| Mac16,7 | Apple M4 Pro | macOS 26.6.2 (25G83) | Physical read-only probe, partial mapped coverage | Physical read-only probe and live history, stopped and spinning | Disabled, research only |
| Other Apple Silicon | Varies | Untested | Discovery planned | Untested | Disabled |
| Intel | Varies | Untested | Outside current scope | Outside current scope | Disabled |

See [research](research.md) for upstream evidence.

## Mac16,7 temperature evidence

Unprivileged reads on macOS 26.6.2 (25G83) returned 12 mapped floating-point readings. The included CPU zones `Te05` and `Te0S` were approximately 50–52 °C, eight GPU zones were approximately 43–51 °C, and battery keys `TB1T` and `TB2T` were approximately 29–30 °C during normal desktop work. No physical core assignment, absolute calibration, or suitability for control has been established.

Several upstream CPU-mapped `Tp*` keys returned values around 2–4 or briefly exactly 40. Their semantics on this machine are uncertain, so they are excluded from the live CPU aggregate. `thermal-probe --catalog` can enumerate plausible numeric candidates with unverified units for further investigation. The app polls only explicitly mapped keys. Neither the diagnostic catalog nor these limited zone aggregates establishes overall SoC temperature or thermal safety.

## Mac16,7 fan evidence

`FNum` returned 2. At idle, both `F0Ac` and `F1Ac` reported 0 RPM. Both fans reported 1,350 RPM minimum, 5,777 RPM maximum, 0 RPM target, and firmware mode 3 (system managed). The app uses firmware ordering and neutral names. A stopped fan is a valid measured zero. The reported minimum is a firmware characteristic and does not describe the minimum observed speed or a safe cooling target.

Live history exports from ordinary use on the same Mac captured nonzero measurements for both fans. Fan 1 peaked at about 5,831 RPM and Fan 2 at about 5,766 RPM, with reported targets up to 5,777 RPM. The reported maximum is a separate firmware value and did not cap the displayed measurements. Physical placement, controlled speed response, safe target limits, manual control, and restoration remain unverified.
