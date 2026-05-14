# xfce4-terminal build notes

## Lesson learned (batch 6, 2026-05-14)

Skipped during batch 4 because xsltproc tried to fetch docbook XSL over the
network (man page generation, same family of bug as gtk3/libsecret/NM).

Resolved as a side effect of batch 5: we installed docbook-xml-4.5 +
docbook-xsl-nons-1.79.2 + populated /etc/xml/catalog for the NetworkManager
build. xfce4-terminal benefits for free — no special flags needed, no
`-D man=false` workaround.

## Build

```bash
cd /sources
wget https://archive.xfce.org/src/apps/xfce4-terminal/1.1/xfce4-terminal-1.1.5.tar.xz
# MD5: d779b64ead82330b6bbc7d500f542490
tar xf xfce4-terminal-1.1.5.tar.xz
cd xfce4-terminal-1.1.5
mkdir build && cd build
meson setup .. --prefix=/usr --buildtype=release
ninja
ninja install
```

Required deps (already installed by batch 4): libxfce4ui-4.20.2, vte-0.82.3.

**Note**: BLFS book uses `.tar.xz`. Earlier batch-4 plan note said `.tar.bz2`
— wrong; upstream archive.xfce.org serves `.xz` only.

## Brand-kit terminalrc

The Workshop palette goes in `/root/.config/xfce4/terminal/terminalrc`. See
`configs/root/.config/xfce4/terminal/terminalrc` in the repo.
