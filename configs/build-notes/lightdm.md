# LightDM build + post-install notes

## What BLFS gives you

- `/usr/sbin/lightdm` (daemon)
- `/usr/bin/lightdm-gtk-greeter` (the GTK greeter)
- `liblightdm-gobject` for the greeter API

## What BLFS does NOT give you

1. **No systemd unit.** lightdm needs `/etc/systemd/system/lightdm.service` written by hand (or pulled from `blfs-systemd-units`, which we never installed). See `configs/etc/systemd/system/lightdm.service`.

2. **No `lightdm-session` wrapper script.** lightdm's default `session-wrapper=/usr/bin/lightdm-session` doesn't exist after `make install` — lightdm's source tree doesn't ship one. Without it, every session attempt exits 1 immediately and lightdm crash-loops between autologin and the greeter forever. See `configs/usr/bin/lightdm-session` for our minimal wrapper. The key thing it does is `exec dbus-run-session -- "$@"` so XFCE's xfconf and friends find a session DBus.

## What lightdm needs

- PAM (`/etc/pam.d/lightdm`, `/etc/pam.d/lightdm-greeter`, `/etc/pam.d/lightdm-autologin` — all installed by `make install` if PAM was present at build time)
- iso-codes + libxklavier for the greeter
- `/etc/lightdm/lightdm.conf` with `[Seat:*]` block. For autologin to root: `autologin-user=root`, `autologin-user-timeout=0`, `autologin-session=xfce`
- `/usr/share/xsessions/xfce.desktop` (provided by xfce4-session)

## Diagnosing failures

If lightdm crash-loops:

1. `journalctl -u lightdm -b --no-pager | tail -50` — top-level lightdm errors
2. `cat /var/log/lightdm/lightdm.log | head -80` — what session command lightdm tried to run
3. `cat /var/log/lightdm/seat0-greeter.log` — greeter crash details
4. `cat /root/.xsession-errors` — what the user-session command (xfce4-session etc.) said before dying

The `.xsession-errors` file is the most useful — it's where stderr from the session wrapper goes.

## XFCE-as-root

XFCE has historically warned about running as root, but our session works fine. If we move to a non-root user later, no XFCE-side changes needed — just create the user, set `autologin-user=` to that user, and they get the same desktop.

## Common warnings (harmless)

- `Failed to open CK session: org.freedesktop.ConsoleKit was not provided` — we use systemd-logind, not ConsoleKit. Ignore.
- `PAM unable to dlopen(/usr/lib/security/pam_systemd.so)` — our LFS systemd was built before PAM was installed. We could rebuild systemd with PAM support but lightdm works without it.
- `xfwm4-WARNING: Another compositing manager is running on screen 0` — xfwm4 is its own compositor, this fires when something else also tries; harmless.
- `No GPG agent found` — we stubbed gpg2 (gnupg not installed). gcr fails to start a real agent; doesn't break the session.
