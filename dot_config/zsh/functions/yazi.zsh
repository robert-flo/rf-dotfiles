# Yazi wrapper that changes cwd on exit (exposed as both yazi and fm)
_yazi_cd() {
  local tmp
  tmp=$(mktemp -t "yazi-cwd.XXXXXX") || return
  command yazi "$@" --cwd-file="$tmp"
  if [[ -s "$tmp" ]]; then
    local cwd
    cwd=$(<"$tmp")
    if [[ -n "$cwd" && "$cwd" != "$PWD" && -d "$cwd" ]]; then
      cd -- "$cwd" || true
    fi
  fi
  rm -f -- "$tmp"
}

yazi() {
  _yazi_cd "$@"
}

fm() {
  _yazi_cd "$@"
}
