#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-debug}"
display_name="${DISPLAY_NAME:-ThermalDeck}"
bundle_id="${BUNDLE_IDENTIFIER:-org.thermaldeck.local}"
output_dir="${OUTPUT_DIR:-$PWD/dist}"

Scripts/swift-tool.sh build --configuration "$configuration" --product ThermalDeck >&2
Scripts/swift-tool.sh build --configuration "$configuration" --product thermal-fan-helper >&2
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
[[ "$bundle_id" =~ ^[A-Za-z0-9.-]+$ ]]
service_label="$bundle_id.fan-control"
service_plist="$bundle/Contents/Library/LaunchDaemons/$service_label.plist"
mkdir -p "$bundle/Contents/Library/LaunchDaemons"
cp App/org.thermaldeck.local.fan-control.plist "$service_plist"
plutil -replace Label -string "$service_label" "$service_plist"
plutil -replace AssociatedBundleIdentifiers.0 -string "$bundle_id" "$service_plist"
plutil -replace MachServices -json "{\"$service_label\":true}" "$service_plist"
cp "$bin_dir/thermal-fan-helper" "$bundle/Contents/MacOS/"
if [[ "$bundle_id" == org.thermaldeck.local ]]; then
    installer_resources="$bundle/Contents/Resources/FanHelperInstaller"
    mkdir -p "$installer_resources"
    cp App/FanHelperInstaller/Distribution.xml App/FanHelperInstaller/postinstall \
        Scripts/install-local-fan-helper.sh "$installer_resources/"
fi
codesign --force --options runtime --sign - --identifier "$service_label" "$bundle/Contents/MacOS/thermal-fan-helper" >&2
codesign --force --options runtime --sign - "$bundle" >&2
codesign --verify --deep --strict "$bundle"
destination="$output_dir/ThermalDeck.app"
if [[ -e "$destination" ]]; then
    mv "$destination" "$staging/previous.app"
fi
if ! mv "$bundle" "$destination"; then
    if [[ -e "$staging/previous.app" ]]; then mv "$staging/previous.app" "$destination"; fi
    exit 1
fi
printf '%s\n' "$destination"
