# Usable-base fixes (fonts, xdg tools, which, unix_chkpwd, timezone)

## Lesson learned (2026-09-13)

Five cheap items left over from the 2026-05-31 audit, all of them "the
system works but nothing on it is comfortable" problems. Nothing here is
a rebuild — four downloads, three small packages, two one-liners.

---

## 1. No proportional UI font

**Wrong:** the desktop had only monospace and symbol faces installed —
Noto Sans Mono, Noto Color Emoji, Noto Sans Symbols 2, Red Hat Mono, plus
the ancient Xorg Luxi/Courier bitmaps. Every proportional request
(`sans-serif`, `serif`, `Arial`, `Times New Roman`) fell through to Luxi
Sans / Luxi Serif from 1996, so all of XFCE, GTK and every web page
rendered in it.

```
$ fc-match sans-serif          ->  luxisr.ttf: "Luxi Sans"   "Regular"
$ fc-match serif               ->  luxirr.ttf: "Luxi Serif"  "Regular"
$ fc-match Arial               ->  luxisr.ttf: "Luxi Sans"   "Regular"
$ fc-match "Times New Roman"   ->  luxirr.ttf: "Luxi Serif"  "Regular"
```

**Done:** installed two families per the BLFS "TTF and OTF fonts" page
(`x/TTF-and-OTF-fonts.html`) — the DejaVu install example there is the
pattern used for both.

- **Liberation 2.1.5** (Sans, Serif, Mono; regular/bold/italic/bolditalic
  — 12 TTFs) into `/usr/share/fonts/liberation/`.
  `https://github.com/liberationfonts/liberation-fonts/files/7261482/liberation-fonts-ttf-2.1.5.tar.gz`
  These are the metric substitutes for Arial / Times New Roman / Courier
  New, which is what fontconfig's `30-metric-aliases.conf` has been
  asking for all along.
- **Noto Sans + Noto Serif** (regular/bold/italic/bolditalic), plus
  **Noto Sans Georgian** and **Noto Serif Georgian** (regular/bold) into
  the existing `/usr/share/fonts/noto/`. Hinted static TTFs from the
  notofonts release repo:
  `https://github.com/notofonts/notofonts.github.io/raw/main/fonts/<Family>/hinted/ttf/<Family>-<Style>.ttf`
  for `NotoSans`, `NotoSerif`, `NotoSansGeorgian`, `NotoSerifGeorgian`.

No CJK — those are 90 MB+ per family and nothing here needs them. Noto
Sans/Serif already cover Latin, Greek and Cyrillic; the Georgian blocks
live in the separate Georgian families, which is why they are pulled in
too (the box lives in Tbilisi now).

Install was the book's recipe:

```sh
install -v -d -m755 /usr/share/fonts/liberation
install -v -m644 liberation-fonts-ttf-2.1.5/*.ttf /usr/share/fonts/liberation/
install -v -m644 Noto*.ttf /usr/share/fonts/noto/
fc-cache -f /usr/share/fonts/liberation /usr/share/fonts/noto
rm -rf ~/.cache/fontconfig && fc-cache -fv
```

**Verify:**

```
$ fc-match sans-serif          ->  NotoSans-Regular.ttf:        "Noto Sans"        "Regular"
$ fc-match serif               ->  NotoSerif-Regular.ttf:       "Noto Serif"       "Regular"
$ fc-match Arial               ->  LiberationSans-Regular.ttf:  "Liberation Sans"  "Regular"
$ fc-match "Times New Roman"   ->  LiberationSerif-Regular.ttf: "Liberation Serif" "Regular"
$ fc-match "Courier New"       ->  LiberationMono-Regular.ttf:  "Liberation Mono"  "Regular"
$ fc-match :lang=ka            ->  NotoSansGeorgian-Regular.ttf
$ fc-match :lang=ru            ->  NotoSans-Regular.ttf
```

