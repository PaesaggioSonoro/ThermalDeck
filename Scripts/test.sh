#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
developer_dir="$(xcode-select -p)"
plugins="$developer_dir/usr/lib/swift/host/plugins/testing"
args=(test --disable-xctest)
if [[ "$developer_dir" == */CommandLineTools ]] && [[ -f "$plugins/libTestingMacros.dylib" ]]; then
    args+=(-Xswiftc -plugin-path -Xswiftc "$plugins")
fi
exec Scripts/swift-tool.sh "${args[@]}" "$@"
