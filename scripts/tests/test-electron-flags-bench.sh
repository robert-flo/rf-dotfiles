#!/usr/bin/env bash
# ==============================================================================
# test-electron-flags-bench.sh — Pruebas de scripts/electron-flags-bench y de las
# decisiones de flags de VS Code, Antigravity IDE, Electron y Spotify (#199).
#
# Sin abrir ventanas: usa apps falsas. Verifica CLI, errores claros, que el arnés
# no deje directorios ni procesos al fallar (idempotencia), que los helpers de
# Python compilen y que los flags rechazados con evidencia no vuelvan a entrar.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BENCH="$REPO_ROOT/scripts/electron-flags-bench"
CONF="$REPO_ROOT/dot_config"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (esperado=$(printf '%q' "$1"), actual=$(printf '%q' "$2"))"; fi; }
assert_contains() { if [[ "$1" == *"$2"* ]]; then pass "$3"; else fail "$3 (no contiene $(printf '%q' "$2"))"; fi; }

TMP_WORK="$(mktemp -d)"
trap 'rm -rf "$TMP_WORK"' EXIT
export TMPDIR="$TMP_WORK/tmp"
mkdir -p "$TMPDIR"
export NO_COLOR=1

run() { set +e; OUT="$("$@" 2>&1)"; RC=$?; set -e; }

# --- CLI ---------------------------------------------------------------------
out="$("$BENCH" --help)"
assert_contains "$out" "electron-flags-bench" "--help muestra el nombre"
assert_contains "$out" "--no-env-hint" "--help documenta --no-env-hint"
assert_contains "$out" "spotify" "--help lista spotify"

run "$BENCH" --bogus
assert_eq "1" "$RC" "opción desconocida termina con 1"
assert_contains "$OUT" "opción desconocida" "opción desconocida da mensaje claro"

run "$BENCH"
assert_eq "1" "$RC" "sin --app termina con 1"
assert_contains "$OUT" "falta -a/--app" "sin --app da mensaje claro"

run "$BENCH" -a code -n 0
assert_eq "1" "$RC" "--windows 0 termina con 1"

run "$BENCH" -a code -f "$TMP_WORK/no-existe.conf"
assert_eq "1" "$RC" "archivo de flags inexistente termina con 1"
assert_contains "$OUT" "no existe el archivo de flags" "archivo de flags inexistente da mensaje claro"

run "$BENCH" -a nada
assert_eq "1" "$RC" "app desconocida termina con 1"
assert_contains "$OUT" "app desconocida" "app desconocida da mensaje claro"

run "$BENCH" -a spotify --typing
assert_eq "1" "$RC" "--typing con spotify termina con 1"

run "$BENCH" -a code --load
assert_eq "1" "$RC" "--load sin --cpu termina con 1"

# --- App falsa: el arnés no deja rastro al fallar ----------------------------
if command -v python3 > /dev/null && command -v curl > /dev/null && command -v wtype > /dev/null && command -v niri > /dev/null && command -v jq > /dev/null && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  FAKE="$TMP_WORK/fake-app"
  printf '#!/usr/bin/env bash\necho "fallo simulado" >&2\nexit 3\n' > "$FAKE"
  chmod +x "$FAKE"
  run env ELECTRON_BENCH_WRAPPER="$FAKE" "$BENCH" -a electron
  assert_eq "1" "$RC" "una app que muere antes del puerto termina con 1"
  assert_contains "$OUT" "fallo simulado" "el error incluye el log de la app"
  assert_eq "0" "$(find "$TMPDIR" -maxdepth 1 -name 'electron-flags-bench.*' | wc -l)" "no deja directorios temporales"

  # Una app que se separa a otra sesión (como el CLI de VS Code) y queda viva: stop_app la mata.
  DETACHED="$TMP_WORK/detached-app"
  cat > "$DETACHED" << 'EOS'
#!/usr/bin/env bash
setsid -f bash -c 'exec -a fake-electron-bench sleep 300' --remote-debugging-port=1 &
sleep 0.2
exit 0
EOS
  chmod +x "$DETACHED"
  run env ELECTRON_BENCH_WRAPPER="$DETACHED" "$BENCH" -a electron
  assert_eq "1" "$RC" "una app sin puerto de depuración termina con 1"
  assert_eq "0" "$(find "$TMPDIR" -maxdepth 1 -name 'electron-flags-bench.*' | wc -l)" "no deja directorios temporales (app separada)"
  assert_eq "0" "$(pgrep -fc fake-electron-bench || true)" "no deja procesos de la app separada"
else
  printf '  [SKIP] pruebas con app falsa: faltan python3, curl, wtype, niri, jq o sesión Wayland\n'
fi

# --- Helpers de Python -------------------------------------------------------
for f in electron_probe.py browser_probe.py cdp.py; do
  if python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$REPO_ROOT/scripts/lib/$f"; then
    pass "$f es Python válido"
  else
    fail "$f no compila"
  fi
done

# --- Decisiones de flags (evidencia en #199) ---------------------------------
# Spotify (CEF) ignora ELECTRON_OZONE_PLATFORM_HINT: sin este flag corre en XWayland.
assert_eq "--ozone-platform=wayland" "$(grep -v '^#' "$CONF/spotify-flags.conf" | tr -d '[:space:]')" \
  "spotify-flags.conf conserva solo --ozone-platform=wayland"

# Rechazados con evidencia (#199): no entran en el archivo de Spotify ni en los de VS Code,
# Antigravity IDE o Electron (hoy no existen: la variable de sesión basta). Se ignoran comentarios
# y se compara el flag completo, no una subcadena.
for rejected in --no-sandbox --disable-gpu --disable-gpu-sandbox --enable-wayland-ime --ozone-platform-hint; do
  hits=""
  for f in spotify code antigravity-ide electron; do
    [[ -f "$CONF/$f-flags.conf" ]] || continue
    if grep -v '^[[:space:]]*#' "$CONF/$f-flags.conf" | grep -qE -- "^[[:space:]]*${rejected}([=[:space:]]|$)"; then hits+="$f "; fi
  done
  assert_eq "" "$hits" "ningún archivo de flags de Electron/Spotify lleva $rejected"
done

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
