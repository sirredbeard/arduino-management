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

## Clock showed the wrong time zone

Date: 2026-10-08

The GNOME clock was four hours ahead. Settings showed `UTC (London, United
Kingdom)` with both `Automatic Date & Time` and `Automatic Time Zone` turned
on.

The clock itself was correct. `timedatectl` reported `System clock
synchronized: yes` with the NTP service active. Only the zone was wrong:

```
Time zone: Etc/UTC
```

`/etc/localtime` pointed at `/usr/share/zoneinfo/Etc/UTC`.

Two separate things were going on.

First, automatic time zone could never work. `geoclue-2.0 2.7.0-3ubuntu7`
still defaults to the Mozilla Location Service, which was retired in June
2024. Every lookup fails:

```
geoclue[...]: Failed to query location: Query location SOUP error: Not Found
```

GNOME asks geoclue for a position, geoclue gets an HTTP 404, and the time zone
is never set. The toggle is on and does nothing.

Second, `London` was never a detected location. `gnome-control-center
1:46.7-0ubuntu0.24.04.6` logs:

```
gnome-control-c: Timezone 'Etc/UTC' is unhandled, setting Europe/London as default
```

That is Settings mislabeling `Etc/UTC` in the picker. The board did not think
it was in the United Kingdom. It thought it was in UTC, which it was.

The fix is to set the zone explicitly:

```
$ sudo timedatectl set-timezone America/New_York
```

`timedatectl` writes the `/etc/localtime` symlink but leaves the Debian legacy
file alone, so that needs syncing too or tools that read it stay on the old
value:

```
$ echo 'America/New_York' | sudo tee /etc/timezone
```

After that, `timedatectl status` reports `America/New_York (EDT, -0400)` and
the clock is correct.

I would leave `Automatic Time Zone` off on this board. It is a stationary
device, the geolocation backend it depends on no longer exists, and an
explicit zone is one less moving part. There is a `[static-source]` section in
`/etc/geoclue/geoclue.conf` that can feed geoclue fixed coordinates, but that
is more machinery than a board that never moves needs.