No new fontconfig rule was needed — the stock `30-metric-aliases.conf`
and `45/60-latin.conf` already prefer exactly these families, they just
had nothing to point at. `65-bero-symbol-fallback.conf` from the May
session is untouched and still applies.

**Not committed:** the TTFs themselves are ~8 MB (2.3 MB Liberation +
5.7 MB Noto), over the size line for this repo. The URLs above are the
record. The four small Noto faces already in `configs/usr/share/fonts/noto/`
from May stay as they are.

**Gotcha:** same as May — running apps keep the fontconfig state they
started with. XFCE panel, Thunar and any open terminal keep rendering in
Luxi until the session is restarted.

---

## 2. desktop-file-utils, xdg-utils, xdg-user-dirs

**Wrong:** none of the three were ever installed. No `xdg-open` (so
anything trying to hand a file or URL to the desktop just failed), no
`update-desktop-database` (so `/usr/share/applications/mimeinfo.cache`
never existed and MIME→app lookup was dead), and no XDG user dirs.

**Done:**

### desktop-file-utils 0.28 (BLFS `general/desktop-file-utils.html`)

Book commands verbatim (meson, `--buildtype=release`).

> **Gotcha:** the book's download URL,
> `https://www.freedesktop.org/software/desktop-file-utils/releases/desktop-file-utils-0.28.tar.xz`,
> returns **HTTP 418** to curl *and* wget, with or without a browser
> User-Agent, from both this laptop and the box. The anduin BLFS mirror
> 404s for this package. Used the upstream GitLab tag archive instead:
> `https://gitlab.freedesktop.org/xdg/desktop-file-utils/-/archive/0.28/desktop-file-utils-0.28.tar.gz`
> — same source at tag 0.28, but it is a git-export tarball so the
> book's MD5 (`dec5d7265c802db1fde3980356931b7b`) does **not** apply.
> The .tar.gz is `7a20e687e0a24fceda4a0dfa61d1a622`. If the freedesktop
> host ever starts answering again, prefer the release tarball.

Then, as root, the book's configuration step:

```sh
install -vdm755 /usr/share/applications
update-desktop-database /usr/share/applications
```

### xdg-user-dirs 0.19 (BLFS `general/xdg-user-dirs.html`)

Book commands verbatim, including `-D docs=false` (docbook-xsl / libxslt
man-page path not wanted). Then, as bero, `xdg-user-dirs-update` — which
created `~/Desktop ~/Downloads ~/Documents ~/Music ~/Pictures ~/Public
~/Templates ~/Videos` and `~/.config/user-dirs.dirs`.

New system files, mirrored into the repo:
`/etc/xdg/user-dirs.conf`, `/etc/xdg/user-dirs.defaults`,
`/etc/xdg/autostart/xdg-user-dirs.desktop`.

### xdg-utils 1.2.1 (BLFS `xsoft/xdg-utils.html`)

This one needed a deviation. The book lists **xmlto** as a hard
dependency, and xmlto in turn wants lynx/links/w3m. None of them are on
bero-os and none are worth installing for help text.

The catch: xmlto here is not only for the man pages. The build turns
`desc/*.xml` (DocBook) into `*.txt` with `xmlto txt`, and `%: %.in %.txt`
inlines that text into each script's `--help` / `--manual` heredoc. So
without xmlto the **scripts themselves** don't generate, not just the
docs. Two extra traps:

- `./configure` reports `checking for xmlto... /usr/bin/xmlto` even when
  there is no xmlto — it falls back to that path unconditionally. The
  failure only shows up at `make` time as `/bin/sh: /usr/bin/xmlto: No
  such file or directory`.
- Plain `make` also builds `html/` and `man/`, which are pure xmlto.

Workaround, in `/sources/xdg-utils-v1.2.1/scripts`: generate the eight
`.txt` files with a ~50-line DocBook-refentry-to-text converter kept at
`configs/patches/xdg-utils-1.2.1-docbook-to-txt.py` (stdlib
ElementTree only — the XML has no external entity refs, so no DTD fetch),
then build only the `scripts` target:

