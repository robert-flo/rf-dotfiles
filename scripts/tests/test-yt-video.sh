#!/usr/bin/env bash
# ==============================================================================
# test-yt-video.sh — Tests automatizados de CLI para scripts/yt-video (sin red)
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
YT_VIDEO="$REPO_ROOT/scripts/yt-video"

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
# - MOCK_JSON_FILE: ruta al JSON de formatos
# - MOCK_LOG: ruta donde registra cada invocación
# - MOCK_SUB_MODE: ok | 429_all | 429_fallback_ok
cat > "$MOCK_BIN/yt-dlp" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'CALL: %s\n' "$*" >> "${MOCK_LOG:?}"

is_skip_download=false
is_json=false
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
  [[ "$a" == "--skip-download" ]] && is_skip_download=true
  [[ "$a" == "-J" ]] && is_json=true
  prev="$a"
done

if [[ "$is_json" == true ]]; then
  cat "${MOCK_JSON_FILE:?}"
  exit 0
fi

if [[ "$is_skip_download" == true ]]; then
  case "${MOCK_SUB_MODE:-ok}" in
    ok)
      : > "$dest_dir/Mock Video [mock123].en.srt"
      exit 0
      ;;
    429_fallback_ok)
      if [[ "$use_android" == true ]]; then
        : > "$dest_dir/Mock Video [mock123].en.srt"
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

# Stubs mínimos para aria2c/ffmpeg/deno si no hicieran falta
cat > "$MOCK_BIN/aria2c" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MOCK_BIN/aria2c"

MOCK_JSON="$TMP_WORK/formats.json"
cat > "$MOCK_JSON" << 'EOF'
{
  "title": "Mock Video",
  "duration": 1000,
  "formats": [
    {"format_id": "251", "ext": "webm", "vcodec": "none", "acodec": "opus", "abr": 128, "filesize": 16000000},
    {"format_id": "313", "ext": "webm", "width": 3840, "height": 2160, "vcodec": "vp9", "acodec": "none", "protocol": "https", "filesize": 900000000, "tbr": 7200},
    {"format_id": "137", "ext": "mp4", "width": 1920, "height": 1080, "vcodec": "avc1.640028", "acodec": "none", "protocol": "https", "filesize": 300000000, "tbr": 2400},
    {"format_id": "399", "ext": "mp4", "width": 1920, "height": 1080, "vcodec": "av01.0.08M.08", "acodec": "none", "protocol": "https", "filesize": 150000000, "tbr": 1200},
    {"format_id": "248", "ext": "webm", "width": 1920, "height": 1080, "vcodec": "vp9", "acodec": "none", "protocol": "https", "filesize": 200000000, "tbr": 1600},
    {"format_id": "616", "ext": "mp4", "width": 1920, "height": 1080, "vcodec": "vp09.00.40.08", "acodec": "none", "protocol": "m3u8_native", "format_note": "Premium", "tbr": 3800},
    {"format_id": "247", "ext": "webm", "width": 1280, "height": 720, "vcodec": "vp9", "acodec": "none", "protocol": "https", "filesize": 100000000, "tbr": 800},
    {"format_id": "136", "ext": "mp4", "width": 1280, "height": 720, "vcodec": "avc1.64001F", "acodec": "none", "protocol": "https", "filesize": 140000000, "tbr": 1100}
  ]
}
EOF

export PATH="$MOCK_BIN:$PATH"
export MOCK_JSON_FILE="$MOCK_JSON"
export YT_RETRY_SLEEP=0
export NO_COLOR=1

echo "==> Test 1: Orden del menú, exclusión >1080p, rechazo de Enter vacío y pre-chequeo exitoso"
DEST1="$TMP_WORK/dest1"
LOG1="$TMP_WORK/log1.txt"
mkdir -p "$DEST1"
OUT1="$(
  printf '\n2\n' | env YT_FORCE_INTERACTIVE=1 MOCK_LOG="$LOG1" MOCK_SUB_MODE=ok \
    "$YT_VIDEO" -P "$DEST1" "https://youtu.be/mock123" 2>&1
)"
assert_contains "$OUT1" "1) 1080p Premium (vp9, HLS m3u8)" "Opción 1 es 1080p Premium"
assert_contains "$OUT1" "2) 1080p (vp9, webm)" "Opción 2 es 1080p vp9"
assert_contains "$OUT1" "3) 1080p (av01, mp4)" "Opción 3 es 1080p av01"
assert_contains "$OUT1" "4) 1080p (h264, mp4)" "Opción 4 es 1080p h264"
assert_contains "$OUT1" "5) 720p (vp9, webm)" "Opción 5 es mejor 720p"
assert_not_contains "$OUT1" "2160" "Excluye formatos >1080p (2160p)"
assert_contains "$OUT1" "Elección inválida" "Rechaza Enter vacío y re-pide opción"
assert_contains "$OUT1" "Subtítulos listos: Mock Video [mock123].en.srt" "Informa descarga exitosa de subtítulos"
assert_contains "$(cat "$LOG1")" "-f 248+ba/b[height<=1080]" "Usa el format_id elegido (248) con tope <=1080p"

