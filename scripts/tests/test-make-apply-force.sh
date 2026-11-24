#!/usr/bin/env bash
# make apply y make apply-<perfil> son un apply completo: --force, sudo una sola
# vez con keepalive que no sobrevive, fallo previo sin terminal ni sudo sin
# contraseña, scripts que fallan sin sudo y re-ejecución de todos los run_onchange.
# make safe sigue siendo el camino prudente. Interfaz pública: salida y código de
# salida de make, y lo que reciben chezmoi y sudo falsos.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

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

assert_ne() {
  local unexpected="$1" actual="$2" msg="$3"
  if [[ "$unexpected" != "$actual" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [PASS] %s\n' "$msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL] %s (no debía ser %q)\n' "$msg" "$actual" >&2
  fi
}

finish() {
  printf '  %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
  if [[ "$FAIL_COUNT" -ne 0 ]]; then
    exit 1
  fi
}

tmp="$(mktemp -d)"
KEEPALIVE_PATTERN="$REPO_ROOT/scripts/rf-make-daily.sh sudo-keepalive"
cleanup() {
  pkill -f "$KEEPALIVE_PATTERN" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT
mkdir -p "$tmp/bin" "$tmp/prod"
REAL_CHEZMOI="$(command -v chezmoi || true)"

# chezmoi falso: registra cada invocación; `apply` puede tardar o fallar.
cat > "$tmp/bin/chezmoi" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'profile=%s full=%s args=%s\n' "${CHEZMOI_PROFILE-}" "${RF_APPLY_FULL-}" "$*" >> "${CHEZMOI_LOG:?}"
case " $* " in
  *" source-path "*) printf '%s\n' "${CHEZMOI_SOURCE:?}" ;;
  *" managed "*) printf '%s\n' "/home/test/01-install-packages.sh" "/home/test/install-spicetify.sh" ;;
  *" status "*) if [[ -f "${CHEZMOI_STATUS_FILE:-}" ]]; then cat "$CHEZMOI_STATUS_FILE"; fi ;;
  *" apply "*)
    printf '%s\n' "$PPID" > "${APPLY_PPID_FILE:?}"
    if [[ -n "${APPLY_SLEEP:-}" ]]; then sleep "$APPLY_SLEEP"; fi
    if [[ "${APPLY_FAIL:-0}" == 1 ]]; then exit 3; fi
    ;;
esac
EOF
# sudo falso. SUDO_MODE=nopass: todo pasa. password: -n falla hasta que -v lo
# autorice. deny: siempre falla.
cat > "$tmp/bin/sudo" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${SUDO_LOG:?}"
case "${SUDO_MODE:-nopass}" in
  nopass) exit 0 ;;
  deny) exit 1 ;;
  password)
    if [[ "$*" == "-v" ]]; then : > "${SUDO_OK:?}"; exit 0; fi
    [[ -f "${SUDO_OK:?}" ]] && exit 0
    exit 1
    ;;
esac
EOF
chmod +x "$tmp/bin/chezmoi" "$tmp/bin/sudo"
export PATH="$tmp/bin:$PATH"
export CHEZMOI_LOG="$tmp/chezmoi.log" SUDO_LOG="$tmp/sudo.log" SUDO_OK="$tmp/sudo.ok"
export APPLY_PPID_FILE="$tmp/apply.ppid"
export CHEZMOI_SOURCE="$tmp/prod" CHEZMOI_STATUS_FILE="$tmp/status.txt"
: > "$CHEZMOI_STATUS_FILE"

reset_logs() {
  : > "$CHEZMOI_LOG"
  : > "$SUDO_LOG"
  rm -f "$SUDO_OK" "$APPLY_PPID_FILE"
}

run_make() {
  make -C "$REPO_ROOT" "$@"
}

keepalive_count() {
  pgrep -fc "$KEEPALIVE_PATTERN" || true
}

wait_for_apply_start() {
  local _
  for _ in $(seq 1 50); do
    [[ -s "$APPLY_PPID_FILE" ]] && return 0
    sleep 0.1
  done
}

