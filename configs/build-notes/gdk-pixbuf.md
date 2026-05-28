# gdk-pixbuf build flags

## Lesson learned (2026-05-13)

GTK's image format support comes from **gdk-pixbuf MODULES**, not from system libs at runtime. If you build gdk-pixbuf with `-D png=disabled`, GTK cannot load PNG images **even if** libpng is installed system-wide. The same goes for `-D jpeg=disabled`, `-D gif=disabled`, `-D tiff=disabled`.

This bit us hard during the XFCE batch: gdk-pixbuf was first built with all loaders disabled (the wrong assumption was that gdk would use system libs). Result: the lightdm GTK greeter crashed on `Gtk:ERROR:.../gtkiconhelper.c:495:ensure_surface_for_gicon` because it couldn't load `image-missing.png`.

## The right flags

```
meson setup .. --prefix=/usr --libdir=lib64 --buildtype=release \
  -D png=enabled \
  -D gif=enabled \
  -D jpeg=enabled \
  -D tiff=enabled \
  -D others=enabled \
  -D thumbnailer=disabled \
  -D glycin=disabled \
  --wrap-mode=nofallback
```

After install, always:
```
gdk-pixbuf-query-loaders --update-cache
```

## Why `others=enabled` is mandatory (added 2026-05-28)

`others` defaults to `disabled` in upstream meson_options.txt. It gates
the **BMP, ICO, ICNS, XPM, XBM, TGA, PNM, QTIF, ANI** loaders — described
as "weakly maintained" upstream but critical for the rest of the stack.

The one that bites first: **BMP**. libxfce4windowing's
`xfw_window_get_icon()` (the function xfce4-panel's tasklist plugin uses
to fetch per-window icons) reads `_NET_WM_ICON` ARGB data, packages it
into an in-memory BMPv4-with-alpha, and hands it to gdk-pixbuf to decode.
Without the BMP loader installed, the decode fails silently and
`xfw_window_get_icon()` returns NULL — which xfce4-panel renders as an
**empty (blank) tasklist button** for every running window.

The terminal happened to render via `xfw_application_get_icon()` (a
different code path that goes through the icon theme by name) so its
group button looked fine. Firefox, Thunar, mousepad — all the apps whose
icon resolution fell into the per-window pixmap path — showed up as
blank buttons in the dock. Looked identical to the symptoms documented
as "parked vertical-mode tasklist bug" in `desktop-theming.md`; it
wasn't a vertical-mode bug at all.

### Fingerprint when BMP is missing

```sh
gdk-pixbuf-query-loaders | grep -i bmp
# (no output → BMP loader missing → blank tasklist buttons)
```

Or, with a tiny C helper that uses libxfce4windowing directly:
```
'Session 8 - Claude — Mozilla Firefox'
  win_icon=(nil) (0x0) fallback=0    ← libxfce4windowing got nothing back
  app_icon=0x... (32x32) fallback=0  ← app-level icon works (different path)
```

After enabling `others=enabled` and rebuilding, `win_icon` becomes
non-NULL and the tasklist draws the actual app icon. The
`desktop-theming.md` "parked" issue is resolved.

## Why `others` is "disabled" by default upstream

Same CONFIG-default-silently-disables-feature pattern as
[[librsvg-pixbuf-loader-must-be-enabled]] and the HDA codec y/m thing.
Upstream marks them "weakly maintained" so distros opt in selectively;
for a desktop build, opt them ALL in.

## Why glycin=disabled

`glycin` is a newer GNOME image-loading framework. As of BLFS 13.0 it isn't packaged in the book; gdk-pixbuf's meson check fails if you don't set it disabled.

## Why thumbnailer=disabled

The thumbnailer pulls in extra deps and isn't needed unless you want filemanager thumbnails for less-common formats. Thunar's built-in thumbnailing covers the common cases.
