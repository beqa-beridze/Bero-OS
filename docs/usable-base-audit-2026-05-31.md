> This audit was produced on 2026-05-31 by running checks on the live box and comparing against the BLFS 13.0 systemd book, with Claude Code doing the legwork and a second pass re-verifying anything that looked wrong. Nothing was changed on the machine during it. I keep it in the repo because it is the most honest map of what the system is and is not.

# What's actually on bero-os: a usable-base audit against the BLFS book

Date: 2026-05-31. This is a verification pass, not a fixing pass. Nothing on the
machine was changed. Every line below was checked live on the box and compared to
the BLFS 13.0 systemd-edition book that lives in `context/`. Where the first check
looked wrong, a second independent agent re-ran it with different commands, so the
verdicts here are the reconciled ones.

The point of this file is to teach you your own system: what each piece is for,
what the book says it should look like, what is really there, and what the gap is.
Fixes are proposed, not applied.

A note on method, because it matters for trust: a few of the first-pass findings
were wrong and the recheck caught them. The CPU-frequency setup looked broken but
is actually fine. The p11-kit trust path looked missing but was just read from the
wrong file. GnuPG looked merely misconfigured but is actually a do-nothing stub.
So treat single greps with suspicion; the live behaviour is the truth.

The two biggest surprises up front, because they contradict what we assumed going
in:

1. The desktop is not rendering in Noto. Generic "sans-serif" and "serif" both
   fall back to Luxi, a legacy X11 font, because no proportional Noto Sans or Noto
   Serif (and no DejaVu, no Liberation) was ever installed. Only the monospace
   slot is Noto. The whole XFCE UI is Luxi Sans.
2. The graphical session is not a logind session. `loginctl` reports no sessions,
   there is no `/run/user/1000`, and `user@1000.service` is dead. The reason is
   that `pam_systemd.so` exists only inside the Nix store, not in PAM's real
   module directory, so the one PAM line that would register the session silently
   does nothing.

Both are explained in full below.

---

## Fonts

What it is for. Three layers do the work. FreeType rasterises glyphs (turns font
outlines into pixels). HarfBuzz shapes text (decides which glyphs and where, for
ligatures and complex scripts). Fontconfig picks which font answers a request like
"sans-serif" or "Arial". On top of that you need actual font files installed, or
the generic names resolve to whatever ancient fallback happens to exist.

What BLFS expects. FreeType 2.14, HarfBuzz 12, Fontconfig 2.17, plus enough font
families that "sans-serif", "serif" and "monospace" all resolve to a modern face,
emoji and symbols resolve to a real emoji font, and the MS metric names (Arial,
Times New Roman, Courier New) map to Liberation so documents keep their layout.
Since Fontconfig 2.14 the book expects Noto to win the generic aliases ahead of
DejaVu.

What is on your box. The engine is in excellent shape: FreeType 2.14.1 with
subpixel rendering compiled in, HarfBuzz 12.3.2 with all its sub-libraries,
Fontconfig 2.17.1 with all nine tools, a complete and correct `/etc/fonts/conf.d`
(including a smart `70-no-bitmaps-except-emoji.conf` that rejects bitmap fonts but
still lets the colour-emoji font through), font directories at the right
permissions, and a healthy cache. Emoji resolves correctly to Noto Color Emoji,
and monospace resolves to Noto Sans Mono. That part is genuinely good.

The gap. The font inventory is thin (49 faces) and missing the most important
piece: there is no proportional Noto Sans or Noto Serif, no DejaVu, and no
Liberation. So:

- `fc-match sans-serif` returns Luxi Sans, `fc-match serif` returns Luxi Serif.
  Luxi is a 1990s X11 font. Your entire desktop UI (XFCE is set to "Sans 10") is
  therefore drawn in Luxi Sans.
- Arial resolves to Luxi Sans, Times New Roman to Luxi Serif, Courier New to the
  old Type1 Courier. The `30-metric-aliases.conf` rule is installed and linked,
  but it has no Liberation target to point at, so MS-font documents reflow instead
  of keeping their metrics.
- CJK (Chinese, Japanese, Korean) is entirely absent, so that text would be
  tofu boxes. Optional families (Source Code Pro, FreeFont, Carlito/Caladea/
  Gelasio) are also absent. These are nice-to-haves, not defects.

