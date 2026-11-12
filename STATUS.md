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
| Manual control | Disabled. The M4 diagnostic override, independent recovery on service termination, and control-grade sensing are unresolved. No hardware writes or stress tests occurred. |
| Curves | Automatic is the only active profile. The Custom editor saves a local draft. Tests cover interpolation, rate limits, hysteresis, settling and simulated fallback. |
| Reliability | 23 Swift Testing tests passed, including 28 parameterized control fault cases, a preference persistence regression, and simulated workspace sleep/wake. Verified visible and closed-window cadence and physical read-only sampling. Physical sleep/wake, longer-duration profiling and battery impact remain unmeasured. |
| UI and privacy | The optimized app displayed live telemetry, charts, profiles, and Settings. Both native export dialogs saved parseable files with matching live samples. A crash on preference edits was fixed and the rebuilt app switched between Light, Dark, and System appearance while monitoring. The Compatibility page previews a user-initiated report with model, app and OS version, and telemetry availability. Local history is opt-in. No network client or privileged helper ships. |
| Notifications and login | Alert policy is tested. End-to-end notification delivery remains unverified. The local app returned login-item unavailable. Installed signed-build registration needs verification. |
| Documentation and distribution | Release, compatibility, safety and recovery documentation, CI configuration and local packaging are present. Hosted CI, Developer ID signing, notarization and public release remain pending. The name is provisional after finding another cooling project with the same name. |

See [compatibility](docs/hardware/compatibility.md), [performance](docs/development/performance.md), and [distribution](docs/releases/distribution.md) for exact evidence and gates. Get the current committed checkpoint with `git log -1 --oneline`.

## Next verification

With a compatible full Xcode installation, build the shared ThermalDeck scheme. On supported test systems, verify the minimum macOS runtime, notification delivery, physical sleep/wake and login behavior in an installed build. Keep live fan control disabled while the independent recovery gate is unresolved.
