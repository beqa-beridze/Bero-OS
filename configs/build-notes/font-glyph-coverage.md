# Font glyph coverage build notes

## Lesson learned (2026-05-28)

**bero-os shipped with no font that has glyphs for dingbats, symbols, or
emoji.** Everywhere a `●` `⏵` `🤖` should appear — Claude Code status
markers, terminal title bar, app chrome — you got an empty box (tofu).
Fontconfig had fallback rules for Noto Color Emoji baked into the upstream
`45-generic.conf` and `60-generic.conf`, but the Noto font files were
never installed, so the rules were orphaned and silently did nothing.

## Symptom

Every line of Claude Code output is prefixed with a tofu box. `echo
'🎨 ☕ 🐧'` shows three boxes. `fc-match -s :charset=$(printf %x "'●")`
returns Luxi Sans — but Luxi Sans has no glyph at U+25CF, so pango falls
back to the Unicode-code-point hex box.

## Diagnosis (the one command that proves it)

```sh
for ch in '●' '⏵' '◯' '▮' '⏺' '☰' '⚡' '🤖' '🎨'; do
  printf '%s -> ' "$ch"
  fc-match -s :charset=$(printf '%x' "'$ch") | head -1
done
```

Before the fix: every line returns `luxisr.ttf: "Luxi Sans" "Regular"` (a
font that does not actually contain those glyphs — fontconfig's "best of
the worst" pick).

After the fix: lines return `NotoSansSymbols2-Regular.ttf`,
`NotoSansMono-Regular.ttf`, or `NotoColorEmoji.ttf` as appropriate.

## Root cause

`/etc/fonts/conf.d/45-generic.conf` and `60-generic.conf` (upstream
fontconfig) both append `Noto Color Emoji` and similar to the fallback
chain — but rely on those fonts actually being installed. With only
Red Hat Mono + Luxi + Courier + Goha-Tibeb-Zemen on disk (45 faces
total), none of the symbol-block ranges Claude Code uses have any
covering font, and pango renders the tofu / code-point box.

## Fix

Install three Noto fonts and one fallback rule:

```sh
# 1. Download to /tmp
cd /tmp/fonts-staging
wget https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoColorEmoji.ttf
wget https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansSymbols2/hinted/ttf/NotoSansSymbols2-Regular.ttf
wget https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansMono/hinted/ttf/NotoSansMono-{Regular,Bold}.ttf

# 2. Install system-wide
sudo install -d -m 755 /usr/share/fonts/noto
sudo install -m 644 *.ttf /usr/share/fonts/noto/

# 3. Drop the fallback rule (mirrored in this repo at
#    configs/etc/fonts/conf.d/65-bero-symbol-fallback.conf)
sudo install -m 644 65-bero-symbol-fallback.conf /etc/fonts/conf.d/

# 4. Rebuild cache
sudo fc-cache -f /usr/share/fonts/noto
rm -rf ~/.cache/fontconfig && fc-cache -fv
```

## Gotcha: xfce4-terminal's D-Bus daemon caches pango state

After the install, opening a "new" xfce4-terminal tab or window still
shows tofu — because xfce4-terminal connects to a per-user D-Bus daemon
that holds the old fontconfig state. Two ways to verify the fix:

- `xfce4-terminal --disable-server` — spawns a fresh process not bound to
  the daemon. Will render correctly immediately.
- Logout + login — fully restarts the user session and all of its
  D-Bus-attached daemons.

Long-running terminals (e.g. one currently hosting a Claude Code session)
won't pick up the new fonts mid-flight. Plan for a session restart.

## What we explicitly did NOT do

- **Did not patch Red Hat Mono with Nerd Fonts.** ryanoasis/nerd-fonts
  v3.4.0 doesn't ship a Red Hat Mono variant. Patching it ourselves would
  need FontForge + the patcher script, ~30 min for 10 weights. Skipped
  because Noto fallbacks already cover every glyph Claude Code and the
  desktop actually use. Re-open this decision if we ever want
  Powerline/Devicons style CLI prompts.
- **Did not change the terminal font.** Red Hat Mono Medium 11 stays as
  the primary; fontconfig now adds Noto as a fallback for the rare
  symbol/emoji glyph it doesn't have.

## Reference

- Symptom screenshot before/after: `/tmp/desktop-icons.png` and
  `/tmp/desktop-icons-after.png` (not committed)
- Memory: [[reference-font-glyph-coverage]]