There is also a cosmetic point. XFCE has `Xft/HintStyle=hintnone` and
`Xft/RGBA=none`, which turn off hinting and LCD subpixel smoothing even though the
engine supports both and a `10-hinting-slight.conf` is linked. On the X230's panel,
`hintslight` plus `rgb` usually looks sharper. This is a preference, not breakage.

Proposed fix. Install a modern proportional family. The cleanest single move that
fixes both the UI font and the MS aliases is to install Liberation (Sans, Serif,
Mono) and a proportional Noto Sans plus Noto Serif into `/usr/share/fonts`, then
rebuild the cache. Once present, the existing fontconfig rules make sans-serif and
serif resolve to Noto and Arial/Times/Courier map to Liberation automatically. The
hinting and subpixel settings can be changed later with `xfconf-query` if you want
sharper text. CJK only if you ever read CJK content. Graphite2 in HarfBuzz is
genuinely optional and not worth a rebuild.

---

## Desktop integration

What it is for. This is the freedesktop glue that makes "open this file with the
right app" and "click this link" work. `shared-mime-info` is the database that
decides what a file *is*. `desktop-file-utils` builds the cache that maps a file
type to the apps that can open it. `xdg-utils` provides `xdg-open` (the dispatcher
apps call to launch a handler) and `xdg-mime`/`xdg-settings` (query and set
defaults). `xdg-user-dirs` manages the Desktop/Downloads/Documents folders.
Underneath, the icon themes and the SVG loader make icons actually appear.

What BLFS expects. All of the above installed, with the post-install cache steps
run: `update-mime-database` (built in via `-D update-mimedb=true`),
`update-desktop-database` to produce `mimeinfo.cache`, and per-theme icon caches.

What is on your box. The rendering and MIME-database layer is healthy. The MIME
database is compiled (`/usr/share/mime/mime.cache` is 158 KB and includes the
systemd MIME definitions, which proves the build flag was set). The hicolor
fallback icon theme and the Adwaita theme are both present with their caches, and
the librsvg SVG pixbuf loader is correctly registered, so SVG icons render. That
last one is the footgun we have hit before, and here it is fine.

The gap. The freedesktop command-line layer is simply not installed:

- `xdg-utils` is absent. None of the eight `xdg-*` tools exist on the system PATH.
  (There is a copy inside the Claude Code Nix store, but that is part of this tool,
  not your system, and it is not on PATH.) Anything that shells out to `xdg-open`
  to open a link or a file has no handler. XFCE's own `exo-open` and `gio` partly
  cover this for XFCE-native apps, but the standard mechanism is missing.
- `desktop-file-utils` is absent, and as a direct consequence
  `/usr/share/applications/mimeinfo.cache` does not exist. You have 39 `.desktop`
  launchers installed but never indexed, so MIME-type-to-app resolution through
  that cache does not work.
- `xdg-user-dirs` is absent, along with its `/etc/xdg/user-dirs.*` config and the
  per-user `~/.config/user-dirs.dirs`. Low impact on a single-user English desktop,
  but it is a real gap.
- `icon-naming-utils` is absent, but that is only a build-time helper for old icon
  themes and does not matter on a spec-compliant Adwaita/hicolor setup.

Proposed fix. Install `xdg-utils`, `desktop-file-utils`, and `xdg-user-dirs` from
the book (all small, standard builds), then run
`update-desktop-database /usr/share/applications` once to generate `mimeinfo.cache`.
This is low risk.

---

## Filesystems and removable media

What it is for. A laptop meets USB sticks, SD cards, and phones. FAT and exFAT are
the usual formats for flash media, NTFS for Windows drives. FUSE is the kernel
mechanism that lets userspace drivers (ntfs-3g, sshfs, MTP for phones, AppImages,
some gvfs backends) mount things. `dosfstools` formats and repairs FAT volumes.
`smartmontools` reads the SMART health data off the internal disk so you get
warned before it dies.

What BLFS expects. Kernel support for VFAT, exFAT and (preferably) the in-kernel
NTFS3 driver, plus FUSE. Userspace `dosfstools`, optionally `ntfs-3g`, and
`smartmontools` with its `smartd` service enabled.

What is on your box. The FAT stack is complete and correct in the kernel:
`VFAT_FS=y`, `FAT_FS=y`, codepage 437, utf8 default, the iso8859-1 and utf8
charsets. So the kernel can mount a normal FAT USB stick.

The gap. Almost everything else in this area is absent on both sides:

