# Hardware compatibility

| Model | Chip | OS tested | Temperatures | Fan RPM | Manual / curves |
| --- | --- | --- | --- | --- | --- |
| Mac16,7 | Apple M4 Pro | macOS 26.6.2 (25G83) | Physical read-only probe, partial mapped coverage | Probe pending | Disabled, research only |
| Other Apple Silicon | Varies | Untested | Discovery planned | Untested | Disabled |
| Intel | Varies | Untested | Outside current scope | Outside current scope | Disabled |

See [research](research.md) for upstream evidence.

## Mac16,7 temperature evidence

Unprivileged reads on macOS 26.6.2 (25G83) returned 12 mapped floating-point readings. The included CPU zones `Te05` and `Te0S` were approximately 50–52 °C, eight GPU zones were approximately 43–51 °C, and battery keys `TB1T` and `TB2T` were approximately 29–30 °C during normal desktop work. No physical core assignment, absolute calibration, or suitability for control has been established.

Several upstream CPU-mapped `Tp*` keys returned values around 2–4 or briefly exactly 40. Their semantics on this machine are uncertain, so they are excluded from the live CPU aggregate. `thermal-probe --catalog` can enumerate plausible numeric candidates with unverified units for further investigation. The app polls only explicitly mapped keys. Neither the diagnostic catalog nor these limited zone aggregates establishes overall SoC temperature or thermal safety.
