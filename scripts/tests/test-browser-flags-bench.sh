#!/usr/bin/env bash
# ==============================================================================
# test-browser-flags-bench.sh — Pruebas de scripts/browser-flags-bench
#
# Sin abrir ventanas: usa un navegador falso. Verifica CLI, check-flags contra un
# binario de fixture, que el arnés descarte los flags que controla, que no deje
# archivos ni procesos al fallar (idempotencia) y que los helpers de Python compilen.
# Con BENCH_LIVE=1 además hace una corrida real corta con Chrome (abre ventanas).
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BENCH="$REPO_ROOT/scripts/browser-flags-bench"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }

assert_eq() {
  if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (esperado=$(printf '%q' "$1"), actual=$(printf '%q' "$2"))"; fi
}
assert_contains() {
  if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (no contiene $(printf '%q' "$2"))"; fi
}
assert_not_contains() {
  if [[ "$1" != *"$2"* ]]; then pass "$3"; else fail "$3 (contiene $(printf '%q' "$2") inesperadamente)"; fi
}

TMP_WORK="$(mktemp -d)"
trap 'rm -rf "$TMP_WORK"' EXIT
export TMPDIR="$TMP_WORK/tmp"
mkdir -p "$TMPDIR"
export NO_COLOR=1

# --- CLI ---------------------------------------------------------------------
out="$("$BENCH" --help)"
assert_contains "$out" "browser-flags-bench" "--help muestra el nombre"
assert_contains "$out" "check-flags" "--help documenta check-flags"

set +e
out="$("$BENCH" --bogus 2>&1)"; rc=$?
set -e
assert_eq "1" "$rc" "opción desconocida termina con 1"
assert_contains "$out" "opción desconocida" "opción desconocida da mensaje claro"

set +e
out="$("$BENCH" -f "$TMP_WORK/no-existe.conf" -b /bin/true 2>&1)"; rc=$?
set -e
assert_eq "1" "$rc" "archivo de flags inexistente termina con 1"
assert_contains "$out" "no existe el archivo de flags" "archivo de flags inexistente da mensaje claro"

# --- check-flags contra un binario de fixture --------------------------------
FAKE="$TMP_WORK/fake-browser"
cat > "$FAKE" << 'EOF'
#!/usr/bin/env bash
# Literales como los de un binario real: features con prefijo k, switches sin él.
# kRealFeature enable-real-switch ozone-platform
[[ "${1:-}" == "--version" ]] && echo "Fake 1.0"
exit 0
EOF
chmod +x "$FAKE"

cat > "$TMP_WORK/flags.conf" << 'EOF'
# comentario
--ozone-platform=wayland
--enable-real-switch
--dead-switch=1
--enable-features=RealFeature,DeadFeature:param/1
EOF

set +e
out="$("$BENCH" check-flags -b "$FAKE" -f "$TMP_WORK/flags.conf" 2>&1)"; rc=$?
set -e
assert_eq "1" "$rc" "check-flags falla si hay flags inexistentes"
assert_contains "$out" "OK      switch --ozone-platform" "switch existente marcado OK"
assert_contains "$out" "OK      switch --enable-real-switch" "switch existente (otro) marcado OK"
assert_contains "$out" "MISSING switch --dead-switch" "switch inexistente marcado MISSING"
assert_contains "$out" "OK      --enable-features RealFeature" "feature con literal kNombre marcado OK"
assert_contains "$out" "MISSING --enable-features DeadFeature" "feature inexistente marcado MISSING (sin :params)"
assert_contains "$out" "missing=2" "cuenta de faltantes correcta"

printf -- '--ozone-platform=wayland\n--enable-real-switch\n' > "$TMP_WORK/good.conf"
set +e
out="$("$BENCH" check-flags -b "$FAKE" -f "$TMP_WORK/good.conf" 2>&1)"; rc=$?
set -e
assert_eq "0" "$rc" "check-flags pasa si todos los flags existen"
assert_contains "$out" "missing=0" "sin faltantes"

