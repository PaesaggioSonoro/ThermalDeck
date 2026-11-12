#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVELOPER_ID_IDENTITY:?Set an authorized Developer ID Application signing identity.}"
: "${NOTARY_PROFILE:?Set the name of an authorized notarytool keychain profile.}"
: "${BUNDLE_IDENTIFIER:?Set the verified distribution bundle identifier.}"
[[ "$DEVELOPER_ID_IDENTITY" == 'Developer ID Application:'* ]]
[[ "$BUNDLE_IDENTIFIER" != org.thermaldeck.local ]]
[[ "$(uname -m)" == arm64 ]]

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
app="$(CONFIGURATION=release OUTPUT_DIR="$staging" Scripts/build-app.sh)"
codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_IDENTITY" "$app"
codesign --verify --strict "$app"
archive="$staging/submission.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$staging/notary.json"
status="$(plutil -extract status raw "$staging/notary.json")"
if [[ "$status" != Accepted ]]; then
    cat "$staging/notary.json" >&2
    exit 1
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute "$app"
version="$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")"
mkdir -p dist
destination="dist/ThermalDeck-${version}-macos-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$staging/release.zip"
mv "$staging/release.zip" "$destination"
shasum -a 256 "$destination"
