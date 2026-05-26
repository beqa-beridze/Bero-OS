# librsvg pixbuf-loader build notes

## Lesson learned (2026-05-26)

**librsvg 2.61.4 ships with the gdk-pixbuf SVG loader DISABLED by default.**
This silently broke every SVG-based icon theme on bero-os from batch 4
onwards. Took ~3 hours of "why isn't this theme applying" thrash to find.

## Symptom

ANY GTK app falls back to its built-in 16x16 PNGs for "folder" and most
icons, regardless of which icon theme is set in xfconf. Concrete:

- `xfconf-query -c xsettings -p /Net/IconThemeName` correctly reports
  whatever theme you set (Adwaita, Tela, Papirus-Dark, etc.)
- The icon files are physically on disk
- The `icon-theme.cache` is fresh
- But Thunar, the panel, dialogs all show the same stock GTK icons

The fingerprint: `Gtk.IconTheme.lookup_icon('folder', 48, 0)` returns
`/org/gtk/libgtk/icons/16x16/actions/folder.png` (the GResource fallback
embedded in libgtk.so itself). With `Gtk.IconLookupFlags.FORCE_SVG`,
GTK correctly resolves to the theme's actual SVG file — proving the
files exist but the default path is rejecting them.

`gdk-pixbuf-query-loaders` shows NO entry for SVG. Direct load:

```
GdkPixbuf.Pixbuf.new_from_file('/usr/share/icons/Papirus-Dark/48x48/places/folder-red.svg')
# → gdk-pixbuf-error-quark: Couldn’t recognize the image file format
```

## Root cause

`/sources/librsvg-2.61.4/meson_options.txt`:

```
option('pixbuf-loader',
       type: 'feature',
       value: 'disabled',
       yield: true,
       description: 'Build the GDK-Pixbuf SVG loader (requires gdk-pixbuf-query-loaders)')
```

`disabled` by default. Batch 4 used the BLFS librsvg default options, so
the `libpixbufloader-svg.so` module never got built. Without that module
in `/usr/lib64/gdk-pixbuf-2.0/2.10.0/loaders/`, gdk-pixbuf cannot read SVG
files. Every modern Linux icon theme (Adwaita, Papirus, Tela, etc.) is
predominantly SVG. So everything fell back to the GResource PNGs.

## Fix — rebuild with the flag explicitly enabled

```sh
cd /sources/librsvg-2.61.4
export PATH=/opt/rustc/bin:$PATH
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/lib/pkgconfig
meson setup build --prefix=/usr --libdir=lib --buildtype=release \
    -D pixbuf-loader=enabled \
    -D introspection=enabled \
    -D docs=disabled \
    -D vala=disabled \
    -D tests=false
ninja -C build              # ~2-3 min (Rust compile)
sudo ninja -C build install # also runs the install script that drops
                            # libpixbufloader_svg.so into gdk-pixbuf's
                            # loaders/ dir and updates loaders.cache
```

Confirm:

```sh
gdk-pixbuf-query-loaders | grep -i svg
# "/usr/lib64/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader_svg.so"
# "svg" 6 "gdk-pixbuf" "Scalable Vector Graphics" "LGPL"
# "image/svg+xml" "image/svg" ... ""
```

Loader filename uses an UNDERSCORE (`libpixbufloader_svg.so`), not a dash
like the other loaders. Don't grep for `libpixbufloader-svg.so` and panic
that it's missing.

## Rule for future kernel/library work

**Any time librsvg gets touched** (rebuild, upgrade, refactor) — verify
`-D pixbuf-loader=enabled` is in the meson command, and verify
`gdk-pixbuf-query-loaders | grep svg` returns the loader after install.

## Reference

- [librsvg meson_options.txt source](https://gitlab.gnome.org/GNOME/librsvg/-/blob/main/meson_options.txt)
- Related memory: [[librsvg-pixbuf-loader-must-be-enabled]]
- Same pattern as the HDA codec y/m mismatch — silent CONFIG default that
  silently breaks something downstream. See `kernel-audio.md`.
