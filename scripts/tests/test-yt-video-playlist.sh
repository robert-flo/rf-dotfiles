#!/usr/bin/env bash
# ==============================================================================
# test-yt-video-playlist.sh — Tests automatizados de CLI para scripts/yt-video-playlist (sin red)
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
YT_PLAYLIST="$REPO_ROOT/scripts/yt-video-playlist"

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [PASS] %s\n' "$msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL] %s (esperado=%q, actual=%q)\n' "$msg" "$expected" "$actual" >&2
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [PASS] %s\n' "$msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL] %s (no contiene %q)\n' "$msg" "$needle" >&2
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [PASS] %s\n' "$msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL] %s (contiene %q inesperadamente)\n' "$msg" "$needle" >&2
  fi
}

TMP_WORK="$(mktemp -d)"
trap 'rm -rf "$TMP_WORK"' EXIT

MOCK_BIN="$TMP_WORK/bin"
mkdir -p "$MOCK_BIN"

# Mock yt-dlp configurable por variables de entorno:
# - MOCK_LOG: archivo donde registra cada invocación
# - MOCK_SUB_MODE: ok | 429_all | 429_fallback_ok
cat > "$MOCK_BIN/yt-dlp" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'CALL: %s\n' "$*" >> "${MOCK_LOG:?}"

is_flat=false
is_skip_download=false
is_print=false
dest_dir="."
use_android=false
prev=""
for a in "$@"; do
  case "$prev" in
    -P) dest_dir="$a" ;;
    --extractor-args)
      [[ "$a" == *"android"* ]] && use_android=true
      ;;
  esac
  [[ "$a" == "--flat-playlist" ]] && is_flat=true
  [[ "$a" == "--skip-download" ]] && is_skip_download=true
  [[ "$a" == "--print" ]] && is_print=true
  prev="$a"
done

if [[ "$is_flat" == true && "$is_print" == true ]]; then
  printf 'https://www.youtube.com/watch?v=vid001\n'
  printf 'https://www.youtube.com/watch?v=vid002\n'
  exit 0
fi

if [[ "$is_skip_download" == true ]]; then
  vid_id="mock"
  for a in "$@"; do
    if [[ "$a" =~ v=([A-Za-z0-9_-]+) ]]; then
      vid_id="${BASH_REMATCH[1]}"
    fi
  done
  case "${MOCK_SUB_MODE:-ok}" in
    ok)
      : > "$dest_dir/Mock Video [$vid_id].en.srt"
      exit 0
      ;;
    429_fallback_ok)
      if [[ "$use_android" == true ]]; then
        : > "$dest_dir/Mock Video [$vid_id].en.srt"
        exit 0
      fi
      echo "ERROR: Unable to download video subtitles for 'en': HTTP Error 429: Too Many Requests" >&2
      exit 1
      ;;
    429_all)
      echo "ERROR: Unable to download video subtitles for 'en': HTTP Error 429: Too Many Requests" >&2
      exit 1
      ;;
  esac
fi

exit 0
EOF
chmod +x "$MOCK_BIN/yt-dlp"

cat > "$MOCK_BIN/aria2c" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MOCK_BIN/aria2c"

export PATH="$MOCK_BIN:$PATH"
export YT_RETRY_SLEEP=0
export NO_COLOR=1
export XDG_STATE_HOME="$TMP_WORK/state"

PLAYLIST_URL="https://www.youtube.com/playlist?list=PLMock123"

echo "==> Test 1: Prompt único de perfil al inicio para toda la playlist + rechazo de Enter vacío"
DEST1="$TMP_WORK/dest1"
LOG1="$TMP_WORK/log1.txt"
mkdir -p "$DEST1"
OUT1="$(
  printf '\n1\n' | env YT_FORCE_INTERACTIVE=1 MOCK_LOG="$LOG1" MOCK_SUB_MODE=ok \
    "$YT_PLAYLIST" -P "$DEST1" "$PLAYLIST_URL" 2>&1
)"
PROMPT_COUNT="$(printf '%s\n' "$OUT1" | grep -c "Seleccioná el perfil de calidad para toda la playlist" || true)"
assert_eq "1" "$PROMPT_COUNT" "Pregunta el perfil una sola vez al inicio para toda la playlist"
assert_contains "$OUT1" "1) 1080p Estándar/Ligero" "Muestra opción 1 (Estándar/Ligero)"
assert_contains "$OUT1" "2) 1080p Premium" "Muestra opción 2 (Premium)"
assert_contains "$OUT1" "3) 720p" "Muestra opción 3 (720p)"
assert_contains "$OUT1" "Elección inválida" "Rechaza Enter vacío y re-pide opción"
assert_contains "$OUT1" "Perfil elegido: 1080p Estándar/Ligero" "Confirma perfil elegido"
assert_contains "$(cat "$LOG1")" "height<=1080" "Aplica tope <=1080p"
assert_contains "$(cat "$LOG1")" "protocol!*=m3u8" "Perfil estándar excluye HLS m3u8"

echo "==> Test 2: Flags rápidos --standard, --premium y --720p (sin prompt, con tope <=1080p)"
DEST2="$TMP_WORK/dest2"
mkdir -p "$DEST2"

