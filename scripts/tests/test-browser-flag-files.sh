#!/usr/bin/env bash
# ==============================================================================
# test-browser-flag-files.sh — Los archivos de flags de la familia Chromium
# comparten una sola base (dot_config/chrome-flags.conf). La única diferencia
# permitida es --load-extension de Omarchy en chromium, y solo en el perfil omarchy.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF="$REPO_ROOT/dot_config"
BASE="$CONF/chrome-flags.conf"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@"; then pass "$d"; else fail "$d"; fi; }

command -v chezmoi > /dev/null || { echo "falta chezmoi" >&2; exit 1; }

render_chromium() { CHEZMOI_PROFILE="$1" chezmoi execute-template < "$CONF/chromium-flags.conf.tmpl"; }
same() { diff -q "$1" "$2" > /dev/null; }

for f in brave-origin-flags.conf chrome-beta-flags.conf microsoft-edge-stable-flags.conf; do
  check "$f es idéntico a la base" same "$CONF/$f" "$BASE"
done

for profile in clavis nyxuri clavis-upstream; do
  check "chromium en $profile = base (sin extensiones de Omarchy)" \
    same <(render_chromium "$profile") "$BASE"
done

omarchy="$(render_chromium omarchy)"
check "chromium en omarchy empieza con la base" \
  [ "$(head -n "$(wc -l < "$BASE")" <<< "$omarchy")" = "$(cat "$BASE")" ]
extra="$(tail -n +"$(($(wc -l < "$BASE") + 1))" <<< "$omarchy")"
if [[ -z "$extra" ]]; then
  pass "chromium en omarchy sin extensiones: Omarchy no está instalado aquí"
else
  check "chromium en omarchy añade solo --load-extension con rutas de Omarchy" \
    grep -q -x -E -- '--load-extension=/usr/share/omarchy/default/chromium/extensions/[^ ]+' <<< "$extra"
  check "chromium en omarchy añade una sola línea" [ "$(wc -l <<< "$extra")" -eq 1 ]
fi

hardcoded="$(grep -l '/home/' "$CONF"/*flags.conf "$CONF"/chromium-flags.conf.tmpl || true)"
check "ningún archivo de flags lleva rutas /home/<user>" [ -z "$hardcoded" ]

# Flags que no existen en ningún binario instalado (verificado en #198).
for dead in --ozone-platform-hint CanvasOopRasterization WaylandWindowDecorations --process-per-site; do
  check "ya no queda $dead" [ -z "$(grep -l -- "$dead" "$CONF"/*flags.conf "$CONF"/chromium-flags.conf.tmpl || true)" ]
done

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
