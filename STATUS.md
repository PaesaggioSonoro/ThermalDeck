# Project status

## Environment

Local development runs on an arm64 Mac16,7 with Apple M4 Pro, macOS 26.6.2 (25G83), Apple Swift 6.4, and Apple Git 2.54.0. The active Command Line Tools include macOS SDKs 26.5 and 27.0. Full Xcode is unavailable in the standard Applications locations and is required for xcodebuild verification. The local wrapper selects SDK 26.5 because the SDK 27 SwiftUI State macro plugin is absent from these tools. SwiftBuild emits missing optional developer search-path warnings. See [development setup](docs/development/setup.md).

## Readiness

| Area | Evidence and remaining work |
| --- | --- |
| Build | Debug and optimized app bundles built with SwiftPM/CLT and passed strict ad-hoc signature verification. The binary declares macOS 15 minimum. Xcode project, scheme and plists passed structural checks. Full Xcode and macOS 15 runtime testing are pending. |
| Temperatures | Unprivileged AppleSMC and HID discovery on Mac16,7 returned 171 named temperature readings, including all ten performance core labels. Two individual efficiency-core labels and vendor GPU cluster aliases remain unverified. |
| Battery power | The physical probe and optimized Overview reported 90% charge, external power, no active charging, and 0 W of battery flow. Tests cover signed current, zero, missing and invalid inputs. Physical charging and discharging values remain unverified. |
| Fan monitoring | Physical verification of both stopped fans at 0 RPM, firmware-reported 1,350–5,777 RPM bounds and mode 3. Live exports also captured both fans spinning during ordinary use. Other models are unverified. |
| Manual control | The installed helper reached Maximum on Mac16,7/M4 Pro. Restore Automatic returned both fans to 0 RPM. A second run quit from Maximum, then an independent probe confirmed both fan modes at 3 and the override flag at 0. See [fan control](docs/safety/fan-control.md). |
| Curves | The Custom editor saves a shared percentage draft for both fans. In explicit Demo sessions, run a saved curve or use the Max Fans override. Turning the override off restores the previous mode if it can still be applied. Live Max Fans restores Automatic. |
| Reliability | 42 Swift Testing tests passed, including 28 parameterized simulation fault cases, delayed fan spin-up, sensor history, fan alert deduplication and the M4 Pro temperature mappings. Physical sleep/wake during an override, longer-duration profiling and battery impact remain unmeasured. |
| UI and privacy | The optimized app displayed live telemetry, charts, profiles, and Settings. Both native export dialogs saved parseable files with matching live samples. The Compatibility page previews a user-initiated report with model, app and OS version, and telemetry availability. Local history is opt-in. Monitoring remains unprivileged. |
| Notifications and login | Alert policy covers temperature, monitoring outages, loss of fan control, helper disconnect and unconfirmed restoration. End-to-end notification delivery remains unverified. The local app returned login-item unavailable. Installed registration needs verification. |
| Documentation and distribution | Release, compatibility, safety and recovery documentation, CI configuration and local packaging are present. Hosted CI, Developer ID signing, notarization and public release remain pending. The name is provisional after finding another cooling project with the same name. |
| Monitoring controls | Sensors supports sorting, grouping and visibility. The menu bar adds Max Fans and Use Automatic. History records up to four selected mapped sensors and includes them in exports. Direct inspection of the macOS status item was unavailable in the UI tool. |

See [compatibility](docs/hardware/compatibility.md), [performance](docs/development/performance.md), and [distribution](docs/releases/distribution.md) for exact evidence and gates. Get the current committed checkpoint with `git log -1 --oneline`.

## Next verification

With a compatible full Xcode installation, build the shared ThermalDeck scheme. Verify the minimum macOS runtime, notification delivery, physical sleep/wake and login behavior in an installed build.
