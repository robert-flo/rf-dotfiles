# shellcheck shell=bash
# Wrapper for fastfetch that rotates sequentially (round-robin) through .icon logos.

fastfetch() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --)
        break
        ;;
      --logo|--logo=*|-l|-l*)
        command fastfetch "$@"
        return
        ;;
    esac
  done

  local logo_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/logo"
  local -a logos=()
  local f
  if [[ -d "$logo_dir" ]]; then
    while IFS= read -r f; do
      [[ -f "$f" ]] && logos+=("$f")
    done < <(LC_ALL=C printf '%s\n' "$logo_dir"/*.icon | LC_ALL=C sort)
  fi

  local total="${#logos[@]}"
  if (( total == 0 )); then
    command fastfetch "$@"
    return
  fi

  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/fastfetch"
  local index_file="$cache_dir/logo-index"
  local idx=0
  if [[ -r "$index_file" ]]; then
    IFS= read -r idx < "$index_file" || idx=0
  fi
  if [[ ! "$idx" =~ ^[0-9]+$ ]]; then
    idx=0
  fi

  idx=$(( 10#$idx % total ))
  local logo="${logos[$idx]}"
  local next_idx=$(( (idx + 1) % total ))

  if mkdir -p "$cache_dir" 2>/dev/null; then
    printf '%s\n' "$next_idx" > "$index_file" 2>/dev/null || true
  fi

  command fastfetch --logo "$logo" --logo-type kitty "$@"
}