- `dosfstools` is not installed. The kernel can mount a FAT volume but you have no
  tool to format or fsck one. The EFI System Partition is itself FAT, so you cannot
  repair it either.
- FUSE is off in the kernel (`# CONFIG_FUSE_FS is not set`) and the `fuse3`
  userspace is not installed. This is the root cause of a chain: no FUSE means no
  ntfs-3g, no sshfs, no MTP phone mounting, no AppImages, no gvfs FUSE backends.
- NTFS has no support at all. The in-kernel NTFS3 and legacy NTFS drivers are both
  off, and `ntfs-3g` is not installed. A Windows-formatted USB drive will not mount.
- exFAT is off in the kernel (`# CONFIG_EXFAT_FS is not set`). Most large (over
  32 GB) USB sticks and SD cards ship exFAT and will not mount.
- `smartmontools` is entirely absent, so there is no disk-health monitoring on the
  laptop's SSD.

Proposed fix. Two parts. The kernel part (one rebuild): enable `FUSE_FS=m`,
`NTFS3_FS=m` and `NTFS_FS`, and `EXFAT_FS=m`. Enabling NTFS3 in the kernel is the
clean way to get NTFS because it avoids the whole FUSE-plus-ntfs-3g chain. The
userspace part: install `dosfstools` (with `--enable-compat-symlinks` so `mkfs.vfat`
and friends exist) and `smartmontools` (then enable `smartd.service`). Install
`fuse3` only if you actually want sshfs/MTP/AppImages; if all you care about is
NTFS, the kernel NTFS3 driver alone is enough.

---

## Power management

What it is for. On a laptop you want the battery readout in the panel, the lid to
suspend the machine, and the CPU to scale down to save power. The book's preferred
modern stack is power-profiles-daemon (the profile switcher), UPower (battery
state), and systemd-logind (handles the lid by default).

What BLFS expects on a systemd box. power-profiles-daemon installed and enabled,
UPower present, logind handling the lid, and both acpid and pm-utils absent because
systemd already does their jobs and they can conflict.

What is on your box. The power stack here is built differently from the book, on
purpose, and it works. power-profiles-daemon is not installed at all. Instead the
box uses acpid plus UPower plus xfce4-power-manager:

- UPower 1.91.1 is healthy and live on the system bus. It sees BAT0 and the AC
  line, so the panel battery readout works.
- The lid is handled by acpid, not logind, and the two are correctly coordinated.
  `acpid.service` is enabled and running. `/etc/acpi/events/lid` calls
  `/etc/acpi/lid.sh`, which runs `systemctl suspend` when the lid closes, and
  `/etc/systemd/logind.conf.d/acpi.conf` sets `HandleLidSwitch=ignore` so logind
  does not also try to suspend. This is a complete, consistent chain, not a
  half-finished leftover.
- pm-utils is correctly absent; suspend and hibernate are provided by systemd's
  own targets.
- CPU frequency scaling works. The driver is `intel_cpufreq` (intel_pstate in
  passive mode) with the `schedutil` governor. This is fine and modern. (The first
  pass flagged it as broken because the old `powersave` governor is not compiled
  in, but that governor is irrelevant here; the recheck confirmed scaling is fully
  working.)

So power-profiles-daemon being absent is a design choice, not a defect. Worth
knowing: even if it were installed, on this Ivy Bridge X230 with `intel_cpufreq`
its CPU control would be largely cosmetic anyway.

The gap. Two real ones, both kernel-side, plus one inert feature:

- `THINKPAD_ACPI` is not built (the config has `# CONFIG_THINKPAD_ACPI is not
  set`). On a ThinkPad this is what gives you the Fn-key hotkeys, the battery
  charge thresholds (conservation mode), fan control, and the firmware power
  profiles. Without it you lose all of that ThinkPad-specific behaviour.
- The `powersave` cpufreq governor is not compiled in. Minor on a schedutil box.
- Hibernation is compiled in (`HIBERNATION=y`) but cannot actually work: there is
  no `resume=` on the kernel command line pointing at the swap partition, so the
  kernel could write a hibernate image but never resume it. Suspend-to-RAM (the lid
  action you actually use) works fine; only hibernate is dead.

Proposed fix. Fold `THINKPAD_ACPI=m` and `CPU_FREQ_GOV_POWERSAVE` into the same
kernel rebuild as the filesystem options. If you ever want hibernate, add
`resume=PARTUUID=...` (pointing at the existing 4 GB swap partition) to the
bootloader command line. None of this is urgent; suspend and battery already work.

