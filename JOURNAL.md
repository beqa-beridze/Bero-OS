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
