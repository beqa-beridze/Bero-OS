
# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
# End Nix


# Bero-OS aliases + shell polish (for non-login interactive shells like `su user`)
if [ -r /etc/profile.d/bero-shell.sh ]; then
    . /etc/profile.d/bero-shell.sh
fi
