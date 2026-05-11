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
