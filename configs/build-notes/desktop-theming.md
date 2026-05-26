# Desktop theming notes — icons, GTK theme, xfwm4 theme

## Lesson learned (2026-05-25 / 2026-05-26)

Captures the multi-hour journey of trying to make the desktop look slick
after the Workshop Rail panel v1. **Pre-requisite for any of this to
work is `librsvg-pixbuf-loader.md`** — without that, every theme silently
falls back to GTK's built-in PNGs and nothing changes visually.

## What's installed

### Icon theme — Papirus-Dark (with red folder colour)

```sh
cd /tmp && git clone --depth=1 https://github.com/PapirusDevelopmentTeam/papirus-icon-theme.git
cd papirus-icon-theme && sudo ./install.sh        # installs Papirus, Papirus-Dark, Papirus-Light
cd /tmp && git clone --depth=1 https://github.com/PapirusDevelopmentTeam/papirus-folders.git
sudo install -Dm755 papirus-folders/papirus-folders /usr/local/bin/papirus-folders
sudo papirus-folders -C red --theme Papirus-Dark  # recolor folder icons
sudo gtk-update-icon-cache -f -t /usr/share/icons/Papirus-Dark
```

Tela-circle-icon-theme was tried first and abandoned — `red` variant of
Tela-circle only changes overlay accents, NOT folder body colour. Folders
in Tela-circle are monochrome symbolic outlines. Use Papirus when you
want visibly-red folders.

### GTK + xfwm4 theme — Catppuccin Mocha Red Dark

```sh
cd /tmp && git clone --depth=1 https://github.com/Fausto-Korpsvart/Catppuccin-GTK-Theme.git
cd Catppuccin-GTK-Theme/themes
sudo ./install.sh -t red -c dark --tweaks black   # needs sassc; nix profile add nixpkgs#sassc
```

The script builds SCSS → CSS using `sassc` and installs to
`/usr/share/themes/Catppuccin-Red-Dark/` with GTK 2/3/4, Cinnamon,
GNOME-Shell, Metacity, Plank, and **xfwm4** sub-themes — one theme name
covers everything.

### Active config (xfconf)

```
xsettings  /Net/ThemeName       = Catppuccin-Red-Dark
xsettings  /Net/IconThemeName   = Papirus-Dark
xfwm4      /general/theme       = Catppuccin-Red-Dark
xfwm4      /general/title_font  = Red Hat Mono SemiBold 10
xfwm4      /general/button_layout = |SHMC    (no menu button on the left)
```

And `~/.config/gtk-3.0/settings.ini`:

```
[Settings]
gtk-icon-theme-name=Papirus-Dark
gtk-theme-name=Catppuccin-Red-Dark
gtk-application-prefer-dark-theme=true
gtk-font-name=Red Hat Mono Medium 10
```

The settings.ini is the fallback path GTK reads when xsettings broadcast
isn't reaching it — kept as belt-and-suspenders.

## xfce4-terminal icon symlink fix

xfce4-terminal's WM_CLASS is `xfce4-terminal` but Papirus's terminal icon
is at `categories/org.xfce.terminal.svg`. The panel tasklist looks up
icons by WM_CLASS, so it doesn't find anything. Fix: symlink
`apps/xfce4-terminal.svg → ../categories/org.xfce.terminal.svg` for every
size dir:

```sh
sudo bash -c '
for sz in 16 22 24 32 48 64; do
  base=/usr/share/icons/Papirus-Dark/${sz}x${sz}
  ln -sf ../categories/org.xfce.terminal.svg "$base/apps/xfce4-terminal.svg"
done
gtk-update-icon-cache -f -t /usr/share/icons/Papirus-Dark'
```

## Known issues (parked)

1. **Panel tasklist shows no icons** even though `_NET_WM_ICON` is set on
   each window, libwnck-3 is loaded, and the tasklist plugin is rendering
   buttons (labels work when `show-labels=true`). Suspect a vertical-mode
   tasklist icon-size calculation bug in xfce4-panel 4.20.6. Workaround:
   set `show-labels=true` to at least see app names; or live with empty
   slots.

2. **xfwm4 close/min/max buttons are subtle** — Catppuccin ships them as
   36×34 8-bit-colormap PNGs without alpha. xfwm4 renders them but they
   sit low-contrast against the dark title bar. Close doesn't go red on
   hover because Catppuccin's prelight image is just a brightened version
   of the base, not the workshop accent colour. Future: either swap to
   `WhiteSur-Dark` xfwm4 (clear macOS-style buttons) or hand-edit
   Catppuccin's xfwm4 PNGs.

3. **Cursor theme** — still the default chunky X11 cursor. Bibata-Modern
   or Capitaine-cursors recommended per HANDOFF §4.6. Untouched in this
   pass.

## When to re-do this work

The Workshop Rail panel itself was already flagged as v1 in
`feedback_panel_v1_needs_redesign.md`. The theme work captured above is
"good enough to daily-drive" — the user explicitly accepted Catppuccin
as the look. Don't iterate on title bar visuals without doing the
modern-dock research pass first.
