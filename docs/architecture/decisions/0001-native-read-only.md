# ADR 0001 — Native Swift and a read-only hardware boundary

Status: Accepted.

## Context

Swift 6 and macOS SDKs are available via Command Line Tools. Full Xcode is absent. AppleSMC wire layout is a C ABI and its protocol is undocumented. No supported Apple API exposes the required fan telemetry.

## Decision

Target macOS 15 and use SwiftPM for build and tests, SwiftUI/AppKit and Charts for the app, and a narrow C target for AppleSMC reads. Package a local .app with the CLI toolchain and include an Xcode project for IDE use. Make hardware availability explicit. Keep simulation and persistence in pure Swift without third-party packages.

Do not compile any SMC write selector or ship a helper. Store settings locally using versioned Codable values and bound any local history. Require real read-only testing and document OS evidence separately from the deployment target.

## Consequences

Ordinary monitoring runs unprivileged. Firmware or OS changes can remove telemetry. Unknown keys and failures require visible fallbacks. Control validation, signed distribution and full Xcode verification are independent tasks.
