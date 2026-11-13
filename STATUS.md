# Project status

## Environment

Local development runs on an arm64 Mac16,7 with Apple M4 Pro, macOS 26.6.2 (25G83), Apple Swift 6.4, and Apple Git 2.54.0. The active Command Line Tools include macOS SDKs 26.5 and 27.0. Full Xcode is unavailable in the standard Applications locations and is required for xcodebuild verification. The local wrapper selects SDK 26.5 because the SDK 27 SwiftUI State macro plugin is absent from these tools. SwiftBuild emits missing optional developer search-path warnings. See [development setup](docs/development/setup.md).

## Readiness

| Area | Evidence and remaining work |
| --- | --- |
| Build | Debug and optimized app bundles built with SwiftPM/CLT and passed strict ad-hoc signature verification. The binary declares macOS 15 minimum. Xcode project, scheme and plists passed structural checks. Full Xcode and macOS 15 runtime testing are pending. |
| Temperatures | Physical read-only verification of two CPU zones, eight GPU zones and two battery readings. Several upstream CPU candidates were excluded after inconsistent values. Coverage is partial. |
| Battery power | The physical probe and optimized Overview reported 90% charge, external power, no active charging, and 0 W of battery flow. Tests cover signed current, zero, missing and invalid inputs. Physical charging and discharging values remain unverified. |
| Fan monitoring | Physical read-only verification of both stopped fans at 0 RPM, firmware-reported 1,350–5,777 RPM bounds and mode 3. Live exports also captured both fans spinning during ordinary use. Controlled speed response and other models are unverified. |
| Manual control | Overview connects Max Fans and Restore Automatic to an authenticated helper for Mac16,7/M4 Pro on macOS 26.6.2 build 25G83. The ad hoc local build passes the installer preflight and supports administrator installation without an Apple Developer membership. Root installation and physical verification are pending. See [fan control](docs/safety/fan-control.md). |
| Curves | The Custom editor saves a shared percentage draft for both fans. In explicit Demo sessions, run a saved curve or use the Max Fans override. Turning the override off restores the previous mode if it can still be applied. Live Max Fans restores Automatic. |
| Reliability | 37 Swift Testing tests passed, including 28 parameterized simulation fault cases and the maximum-only controller's readback, rollback and restoration tests. Physical sleep/wake, longer-duration profiling and battery impact remain unmeasured. |
| UI and privacy | The optimized app displayed live telemetry, charts, profiles, and Settings. Both native export dialogs saved parseable files with matching live samples. The Compatibility page previews a user-initiated report with model, app and OS version, and telemetry availability. Local history is opt-in. Monitoring remains unprivileged. |
| Notifications and login | Alert policy is tested. End-to-end notification delivery remains unverified. The local app returned login-item unavailable. Installed signed-build registration needs verification. |
| Documentation and distribution | Release, compatibility, safety and recovery documentation, CI configuration and local packaging are present. Hosted CI, Developer ID signing, notarization and public release remain pending. The name is provisional after finding another cooling project with the same name. |
| Monitoring controls | Sensors shows zone icons and supports Name and Temperature order, optional zone grouping, and a separate visibility menu. The sidebar Menu Bar page previews the monochrome logo with up to two live values. The selectors sit side by side and the second is available only when the first is selected. The preview uses the same artwork as the native status item. Direct inspection of the macOS status item was unavailable in the UI tool. |

See [compatibility](docs/hardware/compatibility.md), [performance](docs/development/performance.md), and [distribution](docs/releases/distribution.md) for exact evidence and gates. Get the current committed checkpoint with `git log -1 --oneline`.

## Next verification

With a compatible full Xcode installation, build the shared ThermalDeck scheme. On the development Mac, verify administrator installation, physical Max Fans, Restore Automatic and normal Quit. Verify the minimum macOS runtime, notification delivery, physical sleep/wake and login behavior in an installed build.