LOG2A="$TMP_WORK/log2a.txt"
OUT2A="$(
  env YT_FORCE_INTERACTIVE=1 MOCK_LOG="$LOG2A" MOCK_SUB_MODE=ok \
    "$YT_PLAYLIST" --standard -P "$DEST2" "$PLAYLIST_URL" 2>&1
)"
assert_not_contains "$OUT2A" "Seleccioná el perfil de calidad" "--standard omite el menú"
assert_contains "$(cat "$LOG2A")" "bv*[height<=1080][protocol!*=m3u8]" "--standard usa selector <=1080p sin HLS"

LOG2B="$TMP_WORK/log2b.txt"
OUT2B="$(
  env YT_FORCE_INTERACTIVE=1 MOCK_LOG="$LOG2B" MOCK_SUB_MODE=ok \
    "$YT_PLAYLIST" --premium -P "$DEST2" "$PLAYLIST_URL" 2>&1
)"
assert_not_contains "$OUT2B" "Seleccioná el perfil de calidad" "--premium omite el menú"
assert_contains "$(cat "$LOG2B")" "-f bv*[height<=1080]+ba/b[height<=1080]" "--premium usa máxima calidad <=1080p"

LOG2C="$TMP_WORK/log2c.txt"
OUT2C="$(
  env YT_FORCE_INTERACTIVE=1 MOCK_LOG="$LOG2C" MOCK_SUB_MODE=ok \
    "$YT_PLAYLIST" --720p -P "$DEST2" "$PLAYLIST_URL" 2>&1
)"
assert_not_contains "$OUT2C" "Seleccioná el perfil de calidad" "--720p omite el menú"
assert_contains "$(cat "$LOG2C")" "bv*[height<=720]" "--720p usa tope 720p (<=1080p)"

echo "==> Test 3: Bypass del menú con -f explícito"
DEST3="$TMP_WORK/dest3"
LOG3="$TMP_WORK/log3.txt"
mkdir -p "$DEST3"
OUT3="$(
  env YT_FORCE_INTERACTIVE=1 MOCK_LOG="$LOG3" MOCK_SUB_MODE=ok \
    "$YT_PLAYLIST" -P "$DEST3" -f "137+251" "$PLAYLIST_URL" 2>&1
)"
assert_not_contains "$OUT3" "Seleccioná el perfil de calidad" "Hace bypass del menú cuando se pasa -f"
assert_contains "$(cat "$LOG3")" "-f 137+251" "Respeta el -f explícito del usuario"

echo "==> Test 4: Pre-chequeo de subtítulos ante 429 con rechazo interactivo ('n' aborta antes de bajar)"
DEST4="$TMP_WORK/dest4"
LOG4="$TMP_WORK/log4.txt"
mkdir -p "$DEST4"
set +e
OUT4="$(
  printf '2\nn\n' | env YT_FORCE_INTERACTIVE=1 MOCK_LOG="$LOG4" MOCK_SUB_MODE=429_all \
    "$YT_PLAYLIST" -P "$DEST4" "$PLAYLIST_URL" 2>&1
)"
RC4=$?
set -e
assert_eq "1" "$RC4" "Retorna código 1 si el usuario rechaza continuar sin subtítulos"
assert_contains "$OUT4" "HTTP Error 429" "Muestra el error 429 explícito"
assert_contains "$OUT4" "¿Continuar descargando el video sin estos subtítulos?" "Pide confirmación explícita"
assert_not_contains "$(cat "$LOG4")" "--merge-output-format mp4" "No descarga la playlist si el usuario cancela"

echo "==> Test 5: Modo no interactivo ante 429 avisa explícitamente y no usa --ignore-errors"
DEST5="$TMP_WORK/dest5"
LOG5="$TMP_WORK/log5.txt"
mkdir -p "$DEST5"
OUT5="$(
  env YT_FORCE_INTERACTIVE=0 MOCK_LOG="$LOG5" MOCK_SUB_MODE=429_all \
    "$YT_PLAYLIST" -P "$DEST5" "$PLAYLIST_URL" 2>&1
)"
assert_contains "$OUT5" "ERROR en subtítulos" "Reporta error de subtítulos explícitamente"
assert_contains "$OUT5" "Aviso (modo no interactivo): el video se descargará sin subtítulos" "Avisa explícitamente en modo no interactivo"
assert_contains "$OUT5" "sin subtítulos tras pre-chequeo anti-429" "Resume videos sin subtítulos explícitamente"
assert_not_contains "$(cat "$LOG5")" "--ignore-errors" "No oculta errores tras --ignore-errors"
assert_not_contains "$(cat "$LOG5")" "--embed-subs" "No intenta embeber subs cuando todos fallaron"

echo "==> Test 6: Mitigación 429 exitosa vía fallback android"
DEST6="$TMP_WORK/dest6"
LOG6="$TMP_WORK/log6.txt"
mkdir -p "$DEST6"
OUT6="$(
  env YT_FORCE_INTERACTIVE=0 MOCK_LOG="$LOG6" MOCK_SUB_MODE=429_fallback_ok \
    "$YT_PLAYLIST" --premium -P "$DEST6" "$PLAYLIST_URL" 2>&1
)"
assert_contains "$OUT6" "Reintentando con mitigación anti-429" "Activa reintento anti-429"
assert_contains "$OUT6" "Subtítulos listos: Mock Video [vid001].en.srt" "Recupera subtítulos vía fallback"
assert_contains "$(cat "$LOG6")" "--embed-subs" "Habilita --embed-subs tras recuperar subtítulos"

echo "----------------------------------------"
printf 'Resumen: %d PASS, %d FAIL\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
