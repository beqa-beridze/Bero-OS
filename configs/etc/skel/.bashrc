# Bero-OS user shell config (from /etc/skel/.bashrc)
# If not interactive, do nothing
[[ $- != *i* ]] && return

# Source brand prompt + banner
[ -r /etc/profile.d/bero-prompt.sh ] && . /etc/profile.d/bero-prompt.sh
[ -r /etc/profile.d/bero-banner.sh ] && . /etc/profile.d/bero-banner.sh