# --- DRY_RUN: muestra el comando con --force, no pide sudo ni toca chezmoi ---
reset_logs
out="$(DRY_RUN=1 SUDO_MODE=deny run_make apply)"
assert_contains "$out" "apply --force" "DRY_RUN apply muestra --force"
assert_contains "$out" "$REPO_ROOT" "DRY_RUN muestra el source"
out="$(DRY_RUN=1 SUDO_MODE=deny run_make apply-clavis)"
assert_contains "$out" "apply --force" "DRY_RUN apply-clavis muestra --force"
assert_contains "$out" "CHEZMOI_PROFILE=clavis" "DRY_RUN apply-clavis conserva el perfil"
assert_contains "$out" "state delete --bucket=entryState" "DRY_RUN anuncia el reset del estado de los run_onchange"
assert_eq "" "$(cat "$SUDO_LOG")" "DRY_RUN no ejecuta sudo"
assert_eq "" "$(cat "$CHEZMOI_LOG")" "DRY_RUN no invoca chezmoi (ni state ni apply)"

# --- apply de verdad: --force, RF_APPLY_FULL=1, reset de estado antes del apply ---
for target in apply apply-clavis apply-nyxuri apply-omarchy; do
  reset_logs
  SUDO_MODE=nopass run_make "$target" > /dev/null
  log="$(cat "$CHEZMOI_LOG")"
  assert_contains "$log" "full=1 args=apply --force -S $REPO_ROOT" "$target llama chezmoi apply --force con RF_APPLY_FULL=1"
  assert_contains "$log" "args=state delete --bucket=entryState --key=/home/test/01-install-packages.sh" "$target borra el estado de cada run_onchange (re-ejecuta todos)"
  assert_contains "$log" "args=state delete --bucket=entryState --key=/home/test/install-spicetify.sh" "$target borra el estado de todos los scripts, no solo de uno"
  assert_eq "apply" "$(grep -oE 'args=(state|apply)' <<< "$log" | tail -n1 | cut -d= -f2)" "$target borra el estado antes de aplicar (apply va al final)"
done
reset_logs
SUDO_MODE=nopass run_make apply-nyxuri > /dev/null
assert_contains "$(cat "$CHEZMOI_LOG")" "profile=nyxuri full=1 args=apply" "apply-nyxuri pasa CHEZMOI_PROFILE=nyxuri"

# --- sudo: sin contraseña no se pide; con contraseña se pide una sola vez ---
reset_logs
SUDO_MODE=nopass run_make apply-clavis > /dev/null
assert_not_contains "$(cat "$SUDO_LOG")" "-v" "con sudo sin contraseña no se pide sudo -v"

reset_logs
set +e
SUDO_MODE=password script -qec "make -C $REPO_ROOT apply-clavis" /dev/null > "$tmp/tty.out" 2>&1
code=$?
set -e
assert_eq "0" "$code" "con terminal y sudo con contraseña, apply-clavis termina bien"
assert_eq "1" "$(grep -cx -- '-v' "$SUDO_LOG")" "con terminal, sudo -v se pide una sola vez"
assert_contains "$(cat "$CHEZMOI_LOG")" "args=apply --force" "tras sudo -v se aplica"

# --- sin terminal y sin sudo sin contraseña: falla antes de tocar nada ---
reset_logs
set +e
out="$(SUDO_MODE=password setsid -w make -C "$REPO_ROOT" apply-clavis < /dev/null 2>&1)"
code=$?
set -e
assert_ne "0" "$code" "sin terminal y sin sudo sin contraseña, apply-clavis falla"
assert_contains "$out" "no hay terminal" "el mensaje explica que no hay terminal"
assert_contains "$out" "make safe" "el mensaje dice qué hacer"
assert_eq "" "$(cat "$CHEZMOI_LOG")" "falla antes de invocar chezmoi (no toca nada)"
assert_not_contains "$(cat "$SUDO_LOG")" "-v" "no intenta sudo -v sin terminal"

# --- keepalive: vive durante el apply y no queda después ---
assert_eq "0" "$(keepalive_count)" "no hay keepalive previo"
reset_logs
(APPLY_SLEEP=2 SUDO_MODE=nopass run_make apply-clavis > /dev/null 2>&1) &
bg=$!
wait_for_apply_start
script_pid="$(cat "$APPLY_PPID_FILE")"
assert_eq "1" "$(pgrep -fc "$KEEPALIVE_PATTERN $script_pid" || true)" "durante el apply hay un keepalive de sudo"
wait "$bg"
assert_eq "0" "$(keepalive_count)" "tras un apply exitoso no queda keepalive"

reset_logs
set +e
APPLY_FAIL=1 SUDO_MODE=nopass run_make apply-clavis > /dev/null 2>&1
code=$?
set -e
assert_ne "0" "$code" "si chezmoi apply falla, make falla"
assert_eq "0" "$(keepalive_count)" "tras un apply fallido no queda keepalive"

