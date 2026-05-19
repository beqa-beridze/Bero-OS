# Brand accent rule — interpretation note

## The contradiction

HANDOFF.md §2 says:

> **Accent rule:** never use `accent` as a background fill. Only for cursors,
> prompt markers, single dots, error states. One red object per screen.

HANDOFF.md §4.6 says:

> Use **Adwaita-dark** as a base, then override accent via
> `gtk-3.0/gtk.css` → `@define-color accent_bg_color #c8102e;`

These contradict each other on the surface: `accent_bg_color` is the GTK
variable used for selection highlights, focused buttons, switch-on
states, link colors, etc. — i.e., background fills on small interactive
elements.

## How we read it (the bero-os interpretation)

The §2 rule is about **large** background fills — wallpaper, panels,
cards, surfaces. The accent must not dominate any composition.

Small interactive bg fills (a row selection, a focused button outline,
a toggle's "on" state, a progress-bar fill) are **functional cues**,
not decorative fills. They're indistinguishable from "single dots" /
"error states" in scale and intent — momentary, contextual, you-look-
at-it-and-move-on. They satisfy "one red object per screen" because
you only see one selected row or one focused button at a time.

So we keep §4.6's instruction: `accent_bg_color = #c8102e` in
`/root/.config/gtk-3.0/gtk.css`. GTK selections + focus rings show in
accent red. Panels, headerbars, window backgrounds, terminal canvas
all remain Workshop ground/surface — no large accent fills anywhere.

If a future review disagrees, the rollback is one line: delete the
`accent_bg_color` line from `gtk.css`, leave `theme_selected_bg_color`
and the cursor color alone. GTK will fall back to Adwaita-dark's
default blue accent.

## Where accent IS used on bero-os (canonical inventory)

- xterm cursor color (when xterm existed, removed in 77676dd)
- xfce4-terminal cursor color (`ColorCursor=#c8102e`)
- bash prompt `▮` operator marker
- bash prompt `❯` separator
- `bero` CLI mark output, error lines, palette swatch, command_not_found
- xfwm4 `active_hilight_1` (title-bar highlight pixel — one pixel,
  technically a fill but minimal)
- /etc/issue ANSI escape on the `▮` glyph
- GTK accent_bg_color → selections, focus, switches (per §4.6)
- LightDM greeter: nowhere (background is wallpaper; no accent fill)
- Wallpaper: cursor mark uses accent per the canonical logo

All other surfaces use Workshop palette ground/surface/hairline/paper/
mid/dim. Accent never appears as a wallpaper, panel, headerbar, or any
surface taller than ~2px.
