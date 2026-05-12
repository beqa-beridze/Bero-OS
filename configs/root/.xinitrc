#!/bin/sh
xrdb -merge /etc/X11/app-defaults/XTerm 2>/dev/null
xterm -geometry 80x25+10+10 -title "Bero-OS X11 OK" &
exec twm