---

## Security base

This is the area with the most real gaps, so read it carefully. Some of it is
deliberate single-user convenience, some of it is genuinely exposed.

What is in good shape. The certificate and authentication plumbing is solid:

- The system CA store is built. `make-ca` is installed, `ca-bundle.crt` has 121
  trusted roots, and the `update-pki.timer` is enabled to refresh it weekly. p11-kit
  and `trust` work, and `update-ca-certificates` is wired up. (The trust path
  `/etc/pki/anchors` is compiled into the trust module, not the core library; the
  first pass grepped the wrong file and falsely flagged it, the recheck confirmed
  it is fine.) So HTTPS in curl, git and browsers can validate certificates.
- Linux-PAM core is correctly installed: the libraries, the standard module set
  (pam_unix, pam_access, pam_limits, pam_env, pam_faillock and more), and a proper
  fail-closed `/etc/pam.d/other` (pam_warn then pam_deny). sudo 1.9.17p2 is present
  and setuid-root with a `%wheel` rule, and bero is in wheel. OpenSSH 10.2p1 is
  installed and running with correctly-permissioned host keys.

The gaps, roughly in order of how much they matter.

1. GnuPG is a stub, not a program. `/usr/bin/gpg` is a symlink to `gpg2`, which is
   a four-line shell script that prints "gpg (stub for Bero-OS XFCE batch)" and
   exits 0. There is no real gpg, no gpg-agent, no gpgv, no dirmngr, and no
   pinentry. The dangerous part is the `exit 0`: anything that runs `gpg --verify`
   on a signature gets a success exit code regardless of whether the signature is
   valid. Any script that trusts a gpg check is being silently lied to. This was
   clearly a deliberate batch placeholder, but it is a real risk while it stands.

2. There is no firewall of any kind, and the kernel cannot host one. The iptables
   userspace tools are installed (v1.8.12), but there is no firewall script, no
   `iptables.service`, and `iptables -L` fails outright with "Table does not exist"
   because the kernel was built without `IP_NF_FILTER` (the filter table) and
   without the `ip_tables` module. nftables is not installed either, and
   `NF_TABLES` is off. So the machine is wide open on every port that something is
   listening on, which matters because sshd is listening (see next point) on a
   laptop whose IP rotates on Wi-Fi DHCP.

3. sshd allows remote root login with a password. The effective config (read with
   `sshd -T`) shows `PermitRootLogin yes` and `PasswordAuthentication yes`, and
   `UsePAM` is off with no `/etc/pam.d/sshd`. This is why root/root works over SSH.
   On a network-facing box with no firewall, this is the most exposed item.

4. The password-quality chain does not exist. CrackLib, libpwquality and
   pam_pwquality are all absent. `/etc/pam.d/system-password` is a bare
   `pam_unix.so sha512` line, which also contradicts `/etc/login.defs` (which says
   `ENCRYPT_METHOD YESCRYPT`): PAM-driven password changes would hash as SHA-512,
   not yescrypt, and with no strength check at all.

5. Shadow was not built against PAM. Proven by `ldd /usr/bin/passwd` showing no
   libpam, and by the absence of per-program PAM files (no `/etc/pam.d/login`,
   `passwd`, `su`, and so on). So passwd/login/su use their own crypt path (which
   does honour yescrypt via libcrypt). It works, but it is not the book's
   PAM-integrated Shadow, and the system-auth stack is a single bare `pam_unix`
   line with none of the pam_env / pam_limits / pam_access modules wired in (they
   are installed but never invoked, so `/etc/security/limits.conf` and friends are
   inert).

6. Polkit's GUI authentication is non-functional. polkitd runs and is logind-aware
   (linked to libsystemd), but it was built without PAM and there is no
   `/etc/pam.d/polkit-1`, so any polkit auth conversation falls through to
   `other` = pam_deny and fails closed. On top of that, the polkit-gnome agent
   binary is installed but has no autostart `.desktop`, so it never launches in the
   XFCE session. Between the two, graphical privilege prompts (mounting a disk,
   NetworkManager admin actions) have no working auth path.

7. `unix_chkpwd` is not setuid. It is mode 0755, where the book installs it setuid
   root (4755). This helper is what lets a non-root process (a screen locker, for
   example) verify the user's password against `/etc/shadow`. Without the setuid
   bit, non-root password checks can fail. Impact is limited here because the
   lightdm daemon runs as root (so greeter logins are fine) and bero's sudo never
   prompts, but a screen-unlock-by-password path could be affected. Cheap to fix.

