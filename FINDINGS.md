# GNOME launch findings

Date: 2026-10-09

The board boots to `multi-user.target`, not `graphical.target`. That is the
right default for a mostly headless system running memory-intensive services.
GDM and GNOME should not consume memory before there is a reason to use the
display.

## What failed

The direct `startx` session was not a normal GNOME login session:

- `gdm.service` was inactive.
- `Xorg :0 vt8`, `gnome-session-binary`, and `gnome-shell` were started from a
  transient `arduino-desktop.service`.
- GNOME reported that screen locking was not enabled without GDM.
- The graphical processes were moved by PAM and logind into
  `session-*.scope`, not the transient service cgroup.
- The old shutdown code searched the empty transient cgroup for
  `gnome-session-binary`, so its graceful logout path did not work.

The local crash dialog showed Ubuntu 24.04, GNOME Shell 46.0, arm64, and
`SIGABRT`. The separate Edge investigation recorded a Mutter assertion in
`meta_window_unmaximize()`, reached through an X11 window operation. That is
not evidence that FEX itself caused the GNOME crash, and it is not a reason to
run GDM all the time.

## Decision

The scripts now use GDM as an on-demand display manager:

1. `launch_desktop.sh` saves the current virtual terminal and starts
   `display-manager.service`.
2. GDM creates the PAM, logind, seat, lock-screen, and compositor session.
3. The user selects `Ubuntu on Wayland` at the display.
4. `stop_desktop.sh` stops GDM and restores the saved virtual terminal.

The old direct `startx` scripts were removed. Wayland is the preferred first
test because native Wayland applications avoid the X11 window-management path
associated with the Mutter backtrace. X11 applications still use Xwayland, so
this does not make the crash impossible.

## Resource decision

Changing `CPUWeight` or `IOWeight` would not solve the boot-time problem. An
idle compositor still holds memory and the DRM device. Memory limits would
make GNOME more likely to be killed under pressure, which is not a useful
stability strategy.

The system therefore keeps GDM disabled at boot and retains a terminal
on/off switch. The installed `gdm.service` is static and wanted by
`graphical.target`, while the default target remains `multi-user.target`.

The findings came from the separate `~/edge-fex/findings` repository. That
repository was read only and was not modified from this project.
