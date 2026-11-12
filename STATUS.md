# Project status

## Environment and initialization

The workspace started empty. Local development runs on an arm64 Mac16,7 with Apple M4 Pro, macOS 26.6.2 (25G83), Apple Swift 6.4 and Apple Git 2.54.0. Command Line Tools are active and provide macOS SDKs 26.5 and 27.0. Full Xcode is not active or present in the standard Applications directory. Local commit identity is configured.

Use Command Line Tools for package compilation and app packaging. Full Xcode is needed for xcodebuild and Xcode-specific verification. Install a compatible version through Apple's [Xcode resources](https://developer.apple.com/xcode/resources/) if that verification is needed.

## Research checkpoint

Pinned reference revisions, ABI assumptions and scope are recorded in docs/hardware/research.md. The architecture uses SwiftUI, SwiftPM, and a C read-only boundary. Control remains disabled. Next action is the launchable native foundation, followed by a hardware probe.

## Native foundation

The ad-hoc-signed SwiftUI bundle built and launched in explicit demo mode. The dashboard showed the simulation label and live CPU/GPU sample values. Two telemetry tests passed. The installed CLT defaults to SDK 27, which exposes a SwiftUI State macro whose plugin is absent. The local Swift wrapper selects the installed SDK 26.5 and the test wrapper locates the Swift Testing plugin. CLT's SwiftBuild emits missing optional developer search-path warnings on this host. Next action is read-only telemetry discovery on Mac16,7.

## Temperature monitoring

The Mac16,7 read-only probe returned two CPU zones, eight GPU zones and two battery readings. Upstream-mapped Tp keys had inconsistent values and were excluded. Four tests passed and the normal app bundle compiled against the hardware reader. Next action is read-only fan discovery and an end-to-end live UI smoke test.

## Fan monitoring

The same unprivileged probe found two fans, both stopped in firmware mode 3 with reported bounds of 1,350–5,777 RPM and targets of 0 RPM. The app displays current and target separately. Five tests passed. No spinning-load or fan-control test was performed. Next action is bounded history and local notifications.

## Charts, history and notifications

The app builds with native Charts, fixed time and sample limits, a local opt-in archive, and permission-aware local alert delivery. The alert and archive policies are covered by tests. Notification delivery has not been manually exercised. Next action is deterministic control simulation and an explicit feasibility decision.

## Fan control feasibility

Fourteen tests passed, including 28 parameterized start and active control fault cases and dedicated settling, transition and curve tests. The tests use virtual time and an in-memory plant. Hardware control is blocked by undocumented override semantics, absent control-grade telemetry and unverified recovery after helper failure. No write authorization is requested while these prerequisites are open. Next action is the Automatic profile and offline curve editor.

## Cooling profiles

Automatic is the app's only active profile. Quiet, Balanced and Performance show their unavailable state. The Custom editor validates a versioned local curve and previews interpolated targets using simulated temperatures. It cannot apply a target. The bundle builds and the 14-test suite passes. Next action is end-to-end live UI verification and packaging.

## Native integration

The live app rendered the Mac16,7 dashboard, both physical fan detail panels, the temperature and RPM history, Automatic profile and offline editor, and Settings in a native UI smoke test. The local build reported login registration unavailable. The original vector-derived ICNS is packaged and the Xcode project passed plist validation. Full Xcode project builds remain unverified. Next action is lifecycle, reliability and performance verification.

## Reliability

Hardware reads use a dedicated serial executor. The dashboard switches between one-second default visible sampling and five seconds when closed, verified in local unified logs and on reopening. The 20-read physical probe had a 4.987 ms warm median. See docs/development/performance.md for CPU and memory observations and limitations. Sleep/wake logic invalidates snapshots and reconnects. Physical sleep/wake, notification delivery and login registration remain unverified. Next action is history export and lightweight indicator configuration.

## Optional features

CSV and JSON export include units, UTC timestamps, measured and reported fan series, and an explicit simulation marker. Settings can select the menu bar fan and hide the Overview chart. Power metrics, optional update checks and diagnostic sharing remain deferred. Next action is local release preparation and final verification.
