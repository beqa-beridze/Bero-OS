# DNS fallback via systemd-tmpfiles

## Why this exists

`/etc/resolv.conf` is a symlink to `/run/NetworkManager/resolv.conf`.
NM writes that file when a connection comes up. The chain:

- Boot: `/run` is a fresh tmpfs (empty). `/etc/resolv.conf` is a
  dangling symlink. DNS is broken until NM finishes initialising.
- NM start: writes `nameserver <dhcp-dns> nameserver 1.1.1.1` (the
  1.1.1.1 entry comes from a per-connection `ipv4.dns` setting on the
  saved wifi profiles).
- NM crash mid-session: the file persists with whatever NM last wrote,
  so steady-state DNS still works.
- NM stopped intentionally: NM tears down its managed interfaces, so
  DNS is moot anyway (no network).

The only genuine gap the audit (`#12`) flagged is **the early-boot
window before NM finishes writing**, plus the corner case where some
admin action wipes `/run/NetworkManager/` without NM being able to
recreate it.

## What this adds

`/etc/tmpfiles.d/networkmanager-dns-fallback.conf`:

```
d /run/NetworkManager 0755 root root -
f /run/NetworkManager/resolv.conf 0644 root root - nameserver\x201.1.1.1\nnameserver\x209.9.9.9\n
```

The `f` verb creates the file IFF it doesn't exist. systemd-tmpfiles
runs early in boot (`systemd-tmpfiles-setup.service`, before NM), so
the file exists with `1.1.1.1` and `9.9.9.9` (Cloudflare + Quad9)
before NM gets a chance to write it. NM still owns the file once
running and overwrites on every state change.

Mirrored in `configs/etc/tmpfiles.d/`.

## Tested live (2026-05-28)

1. **File-missing-while-NM-up (the actual gap)**:
   ```
   sudo rm -f /run/NetworkManager/resolv.conf
   sudo systemd-tmpfiles --create /etc/tmpfiles.d/networkmanager-dns-fallback.conf
   cat /run/NetworkManager/resolv.conf
   ```
   File contains `nameserver 1.1.1.1\nnameserver 9.9.9.9`.
   `getent hosts example.com` → returns IPv6 records. DNS works via
   the fallback.

2. **Full-/run-wipe**:
   ```
   sudo rm -rf /run/NetworkManager
   sudo systemd-tmpfiles --create /etc/tmpfiles.d/networkmanager-dns-fallback.conf
   ```
   Both directory and file get created. NM eventually reclaims the
   file when it next writes (next connection-up event).

3. **Steady-state**: file content reverts to NM's dynamic content
   (`nameserver <dhcp-dns> nameserver 1.1.1.1`) on next NM activity.

## What this does NOT solve

- **NM stopped + network down**: stopping NM brings down the wifi
  interface, so even with a working resolv.conf there's no route to
  1.1.1.1. The audit said "NM dying" but the realistic scenarios are
  "NM not yet started after boot" and "NM crashed mid-session" — both
  of which leave the interface in some up state where the fallback
  helps.
- **systemd-resolved**: still masked (deliberately, per
  `configs/etc/systemd/system/systemd-resolved.service` → /dev/null).
  This fix avoids needing resolved.
- **Local-domain (.home) resolution**: when only the fallback file is
  in play, only public DNS works. `*.home` hostnames served by the
  DHCP DNS resolver won't resolve in that window. Brief tolerable
  outage on the path that's already broken without this fix.

## Pre-existing nuisance (not introduced by this change)

NM logs `dns-mgr: resolvconf failed with status 256` on every state
change because `dns=default` in `conf.d/dns.conf` makes NM probe for
the `resolvconf` binary, which isn't installed. The warning is
non-fatal — NM falls back to writing resolv.conf directly. Worth
silencing later by setting `rc-manager=symlink` or installing
`openresolv`, but out of scope here.
