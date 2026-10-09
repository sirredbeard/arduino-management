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
    echo "The legacy direct GNOME session is already running. Stop it before starting GDM." >&2
    exit 1
fi

if run_as_root systemctl is-active --quiet "$unit"; then
    echo "The display manager is already running."
    exit 0
fi

previous_vt=$(run_as_root fgconsole 2>/dev/null || printf '1')
case "$previous_vt" in
    *[!0-9]*|'')
        echo "Unable to determine the current virtual terminal." >&2
        exit 1
        ;;
esac

printf '%s\n' "$previous_vt" | run_as_root tee "$state_file" >/dev/null

cleanup_state() {
    run_as_root rm -f "$state_file"
}
trap cleanup_state EXIT HUP INT TERM

if ! run_as_root systemctl start "$unit"; then
    echo "The display manager failed to start. Recent service logs:" >&2
    run_as_root journalctl --unit="$unit" --lines=40 --no-pager >&2
    exit 1
fi

trap - EXIT HUP INT TERM
echo "GDM is running. Select Ubuntu on Wayland at the display."
