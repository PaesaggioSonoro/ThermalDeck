# Local release preparation

The current bundle is a development build. Its ad-hoc signature supports local launch. The checked-in workflow builds and tests the package, verifies local packaging, and exercises the Xcode scheme on a macOS runner once hosted CI is enabled. It performs no hardware tests, signing-credential use, or publishing.

Before distribution:

1. Choose and clear a public [name](naming.md) and bundle identifier. The initial MIT copyright notice uses the project contributors collectively.
2. Install compatible Xcode and verify the Xcode scheme and package build. Review the [hardware matrix](../hardware/compatibility.md). Verify the supported macOS versions and models you intend to advertise.
3. Test local notification delivery, login-item registration and uninstall in a signed installed build. Confirm the app's menu and history behavior after sleep/wake. Verify helper authorization and the [physical Max Fans and Auto handoff](../safety/fan-control.md) before advertising support.
4. With authorized Developer ID and an existing notarytool keychain profile, run Scripts/prepare-release.sh with DEVELOPER_ID_IDENTITY, NOTARY_PROFILE and BUNDLE_IDENTIFIER set. It builds an arm64 app, applies hardened-runtime Developer ID signing, submits to Apple, staples and verifies the result, and produces a local ZIP with a SHA-256 digest. It must be run only by an authorized release operator. Review [Apple's notarization procedure](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
5. Verify the packaged release on a fresh supported Mac and capture real screenshots if desired. Publish only after owner approval.

A future [Homebrew cask](https://docs.brew.sh/Cask-Cookbook) can use the versioned ZIP, digest, macOS and ARM constraints, and `app` stanza. Before removing an approved build, restore Automatic and quit the app, then remove its login and background permissions in System Settings. Verify service removal and upgrades with a signed build. Offer removal of preferences and the optional archive separately.
