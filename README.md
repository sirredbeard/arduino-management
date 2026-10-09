# arduino-management

Two small scripts to start and stop the GNOME desktop on demand on the Arduino VENTUNO Q, which boots to a text terminal.

## Why

The board is mostly headless and runs memory-intensive services, so GNOME should not be running at boot. The default target stays `multi-user.target`; GDM starts only when the GUI is needed.

## Scripts

`launch_desktop.sh` - Start GDM on demand, then select `Ubuntu on Wayland` at the display.

`stop_desktop.sh` - Stop GDM, release the graphical session, and switch back to the terminal you launched from.

Run them with:

```sh
$ ~/launch_desktop.sh
$ ~/stop_desktop.sh
```

Both of those in `~/` are soft links to the copies in this repo.

## How it works

`launch_desktop.sh` saves the active virtual terminal and starts `display-manager.service`, which is GDM on this system. GDM owns the Wayland/X11 choice, PAM session, logind seat, and lock-screen integration. The launcher does not enable `graphical.target`, and it does not start GNOME at boot.

`stop_desktop.sh` stops GDM, which logs out the graphical session and releases the compositor. It then switches back to the saved virtual terminal. Both scripts use `sudo` when they aren't run as root. The launcher refuses to start if the old direct `arduino-desktop.service` is still active, so it cannot start a second display stack.

## Notes

GDM is installed but not enabled at boot. `systemctl get-default` should remain `multi-user.target`. Starting `display-manager.service` manually is the on/off switch:

```sh
sudo systemctl start display-manager.service
sudo systemctl stop display-manager.service
```

The installed session list includes `Ubuntu on Wayland`. Wayland is the preferred first test because the separate Edge investigation found a GNOME Shell/Mutter assertion in `meta_window_unmaximize()` on an X11 window path. Wayland will not fix native compositor bugs, and X11 applications still use Xwayland, but native Wayland applications avoid that particular X11 management path.

The old direct `startx` implementation was removed. It created a partial GNOME session without GDM's PAM and logind setup, produced the "screen lock is not enabled without gdm" warning, and put the graphical processes in `session-*.scope` rather than the transient service cgroup. Resource controls and the old cgroup-based shutdown path therefore did not work as intended.

This does not promise that GNOME Shell is stable. The crash evidence points at Mutter and a headed Edge window operation, not at FEX itself. Keep the GUI off when it isn't needed.

## Findings

The relevant investigation was done on 2026-10-09:

- `/home/arduino/edge-fex/findings/2026-10-09-gnome-shell-crash.md` records a `SIGABRT` in GNOME Shell 46.0 on arm64, through `meta_window_unmaximize()` in libmutter.
- `/home/arduino/edge-fex/findings/crashes/summary.txt` records the same backtrace and a separate FEX `SIGSEGV` from Edge. Those are distinct failures.
- The local crash dialog reported Ubuntu 24.04, GNOME Shell 46.0, and `SIGABRT` in `__pthread_kill_implementation`.
- The non-GDM session showed `Xorg :0 vt8`, `gnome-session-binary`, and `gnome-shell`, while `gdm.service` was inactive.
- GDM is a static unit wanted by `graphical.target`; the default target is `multi-user.target`, so it can remain off at boot and be started on demand.

Do not edit the `edge-fex/findings` repository from this project. It has its own Git history and Copilot session.

## License

MIT. See [LICENSE](LICENSE).
