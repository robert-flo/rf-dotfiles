#!/usr/bin/env bash
# Funciones compartidas de brief / brief-trend / brief-session.
# No imprime secretos. Solo lee PRIORIDAD_REPOS de brief.env (ignora el resto).
# shellcheck disable=SC2034

: "${ROBERTOS_TOOLS_ROOT:=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"

brief_paths() {
  ROBERTOS_CONFIG_DIR=${ROBERTOS_CONFIG_DIR:-"${XDG_CONFIG_HOME:-$HOME/.config}/robertos"}
  ROBERTOS_CACHE_DIR=${ROBERTOS_CACHE_DIR:-"${XDG_CACHE_HOME:-$HOME/.cache}/robertos"}
  ROBERTOS_DATA_DIR=${ROBERTOS_DATA_DIR:-"${XDG_DATA_HOME:-$HOME/.local/share}/robertos"}
  BRIEF_CACHE_TXT=${BRIEF_CACHE_TXT:-"$ROBERTOS_CACHE_DIR/brief.txt"}
  BRIEF_HISTORY_DIR=${BRIEF_HISTORY_DIR:-"$ROBERTOS_DATA_DIR/brief"}
  BRIEF_ENV_FILE=${BRIEF_ENV_FILE:-"$ROBERTOS_CONFIG_DIR/brief.env"}
  BRIEF_SCHEMA_VERSION=${BRIEF_SCHEMA_VERSION:-1}
  BRIEF_QUIET_DAYS=${ROBERTOS_QUIET_DAYS:-${GH_BRIEF_STALE_DAYS:-7}}
  BRIEF_CACHE_MAX_AGE_SEC=${ROBERTOS_CACHE_MAX_AGE_SEC:-3600}
  BRIEF_SESSION_MAX_BYTES=${ROBERTOS_SESSION_MAX_BYTES:-600}
  BRIEF_LOCK_MAX_AGE_SEC=${ROBERTOS_LOCK_MAX_AGE_SEC:-900}
  DEFAULT_PRIORIDAD_REPOS=${DEFAULT_PRIORIDAD_REPOS:-'robert-flo/funeraria-monte-tabor,robert-flo/funeraria-monte-tabor-*'}
  PRIORIDAD_REPOS=${PRIORIDAD_REPOS:-$DEFAULT_PRIORIDAD_REPOS}
}

brief_now_epoch() {
  if [[ -n ${ROBERTOS_NOW:-} ]]; then
    date -d "$ROBERTOS_NOW" +%s
  else
    date +%s
  fi
}

brief_today() {
  if [[ -n ${ROBERTOS_NOW:-} ]]; then
    date -d "$ROBERTOS_NOW" +%F
  else
    date +%F
  fi
}

brief_generated_at() {
  if [[ -n ${ROBERTOS_NOW:-} ]]; then
    date -d "$ROBERTOS_NOW" -Iseconds
  else
    date -Iseconds
  fi
}

brief_days_since() {
  local ts=$1
  echo $(( ( $(brief_now_epoch) - $(date -d "$ts" +%s) ) / 86400 ))
}

brief_age_label() {
  local d
  d=$(brief_days_since "$1")
  case $d in
    0) echo "hoy" ;;
    1) echo "ayer" ;;
    *) echo "hace ${d}d" ;;
  esac
}

# Solo PRIORIDAD_REPOS=; nunca volcar el archivo (podría tener otras claves).
brief_load_env() {
  local f=$BRIEF_ENV_FILE line val
  [[ -f $f ]] || return 0
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*# ]] && continue
    [[ $line =~ ^[[:space:]]*$ ]] && continue
    if [[ $line =~ ^[[:space:]]*PRIORIDAD_REPOS= ]]; then
      val=${line#*=}
      val=${val#"${val%%[![:space:]]*}"}
      if [[ $val == \"*\" ]]; then val=${val#\"}; val=${val%\"}; fi
      if [[ $val == \'*\' ]]; then val=${val#\'}; val=${val%\'}; fi
      PRIORIDAD_REPOS=$val
    fi
  done <"$f"
}

brief_split_patterns() {
  local IFS=',' p
  BRIEF_PATTERNS=()
  for p in $PRIORIDAD_REPOS; do
    p=${p#"${p%%[![:space:]]*}"}
    p=${p%"${p##*[![:space:]]}"}
    [[ -n $p ]] && BRIEF_PATTERNS+=("$p")
  done
}

brief_repo_is_priority() {
  local repo=$1 pat
  for pat in "${BRIEF_PATTERNS[@]}"; do
    # glob del patrón (p.ej. robert-flo/funeraria-monte-tabor-*)
    # shellcheck disable=SC2254
    case $repo in
      $pat) return 0 ;;
    esac
  done
  return 1
}

brief_atomic_write() {
  local dest=$1 tmp dir
  dir=$(dirname "$dest")
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/.tmp.XXXXXX")
  cat >"$tmp"
  mv -f "$tmp" "$dest"
}

brief_atomic_append_line() {
  local dest=$1 line=$2 tmp dir
  dir=$(dirname "$dest")
  mkdir -p "$dir"
  tmp=$(mktemp "$dir/.tmp.XXXXXX")
  if [[ -f $dest ]]; then
    cat "$dest" >"$tmp"
  fi
  printf '%s\n' "$line" >>"$tmp"
  mv -f "$tmp" "$dest"
}

brief_file_mtime() {
  local f=$1
  [[ -e $f ]] || { echo 0; return; }
  stat -c %Y "$f" 2>/dev/null || echo 0
}

brief_utf8_max_bytes() {
  local n=$1
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import sys
n=int(sys.argv[1])
data=sys.stdin.buffer.read()
if len(data)<=n:
    sys.stdout.buffer.write(data)
    raise SystemExit(0)
s=data[:n]
while s and (s[-1] & 0xC0) == 0x80:
    s=s[:-1]
if s and (s[-1] & 0xC0) == 0xC0:
    s=s[:-1]
sys.stdout.buffer.write(s)
' "$n"
  else
    head -c "$n"
  fi
}

brief_strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g;s/\x1B\]8;;[^\x07\x1B]*(\x07|\x1B\\)//g'
}

brief_short_repo() {
  local r=$1
  printf '%s' "${r#*/}"
}

brief_help_common() {
  cat <<'EOF'
Variables (todas opcionales):
  ROBERTOS_CONFIG_DIR  ROBERTOS_CACHE_DIR  ROBERTOS_DATA_DIR
  ROBERTOS_QUIET_DAYS  (default 7; también GH_BRIEF_STALE_DAYS)
  PRIORIDAD_REPOS      o ~/.config/robertos/brief.env
  ROBERTOS_NOW         reloj ficticio para tests (GNU date -d)
  ROBERTOS_BRIEF_TIMEOUT  segundos por llamada a gh (default 120; 0=sin timeout)
  NO_COLOR  GH_BRIEF_NO_LINKS  GH_BRIEF_WIDTH
EOF
}
