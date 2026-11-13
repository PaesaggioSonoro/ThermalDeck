#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 077

label=org.thermaldeck.local.fan-control
helper_dir=/Library/PrivilegedHelperTools
daemon_dir=/Library/LaunchDaemons
helper="$helper_dir/$label"
config="$helper_dir/$label.plist"
daemon="$daemon_dir/$label.plist"

usage() {
    printf '%s\n' 'Quit ThermalDeck first. Run one of these commands from the repository:' \
        '  /bin/bash Scripts/install-local-fan-helper.sh check dist/ThermalDeck.app' \
        '  sudo /bin/bash Scripts/install-local-fan-helper.sh install dist/ThermalDeck.app' \
        '  sudo /bin/bash Scripts/install-local-fan-helper.sh remove'
}

case "${1:-}" in
    check|install) [[ $# == 2 ]] || { usage >&2; exit 64; } ;;
    remove) [[ $# == 1 ]] || { usage >&2; exit 64; } ;;
    *) usage >&2; exit 64 ;;
esac
if [[ "$1" != check && "$EUID" != 0 ]]; then
    usage >&2
    exit 77
fi

trusted_directory() {
    local mode
    [[ -d "$1" && ! -L "$1" && "$(stat -f '%u' "$1")" == 0 ]] || return 1
    mode="$(stat -f '%Lp' "$1")"
    (( (8#$mode & 022) == 0 ))
}

if [[ "$1" != check ]]; then
    trusted_directory /Library && trusted_directory "$daemon_dir" ||
        { printf '%s\n' 'The system service directory is not owned and protected by root.' >&2; exit 78; }
    if [[ ! -e "$helper_dir" && ! -L "$helper_dir" && "$1" == install ]]; then
        install -d -o root -g wheel -m 755 "$helper_dir"
    fi
    if [[ -e "$helper_dir" || -L "$helper_dir" ]]; then
        trusted_directory "$helper_dir" ||
            { printf '%s\n' 'The helper directory is not owned and protected by root.' >&2; exit 78; }
    fi
fi

unload() {
    if launchctl print "system/$label" >/dev/null 2>&1; then
        launchctl bootout "system/$label"
    fi
}

if [[ "$1" == remove ]]; then
    unload
    rm -f "$daemon" "$config" "$helper"
    printf '%s\n' 'ThermalDeck fan helper removed.'
    exit
fi

[[ -d "$2" ]] || { printf '%s\n' 'Build ThermalDeck first and pass the path to ThermalDeck.app.' >&2; exit 66; }
if [[ "$1" == check ]]; then
    stage="$(mktemp -d -t thermaldeck)"
else
    stage="$(mktemp -d "$helper_dir/.thermaldeck.XXXXXXXX")"
fi
trap 'rm -rf "$stage"' EXIT
app="$stage/ThermalDeck.app"
source_app="$(cd "$2" && pwd -P)"
ditto --norsrc "$source_app" "$app"
app_helper="$app/Contents/MacOS/thermal-fan-helper"
[[ ! -L "$app/Contents" && ! -L "$app/Contents/MacOS" && -f "$app_helper" && ! -L "$app_helper" ]]
codesign --verify --deep --strict -R '=identifier "org.thermaldeck.local"' "$app"
codesign --verify --strict -R "=identifier \"$label\"" "$app_helper"

local_hash() {
    local details hash
    details="$(codesign -dv --verbose=4 "$1" 2>&1)" || return 1
    [[ "$details" == *'Signature=adhoc'* && "$details" == *'(adhoc,runtime)'* ]] || return 1
    hash="$(awk -F= '$1 == "CDHash" { print $2 }' <<< "$details")"
    [[ "$hash" =~ ^[0-9a-f]{40}$ ]] || return 1
    codesign --verify --strict -R "=cdhash H\"$hash\"" "$1" || return 1
    printf '%s' "$hash"
}

app_hash="$(local_hash "$app")" && helper_hash="$(local_hash "$app_helper")" ||
    { printf '%s\n' 'Use an ad hoc ThermalDeck build made with Scripts/build-app.sh.' >&2; exit 78; }

plutil -create xml1 "$stage/identity.plist"
plutil -insert appCDHash -string "$app_hash" "$stage/identity.plist"
plutil -insert helperCDHash -string "$helper_hash" "$stage/identity.plist"
plutil -create xml1 "$stage/daemon.plist"
plutil -insert Label -string "$label" "$stage/daemon.plist"
plutil -insert ProgramArguments -json "[\"$helper\"]" "$stage/daemon.plist"
plutil -insert MachServices -json "{\"$label\":true}" "$stage/daemon.plist"
plutil -insert ExitTimeOut -integer 65 "$stage/daemon.plist"
plutil -lint "$stage/identity.plist" "$stage/daemon.plist"
if [[ "$1" == check ]]; then
    printf '%s\n' 'ThermalDeck.app and its local fan helper passed the install checks.'
    exit
fi

save_previous() {
    local existing="$1" backup="$2"
    if [[ -e "$existing" || -L "$existing" ]]; then
        [[ -f "$existing" && ! -L "$existing" && "$(stat -f '%u' "$existing")" == 0 ]] ||
            { printf 'Unexpected existing file: %s\n' "$existing" >&2; exit 78; }
        cp -p "$existing" "$stage/$backup"
    fi
}
save_previous "$helper" previous-helper
save_previous "$config" previous-config
save_previous "$daemon" previous-daemon

put_file() {
    local source="$1" target="$2" mode="$3" temporary
    temporary="$(mktemp "${target%/*}/.thermaldeck-file.XXXXXXXX")" || return 1
    if install -o root -g wheel -m "$mode" "$source" "$temporary" && mv -f "$temporary" "$target"; then
        return 0
    fi
    rm -f "$temporary"
    return 1
}

unload
if put_file "$app_helper" "$helper" 755 &&
   put_file "$stage/identity.plist" "$config" 644 &&
   put_file "$stage/daemon.plist" "$daemon" 644 &&
   launchctl bootstrap system "$daemon"; then
    printf '%s\n' 'ThermalDeck fan helper installed. Open ThermalDeck and check Overview.'
else
    unload || true
    rm -f "$daemon" "$config" "$helper"
    if [[ -f "$stage/previous-daemon" && -f "$stage/previous-config" && -f "$stage/previous-helper" ]]; then
        put_file "$stage/previous-helper" "$helper" 755
        put_file "$stage/previous-config" "$config" 644
        put_file "$stage/previous-daemon" "$daemon" 644
        launchctl bootstrap system "$daemon" || true
    fi
    printf '%s\n' 'Could not install the ThermalDeck fan helper.' >&2
    exit 1
fi
