# gdk-pixbuf build flags

## Lesson learned (2026-05-13)

GTK's image format support comes from **gdk-pixbuf MODULES**, not from system libs at runtime. If you build gdk-pixbuf with `-D png=disabled`, GTK cannot load PNG images **even if** libpng is installed system-wide. The same goes for `-D jpeg=disabled`, `-D gif=disabled`, `-D tiff=disabled`.

This bit us hard during the XFCE batch: gdk-pixbuf was first built with all loaders disabled (the wrong assumption was that gdk would use system libs). Result: the lightdm GTK greeter crashed on `Gtk:ERROR:.../gtkiconhelper.c:495:ensure_surface_for_gicon` because it couldn't load `image-missing.png`.

## The right flags

```
meson setup .. --prefix=/usr --buildtype=release \
  -D png=enabled \
  -D gif=enabled \
  -D jpeg=enabled \
  -D tiff=enabled \
  -D thumbnailer=disabled \
  -D glycin=disabled \
  --wrap-mode=nofallback
```

After install, always:
```
gdk-pixbuf-query-loaders --update-cache
```

## Why glycin=disabled

`glycin` is a newer GNOME image-loading framework. As of BLFS 13.0 it isn't packaged in the book; gdk-pixbuf's meson check fails if you don't set it disabled.

## Why thumbnailer=disabled

The thumbnailer pulls in extra deps and isn't needed unless you want filemanager thumbnails for less-common formats. Thunar's built-in thumbnailing covers the common cases.
