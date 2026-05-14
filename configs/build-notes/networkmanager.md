# NetworkManager build notes

## Lesson learned (batch 5, 2026-05-14)

NetworkManager 1.56.0 has a **hard build-time dep on PyGObject** that's not
called out in the "Required" section of the BLFS NM page — it's listed as
"Recommended" under the python deps catalog, easy to miss.

The build fails ~60% through `ninja` with:

```
File "tools/generate-docs-nm-settings-docs-gir.py", line 12, in <module>
    gi.require_version("NM", "1.0")
AttributeError: module 'gi' has no attribute 'require_version'
```

That script generates `nm-property-infos-dbus.xml` and `nm-property-infos-nmcli.xml`
— the long-form settings descriptions that `nmcli connection edit` uses for its
inline help. It's not a docs-only thing (the `-D docs=false` default doesn't skip
it). It runs whenever `-D introspection=true` is on, which is the BLFS default
because libnm's GIR is needed for `nmtui` and any other introspection consumer.

## The fix

Install PyGObject 3.54.5 **before** NetworkManager. From BLFS book
(general/python-modules.html#pygobject3):

```bash
# MD5: 613245df25142059c2b1c04850e23532
# URL: https://download.gnome.org/sources/pygobject/3.54/pygobject-3.54.5.tar.gz
tar xf pygobject-3.54.5.tar.gz
cd pygobject-3.54.5
mkdir build && cd build
meson setup --prefix=/usr --buildtype=release ..
ninja
ninja install
# Verify:
python3 -c 'import gi; print(hasattr(gi, "require_version"))'   # → True
```

PyCairo is listed as "Recommended" for PyGObject. NM doesn't actually use cairo
through Python so it's safe to skip. Build still works.

## Watch out for a stale, empty `/usr/lib/python3.14/site-packages/gi/`

Some other batch-4 builds (looked at by accountsservice, maybe gobject-introspection)
can leave behind an empty `gi/` directory containing only `overrides/`. That makes
`python3 -c 'import gi'` succeed but find a namespace package with no attributes —
`gi.__file__` is `None`, `gi.require_version` doesn't exist. PyGObject's `ninja
install` won't overwrite it because meson sees the dir as already populated.

Before installing PyGObject:

```bash
rm -rf /usr/lib/python3.14/site-packages/gi
```

Then build PyGObject — it'll lay down the real `gi/__init__.py` and `_gi.so`.

## NM meson flags we use on bero-os

```
meson setup .. --prefix=/usr --buildtype=release \
  -D libaudit=no \
  -D nmtui=true \
  -D ovs=false \
  -D ppp=false \
  -D nbft=false \
  -D selinux=false \
  -D qt=false \
  -D session_tracking=systemd \
  -D nm_cloud_setup=false \
  -D modem_manager=false \
  -D firewalld_zone=false
```

Defaults that stay good:
- `crypto=nss` (NM 1.56 default; gnutls alt would cascade nettle+gmp deps)
- `docs=false`
- `introspection=true` (needed for nmtui + libnm GIR consumers)

`firewalld_zone=false` we set because firewalld isn't installed; the default
`true` would install an XML zone file into a non-existent `/usr/lib/firewalld/`
tree.

## Post-install steps

After `ninja install`:

```bash
rm -rf /usr/share/doc/NetworkManager-1.56.0
mv -v /usr/share/doc/NetworkManager /usr/share/doc/NetworkManager-1.56.0
```

## GI_TYPELIB_PATH must be in the env (not just login shells)

On bero-os, GObject Introspection typelibs are **split across two directories**:

- `/usr/lib/girepository-1.0/` — Garcon, Xfconf, libxfce4*, LightDM (xfce-installed)
- `/usr/lib64/girepository-1.0/` — GLib, Gio, Atk, AccountsService, the GTK base (everything that's lib64-installed)

`libgirepository` was compiled with a default search path that only includes
`/usr/lib/girepository-1.0` (NOT lib64). So when NM's
`generate-docs-nm-settings-docs-gir.py` does `from gi.repository import Gio`,
it can't find `Gio-2.0.typelib` unless `GI_TYPELIB_PATH` is set.

`/etc/profile.d/pkg-config-lib64.sh` exports it correctly:

```sh
GI_TYPELIB_PATH=${GI_TYPELIB_PATH:+$GI_TYPELIB_PATH:}/usr/lib64/girepository-1.0:/usr/lib/girepository-1.0
export PKG_CONFIG_PATH GI_TYPELIB_PATH
```

But that only runs in **login shells**. `ssh user@host 'cmd'` runs `cmd` in
a non-login non-interactive shell, no profile sourcing. Inside that, ninja
spawns Python scripts in even more sanitized child envs. The Python script
fails:

```
ImportError: Typelib file for namespace 'Gio', version '2.0' not found
```

Fix: prefix the SSH command with an explicit export.

```bash
ssh root@host 'set -e
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig
export GI_TYPELIB_PATH=/usr/lib64/girepository-1.0:/usr/lib/girepository-1.0
...'
```

This applies to **any** future build that runs introspection-using Python
scripts during compile (NM, accountsservice doc-gen if re-enabled, anything
similar). Set both env vars at the top of the SSH command.

A more durable fix would be to merge the two typelib dirs (symlinks) or
write the env var to `/etc/environment`, but bero-os hasn't needed it
outside build time so far.

## docbook-xml + docbook-xsl-nons must be installed (for man pages)

NM 1.56 has `option('man', type: 'boolean', value: true, ...)` — man pages
build by default. The `man/` xsltproc commands use `--nonet` and reference
`http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl`
plus the DocBook 4.5 DTD. Both must resolve via the local XML catalog or
the build fails at ~957/970 with:

```
I/O error : failed to load "http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl": Attempt to load network entity
```

Install both packages **before** NM:

- **docbook-xml-4.5** (~96 KB, BLFS PST chapter) — MD5
  `03083e288e87a7e829e437358da7ef9e` from
  `https://archive.docbook.org/xml/4.5/docbook-xml-4.5.zip`. The `.zip`
  format means you need `unzip` OR use `python3 -m zipfile -e file.zip dir/`
  (bero-os doesn't have unzip).
- **docbook-xsl-nons-1.79.2** (~22 MB) — MD5
  `2666d1488d6ced1551d15f31d7ed8c38` from
  `https://github.com/docbook/xslt10-stylesheets/releases/download/release/1.79.2/docbook-xsl-nons-1.79.2.tar.bz2`.
  Apply patch `docbook-xsl-nons-1.79.2-stack_fix-1.patch` first.

Both packages just `cp` files into `/usr/share/xml/docbook/...` — there's
no autotools/meson build. The catalog wiring is what makes them work.

After install, populate `/etc/xml/catalog` per BLFS docbook + docbook-xsl
pages. Critical entry for NM specifically:

```bash
for uri in http{,s}://cdn.docbook.org/release/xsl-nons/{1.79.2,current} \
           http://docbook.sourceforge.net/release/xsl/current; do
  for rewrite in System URI; do
    xmlcatalog --noout --add "rewrite$rewrite" \
      "$uri" \
      "/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2" \
      /etc/xml/catalog
  done
done
```

The last URI (`http://docbook.sourceforge.net/release/xsl/current`) is the
old one NM's man XML files reference — needed despite being officially
deprecated upstream.

Verify by resolving:
```bash
xmlcatalog /etc/xml/catalog "http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl"
# → /usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/manpages/docbook.xsl
```

Once both are in place, NM's build picks up cleanly. The build dir from a
previous failed attempt **can be resumed** — ninja re-runs only the failed
xsltproc steps.

## Python-3 shebang fix

NM source has a few python scripts with `#!.../python` (no `3`). bero-os has
no `python` symlink — only `python3`. Apply before configure:

```bash
fixed=$(grep -rl "^#!.*python$" . 2>/dev/null)
[ -n "$fixed" ] && echo "$fixed" | xargs sed -i "1s/python/&3/"
```

## Misc gotcha — kernel netfilter

bero-os kernel has only `CONFIG_NETFILTER=y`. No `NF_TABLES`, no `IP_NF_*`,
no `IP_TABLES`. `iptables` userspace builds and installs fine; at runtime
`iptables -L` errors with "Table does not exist" because the `ip_tables`
kernel module is missing. **NM doesn't care for pure client mode** (wifi/eth
→ router → internet). The firewalld_zone=false flag avoids the only NM path
that would expect firewall rules to actually apply. If shared-connection /
hotspot mode is ever needed, the kernel needs a rebuild first.
