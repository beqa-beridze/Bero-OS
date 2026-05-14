# UPower build + post-install notes

## Lesson learned (batch 5, 2026-05-14)

The UPower 1.91.1 upstream systemd unit `/usr/lib/systemd/system/upower.service`
is heavily hardened — among other settings, it sets:

```
PrivateUsers=yes
```

This makes systemd spawn upowerd inside a private user namespace. **Requires
`CONFIG_USER_NS=y` in the kernel**. The current bero-os kernel (6.18.10) was
configured WITHOUT user namespaces:

```bash
grep -E "^CONFIG_(USER_NS|SECCOMP)=" /boot/config-6.18.10
# CONFIG_SECCOMP=y          ← only this
```

Without USER_NS, `PrivateUsers=yes` fails at startup with:

```
upower.service: Failed to set up user namespacing: Invalid argument
upower.service: Failed at step USER spawning /usr/libexec/upowerd: Invalid argument
upower.service: Main process exited, code=exited, status=217/USER
```

After 5 restart attempts systemd gives up (rate-limited).

## Fix — drop-in override

```bash
mkdir -pv /etc/systemd/system/upower.service.d
cat > /etc/systemd/system/upower.service.d/no-user-ns.conf <<'EOF'
[Service]
PrivateUsers=no
EOF
systemctl daemon-reload
systemctl reset-failed upower.service
systemctl start upower.service
```

Mirror in `configs/etc/systemd/system/upower.service.d/no-user-ns.conf`.

`PrivateUsers=no` disables the user-namespace isolation but keeps everything
else (ProtectSystem=strict, SystemCallFilter, CapabilityBoundingSet=empty,
etc) intact. UPower runs as root in the system mount namespace — same security
posture as it had on most distros pre-2021.

## When to revert

When we rebuild the kernel (for the audio codec module — see deferred items),
add `CONFIG_USER_NS=y` to .config. Then this drop-in can be deleted:

```bash
rm /etc/systemd/system/upower.service.d/no-user-ns.conf
rmdir /etc/systemd/system/upower.service.d
systemctl daemon-reload
systemctl restart upower
```

## What UPower exposes after the fix

```bash
upower -e
# /org/freedesktop/UPower/devices/battery_BAT0
# /org/freedesktop/UPower/devices/line_power_AC
# /org/freedesktop/UPower/devices/DisplayDevice
```

`xfce4-power-manager` queries this via D-Bus for the panel battery icon. The
`upower -i` command reads battery details (vendor, model, energy, state).
