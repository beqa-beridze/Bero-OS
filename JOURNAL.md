# Bero-OS Journal

## 2026-05-11

Created Linux from scratch following the LFS 13.0 systemd instructions.

Booted it on a ThinkPad X230 for the first time and set up SSH for easier workflow.

Started a GitHub repo for documentation.

### BLFS batch: curl

Installed curl 8.18.0 (OpenSSL/3.6.1, HTTPS verified against kernel.org).
Built with `--without-libpsl` — libpsl is a BLFS-recommended dep, not required,
and curl's configure errors out by default when the lib is absent. Skipped to
avoid an extra recursive install. Public-suffix-list checks are off; not needed
for our use case (HTTPS API client + git transport).

### BLFS batch: vim

Replaced LFS-built vim with BLFS vim 9.2.0078 (Huge feature set, ncursesw, no GUI).
Added `/etc/vimrc` with minimal sane defaults (nocompatible, backspace=2, syntax on,
dark bg in xterm/putty). Symlinked `vi → vim` and all locale `vi.1` man pages.

### BLFS batch: git

Installed git 2.53.0 (`--with-libpcre2`, `--with-python=python3`,
`perllibdir=/usr/lib/perl5/5.42/site_perl`). HTTPS+TLS path smoke-tested against
public github.com (ls-remote returned HEAD). Seeded `/etc/gitconfig` with
`init.defaultBranch=main`, `pull.ff=only`, `push.autoSetupRemote=true` —
no user identity baked in (left for `~/.gitconfig`).

### BLFS batch: iwlwifi firmware (selective)

WiFi works. Extracted only `iwlwifi-6000g2a-6.ucode` from linux-firmware-20260410
(591 MB tarball stayed on the dev box, never touched bero-os). Installed to
`/lib/firmware/iwlwifi-6000g2a-6.ucode` — kernel asks for the bare filename at
firmware root, not under `intel/` (verified against the original dmesg failed-load
path). After `modprobe -r iwlwifi iwldvm && modprobe iwlwifi`, dmesg shows
`loaded firmware version 18.168.6.1 6000g2a-6.ucode op_mode iwldvm`; interface
`wlp3s0` came up.

Plan called for two ucode files (`-5` and `-6`); upstream removed `-5` in a prior
linux-firmware release, so `-6` only. Kernel still probes for `-5` as fallback
but accepts `-6` — no functional impact.

SHA256 of installed blob: `9c435c7f413ff2ff1320604c68beb6e8239bb93522dc4b7c02c8cc94a393d88a`

### End-of-batch state

Now installed on bero-os: curl 8.18.0, vim 9.2.0078 (Huge), git 2.53.0, iwlwifi
firmware. SSH still over Ethernet (`enp0s25`); wifi is link-up but unconfigured —
no wpa_supplicant or networkd profile for it yet. That's the next mission.
