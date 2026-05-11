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