reset_logs
(APPLY_SLEEP=2 SUDO_MODE=nopass run_make apply-clavis > /dev/null 2>&1) &
bg=$!
wait_for_apply_start
kill -TERM "$(cat "$APPLY_PPID_FILE")"
set +e
wait "$bg"
code=$?
set -e
assert_ne "0" "$code" "un apply interrumpido (TERM) sale distinto de cero"
assert_eq "0" "$(keepalive_count)" "tras un apply interrumpido no queda keepalive"

reset_logs
(APPLY_SLEEP=1 SUDO_MODE=nopass run_make apply-clavis > /dev/null 2>&1) &
bg=$!
wait_for_apply_start
kill -KILL "$(cat "$APPLY_PPID_FILE")"
wait "$bg" 2>/dev/null || true
sleep 7
assert_eq "0" "$(keepalive_count)" "si matan el apply con KILL, el keepalive se va solo"

# --- la ayuda avisa que apply pisa y apunta a lose ---
help_out="$(run_make help)"
assert_contains "$help_out" "overwrites local changes" "make help dice que apply sobrescribe cambios locales"
assert_contains "$help_out" "make lose" "make help menciona make lose"
assert_contains "$help_out" "sudo once" "make help dice que apply pide sudo una vez"

reset_logs
out="$(SUDO_MODE=nopass run_make apply)"
assert_contains "$out" "make lose" "los Quick Actions de apply apuntan a make lose"

# --- safe sigue negándose con cambios locales, nunca pasa --force ni exige sudo ---
cat > "$CHEZMOI_STATUS_FILE" << 'EOF'
MM .config/clavis/ui-preferences.json
EOF
reset_logs
set +e
out="$(CHEZMOI_PROFILE=clavis run_make safe 2>&1)"
code=$?
set -e
assert_ne "0" "$code" "safe sale distinto de cero si lose no está vacío"
assert_contains "$out" ".config/clavis/ui-preferences.json" "safe lista lo que se perdería"
assert_not_contains "$(cat "$CHEZMOI_LOG")" "apply" "safe no llama apply con cambios locales"

: > "$CHEZMOI_STATUS_FILE"
reset_logs
SUDO_MODE=deny CHEZMOI_PROFILE=clavis run_make safe > /dev/null
assert_contains "$(cat "$CHEZMOI_LOG")" "args=apply" "safe aplica con lose vacío, aun sin sudo"
assert_not_contains "$(cat "$CHEZMOI_LOG")" "--force" "safe no pasa --force"
assert_not_contains "$(cat "$CHEZMOI_LOG")" "full=1" "safe no marca apply completo"
assert_not_contains "$(cat "$CHEZMOI_LOG")" "state delete" "safe no borra el estado de scripts"

# --- scripts: fallan sin sudo con RF_APPLY_FULL=1 y siguen tolerantes sin él ---
for tmpl in run_onchange_before_01-install-packages.sh.tmpl run_onchange_after_02-install-system-tools.sh.tmpl; do
  if [[ -z "$REAL_CHEZMOI" ]]; then
    printf '  [SKIP] sin chezmoi real para renderizar %s\n' "$tmpl"
    continue
  fi
  script="$tmp/${tmpl%.tmpl}"
  "$REAL_CHEZMOI" execute-template -S "$REPO_ROOT" < "$REPO_ROOT/$tmpl" > "$script"
  set +e
  out="$(SUDO_MODE=deny RF_APPLY_FULL=1 bash "$script" 2>&1)"
  code=$?
  set -e
  assert_ne "0" "$code" "$tmpl falla sin sudo cuando viene de make apply*"
  assert_contains "$out" "apply completo" "$tmpl explica por qué falla"
  set +e
  out="$(SUDO_MODE=deny env -u RF_APPLY_FULL bash "$script" 2>&1)"
  code=$?
  set -e
  assert_eq "0" "$code" "$tmpl sigue tolerante si chezmoi corre directo"
  assert_contains "$out" "Omitiendo" "$tmpl conserva el aviso de omitir"
done
for tmpl in run_onchange_before_01-install-packages.sh.tmpl run_onchange_after_02-install-system-tools.sh.tmpl run_onchange_after_install-spicetify.sh.tmpl; do
  assert_contains "$(cat "$REPO_ROOT/$tmpl")" 'RF_APPLY_FULL' "$tmpl distingue el apply completo"
done

finish
