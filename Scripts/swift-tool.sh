#!/bin/bash
set -euo pipefail

# CLT 27 currently defaults to an SDK whose SwiftUI State macro needs full Xcode.
if [[ -z "${SDKROOT:-}" ]]; then
    developer_dir="$(xcode-select -p)"
    if [[ "$developer_dir" == */CommandLineTools ]] &&
       [[ "$(xcrun --sdk macosx --show-sdk-version)" == 27.* ]] &&
       [[ -d "$developer_dir/SDKs/MacOSX26.sdk" ]]; then
        export SDKROOT="$developer_dir/SDKs/MacOSX26.sdk"
    fi
fi
exec swift "$@"
