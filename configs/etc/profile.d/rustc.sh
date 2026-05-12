pathprepend() {
  if ! echo "$PATH" | grep -q "(^|:)$1(:|$)"; then
    case ":$PATH:" in
      *":$1:"*) ;;
      *) PATH="$1${PATH:+:$PATH}" ;;
    esac
  fi
}
pathprepend /opt/rustc/bin
export PATH
