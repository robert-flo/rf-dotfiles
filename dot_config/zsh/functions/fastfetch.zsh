# Run fastfetch rotating sequentially through .icon logos (0-indexed parity with Fish)
fastfetch() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --) break ;;
      --logo|--logo=*|-l|-l*)
        command fastfetch "$@"
        return $?
        ;;
    esac
  done

  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local logo_dir="$config_home/fastfetch/logo"
  local -a logos=()

  if [[ -d "$logo_dir" ]]; then
    local f
    for f in "$logo_dir"/*.icon(N); do
      [[ -f "$f" ]] && logos+=("$f")
    done
    logos=( "${(o)logos[@]}" )
  fi

  local total=${#logos}
  if (( total == 0 )); then
    command fastfetch "$@"
    return $?
  fi

  local cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  local cache_dir="$cache_home/fastfetch"
  local index_file="$cache_dir/logo-index"
  local idx=0

  if [[ -r "$index_file" ]]; then
    local raw_idx
    IFS= read -r raw_idx < "$index_file"
    [[ "$raw_idx" =~ ^[0-9]+$ ]] && idx=$(( raw_idx + 0 ))
  fi

  idx=$(( idx % total ))
  local logo="${logos[$(( idx + 1 ))]}"
  local next_idx=$(( (idx + 1) % total ))

  if mkdir -p "$cache_dir" 2>/dev/null; then
    printf '%s\n' "$next_idx" > "$index_file" 2>/dev/null
  fi

  command fastfetch --logo "$logo" --logo-type kitty "$@"
}
