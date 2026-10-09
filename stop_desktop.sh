#!/bin/sh
set -eu

unit=display-manager.service
legacy_unit=arduino-desktop.service
state_file=/run/arduino-desktop.previous-vt

if [ "$(id -u)" -eq 0 ]; then
    sudo=
else
    sudo=sudo
fi

run_as_root() {
    if [ -n "$sudo" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

if run_as_root systemctl is-active --quiet "$legacy_unit"; then
    run_as_root systemctl stop "$legacy_unit"
fi

if run_as_root test -f "$state_file"; then
    if run_as_root systemctl is-active --quiet "$unit"; then
        run_as_root systemctl stop "$unit"
    fi

    previous_vt=$(run_as_root cat "$state_file")
    run_as_root rm -f "$state_file"

    case "$previous_vt" in
        *[!0-9]*|'')
            echo "Ignoring invalid saved virtual terminal: $previous_vt" >&2
            ;;
        *)
            run_as_root chvt "$previous_vt"
            ;;
    esac
fi
