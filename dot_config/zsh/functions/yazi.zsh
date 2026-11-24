# Yazi wrapper that changes cwd on exit (exposed as yazi and fm)
yazi() {
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

alias fm='yazi'
