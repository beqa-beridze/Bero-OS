# Bero-OS Journal

## 2026-05-11

Created Linux from scratch following the LFS 13.0 systemd instructions.

Booted it on a ThinkPad X230 for the first time and set up SSH for easier workflow.

Started a GitHub repo for documentation.

Installed wget so building from now on is easier.

After that I decided to speed things up by having Claude Code do the busy work. Skipping sudo while building — will install it later when I add a non-root user.

First things I had CC do: editor (vim), firmware bundle (audio and wifi weren't working), curl, git. First prompt to see how CC performs.

Did another batch right after. 17 packages this time — cmake and nasm so the cmake-using stuff can build, then libpsl, ICU, libxml2, libxslt, libjpeg-turbo, libpng, libtiff, freetype, glib, fribidi, pixman, fontconfig, harfbuzz, cairo, pango. The idea is to have everything X11 will need already in place so next session I can go straight into Xorg.

One hiccup: glib wanted Python docutils for its man pages. Just turned man-pages off, nothing important lost.

Also had CC download the BLFS book locally so it stops hitting the web for every page. Sits in `context/`, gitignored.

Quick cleanup batch before starting X11. Installed rsync so I have a proper sync tool. Installed docutils via pip — last batch needed it for glib man pages and I skipped them. Now it's available so future packages get their docs. Also rebuilt curl with libpsl since libpsl exists now (last batch curl was built without it because libpsl wasn't installed yet).

Also: decided to switch the endgame DE from KDE Plasma to XFCE. GTK3-based, simpler, fits the AI co-driver idea better than Plasma's complexity. Foundation libs are toolkit-agnostic so nothing to redo.

## 2026-05-12

X11 stack landed overnight. Long batch — went to bed with CC running, woke up to it done.

Big surprise: Mesa refused to build without LLVM, even with crocus driver only (softpipe and Vulkan swrast both pull LLVM in). Plan was to skip LLVM and save ~6-8 hrs but had to bite the bullet. LLVM 21.1.8 with clang + compiler-rt took about 6 hrs on the X230. After that Mesa built clean in ~30 min.

