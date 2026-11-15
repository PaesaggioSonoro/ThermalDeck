# Development setup

Use macOS and Swift 6. The app declares macOS 15 as its deployment target. The verified SDK and host versions are recorded in [status](../../STATUS.md). Install compatible full Xcode for IDE use or xcodebuild through [Apple's Xcode resources](https://developer.apple.com/xcode/resources/). The package and bundle scripts also work with compatible Apple Command Line Tools.

```sh
Scripts/test.sh
Scripts/build-app.sh
open dist/ThermalDeck.app
Scripts/swift-tool.sh run thermal-probe
```

The shell wrappers use the selected developer tools. On the locally tested CLT 27 installation, they select the installed SDK 26.5 because the SDK 27 SwiftUI State macro plugin is unavailable. The testing wrapper locates the bundled Swift Testing macro plugin. An explicit SDKROOT takes precedence. The developer search-path warnings on that CLT SwiftBuild did not prevent compilation or tests.

To use Xcode, open the project and build the shared ThermalDeck scheme. The library modules resolve from the local Swift package. The GUI project was plist-validated locally. Full Xcode validation requires an Xcode installation.

The bundle script accepts CONFIGURATION, DISPLAY_NAME, BUNDLE_IDENTIFIER, and OUTPUT_DIR. It builds and packages the fan helper with an ad hoc signature. Open a packaged local build with the default identifier and use **Install Fan Helper** or **Update Fan Helper** in Overview. The app builds a package from its current signed bundle and opens macOS Installer for administrator approval. The shared Xcode scheme builds the dashboard for development. Use the bundle script to package the helper.

For Terminal setup, quit the app and run `sudo /bin/bash Scripts/install-local-fan-helper.sh install dist/ThermalDeck.app`. Use `/bin/bash Scripts/install-local-fan-helper.sh check dist/ThermalDeck.app` to validate the bundle and generate a temporary service configuration. See the [README](../../README.md) for removal.

See [compatibility](../hardware/compatibility.md) and [fan safety](../safety/fan-control.md) before recording hardware claims.
