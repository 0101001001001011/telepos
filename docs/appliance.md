# TelePOS OS appliance

TelePOS runs on ordinary desktops, but it also ships as a Linux appliance that
boots straight into the kiosk. That image lives in a separate repository,
[telepos-os](https://github.com/kvgosu/telepos-os), and the two halves meet at a
small runtime contract documented here.

When the POS is running anywhere other than the appliance, none of this applies:
**Settings → System** simply reports the daemon as unavailable and the rest of
the application is unaffected.

## The contract

| What | Value | POS side | Appliance side |
| --- | --- | --- | --- |
| Daemon | `telepos-sysd` | — | `sysd/` (Rust) |
| Socket | `/run/telepos/sysd.sock` | `lib/data/sysd/sysd_client.dart` | `sysd/src/main.rs` |
| Kiosk user | `telepos` | printer group hints | `0100-telepos-user.hook.chroot` |
| Config | `/etc/telepos/telepos.toml` | — | `configs/telepos.toml` |

The socket is a Unix domain socket carrying newline-delimited JSON. Both sides
must agree on the path and on the shape of each request — a mismatch shows up as
an empty or greyed-out System section rather than an error, so change them
together.

## What the daemon provides

Network configuration, package and driver installation from the curated apt
repository, display and session control (switching between kiosk and desktop),
service status, backups, factory reset, and time-boxed remote support access
over SSH.

The POS never shells out to the system directly. Everything the System section
does goes through this daemon, which is what keeps the kiosk user unprivileged.

## Building the image

See the [telepos-os README](https://github.com/kvgosu/telepos-os). Two targets
are supported: an x86 Ubuntu ISO built under Ubuntu 22.04 or WSL, and a
Raspberry Pi 5 image built natively on the Pi because Flutter cannot
cross-compile to arm64.

## Legacy graphics

Machines whose GPU has no KMS driver — VIA Chrome9 in the HP T510, for instance —
have no `/dev/dri`, and wlroots-based compositors hang rather than exit when it
is missing. `telepos-kiosk.sh` probes for a DRM device and goes straight to an
Xorg session on the framebuffer when there is none. The live boot passes
`nomodeset vga=791` so that the fbdev driver has a framebuffer to attach to.
