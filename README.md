# ThermalDeck

ThermalDeck is a native, offline macOS utility for monitoring temperatures, fans, and battery power. The local development build includes a live dashboard, menu bar companion, sensor and fan details, bounded charts, optional local history and alerts, CSV and JSON export, and an offline fan-curve editor. The name and bundle identifier are provisional.

## Hardware and system requirements

The minimum deployment target is macOS 15 on Apple Silicon. Physical testing was performed on a MacBook Pro with Apple M4 Pro (Mac16,7), running macOS 26.6.2 (25G83). The app read two CPU zones, eight GPU zones, two battery temperature sensors, and both fans in stopped and spinning states. Temperature coverage is partial and the readings describe zones. Other Apple Silicon models and OS releases need validation. Intel telemetry is outside the current scope. [Hardware compatibility](docs/hardware/compatibility.md)

## Build and launch

With Swift 6 and a compatible Xcode or Apple Command Line Tools installation:

```sh
Scripts/test.sh
Scripts/build-app.sh
open dist/ThermalDeck.app
```

Set `CONFIGURATION=release` for an optimized local build. The build script packages and ad-hoc signs the app. An Xcode project and shared scheme are included for IDE use. No installer or public release is available. [Development setup](docs/development/setup.md)

Open Sensors for firmware identifiers and reading health. Open Fans for measured RPM, reported target, bounds, and mode. Use History to choose a range, show additional series, or export samples. Settings controls units, appearance, polling, menu bar indicators, retention, and local alerts. To see explicitly labeled simulated telemetry, run `open -n dist/ThermalDeck.app --args --demo`. [Monitoring guide](docs/user/monitoring.md)

## Cooling and safety

Automatic leaves cooling under macOS control. Manual fan control and live fan curves are disabled. The Custom editor only previews curve behavior with simulated inputs. The target Mac's undocumented control pathway and independent restoration after a control-process failure are unverified. [Fan control feasibility](docs/safety/fan-control.md)

ThermalDeck is provided as is under the MIT license. Undocumented monitoring interfaces can vary by hardware and OS version. Manual fan control can alter normal cooling and may contribute to higher temperatures, instability, shortened component life, hardware damage or data loss. Use this software at your own risk. ThermalDeck has no affiliation with Apple.

## Privacy and release status

Monitoring, preferences, and alerts stay on the Mac. Disk history is opt-in, and exports require a local destination selected by the user. The app has no account, analytics, update checks, or network client.

The development build has an ad-hoc signature. Physical sleep/wake, notification delivery, and login registration remain integration checks. Developer ID signing, notarization, Xcode verification, and wider hardware coverage are release steps. The working name collides with an existing Linux cooling project. [Release checklist](docs/releases/distribution.md) · [Naming findings](docs/releases/naming.md)

[Contributing](CONTRIBUTING.md) · [Architecture](docs/architecture/overview.md) · [Status](STATUS.md) · [MIT license](LICENSE)
