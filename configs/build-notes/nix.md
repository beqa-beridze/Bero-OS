# Nix install + post-install notes

## Lesson learned (2026-05-22, post audio fix)

Installed upstream Nix 2.34.7 in multi-user mode, flakes enabled. The
install itself was clean — one latent bero-os bug surfaced as a side
effect (path.sh clobbered PATH after profile drop-ins; documented below).

## The install command used

```sh
curl -L --proto '=https' --tlsv1.2 https://nixos.org/nix/install -o /tmp/nix-install.sh
yes | bash /tmp/nix-install.sh --daemon --no-channel-add
```

- `--daemon` enables multi-user mode (nixbld group, build users, daemon
  + socket).
- `--no-channel-add` skips the legacy default `nixpkgs` channel. We are
  flakes-first; channels are unused clutter.
- `yes |` auto-confirms the installer's prompts. Running interactively
  (via a TTY ssh) works equally well.

The bootstrap is small (`/tmp/nix-install.sh`, 4.3 KB). It downloads the
real `nix-2.34.7-x86_64-linux.tar.xz`, SHA-256 verifies, extracts, then
runs the inner `install` script with our flags.

## What got created

- `/nix/store` + `/nix/var` (package store + state)
- `/etc/nix/nix.conf` (system-wide config)
- `/etc/systemd/system/nix-daemon.service` + `nix-daemon.socket`
- `/etc/profile.d/nix.sh` — sources the per-user setup script under
  `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`
- `nixbld` group (GID 30000) + `nixbld1`..`nixbld32` users
  (UIDs 30001–30032), `/sbin/nologin` shells
- `/root/.bashrc` — installer DID NOT touch it (so no
  `.backup-before-nix` was created). The `/etc/profile.d/nix.sh` does
  the work via /etc/profile.

`/nix/var/nix/profiles/default` is a symlink to
`/nix/var/nix/profiles/per-user/root/profile` — that's why the root user
finds `nix` in PATH the moment its profile gets populated.

## Flakes enablement

Appended to `/etc/nix/nix.conf`:

```
experimental-features = nix-command flakes
```

Then:

```sh
systemctl restart nix-daemon
```

(The `.socket` unit doesn't need a restart — only the `.service` re-reads
config on (re)start.)

## Flakes-first syntax — what works and what doesn't

Since we deliberately skipped `--channel-add`, **the legacy `nix-env`
channel workflow won't work**. Use flake URLs instead:

- ✓ `nix profile add nixpkgs#hello` — flake reference, works
- ✓ `nix shell nixpkgs#htop` — temporary shell, works
- ✗ `nix-env -iA nixpkgs.hello` — needs a channel, will fail
- ✗ `nix-channel --list` — empty by design

If you ever DO want classic channels, run `nix-channel --add
https://nixos.org/channels/nixpkgs-unstable nixpkgs && nix-channel
--update`. We're not doing this — flakes give us reproducibility +
explicit pinning.

Also: `nix profile install` is a deprecated alias for `nix profile add`.
The CLI warns but still works. Prefer `add` in new code.

## path.sh PATH-clobber bug (caught during smoke test)

The bero-os `/etc/profile.d/path.sh` did:

```sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
```

— an absolute assignment, not a prepend. Files in `/etc/profile.d/`
source alphabetically, so `nix.sh` (sourced *before* `path.sh`) was
having its PATH addition wiped immediately after by path.sh's clobber.
Root saw `nix` because somewhere else in their interactive shell setup
PATH got rebuilt, but the `bero` login shell ended up without nix in
PATH.

Fix: renamed `path.sh` → `00-path.sh` so it sorts first and becomes the
base PATH. Everything else (nix.sh, rustc.sh, etc) prepends safely on
top. This was a pre-existing latent bug — any future drop-in that wants
to prepend to PATH would have tripped on it.

Verification after the rename:

```
$ su -l bero -c 'echo $PATH'
/opt/rustc/bin:/home/bero/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

## Smoke test results

Root, then bero:

```
$ nix --version
nix (Nix) 2.34.7

# root:
$ nix profile add nixpkgs#hello && hello
Hello, world!

# bero (UID 1000):
$ su -l bero -c 'nix profile add nixpkgs#cowsay && cowsay "bero-os has nix"'
 _________________
< bero-os has nix >
 -----------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

Both fetched binaries from `cache.nixos.org` (no local builds). Daemon
stayed active after each install. Per-user profile lives at
`~/.nix-profile` for each user.

## XDG_DATA_DIRS gotcha (parked for later)

The `nix-daemon.sh` setup also exports `XDG_DATA_DIRS` including
`~/.nix-profile/share` and `/nix/var/nix/profiles/default/share`. This is
how desktop entries / icons / man pages from nix-installed apps get
picked up.

XFCE's appfinder uses XDG_DATA_DIRS, so any nix-installed `.desktop` file
should appear there as long as the user logged in *after* nix.sh became
part of login. For users already logged in pre-Nix, they need to log out
and back in (or restart their XFCE session) to pick up the new env.

## Rollback (if Nix ever needs to be uninstalled)

```sh
systemctl disable --now nix-daemon.socket nix-daemon.service
systemctl daemon-reload
rm -rf /nix /etc/nix
for i in $(seq 1 32); do userdel nixbld$i 2>/dev/null; done
groupdel nixbld
rm -rf /root/.nix-* /root/.cache/nix
rm -rf /home/bero/.nix-* /home/bero/.cache/nix
rm -f /etc/profile.d/nix.sh /etc/profile.d/nix-daemon.sh
# Restore ~/.bashrc.backup-before-nix if it exists (it didn't for us)
```

Then `git revert` the install commits in the repo.
