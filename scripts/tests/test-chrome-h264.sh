#!/usr/bin/env bash
# ==============================================================================
# test-chrome-h264.sh — Pruebas de dot_local/bin/executable_chrome-h264
#
# Sin abrir ventanas: un "Chrome" falso habla el protocolo --remote-debugging-pipe
# (fd 3 entra, fd 4 sale, JSON separado por NUL). Verifica que el lanzador pida
# auto-attach, inyecte el script antes de reanudar cada target, use un perfil
# dedicado y que --clean no deje residuos.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAUNCHER="$REPO_ROOT/dot_local/bin/executable_chrome-h264"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (esperado=$(printf '%q' "$1"), actual=$(printf '%q' "$2"))"; fi; }
# check "descripcion" comando...  → PASS si el comando sale con 0
check() { local d="$1"; shift; if "$@"; then pass "$d"; else fail "$d"; fi; }
assert_contains() { if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (no contiene $(printf '%q' "$2"))"; fi; }

TMP_WORK="$(mktemp -d)"
trap 'rm -rf "$TMP_WORK"' EXIT
export PYTHONDONTWRITEBYTECODE=1

check "el lanzador compila" python3 -B -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$LAUNCHER"

export CHROME_H264_PROFILE="$TMP_WORK/profiles"
export CHROME_H264_SCRIPT="$TMP_WORK/inject.js"
export CHROME_H264_BIN="$TMP_WORK/fake-chrome"
export LOG="$TMP_WORK/commands.log"
echo "/* MARCA-INYECTADA */" > "$CHROME_H264_SCRIPT"

# Chrome falso: anuncia un page, un worker y un iframe; registra lo que recibe y sale.
cat > "$CHROME_H264_BIN" << 'FAKE'
#!/usr/bin/env python3
import json, os, sys
log = open(os.environ["LOG"], "w")
log.write("ARGS " + " ".join(sys.argv[1:]) + "\n")
log.flush()
rd, wr = os.fdopen(3, "rb", 0), 4
buf = b""
def read_msg():
    global buf
    while b"\0" not in buf:
        chunk = rd.read(65536)
        if not chunk:
            return None
        buf += chunk
    raw, buf = buf.split(b"\0", 1)
    return json.loads(raw)
def emit(obj):
    os.write(wr, json.dumps(obj).encode() + b"\0")
first = read_msg()
log.write(f"CMD {first['method']}\n")
for sid, kind in (("S1", "page"), ("S2", "service_worker"), ("S3", "iframe")):
    emit({"method": "Target.attachedToTarget", "params": {"sessionId": sid, "waitingForDebugger": True,
          "targetInfo": {"type": kind, "url": "https://example.test/"}}})
resumed = 0
while resumed < 3:
    m = read_msg()
    if m is None:
        break
    src = m.get("params", {}).get("source", "")
    log.write(f"CMD {m['method']} {m.get('sessionId','-')} {'INJECT' if 'MARCA-INYECTADA' in src else ''}\n")
    log.flush()
    if m["method"] == "Runtime.runIfWaitingForDebugger":
        resumed += 1
sys.exit(7)
FAKE
chmod +x "$CHROME_H264_BIN"

set +e
"$LAUNCHER" --autoplay https://example.test/ 2> "$TMP_WORK/err"
rc=$?
set -e
out="$(cat "$LOG")"
assert_eq "7" "$rc" "el código de salida de Chrome se propaga"
assert_contains "$out" "--user-data-dir=$CHROME_H264_PROFILE/stable" "usa el perfil dedicado de stable"
assert_contains "$out" "--remote-debugging-pipe" "usa depuración por pipe (sin puerto TCP)"
assert_contains "$out" "https://example.test/" "pasa las URLs a Chrome"
assert_contains "$out" "--autoplay-policy=no-user-gesture-required" "--autoplay llega a Chrome"
assert_contains "$out" "CMD Target.setAutoAttach" "pide auto-attach en el navegador"
assert_contains "$out" "Page.addScriptToEvaluateOnNewDocument S1 INJECT" "inyecta el script en el page"
assert_contains "$out" "Page.addScriptToEvaluateOnNewDocument S3 INJECT" "inyecta el script en el iframe"
check "no inyecta en el service worker" [ "$out" = "${out/addScriptToEvaluateOnNewDocument S2/}" ]

# Orden: en cada sesión, el script va antes de reanudar.
for s in S1 S3; do
  inj="$(grep -n "addScriptToEvaluateOnNewDocument $s" "$LOG" | head -1 | cut -d: -f1 || true)"
  res="$(grep -n "Runtime.runIfWaitingForDebugger $s" "$LOG" | head -1 | cut -d: -f1 || true)"
  check "$s: inyecta" [ -n "$inj" ]; check "$s: reanuda después" [ "${inj:-99}" -lt "${res:-0}" ]
done
check "reanuda el worker sin inyectar" grep -q "Runtime.runIfWaitingForDebugger S2" "$LOG"

# Otro navegador: perfil propio, el stable no se toca.
set +e
"$LAUNCHER" -b edge https://example.test/ 2> "$TMP_WORK/err"
set -e
assert_contains "$(cat "$LOG")" "--user-data-dir=$CHROME_H264_PROFILE/edge" "-b edge usa su propio perfil"
check "-b edge no toca el perfil de stable" [ -d "$CHROME_H264_PROFILE/stable" ]
set +e
"$LAUNCHER" -b netscape 2> "$TMP_WORK/err"; rc=$?
set -e
assert_eq "2" "$rc" "un navegador desconocido termina con 2"

# --clean -b limpia solo ese navegador; --clean limpia todo y no deja residuos.
"$LAUNCHER" --clean -b edge 2> "$TMP_WORK/err"
check "--clean -b edge borra solo edge" [ ! -e "$CHROME_H264_PROFILE/edge" ]
check "--clean -b edge deja stable" [ -d "$CHROME_H264_PROFILE/stable" ]
check "crea el perfil dedicado" [ -d "$CHROME_H264_PROFILE/stable" ]
"$LAUNCHER" --clean 2> "$TMP_WORK/err"
check "--clean borra todos los perfiles y la carpeta" [ ! -e "$CHROME_H264_PROFILE" ]
"$LAUNCHER" --clean 2> "$TMP_WORK/err"
assert_contains "$(cat "$TMP_WORK/err")" "nada que limpiar" "--clean es idempotente"

# Falta el script inyectable.
rm -f "$CHROME_H264_SCRIPT"
set +e
"$LAUNCHER" 2> "$TMP_WORK/err"; rc=$?
set -e
assert_eq "1" "$rc" "sin h264only.js termina con 1"
assert_contains "$(cat "$TMP_WORK/err")" "falta" "sin h264only.js da mensaje claro"
check "no crea el perfil si falla antes" [ ! -e "$CHROME_H264_PROFILE" ]

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
