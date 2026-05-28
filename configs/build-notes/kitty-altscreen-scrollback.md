# Kitty: alt-screen scrollback for Claude Code (2026-05-29)

## Why we installed Kitty

xfce4-terminal (built on VTE) cannot keep the scrollback buffer accessible
when an app switches to the X11 alternate screen — Claude Code, vim, less,
htop. In alt-screen mode, VTE locks `scroll_delta` to 0 (see
`/sources/vte-0.82.3/src/vte.cc:10549` — "The alternate scrn isn't allowed
to scroll at all"). The scrollbar disappears, mouse wheel only fakes
arrow keys via `XTERM_ALTBUF_SCROLL` mode 1007. This is by design in VTE
and there is no build flag or runtime setting that changes it.

Konsole (Ubuntu/KDE default) handles it differently — it keeps the normal
buffer scrollback live underneath the alt-screen, so you can scroll up
mid-Claude-Code-session and select older output. Kitty does the same
thing, and unlike Konsole doesn't pull in Qt + KDE Frameworks.

## What's installed

- **Kitty 0.47.0** — via nix at `~/.nix-profile/bin/kitty` (single binary,
  GPU-accelerated, ~30 MB closure)
- **nixGLIntel wrapper** — needed because nix-bundled libGLX can't query
  our X server's GLXFBConfigs on a non-NixOS host. Fetched on first run
  via `nix run --impure github:nix-community/nixGL#nixGLIntel`.
- **`/usr/local/bin/kitty`** — bash wrapper that invokes Kitty via
  nixGLIntel so plain `kitty <args>` works system-wide. Mirrored at
  `configs/usr/local/bin/kitty`.
- **`/etc/profile.d/99-local-wrappers.sh`** — re-prepends `/usr/local/bin`
  to PATH after nix.sh prepends `~/.nix-profile/bin`, so our wrapper
  shadows the raw nix binary.
- **`~/.config/kitty/kitty.conf`** — Workshop palette, Red Hat Mono,
  50000-line scrollback, Noto fallback for emoji/symbols, `▮` title
  prefix to match the xfce4-terminal brand.
- **`/usr/share/applications/kitty.desktop`** — so it shows up in
  appfinder and the panel can pin a launcher.

## Why GLX fails on bare nix-Kitty

```
[glfw error 65542]: GLX: No GLXFBConfigs returned
OSError: Failed to create GLFWwindow. ... requires working OpenGL 3.1 drivers.
```

Nix's bundled `libGLX_mesa.so` is built against a specific Mesa ABI and
can't introspect the X server's running Mesa. nixGL replaces the bundled
libs at runtime with paths that resolve to the system's GL stack (which
on bero-os is Mesa 25.3.5 + crocus + Intel HD 4000). Same trick Discord
and Element use on non-NixOS.

## Keyboard cheatsheet (works in alt-screen too)

| Action | Keys |
|--------|------|
| Scroll line up/down | `Ctrl+Shift+Up` / `Down` |
| Scroll page up/down | `Ctrl+Shift+PgUp` / `PgDn` |
| Scroll to top/bottom | `Ctrl+Shift+Home` / `End` |
| Open scrollback in `less` | `Ctrl+Shift+H` |
| Copy / paste | `Ctrl+Shift+C` / `V` |
| New tab / window | `Ctrl+Shift+T` / `Enter` |
| Increase / decrease font | `Ctrl+Shift+=` / `-` |

Mouse wheel also scrolls the alt-screen buffer naturally — no Shift
needed, unlike xfce4-terminal.

## Why not replace xfce4-terminal entirely?

xfce4-terminal stays as the default for normal shell work — it's the
brand-themed terminal pinned to the dock, autologin starts it, the
`bero` CLI banner expects it. Kitty is an opt-in second terminal for
Claude-Code-style work where alt-screen scrollback matters.

If we ever want to swap defaults: update
`/home/bero/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml`
(Super+Return binding), the panel launcher .desktop, and `xfce4-session`
autostart entries.

## Reference

- Memory: [[kitty-altscreen-scrollback]]
- Related: gnome-terminal/xfce4-terminal both inherit VTE's behavior;
  Wezterm, foot, st, Konsole all do alt-screen scrollback like Kitty.
