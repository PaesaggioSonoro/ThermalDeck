#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-debug}"
display_name="${DISPLAY_NAME:-ThermalDeck}"
bundle_id="${BUNDLE_IDENTIFIER:-org.thermaldeck.local}"
output_dir="${OUTPUT_DIR:-$PWD/dist}"

Scripts/swift-tool.sh build --configuration "$configuration" --product ThermalDeck >&2
bin_dir="$(Scripts/swift-tool.sh build --configuration "$configuration" --show-bin-path)"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
staging="$(mktemp -d "$output_dir/.thermaldeck.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
bundle="$staging/ThermalDeck.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$bin_dir/ThermalDeck" "$bundle/Contents/MacOS/"
cp App/Info.plist "$bundle/Contents/"
plutil -replace CFBundleName -string "$display_name" "$bundle/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "$display_name" "$bundle/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$bundle_id" "$bundle/Contents/Info.plist"
if [[ -f App/ThermalDeck.icns ]]; then
    cp App/ThermalDeck.icns "$bundle/Contents/Resources/"
fi
codesign --force --sign - "$bundle" >&2
codesign --verify --strict "$bundle"
destination="$output_dir/ThermalDeck.app"
if [[ -e "$destination" ]]; then
    mv "$destination" "$staging/previous.app"
fi
if ! mv "$bundle" "$destination"; then
    if [[ -e "$staging/previous.app" ]]; then mv "$staging/previous.app" "$destination"; fi
    exit 1
fi
printf '%s\n' "$destination"
