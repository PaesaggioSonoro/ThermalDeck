# Project status

## Environment and initialization

The workspace started empty. Local development runs on an arm64 Mac16,7 with Apple M4 Pro, macOS 26.6.2 (25G83), Apple Swift 6.4 and Apple Git 2.54.0. Command Line Tools are active and provide macOS SDKs 26.5 and 27.0. Full Xcode is not active or present in the standard Applications directory. Local commit identity is configured.

Use Command Line Tools for package compilation and app packaging. Full Xcode is needed for xcodebuild and Xcode-specific verification. Install a compatible version through Apple's [Xcode resources](https://developer.apple.com/xcode/resources/) if that verification is needed.

## Research checkpoint

Pinned reference revisions, ABI assumptions and scope are recorded in docs/hardware/research.md. The architecture uses SwiftUI, SwiftPM, and a C read-only boundary. Control remains disabled. Next action is the launchable native foundation, followed by a hardware probe.

## Native foundation

The ad-hoc-signed SwiftUI bundle built and launched in explicit demo mode. The dashboard showed the simulation label and live CPU/GPU sample values. Two telemetry tests passed. The installed CLT defaults to SDK 27, which exposes a SwiftUI State macro whose plugin is absent. The local Swift wrapper selects the installed SDK 26.5 and the test wrapper locates the Swift Testing plugin. CLT's SwiftBuild emits missing optional developer search-path warnings on this host. Next action is read-only telemetry discovery on Mac16,7.