# --- run con navegador falso: flags del arnés y limpieza ---------------------
STUB="$TMP_WORK/stub-browser"
cat > "$STUB" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STUB_LOG"
exec sleep 7311
EOF
chmod +x "$STUB"
export STUB_LOG="$TMP_WORK/stub-args.log"

cat > "$TMP_WORK/candidate.conf" << 'EOF'
--ozone-platform=wayland
--password-store=gnome-libsecret
--no-default-browser-check
--remote-debugging-port=1
--custom-candidate-flag
EOF

run_stub() {
  set +e
  "$BENCH" -b "$STUB" -f "$TMP_WORK/candidate.conf" --no-video --startup-timeout 2 2>&1
  set -e
}

if command -v wtype > /dev/null && command -v niri > /dev/null && command -v ffmpeg > /dev/null && command -v jq > /dev/null && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  out="$(run_stub)"
  assert_contains "$out" "no abrió el puerto de depuración" "navegador sin CDP falla con mensaje claro"
  args="$(cat "$STUB_LOG")"
  assert_contains "$args" "--user-data-dir=" "el arnés pasa su propio --user-data-dir"
  assert_contains "$args" "--remote-debugging-port=" "el arnés pasa su propio puerto de depuración"
  assert_contains "$args" "--password-store=basic" "el arnés fuerza password-store=basic"
  assert_not_contains "$args" "gnome-libsecret" "se descarta --password-store del candidato"
  assert_not_contains "$args" "--remote-debugging-port=1"$'\n' "se descarta el puerto de depuración del candidato"
  assert_contains "$args" "--custom-candidate-flag" "los flags candidatos llegan al navegador"
  assert_contains "$args" "--ozone-platform=wayland" "el flag de plataforma llega al navegador"

  leftovers="$(find "$TMPDIR" -mindepth 1 | wc -l)"
  assert_eq "0" "$leftovers" "no quedan archivos ni perfiles temporales tras fallar"
  set +e
  pgrep -f "sleep 7311" > /dev/null
  rc=$?
  set -e
  assert_eq "1" "$rc" "no queda ningún proceso del navegador falso"

  out="$(run_stub)"
  leftovers="$(find "$TMPDIR" -mindepth 1 | wc -l)"
  assert_eq "0" "$leftovers" "segunda corrida: sigue sin dejar archivos (idempotente)"
  assert_contains "$out" "no abrió el puerto de depuración" "segunda corrida: mismo resultado"
else
  printf '  [SKIP] corrida con navegador falso (faltan wtype, niri, ffmpeg, jq o sesión Wayland)\n'
fi

# --- Helpers de Python -------------------------------------------------------
if python3 -B -c 'import ast,sys; [ast.parse(open(f).read(), f) for f in sys.argv[1:]]' \
  "$REPO_ROOT"/scripts/lib/cdp.py "$REPO_ROOT"/scripts/lib/browser_probe.py; then
  pass "helpers de Python tienen sintaxis válida"
else
  fail "helpers de Python con error de sintaxis"
fi

# --- Corrida real opcional ---------------------------------------------------
if [[ "${BENCH_LIVE:-0}" == "1" ]]; then
  printf '  [LIVE] corrida real corta (abre ventanas de Chrome)...\n'
  if "$BENCH" -b /opt/google/chrome/chrome --codecs h264 --seconds 5 --warmup 3 --no-typing --json > "$TMP_WORK/live.json" 2> "$TMP_WORK/live.err"; then
    assert_eq "VaapiVideoDecoder" "$(jq -r '.video.h264.decoder' "$TMP_WORK/live.json")" "corrida real: H.264 usa VaapiVideoDecoder"
  else
    fail "corrida real falló: $(tail -3 "$TMP_WORK/live.err")"
  fi
  assert_eq "0" "$(find "$TMPDIR" -mindepth 1 | wc -l)" "corrida real: no deja archivos temporales"
fi

printf '\n  total: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
