# Bero-OS first-shell brand banner.
# Interactive shells only, once per session.
case $- in *i*) ;; *) return ;; esac
sentinel=/tmp/.bero-banner-${XDG_SESSION_ID:-$$}
[ -e "$sentinel" ] && return
: > "$sentinel"

R=$'\033[38;2;200;16;46m'
P=$'\033[38;2;233;220;193m'
M=$'\033[38;2;122;116;104m'
X=$'\033[0m'

printf '\n'
printf '   %s▮%s   %sbero-os%s\n' "$R" "$X" "$P" "$X"
printf '       %stwo prompts. one shell.%s\n' "$M" "$X"

if [ -r /usr/local/share/bero-os/workshop-wisdom.txt ]; then
  line=$(shuf -n 1 /usr/local/share/bero-os/workshop-wisdom.txt 2>/dev/null)
  [ -n "$line" ] && printf '       %s%s%s\n' "$M" "$line" "$X"
fi
printf '\n'