```sh
./configure --prefix=/usr
cd scripts
for x in xdg-desktop-menu xdg-desktop-icon xdg-mime xdg-icon-resource \
         xdg-open xdg-email xdg-screensaver xdg-settings; do
    python3 /path/to/xdg-utils-1.2.1-docbook-to-txt.py desc/$x.xml > $x.txt
done
cd ..
make -C scripts scripts
make install          # as root
```

`make install` is safe to run at top level: it does not depend on `all`,
and `scripts/Makefile`'s install target guards the man pages with
`if [ -f $x ]`, so the absent `man/*.1` are simply skipped. The tests and
autotests subdirs have nothing to install.

Result: all eight scripts installed, `--help` and `--manual` work and
read sensibly; only `man xdg-open` is missing. Tests were not run — the
book's own caution says they need an X session, a browser and an MTA.

**Verify:**

```
$ command -v xdg-open xdg-mime update-desktop-database xdg-user-dirs-update
/usr/bin/xdg-open
/usr/bin/xdg-mime
/usr/bin/update-desktop-database
/usr/bin/xdg-user-dirs-update
$ ls /usr/share/applications/mimeinfo.cache
/usr/share/applications/mimeinfo.cache
$ xdg-mime query filetype /etc/fstab
text/plain
```

`mimeinfo.cache` is a generated cache, so it is deliberately **not**
mirrored into the repo — regenerate it with `update-desktop-database`
after installing any `.desktop` file.

---

## 3. No `which`

**Wrong:** `/usr/bin/which` did not exist. The only `which` on the box
was inside the Nix store, reachable only from a nix profile — so scripts
and `bash -c` from outside a nix environment got `which: command not
found`.

**Done:** GNU Which 2.23, the first option on BLFS
`general/which.html`. Not the shell-script alternative and explicitly not
a symlink into `/nix` — nothing in `/usr/bin` should depend on the Nix
store.

```sh
curl -fLO https://ftpmirror.gnu.org/which/which-2.23.tar.gz   # md5 1963b85914132d78373f02a84cdb3c86, OK
./configure --prefix=/usr && make
make install    # as root
```

Builds in seconds; one harmless `-Wdiscarded-qualifiers` warning in
`tilde.c`. No test suite.

**Verify:** `which which` -> `/usr/bin/which`,
`which --version` -> `GNU which v2.23`.

---

## 4. unix_chkpwd not setuid

**Wrong:** `/usr/sbin/unix_chkpwd` was mode `0755`. It is the Linux-PAM
helper `pam_unix` execs to read `/etc/shadow` when the calling process
isn't root — without the setuid bit, any non-root password check
(screen lock, `su`, polkit prompts) can't read the hash. The Linux-PAM
page sets this at install time; our May PAM install missed it.

**Done:** `chmod 4755 /usr/sbin/unix_chkpwd`

**Verify:** `ls -l /usr/sbin/unix_chkpwd` -> `-rwsr-xr-x 1 root root`.

Nothing else in the PAM stack was touched.

---

## 5. Timezone still Asia/Jerusalem

**Wrong:** `/etc/localtime -> /usr/share/zoneinfo/Asia/Jerusalem`, set
when the box was built in May. The box lives in Tbilisi now, so every
timestamp, log line and cron-ish thing was an hour off.

**Done:** `ln -sf /usr/share/zoneinfo/Asia/Tbilisi /etc/localtime`

**Verify:** `date` -> `... +04 2026`; `timedatectl` -> `Time zone:
Asia/Tbilisi (+04, +0400)`, clock still NTP-synchronized.

**Not committed:** `/etc/localtime` has never been tracked in this repo
(`git ls-files configs/etc` has no entry for it), and a git symlink into
`/usr/share/zoneinfo` would be a dangling link on any other machine. Left
untracked on purpose — this note is the record of the change.
