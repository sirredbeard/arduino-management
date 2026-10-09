#!/bin/sh
set -eu

if systemctl is-active --quiet display-manager.service; then
    exit 0
fi

if systemctl is-active --quiet graphical.target; then
    unit=display-manager.service
else
    unit=graphical.target
fi

if [ "$(id -u)" -eq 0 ]; then
    exec systemctl start "$unit"
fi

exec sudo -- systemctl start "$unit"