8. bero has passwordless root. `/etc/sudoers.d/00-bero-nopasswd` contains
   `bero ALL=(ALL) NOPASSWD: ALL`. The sudo mechanics are otherwise correct; this
   is a deliberate convenience, but it means any process running as bero can become
   root with no prompt. Combined with points 1 to 3, it widens the blast radius.
   Worth a conscious decision rather than leaving it by accident.

The kernel `CONFIG_AUDIT` option (needed for pam_loginuid) is present and fine.

Proposed fix. This is the "security pass" batch, best done together because the
pieces depend on each other and several touch PAM at once:

- Replace the gpg stub with real GnuPG plus pinentry.
- Install CrackLib and libpwquality, wire `pam_pwquality` into
  `/etc/pam.d/system-password`, and change that line from `sha512` to `yescrypt` so
  it agrees with login.defs.
- Rebuild Shadow `--with-libpam` to get the per-program PAM files, and flesh out
  system-auth/session with pam_env and pam_limits.
- Rebuild polkit with PAM, add `/etc/pam.d/polkit-1`, and add a polkit-gnome
  autostart `.desktop`.
- `chmod 4755 /usr/sbin/unix_chkpwd`.
- Decide on the firewall: it needs the kernel `IP_NF_FILTER` rebuild first, then
  the book's personal-firewall script at `/etc/systemd/scripts/iptables` plus
  `iptables.service`.
- Decide on sshd: `PermitRootLogin no`, `UsePAM yes`, add `/etc/pam.d/sshd`. This
  one needs coordination because it would end the root-over-SSH workflow, so do it
  deliberately, ideally after a non-root key login is confirmed working.
- Decide consciously whether to keep bero's NOPASSWD sudo.

---

## System hygiene: shell, logging, scheduling, boot

What is in good shape. A lot of this is custom rather than stock BLFS, and the
custom version is fine. The box has its own profile scheme: `/etc/profile` sources
`/etc/profile.d/*.sh`, where a bero-specific set (`00-path.sh`, `bero-shell.sh`,
`bero-prompt.sh`, and so on) carries the PATH, the coloured `ls` aliases, the
prompt, and the history settings. The stock BLFS filenames (extrapaths.sh,
readline.sh, umask.sh, i18n.sh) are absent, but their jobs are done elsewhere
(PATH in 00-path.sh, locale in /etc/profile itself, readline in /etc/inputrc, umask
via login.defs). So those "missing" files are by design, not regressions. Also
healthy and correct: `/etc/inputrc`, `/etc/vimrc` (and vim 9.2 reads it),
`/etc/shells`, `/etc/skel`, `/etc/default/useradd`, and the user dotfiles.

Logging is fine. The systemd journal is persistent: `/var/log/journal` exists and
holds 88 MB, so logs survive reboots. logrotate is not installed, but on a
journald system the book does not require it, so that is acceptable rather than a
defect (it would only matter if you later run a daemon that writes plain-text
`/var/log/*.log` files).

Scheduling is fine. There is no cron daemon, but systemd timers cover periodic
work (tmpfiles cleanup and the weekly CA-cert update are both active). That is the
systemd way.

Boot is fine. No initramfs is needed and none exists, which is correct: root is
specified by PARTUUID, which the kernel resolves directly, and root is not on LVM,
LUKS or RAID, so there is nothing for an initramfs to do. cpio is absent, which is
expected since you do not build one.

The gaps.

