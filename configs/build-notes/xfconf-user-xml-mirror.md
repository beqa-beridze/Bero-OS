# xfconf user XML mirror

`configs/home/bero/.config/xfce4/xfconf/xfce-perchannel-xml/` holds a
byte-identical copy of every active xfconf channel XML on bero's account.

Without this mirror, a disk failure (or `rm -rf ~/.config/xfce4` in a
moment of bad judgment) loses every UI customization made since commit
`15b6b18`: panel layout including the Workshop Rail, Thunar prefs,
xfce4-terminal font/colors, keyboard shortcuts, xfwm4 window-manager
theme, xsettings.

## What lives in each file

| File | What it controls |
|---|---|
| `displays.xml` | Display geometry / output configuration |
| `keyboards.xml` | Keyboard layout, repeat delay, layout switcher |
| `thunar.xml` | Thunar (file manager) preferences |
| `xfce4-appfinder.xml` | App finder bookmarks and recent-items behavior |
| `xfce4-desktop.xml` | Desktop background, icon layout, root-menu enabled |
| `xfce4-keyboard-shortcuts.xml` | All keyboard shortcuts (xfwm4 + xfce4 commands) |
| `xfce4-panel.xml` | Panel layout, plugins, Workshop Rail |
| `xfce4-power-manager.xml` | Power button behavior, lid actions, blank-screen timeouts |
| `xfce4-session.xml` | Session autostart, splash, logout behavior |
| `xfce4-terminal.xml` | Terminal font, colors, scrollback |
| `xfwm4.xml` | Window manager theme, focus model, workspaces |
| `xsettings.xml` | GTK theme, icon theme, font hinting (system-wide GTK look) |

## What's excluded

- `xfce4-panel.xml.pre-workshop-rail` — a one-off backup taken before the
  Workshop Rail panel work. Not active config; lives only in
  `~/.config/...` for now. If you ever revert the Rail, restore from there
  not from the repo.
- Other `~/.config/` subdirs (Thunar cache state, Mousepad recents,
  gtk-3.0/, pulse, mozilla, mimeapps.list, glib-2.0). Scope per audit #17
  is xfconf-only. See audit #14 if a full `~/.config` mirror becomes a
  goal later.

## Restoring on a fresh install

xfconf will read these from `~/.config/xfce4/xfconf/xfce-perchannel-xml/`
on next session start. To restore:

```
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
cp -p configs/home/bero/.config/xfce4/xfconf/xfce-perchannel-xml/*.xml \
   ~/.config/xfce4/xfconf/xfce-perchannel-xml/
xfce4-session-logout --logout   # then log back in for xfconfd to reread
```

Alternative: while xfconfd is running, settings can be replayed channel-
by-channel with `xfconf-query --create` per key, but the file copy +
relogin is simpler.

## Drift

Xfconf rewrites these files anytime a setting changes (panel drag, theme
swap, shortcut binding). The mirror in `configs/` only captures the
moment of commit. To keep it current, re-mirror after major UI work:

```
cp -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/*.xml \
   configs/home/bero/.config/xfce4/xfconf/xfce-perchannel-xml/
git status configs/home/
```