echo "==> Test 2: Bypass del menú con -f explícito"
DEST2="$TMP_WORK/dest2"
LOG2="$TMP_WORK/log2.txt"
mkdir -p "$DEST2"
OUT2="$(
  env YT_FORCE_INTERACTIVE=1 MOCK_LOG="$LOG2" MOCK_SUB_MODE=ok \
    "$YT_VIDEO" -P "$DEST2" -f "137+251" "https://youtu.be/mock123" 2>&1
)"
assert_not_contains "$OUT2" "Seleccioná la calidad de video" "Hace bypass del menú cuando se pasa -f"
assert_contains "$(cat "$LOG2")" "-f 137+251" "Respeta el -f explícito del usuario"

echo "==> Test 3: Flujo ante 429 con confirmación interactiva (rechazo 'n' aborta antes de bajar video)"
DEST3="$TMP_WORK/dest3"
LOG3="$TMP_WORK/log3.txt"
mkdir -p "$DEST3"
set +e
OUT3="$(
  printf 'n\n' | env YT_FORCE_INTERACTIVE=1 MOCK_LOG="$LOG3" MOCK_SUB_MODE=429_all \
    "$YT_VIDEO" -P "$DEST3" "https://youtu.be/mock123" 2>&1
)"
RC3=$?
set -e
assert_eq "1" "$RC3" "Retorna código 1 si el usuario rechaza continuar sin subtítulos"
assert_contains "$OUT3" "HTTP Error 429" "Muestra el error 429 explícito"
assert_contains "$OUT3" "¿Continuar descargando el video sin estos subtítulos?" "Pide confirmación explícita"
assert_not_contains "$(cat "$LOG3")" "--merge-output-format mp4" "No descarga el video si el usuario cancela"

echo "==> Test 4: Flujo ante 429 con confirmación interactiva ('s' continúa y elige calidad)"
DEST4="$TMP_WORK/dest4"
LOG4="$TMP_WORK/log4.txt"
mkdir -p "$DEST4"
OUT4="$(
  printf 's\n1\n' | env YT_FORCE_INTERACTIVE=1 MOCK_LOG="$LOG4" MOCK_SUB_MODE=429_all \
    "$YT_VIDEO" -P "$DEST4" "https://youtu.be/mock123" 2>&1
)"
assert_contains "$OUT4" "Continuando sin subtítulos por confirmación del usuario" "Confirma continuación tras 429"
assert_contains "$(cat "$LOG4")" "-f 616+ba/b[height<=1080]" "Descarga la opción 1 (616 Premium) tras confirmar"
assert_not_contains "$(cat "$LOG4")" "--embed-subs" "No intenta embeber subs cuando el pre-chequeo falló"

echo "==> Test 5: Modo no interactivo ante 429 avisa explícitamente (sin --ignore-errors)"
DEST5="$TMP_WORK/dest5"
LOG5="$TMP_WORK/log5.txt"
mkdir -p "$DEST5"
OUT5="$(
  env YT_FORCE_INTERACTIVE=0 MOCK_LOG="$LOG5" MOCK_SUB_MODE=429_all \
    "$YT_VIDEO" -P "$DEST5" "https://youtu.be/mock123" 2>&1
)"
assert_contains "$OUT5" "Aviso (modo no interactivo): el video se descargará sin subtítulos" "Avisa explícitamente en modo no interactivo"
assert_not_contains "$(cat "$LOG5")" "--ignore-errors" "No usa --ignore-errors"

echo "==> Test 6: Mitigación 429 exitosa vía fallback android"
DEST6="$TMP_WORK/dest6"
LOG6="$TMP_WORK/log6.txt"
mkdir -p "$DEST6"
OUT6="$(
  env YT_FORCE_INTERACTIVE=0 MOCK_LOG="$LOG6" MOCK_SUB_MODE=429_fallback_ok \
    "$YT_VIDEO" -P "$DEST6" "https://youtu.be/mock123" 2>&1
)"
assert_contains "$OUT6" "Reintentando con mitigación anti-429" "Activa reintento anti-429"
assert_contains "$OUT6" "Subtítulos listos: Mock Video [mock123].en.srt" "Recupera subtítulos vía fallback"

echo "----------------------------------------"
printf 'Resumen: %d PASS, %d FAIL\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
