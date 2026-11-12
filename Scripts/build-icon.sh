#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
swift Scripts/draw-icon.swift "$temporary/source.png"
mkdir "$temporary/ThermalDeck.iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$temporary/source.png" --out "$temporary/ThermalDeck.iconset/icon_${size}x${size}.png" >/dev/null
    retina="$((2 * size))"
    sips -z "$retina" "$retina" "$temporary/source.png" --out "$temporary/ThermalDeck.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$temporary/ThermalDeck.iconset" -o App/ThermalDeck.icns