1. The big one: the graphical session is not registered with logind. This is the
   second headline surprise. `loginctl list-sessions` says "No sessions",
   `/run/user/1000` does not exist, and `user@1000.service` is dead. The
   xfce4-session process runs under `system.slice/lightdm.service` instead of a
   per-user session scope, and it has no `XDG_RUNTIME_DIR` or `XDG_SESSION_ID`. The
   cause is that `pam_systemd.so` is not in PAM's module directory at all. It
   exists only inside the Nix store (`/nix/store/...-systemd-260.1/lib/security/`),
   not in `/lib/security` or `/usr/lib/security` where PAM looks. The lightdm PAM
   files do reference it, but as `session optional pam_systemd.so`, and "optional"
   means a module that cannot be loaded is silently skipped. So login never
   registers a systemd session.

   Why it has not obviously broken things: XFCE, dbus-launch and lightdm provide
   fallbacks, and audio is reported working, probably via one of those fallback
   paths. But anything that genuinely depends on `XDG_RUNTIME_DIR` (pipewire and
   wireplumber socket placement, the dbus user bus, some portals), on logind seat
   ACLs (brightness or device access), or on screen-idle and lock behaviour, is on
   shaky ground. This is a real deviation from how a systemd-edition desktop is
   supposed to run.

   This finding is surprising enough that I want to be honest about confidence: two
   independent checks agree (the module is absent from all four standard security
   directories, and the live session state confirms no logind session), so I am
   fairly confident it is real. But the fix needs care. Symlinking the Nix-store
   module into `/lib/security` risks an ABI mismatch with the installed libpam, so
   the safer fix is to install the LFS systemd build's own `pam_systemd.so` into the
   module directory, add `session optional pam_systemd.so` to
   `/etc/pam.d/system-session`, and create `/etc/pam.d/systemd-user`. Confirm where
   PAM's module directory really is and that the module matches libpam before
   touching it.

2. `/etc/systemd/user-environment-generators/50-profile.sh` is missing. Its job is
   to feed the `/etc/profile.d` environment into the per-user systemd manager. It
   is moot right now because the user manager (`user@1000.service`) is not even
   running, but it becomes relevant once the logind session is fixed. Cheap to add.

3. `GPG_TTY` is not exported anywhere. If you ever use gpg with a terminal pinentry
   (signing a git commit in a plain shell, for instance), it needs `GPG_TTY=$(tty)`
   to find the controlling terminal. One line in `bero-shell.sh` fixes it. Also moot
   until real gpg is installed.

4. `which` is not on the system PATH. GNU which exists, but only inside the Nix
   store, not as `/usr/bin/which`, and there is no shell-function fallback. Most
   modern scripts use the bash builtins `type` or `command -v`, but some legacy or
   third-party scripts call `which` and will fail. A symlink or a tiny wrapper
   fixes it.

Proposed fix. The logind item belongs in the same careful PAM batch as the security
work, since it is a PAM-module problem and touches the same files. The other three
(50-profile.sh, GPG_TTY, which) are cheap config-only additions.

---

## How I would sequence the fixes

Grouped by risk, lightest first. Nothing here has been done.

Cheap and safe (config only or small standard package installs, easily reversible):

- Fonts: install Liberation plus proportional Noto Sans and Noto Serif, rebuild the
  cache. This fixes the Luxi UI font and the MS metric aliases in one step.
- Desktop integration: install xdg-utils, desktop-file-utils, xdg-user-dirs, then
  run update-desktop-database once.
- which: symlink or wrapper onto the PATH.
- GPG_TTY export, and the 50-profile.sh user-environment generator.
- unix_chkpwd setuid (chmod 4755).
- Optionally set Xft hinting to slight and RGBA to rgb for sharper text.
- Optionally install dosfstools and smartmontools (small, no rebuild).

Security and PAM pass (do as one coordinated batch, several pieces interlock):

- Real GnuPG plus pinentry, replacing the stub.
- CrackLib plus libpwquality, wired into system-password, sha512 changed to
  yescrypt.
- Shadow rebuilt against PAM, plus fleshing out the system-auth and system-session
  stacks.
- polkit rebuilt with PAM, its PAM file added, and the polkit-gnome agent
  autostarted.
- The pam_systemd / logind session fix (verify the module ABI first).
- sshd hardening (PermitRootLogin no, UsePAM yes), done deliberately after key
  login is confirmed.
- A conscious decision on bero's NOPASSWD sudo.

Kernel rebuild (batch all of these into one rebuild and one reboot):

- FUSE_FS, NTFS3_FS and NTFS_FS, EXFAT_FS for removable media.
- IP_NF_FILTER (and the reject target, and NETFILTER_ADVANCED) so a firewall can
  exist at all, which is the prerequisite for the firewall part of the security
  pass.
- THINKPAD_ACPI for the ThinkPad hotkeys, battery thresholds and fan control.
- CPU_FREQ_GOV_POWERSAVE if you want that governor back.

Out of scope for this audit, noted in one line each so they are not lost: servers,
databases, printing, multimedia codecs, Bluetooth, and the KDE/GNOME stacks were
not checked. Hibernate (the resume= command-line addition) is optional and only
matters if you decide you want it; suspend already works.
