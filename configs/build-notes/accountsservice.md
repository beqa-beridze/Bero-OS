# accountsservice (BLFS sysutils)

`accountsservice-23.13.9` provides `accounts-daemon` (D-Bus interface for
user account info, used by LightDM / GNOME-style display managers) plus
`libaccountsservice` (the client library).

## What's broken in a clean BLFS build

The `tests/` subdir hard-requires two Python modules:

- `gi` (PyGObject — large stack including glib introspection bindings)
- `dbusmock` (python3-dbusmock)

Both were absent in batch 4, and pulling them in would have dragged
PyGObject (which itself wants `pycairo`, `gobject-introspection` already
present, plus a bunch of test infrastructure).

BLFS's documented workaround handles a different sub-case — `dbusmock`
present but with a path conflict — and still needs both modules
installed. It doesn't help when you don't have them at all.

## What we did

Patched out the `tests/` subdir entirely. One-line edit to top-level
`meson.build`:

```diff
-subdir('tests')
+# subdir('tests')  # Bero-OS: tests need pygobject + python-dbusmock
```

Full patch is at `configs/patches/accountsservice-23.13.9-skip-tests-subdir.patch`.

## Re-applying on rebuild

```
cd /sources
tar xf accountsservice-23.13.9.tar.xz
cd accountsservice-23.13.9
patch -p1 < /home/bero/Bero-OS/configs/patches/accountsservice-23.13.9-skip-tests-subdir.patch
mkdir build && cd build
meson setup .. --prefix=/usr --buildtype=release -D admin_group=adm
ninja && sudo ninja install
```

## What this loses

- `ninja test` runs zero tests for accountsservice. Nothing self-checks
  the daemon at build time.
- No runtime impact. `accounts-daemon` + `libaccountsservice` build and
  link normally; LightDM's UserList already uses them in production.

## When to revisit

If you ever bring `python3-dbusmock` and `PyGObject` into the box
(triggered by some other package needing introspected-Python), drop
this patch and use the BLFS-documented `mv` + `sed` flow instead.
Tests will then run and catch regressions on the next build.

## Verification of current build

```
$ /usr/libexec/accounts-daemon --version 2>&1 || true
$ ls /usr/lib*/libaccountsservice.so.0
/usr/lib64/libaccountsservice.so.0
```

Daemon binary present; client library installed under `/usr/lib64/`
(per the lib64 quirk — see `configs/etc/profile.d/pkg-config-lib64.sh`).