Other surprises that needed handling along the way: Mesa wanted Python `mako` and `PyYAML` modules (just pip-installed both), xorg-server needed `font-util` first (built it from the font bundle), `libtirpc` for secure-rpc (just disabled it, we don't need networked X), and `libepoxy` for glamor (small install). libinput needed `mtdev` for multi-touch handling.

End state: full X11 stack — Xorg-server 21.1.21 with glamor + modesetting, Mesa 25.3.5 with crocus for HD 4000, libinput stack, twm + xterm + xinit. Cairo and pango rebuilt to pick up the new X backends (cairo-xlib, cairo-xcb, pangoxft, pangocairo all good now).

`/root/.xinitrc` is set up. To test, switch to a TTY, log in as root, run `startx` — should bring up grey root + an xterm titled "Bero-OS X11 OK" + twm cursor. Type `exit` in xterm to drop back to TTY.

Audio still not working — diagnosed as missing kernel codec module (CONFIG_SND_HDA_CODEC_REALTEK or similar), not firmware. Needs a kernel rebuild session, parking it.

Next session: GTK3, then XFCE itself, then LightDM.

Started the GTK3 + XFCE + LightDM batch later in the day. CC running it while I'm at work.

Phase 0 done: Linux-PAM 1.7.2 installed with minimal pam_unix system stacks. /etc/pam.d/ was empty before this so anything needing PAM (polkit, lightdm) is now ok.

Phase A done: glib 3-pass rebuild with introspection enabled, gobject-introspection 1.86.0 installed. Took a few tries because of two bero-os quirks: `ldd` was broken (linker symlink at the wrong path — fixed), and gobject-introspection installed pc files in /usr/lib64/pkgconfig but pkg-config only searched /usr/lib/pkgconfig (added a profile.d script).

Phase B1 done: shared-mime-info, gdk-pixbuf (with `-D glycin=disabled` because glycin-2 isn't installed), gsettings-desktop-schemas, at-spi2-core.

Phase B2 in progress: Rust 1.93.1 toolchain, ~1.5 hrs in, ~30-60 min to go before librsvg can build.

Eventually finished the whole batch. Total ~10 hrs CC-wall-clock. Bigger surprises:

- harfbuzz and pango both had to be rebuilt with introspection enabled (they were built without it back in batch 2 because glib was missing introspection then). gtk3 wouldn't build without their .gir files.
- Mesa surprise from last batch hit again here too — anything wanting introspection has to wait until glib has it. Built up a stack of small rebuilds because of this.
- The /usr/lib64 quirk: glib, gobject-introspection, gtk3 and most things ended up installing pkgconfig and typelibs into /usr/lib64 instead of /usr/lib. Wrote /etc/profile.d/pkg-config-lib64.sh to handle that for downstream builds.
- gtk3 build fails on docbook man pages (xsltproc tries to fetch docbook.xsl over the network). Set `-D man=false`. Same trick for xfce4-terminal, libsecret, others — they all hit this. xfce4-terminal had no flag to disable man pages, so I skipped that whole package — xterm from batch 3 is the terminal for now.
- vte wanted gnutls. Skipped gnutls (it's a big build) — disabled vte's gnutls support with `-D gnutls=false`.
- gcr wanted gpg2 binary just to configure. Stubbed gpg2 with an exit-0 script so gcr's configure passes. gcr's gpg-using features won't work at runtime but they're not needed for XFCE to come up.
- accountsservice tests wanted Python dbus and PyGObject — patched out the tests subdir entirely.
- libxml2 needed a rebuild with Python bindings for itstool (which lightdm needs). That dragged in doxygen as a build dep.
- iso-codes + libxklavier needed for lightdm even after thinking I'd skip them.
- Dropped gvfs and the whole udisks chain. Too much yak shaving (gvfs needs libsoup needs glib-networking needs gnutls). Means no removable-media handling in thunar yet. Can add later as a one-off batch.
- xfce4-terminal also dropped (docbook man). Skipped a Python pip-install rabbit hole too — installed mako, PyYAML, markdown, pygments, typogrify, lxml, dbus-python as we went.

End state: full XFCE session with xfwm4 + xfce4-panel + xfdesktop + xfce4-session + xfce4-settings + thunar + mousepad + xfce4-appfinder. LightDM autologins as root into xfce. /etc/pam.d/lightdm symlinks to system-auth.

To test: reboot the X230. It should boot through TTY → lightdm → autologin → XFCE desktop. If something fails, drop to TTY (Ctrl+Alt+F2) and check `journalctl -u lightdm -b --no-pager` or `cat ~/.xsession-errors`.

Audio still parked. gvfs deferred. xfce4-terminal deferred.

Tried rebooting and the desktop didn't come up. Spent a while debugging with CC. Two real bugs.

First, gdk-pixbuf was built with all the image-loader flags disabled — turns out those aren't optional, they're how GTK loads PNGs and JPEGs at all. Without them GTK can't load any icon, the greeter crashes on the first one it tries to draw. Rebuilt gdk-pixbuf with all the loaders on.

Second, lightdm's `make install` skips the `lightdm-session` wrapper script. Lightdm tries to run it for every session and exits in milliseconds when it isn't there. Wrote a tiny wrapper that sources /etc/profile and execs the session under dbus-run-session (XFCE needs a session bus). With that in place the autologin worked and the desktop showed up.

Wrote both up in `configs/build-notes/` so I don't repeat the mistakes.

Also: sshd was running by hand on every boot with no systemd unit. That bit me when bero-os rebooted and SSH never came back. Wrote /etc/systemd/system/sshd.service properly. Now SSH survives reboots.

Saw the XFCE desktop for the first time today.

## 2026-05-13

Got XFCE booting today. Hit two surprise bugs at first boot — gdk-pixbuf was built without image loaders so the greeter couldn't draw, and lightdm 1.32.0 doesn't ship the session wrapper so we wrote our own. Both fixed. First time bero-os has a real desktop. 3am, going to sleep.

## 2026-05-14

Batch 5 done. Audio (pipewire + wireplumber + alsa-utils), network manager (NM + wpa_supplicant + libnl + libndp + iptables + nspr + nss), power (upower + acpid + xfce4-power-manager), plus a bunch of small deps. 22 packages total. Hit a bunch of bugs.

NetworkManager refused to build three times in a row.

First try: PyGObject wasn't installed and NM's build runs a Python script that does `import gi`. Got listed in the book as "Recommended" not "Required", easy to miss. Built PyGObject, retried.

Second try: Python couldn't find the Gio typelib. Turns out libgirepository's compiled default search path only covers /usr/lib/girepository-1.0 but Gio's typelib is in /usr/lib64. We had GI_TYPELIB_PATH set in /etc/profile.d/ from a batch 4 fix, but that doesn't fire inside ninja's subprocess shells. Set it explicitly in the build env. Retried.

Third try got to 957/970 and then xsltproc tried to fetch docbook XSL over the network for man pages. Same family of bug we hit twice in batch 4 with gtk3 and libsecret. Stopped working around it this time, just installed docbook-xml-4.5 + docbook-xsl-nons-1.79.2 properly and set up /etc/xml/catalog. Resumed the build from where it failed, finished in 5 minutes.

acpid is the second package in this project that doesn't ship a systemd unit (after openssh in batch 4). Wrote one by hand.

Rebooted. Three more bugs at first boot.

nmcli wouldn't run — libnm.so.0 not in the linker cache. The NM install never ran ldconfig.

upower wouldn't start, exit status 217/USER. Its systemd unit sets PrivateUsers=yes which needs CONFIG_USER_NS=y in the kernel. My kernel doesn't have it. Drop-in to set PrivateUsers=no. Adding USER_NS to the next kernel rebuild list.

DNS was still using the fallback nameservers I put in pre-reboot. NM had written its own resolv.conf at /run/NetworkManager/resolv.conf but didn't touch /etc/resolv.conf. Symlinked /etc to /run. Done.

Laptop also got a new IP from DHCP (.5 instead of .2). Whatever, NM owns the connection now.

Finally fixed the /sbin PATH thing that's been deferred since batch 4. Two lines in /etc/profile.d/path.sh. Should have done it weeks ago.

That's it.

## 2026-05-14 (later)

Brand kit is on the laptop. Wallpaper, palette in xfce4-terminal + GTK + xfwm4 borders, the two-cursor PS1, Red Hat Mono, LightDM greeter branding, and a handful of easter eggs. Plus xfce4-terminal itself — which batch 4 had to skip because xsltproc tried to fetch docbook XSL over the network. That got resolved as a side effect of installing docbook-xsl-nons during the NetworkManager mess in batch 5, so this time it built clean.

Wallpaper note for whoever does the brand v2 — the cursor order in the PNG is swapped from the canonical mark. Logo SVG has red-filled-left, cream-outlined-right. The wallpapers have it the other way around. Living with it for now, flagged for re-export.

Easter eggs in: TTY /etc/issue with the accent bar, /etc/motd ASCII for SSH, a first-shell brand banner in /etc/profile.d/bero-banner.sh that prints a random "workshop wisdom" line per session (sentinel in /tmp suppresses it after the first shell), xfce4-terminal title set to "▮ bero-os", and /etc/skel/ pre-baked with the brand prompt for any future user.

## 2026-05-19

Audit pass on the brand work caught a real one: the wallpaper-cursor-order issue I flagged in batch 6 was never actually a "designer ships a fix later" problem. The fix was already uploaded the SAME night, sitting in `~/Downloads/Bero-OS logo and wallpapers (1).zip` — a wallpaper-only re-export with the correct cursor order. I just never extracted it and never asked where it was. Extracted now (filenames had `bero-os-` prefix instead of `wallpaper-`; renamed during install to keep the existing convention). Overwrote `context/export/wallpaper-*.png` with the v2 set, rsync'd to `/usr/local/share/bero-os/`, forced xfdesktop to redraw via a clear-then-set xfconf trick.

That JOURNAL note from batch 6 about the inconsistency is stale — leaving it in place but the situation is resolved.

## 2026-05-15

XFCE polish pass. The default 2-panel + light-theme + drop-shadows everywhere look was straight out of 2009. Tightened it.

Single top panel (28px), no bottom dock. All compositor shadows off (dock, frame, popup). Desktop icons off. Workshop palette consistent across xfce4-terminal, mousepad, GTK3 dialogs, and the xfwm4 title bars (the `bero-workshop` theme already had the right colors). Mousepad now has a `bero-workshop` GtkSourceView style installed at /usr/share/gtksourceview-4/styles/bero-os.xml — paper text on near-black, accent #c8102e on the cursor only (per brand: accent never as background).

Thunar got a real config — detail view default, sort by name ascending, hidden files off, shortcuts pane (not the tree). And a custom action for "Open Terminal Here" + a "Workshop Wisdom" easter egg in the right-click menu.

Window keybindings:
- Super+Return → xfce4-terminal
- Super+L → xflock4 (lock)
- Super+E → thunar
- Super+R → xfce4-appfinder
- Super+Left/Right → tile half
- Super+Up → maximize
- Super+Down → minimize/hide

Bash + readline polish in /etc/profile.d/bero-shell.sh + /etc/inputrc — sensible aliases (ll, la, grep --color, etc), 20k-line history with timestamps and dedup, case-insensitive completion, history-search via Up/Down, color completion, command_not_found_handle that prints a Workshop-styled hint.

Power manager: dim-on-battery 14min, dim-on-AC 30min, blank screen at 5/10min, lid suspends regardless of AC.

Added a `bero` CLI at /usr/local/bin/bero — public commands include `info`, `version`, `batches`, `art`, `fortune`, `palette`, `wisdom`, `help`. There are a few hidden subcommands too — find them yourself.

Talked to Gemini for the boring file-format lookups (GtkSourceView XML schema, thunar uca format, xfwm4 action name verification). It got the GtkSourceView and thunar bits right first try; the xfwm4 tile action names I made it confirm with sources. Saved a couple iterations of trial-and-error.

That's it.

Couple of small ruts:

xfce4-terminal upstream URL is .tar.xz, not .tar.bz2 as my old batch-4 note said. First wget hit a 404. Fixed and retried.

Red Hat Mono — github default branch is master not main. Repo also doesn't ship TTFs, only OTFs, and they live at fonts/Mono/RedHatMono/otf/ not the path APPLY-bero-os.md guessed. Took three wget attempts to land on the right tarball + path. Installed all 10 OTF faces (Regular, Medium, SemiBold, Bold + 4 italics + Light/LightItalic).

Also established that /root/ config files get mirrored to configs/root/ in the repo from this batch on. First time we've tracked /root/ in git.

That's it.

## 2026-05-22

Kernel rebuild for audio. Three CONFIG flips: SND_HDA_CODEC_REALTEK=m, SND_HDA_CODEC_CONEXANT=m (only the right one will bind), USER_NS=y (finally drops the upower drop-in from batch 5).

Set up a GRUB seatbelt first because the original install had exactly one kernel in /boot and one menuentry — if the new build panicked there was nothing to roll back to. Copied vmlinuz/System.map/config to .working suffixes, copied /lib/modules/6.18.10 to /lib/modules/6.18.10.working, added a second menuentry "bero-os FALLBACK -- pre-audio rebuild" pointing at the .working vmlinuz. Mirrored grub.cfg into configs/boot/grub/.

Expected an incremental build — three small CONFIG flips on an already-built tree. Wrong. USER_NS=y invalidates autoconf.h and the rebuild cascades into near-full. 26 minutes on the X230, all four threads pegged. Exit 0. New vmlinuz 14.52 MB vs 14.50 working, modules dir grew from 2.2M to 3.0M with all 10 Realtek ALC* (260/262/268/269/.../882) + Conexant + generic .ko files installed.

Path note: in newer kernels the codec modules moved from sound/pci/hda/ to sound/hda/codecs/. First verification grep checked the old path and came up empty for a moment.

Boot the new kernel. uname says #2 SMP today. aplay -l: no soundcards. dmesg:
    snd_hda_intel 0000:00:1b.0: bound 0000:00:02.0 (ops intel_audio_component_bind_ops)
    snd_hda_intel 0000:00:1b.0: Cannot probe codecs, giving up

That's the whole HDA story — two lines. Controller register reads 0 codecs on the bus. Adding codec drivers can't fix that, they need a codec to bind to. The original "controller fine, codec missing" diagnosis was probably seeing snd_hda_intel load without an obvious error and assuming the rest was fine. First time trying audio on this machine, no working baseline.

Cold power cycle + BIOS audio verify: same result.

Added snd_hda_intel.single_cmd=1 to the new-kernel menuentry only (fallback stays untouched). Standard X230 workaround that forces PIO mode for codec commands instead of DMA.

Reboot. Big change in dmesg:
    snd_hda_intel 0000:00:1b.0: spurious response 0x10ec0269:0x0, last cmd=0x0f0000
    snd_hda_intel 0000:00:1b.0: spurious response 0x80862806:0x3, last cmd=0x300f0000
    snd_hda_intel 0000:00:1b.0: spurious response 0x17aa21fa:0x0, last cmd=0x1f2000
    ... more spurious ...
    snd_hda_intel 0000:00:1b.0: Cannot probe codecs, giving up

The codec is THERE. 0x10ec0269 = Realtek ALC269. 0x17aa21fa = Lenovo ThinkPad X230 subsystem ID. The HDA bus is alive and the codec is identifying itself as exactly what's expected on this hardware. single_cmd=1 woke up the conversation. But the responses come back out-of-sync with what the controller's waiting for — flagged as spurious — so the init handshake never completes. Still no card.

Went from "codec dead" to "codec alive but talking out of step." Different problem. Hardware is confirmed alive, which was the big unknown.

Parking for tonight. Three things to try next session:
- snd_hda_intel.probe_mask=0x1 to only probe codec at addr 0 (skip the HDMI at addr 3) — cheapest fix attempt
- drop single_cmd, try DMA mode with bdl_pos_adj/position_fix timing tweaks
- boot fallback briefly for a comparison dmesg — would tell us if the codec-init failure is X230 hardware/BIOS or our build

That's it.

## 2026-05-22 (later)

Came back same day to try the three options. Spent the first hour reading kernel source instead of trying parameters. Best decision of the day.

The "spurious response" pattern was misleading me. Found it in `sound/hda/common/bind.c`:

```
static void request_codec_module(struct hda_codec *codec)
{
#ifdef MODULE
    ...
    if (mod)
        request_module(mod);
#endif
}
```

The entire body is `#ifdef MODULE`. That flag gets set per-object-file at compile time. bind.c lives in snd-hda-codec, gated by `CONFIG_SND_HDA`. With `CONFIG_SND_HDA=y` (what we had), snd-hda-codec is built into vmlinuz, `#ifdef MODULE` is false, and `request_codec_module` is an empty stub. The kernel literally never asks for any codec driver. The .ko files just sit there.

That's why rebuild #1 didn't fix anything. The codec drivers were the right thing to build but the wrong build target — `=m` instead of `=y`. Kconfig doesn't warn about the mismatch. `make olddefconfig` accepts it. Silent broken.

Fix: flip `SND_HDA_CODEC_REALTEK` + `_LIB` + `_CONEXANT` + `SND_HDA_GENERIC` from `=m` to `=y`. `olddefconfig` auto-promotes all the individual `ALC*` children because they have `default y if EXPERT` and the parent is now y. Rebuild took ~20 min this time (mostly relinks, not full recompiles). New vmlinuz 14.63 MB vs 14.52 from rebuild #1. Removed the now-stale codec .ko files from `/lib/modules/6.18.10/kernel/sound/hda/codecs/`.

Reboot. dmesg this time:

```
snd_hda_codec_alc269 hdaudioC0D0: ALC269VC: picked fixup for PCI SSID 17aa:21fa
snd_hda_codec_alc269 hdaudioC0D0: autoconfig for ALC269VC: line_outs=1 (0x14/0x0/0x0/0x0/0x0) type:speaker
input: HDA Intel PCH Headphone as ...
input: HDA Intel PCH Mic as ...
```

`aplay -l` shows `card 0: PCH [HDA Intel PCH], device 0: ALC269VC Analog`. 

speaker-test -f 440. ...still nothing.

Second bug, codec-side: Auto-Mute Mode. ALC269 ships with the codec auto-muting the speaker when it thinks a headphone is connected, and the jack-detect on this unit was reporting a phantom headphone. Disabled it via `amixer -c 0 sset 'Auto-Mute Mode' Disabled`, ran `alsactl store`. The `alsa-restore.service` + `90-alsa-restore.rules` udev wiring picks the saved state up on every boot now. Verified across a reboot.

Wrote the y/m gotcha up in `configs/build-notes/kernel-audio.md` and saved a reference memory so future-me doesn't repeat the misdiagnosis. Dropped `snd_hda_intel.single_cmd=1` from grub — that was a red herring all along, it doesn't change the codec's behavior, just shifts which code path logs "spurious response" when DMA-mode RIRB responses arrive without matching the driver's bookkeeping.

Also retired the UPower no-user-ns drop-in. `USER_NS=y` came with rebuild #1, so `PrivateUsers=yes` (upstream-hardened default) works again. UPower runs with the full security posture now.

Commits today: kernel rebuild #2 (`77d2889`) + upower retirement (`0d227b9`).

## 2026-05-23

A lot today. Audio working unlocked everything else.

### Nix

Installed Nix from the upstream installer, multi-user, `--no-channel-add` (flakes-first; don't want a stale nixpkgs channel sitting around). Pre-flight was clean — 205G free on /, systemd 259.1, USER_NS now in, all the standard tools present. Nix 2.34.7 install came down in a few minutes and `nix profile add nixpkgs#hello && hello` printed "Hello, world!"

Latent bero-os bug surfaced as a side effect. /etc/profile.d/nix.sh sources nix-daemon.sh which prepends `~/.nix-profile/bin` and `/nix/var/nix/profiles/default/bin` to PATH. But /etc/profile.d/path.sh ran AFTER it alphabetically and did `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` — absolute, no preserving — clobbering nix.sh's work. Root saw `nix` because something else in their interactive shell rebuilt PATH; `bero` got nothing.

Renamed path.sh → 00-path.sh so it sorts first and becomes the base; everything else (nix.sh, rustc.sh, anything future) safely prepends on top. Any drop-in that wants to extend PATH now Just Works. Would have bitten us on the next package too.

Enabled flakes in `/etc/nix/nix.conf`, restarted nix-daemon, smoke-tested with `nix profile add nixpkgs#hello && hello` as root and `nix profile add nixpkgs#cowsay && cowsay "bero-os has nix"` as `bero`. Multi-user genuinely works.

Commit: `875559f`.

### Wifi

Hardware was alive all along, just no profile. Intel Centrino Advanced-N 6205 AGN, iwlwifi + iwldvm modules loaded from rebuild #2 modules tree, firmware was already there from the early-batch firmware bundle. `nmcli device wifi list` saw 14+ networks on the first scan.

Told nmcli to connect to [home network] with the password I had — wpa_supplicant rejected it. Twice. Pulled the actual saved PSK from kwallet on this laptop via `kwallet-query kdewallet -f "Network Management" -r "{uuid};802-11-wireless-security"`. Real password is `[redacted]` — lowercase d, not capital D. Connected, got DHCP 10.100.102.11, ping 1.1.1.1 ≈ 3.8 ms.

Both ethernet (.5) and wifi (.11) up simultaneously, NM keeps both routes. Can unplug ethernet now.

### Panel + terminal title bar

Started looking at the top panel because it felt generic. Then noticed the bigger issue I'd been ignoring: xfce4-terminal opens with no title bar. No drag handle, no close button, just a borderless rectangle pinned to the corner of the screen.

Spent a while in the wrong place. The legacy terminalrc had `MiscBordersDefault=FALSE`. Flipped it to TRUE. Didn't help. Killed all running xfce4-terminal instances, opened fresh — still no title bar. Mousepad and Thunar both had decorations, so it wasn't xfwm4 being broken globally.

Found a second config: `/root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml` has its own `misc-borders-default = false` and it overrides the legacy terminalrc file silently. Flipped it via xfconf-query, opened a new terminal, the workshop title bar finally showed up.

For the panel itself, switched from top horizontal to a left vertical dock — "Workshop Rail." Whisker menu (with the bero-os mark as the menu icon), pinned launchers (terminal, thunar, mousepad, appfinder, later firefox), vertical icon-only tasklist, workspace pager, showdesktop, systray, stacked HH/MM clock, logout + lock buttons. Built xfce4-whiskermenu-plugin 2.10.0-dev from source (meson + ninja, ~5 min). Workshop dim background (`#4a463e`) so it reads warm-dark instead of pure black — found that the icons cover most of the panel area so the bg only shows in the gaps, widened the panel to 54 px so the color actually breathes.

End of the iteration the consensus was: it's fine for now but looks like an OS from 2002. Saved a feedback memory telling future-me to do research on modern dock patterns (macOS, Plasma Latte, GNOME Dash-to-Dock, COSMIC, Hyprland+Waybar) BEFORE the next visual iteration. Don't touch panel visuals without that research pass.

Commit: `b047954`.

### Repo on the box + Firefox + Claude Code

Pushed the day's work to github (`28d0646..b047954`). Cloned the repo onto bero-os at /root/Bero-OS — had to `ssh-keyscan github.com` first (bero-os didn't know the host key) then `ssh -A` to forward my agent. Quick.

Firefox via Nix: `nix profile add nixpkgs#firefox`. Came down from cache.nixos.org. Mozilla Firefox 151.0.1.

Claude Code via Nix: nixpkgs flags it as unfree (Anthropic ToS). First install needed `NIXPKGS_ALLOW_UNFREE=1 nix profile add --impure nixpkgs#claude-code`. `claude --version` → 2.1.146 (Claude Code). After verifying, set `allowUnfree=true` globally in `/root/.config/nixpkgs/config.nix` and mirrored to `/etc/skel` so future users inherit. Verified — `nix eval nixpkgs#claude-code.name` now works without the flag.

Pinned Firefox as a 5th launcher in the Workshop Rail and swapped the whisker icon to the dark logo variant (the regular one had a white bg that showed through on the dark panel — looked weird). Firefox shows as a generic gear icon in the dock because the system icon theme can't resolve Nix's `firefox` icon name, but clicking it fires up Firefox just fine. Cosmetic, will sort out properly when the panel gets redesigned.

Commit: `f76e794`.

Calling it. Audio works, wifi works, nix works, claude code works on the box, panel is "fine for now." Plenty to do tomorrow.
