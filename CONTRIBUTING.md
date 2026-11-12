# Contributing

Use macOS with Swift 6 and a compatible macOS SDK. Xcode 16 or newer is required for the IDE project. The Command Line Tools can build and test the Swift package and package a local app.

```sh
Scripts/test.sh
Scripts/build-app.sh
open dist/ThermalDeck.app
```

Open ThermalDeck.xcodeproj, select the shared ThermalDeck scheme and select My Mac. Use the package test command for the Swift Testing suite. See [development setup](docs/development/setup.md) for SDK and tooling details.

- Keep hardware transport in SMCRead and HardwareAccess, policy and data in ThermalCore, test-only control in ControlSimulation, and macOS presentation in ThermalDeck.
- Preserve Swift 6 isolation and typed units. Use explicit unavailable states and include a regression test when changing a codec, policy, or persistence schema.
- Work in focused conventional commits. Describe the verified scope, tests, and any changes to model claims in the pull request.
- Hardware troubleshooting uses unprivileged reads. Follow [fan safety and authorization](docs/safety/fan-control.md). Avoid diagnostic overrides, thermal stress and system-security changes.
- Hardware reports need model identifier, chip, OS version/build, and the exact telemetry or symptom. Exclude serial numbers, account names, file paths, unredacted logs, and credentials. Follow [SECURITY.md](SECURITY.md) for vulnerabilities.

Community participation follows the [code of conduct](CODE_OF_CONDUCT.md).
