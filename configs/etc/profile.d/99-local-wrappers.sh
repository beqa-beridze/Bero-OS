# Bero-OS: re-prepend /usr/local/bin AFTER nix.sh has prepended ~/.nix-profile/bin.
# This is so locally-installed wrapper scripts (e.g. /usr/local/bin/kitty wrapping
# nix's kitty via nixGLIntel) take precedence over the raw nix binaries.
# Must sort after nix.sh (which is in same dir, named "nix.sh").
case ":$PATH:" in
  *":/usr/local/bin:"*) PATH=/usr/local/bin:${PATH//:\/usr\/local\/bin/} ;;
  *) PATH=/usr/local/bin:$PATH ;;
esac
export PATH
