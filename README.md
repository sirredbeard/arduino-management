# arduino-management

Small management scripts for the Arduino computer.

## `launch_desktop.sh`

Starts the graphical desktop when it isn't already running.

The script:

1. Exits if `display-manager.service` is already active.
2. Starts `display-manager.service` when the graphical target is active.
3. Starts `graphical.target` otherwise.
4. Uses `sudo` when it isn't run as root.

Run it with:

```sh
~/launch_desktop.sh
```

The copy in `~/launch_desktop.sh` is a symbolic link to the script in this repository. The link is there so existing launchers keep working while the script has a proper home.

## License

MIT. See [LICENSE](LICENSE).
