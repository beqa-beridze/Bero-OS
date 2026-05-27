# systemd units: nix-daemon + masked resolvers

Captures five symlinks under `/etc/systemd/system/` that the repo previously
missed. Without them, a repo-restore would lose two pieces of state:

1. The nix-daemon integration that gives this box `nix profile`.
2. The decision to mask systemd-resolved and systemd-networkd entirely
   (NetworkManager owns networking; resolv.conf comes from NM directly).

## What's mirrored

In `configs/etc/systemd/system/`:

| Symlink in repo | Points to | Mirrors live? |
|---|---|---|
| `nix-daemon.service` | `/nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.service` | yes |
| `nix-daemon.socket` | `/nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.socket` | yes |
| `sockets.target.wants/nix-daemon.socket` | same as above | yes |
| `systemd-resolved.service` | `/dev/null` | yes |
| `systemd-networkd.service` | `/dev/null` | yes |

The symlinks are stored in git as text blobs containing the target string —
no `/nix/store` hash leaks into the repo and no content drifts.

## Why symlinks, not resolved content

`nix-daemon.service`'s `ExecStart=` embeds a `/nix/store/<hash>-nix-2.34.7/`
path. That hash changes every time the nix profile updates. Snapshotting
the file would freeze a stale hash; snapshotting the symlink stays stable
because the profile-pointer path is the same after each upgrade.

For the masked services, the convention "symlink to /dev/null" is the
systemd-defined way to mask a unit short of `systemctl mask`. Recreating
the symlink on a fresh install is faster than running the mask command and
also documents the intent: "we know this exists and we deliberately don't
run it."

## Restoring on a fresh install

Order:

1. Install nix (the Determinate / lix / official installer — whichever
   produced this profile path; check `/nix/var/nix/profiles/default` exists).
2. From repo root, copy/symlink the five entries:
   ```
   sudo install -d /etc/systemd/system/sockets.target.wants
   sudo cp -d configs/etc/systemd/system/nix-daemon.service /etc/systemd/system/
   sudo cp -d configs/etc/systemd/system/nix-daemon.socket /etc/systemd/system/
   sudo cp -d configs/etc/systemd/system/sockets.target.wants/nix-daemon.socket /etc/systemd/system/sockets.target.wants/
   sudo cp -d configs/etc/systemd/system/systemd-resolved.service /etc/systemd/system/
   sudo cp -d configs/etc/systemd/system/systemd-networkd.service /etc/systemd/system/
   ```
   `cp -d` preserves the symlinks themselves rather than resolving them.
3. `sudo systemctl daemon-reload`.
4. `sudo systemctl enable --now nix-daemon.socket`.

## Why systemd-resolved is masked, not just disabled

Disable lets systemd or another package re-enable it on upgrade. Mask
(symlink to /dev/null) cannot be undone by a unit-file rewrite — only by
explicitly unmasking. NetworkManager writes `/etc/resolv.conf` directly
(see `configs/etc/NetworkManager/conf.d/dns.conf`), so resolved would be
redundant + add a hop.

That is also the single point of failure flagged in audit-2026-05-28 #12 —
if NM dies, DNS dies. That fix is separate.
