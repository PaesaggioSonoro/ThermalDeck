# ThermalDeck

ThermalDeck is a native, offline macOS utility for monitoring temperatures, fans, and battery power. The local development build includes a live dashboard, menu bar companion, sensor and fan details, bounded charts, optional local history and alerts, CSV and JSON export, and an offline fan-curve editor. The name and bundle identifier are provisional.

## Hardware and system requirements

The minimum deployment target is macOS 15 on Apple Silicon. The 16-inch M4 Pro MacBook Pro (Mac16,7) shows 26 temperature entries in Sensors. Both fans were measured in stopped and spinning states on macOS 26.6.2 (25G83). Other Apple Silicon models and OS releases need validation. [Hardware compatibility](docs/hardware/compatibility.md)

## Build and launch

With Swift 6 and a compatible Xcode or Apple Command Line Tools installation:

```sh
Scripts/test.sh
Scripts/build-app.sh
open dist/ThermalDeck.app
```

Set `CONFIGURATION=release` for an optimized local build. The build script packages and ad-hoc signs the app. An Xcode project and shared scheme are included for IDE use. No installer or public release is available. [Development setup](docs/development/setup.md)

Open Sensors to sort readings, group by zone, or hide individual rows. Open Fans for measured RPM, reported target, bounds, and mode. Use History to choose a range, show additional series, or export samples. The sidebar Menu Bar page configures up to two live values. The gear beside the Mac model opens Settings for units, appearance, polling, retention, and local alerts. To see explicitly labeled simulated telemetry, run `open -n dist/ThermalDeck.app --args --demo`. [Monitoring guide](docs/user/monitoring.md)

## Cooling and safety

Automatic leaves cooling under macOS control. Max Fans uses a separate root helper. Both fans reached their rated speed on Mac16,7 with M4 Pro on macOS 26.6.2 build 25G83. Restore Automatic and normal Quit both returned cooling to macOS. The local build uses an ad hoc signature and does not require an Apple Developer membership. [Fan control](docs/safety/fan-control.md)

Quit ThermalDeck, then run these commands from the repository to build the app and install the matching helper:

```sh
CONFIGURATION=release Scripts/build-app.sh
sudo /bin/bash Scripts/install-local-fan-helper.sh install dist/ThermalDeck.app
```

Reopen ThermalDeck and use **Max Fans** in Overview. Repeat the install command after a build changes the app's signature. To remove the helper, restore Automatic, quit the app, and run `sudo /bin/bash Scripts/install-local-fan-helper.sh remove`. Demo mode is available with `open -n dist/ThermalDeck.app --args --demo`.

ThermalDeck is provided as is under the MIT license. Undocumented monitoring interfaces can vary by hardware and OS version. Manual fan control can alter normal cooling and may contribute to higher temperatures, instability, shortened component life, hardware damage or data loss. Use this software at your own risk. ThermalDeck has no affiliation with Apple.

## Privacy and release status

Monitoring, preferences, and alerts stay on the Mac. Disk history is opt-in, and exports require a local destination selected by the user. Compatibility offers a local report preview with hardware and telemetry availability. You choose whether to copy any of it. The app has no account, analytics, update checks, or network client.

The development build has an ad-hoc signature. Physical sleep/wake, notification delivery, and login registration remain integration checks. Developer ID signing, notarization, Xcode verification, and wider hardware coverage are release steps. The working name collides with an existing Linux cooling project. [Release checklist](docs/releases/distribution.md) · [Naming findings](docs/releases/naming.md)

[Contributing](CONTRIBUTING.md) · [Architecture](docs/architecture/overview.md) · [Status](STATUS.md) · [MIT license](LICENSE)
