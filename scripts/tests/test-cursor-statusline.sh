#!/usr/bin/env bash
# Las dos cubetas del plan se nombran, y la agotada va primero solo si este modelo la gasta.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/dot_config/cursor/executable_statusline.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@" > /dev/null; then pass "$d"; else fail "$d"; fi; }

command -v jq > /dev/null || { echo "falta jq" >&2; exit 1; }
check "el script existe y es ejecutable" [ -x "$SCRIPT" ]

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home/.cache/cursor-statusline"

now_ms=$(($(date +%s) * 1000))
cycle_end=$((now_ms + 7 * 86400000 + 2 * 3600000))
grok_reset=$((now_ms + 2 * 86400000 + 11 * 3600000))

write_cache() { # auto api grok
  jq -n \
    --argjson now "$now_ms" \
    --argjson auto "$1" --argjson api "$2" --argjson grok "$3" \
    --argjson cycle "$cycle_end" --argjson grok_reset "$grok_reset" \
    '{updated:$now, month_pct:0, auto_pct:$auto, api_pct:$api, cycle_end:$cycle,
      grok_pct:$grok, grok_reset_ms:$grok_reset, grok_available:true}' \
    >"$WORK/home/.cache/cursor-statusline/usage.json"
}

render() { # model_id display_name
  local payload
  payload=$(jq -n --arg id "$1" --arg name "$2" \
    '{model:{id:$id, display_name:$name}, context_window:{used_percentage:49},
      workspace:{current_dir:"/tmp"}, render_width_chars:200, session_id:"t"}')
  printf '%s' "$payload" | HOME="$WORK/home" XDG_CACHE_HOME="$WORK/home/.cache" "$SCRIPT"
}
plain() { sed 's/\x1b\[[0-9;]*m//g' <<<"$1"; }

write_cache 90 100 93
out=$(render "grok-4.7" "Grok 4.7 256K")
text=$(plain "$out")
check "Grok deja primero su cubeta, no la de Claude" grep -F -q "Auto, Composer y Grok queda 10% · Claude y otros: agotado · reset en 7d 2h" <<<"$text"
check "Grok.com va en su propia línea" grep -F -q "Grok.com queda 7% · reset en 2d 11h" <<<"$text"
check "90% usado se pinta de rojo" grep -F -q $'\033[31mAuto, Composer y Grok queda 10%' <<<"$out"

write_cache 90 100 93
out=$(render "claude-opus-4.7" "Claude Opus")
text=$(plain "$out")
check "Claude pone primero su cubeta agotada" grep -F -q "Claude y otros: agotado · Auto, Composer y Grok queda 10% · reset en 7d 2h" <<<"$text"

write_cache 100 40 10
out=$(render "composer-2.5" "Composer 2.5")
text=$(plain "$out")
check "Composer agotado va primero" grep -F -q "Auto, Composer y Grok: agotado · Claude y otros queda 60% · reset en 7d 2h" <<<"$text"
check "40% usado se pinta de verde" grep -F -q $'\033[32mClaude y otros queda 60%' <<<"$out"

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
