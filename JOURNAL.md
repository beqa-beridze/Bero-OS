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

Couple of small ruts:

xfce4-terminal upstream URL is .tar.xz, not .tar.bz2 as my old batch-4 note said. First wget hit a 404. Fixed and retried.

Red Hat Mono — github default branch is master not main. Repo also doesn't ship TTFs, only OTFs, and they live at fonts/Mono/RedHatMono/otf/ not the path APPLY-bero-os.md guessed. Took three wget attempts to land on the right tarball + path. Installed all 10 OTF faces (Regular, Medium, SemiBold, Bold + 4 italics + Light/LightItalic).

Also established that /root/ config files get mirrored to configs/root/ in the repo from this batch on. First time we've tracked /root/ in git.

That's it.
