#!/usr/bin/env bash
# make apply y make apply-<perfil> sobrescriben sin preguntar (--force);
# make safe sigue siendo el camino prudente y nunca pasa --force.
# Interfaz pública: salida de make y argumentos que recibe chezmoi (falso).
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
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/prod"

# chezmoi falso: registra cada invocación completa.
cat > "$tmp/bin/chezmoi" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'profile=%s args=%s\n' "${CHEZMOI_PROFILE-}" "$*" >> "${CHEZMOI_LOG:?}"
case " $* " in
  *" source-path "*) printf '%s\n' "${CHEZMOI_SOURCE:?}" ;;
  *" status "*) if [[ -f "${CHEZMOI_STATUS_FILE:-}" ]]; then cat "$CHEZMOI_STATUS_FILE"; fi ;;
esac
EOF
chmod +x "$tmp/bin/chezmoi"
export PATH="$tmp/bin:$PATH"
export CHEZMOI_LOG="$tmp/chezmoi.log"
export CHEZMOI_SOURCE="$tmp/prod"
export CHEZMOI_STATUS_FILE="$tmp/status.txt"
: > "$CHEZMOI_LOG"
: > "$CHEZMOI_STATUS_FILE"

run_make() {
  make -C "$REPO_ROOT" "$@"
}

# --- DRY_RUN muestra el comando con --force y no ejecuta chezmoi ---
out="$(DRY_RUN=1 run_make apply)"
assert_contains "$out" "apply --force" "DRY_RUN apply muestra --force"
out="$(DRY_RUN=1 run_make apply-clavis)"
assert_contains "$out" "apply --force" "DRY_RUN apply-clavis muestra --force"
assert_contains "$out" "CHEZMOI_PROFILE=clavis" "DRY_RUN apply-clavis conserva el perfil"
assert_contains "$out" "$REPO_ROOT" "DRY_RUN muestra el source"
if [[ -s "$CHEZMOI_LOG" ]]; then
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '  [FAIL] DRY_RUN no debe invocar chezmoi\n' >&2
else
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '  [PASS] DRY_RUN no invoca chezmoi\n'
fi

# --- apply de verdad pasa --force, en todos los perfiles ---
for target in apply apply-clavis apply-nyxuri apply-omarchy; do
  : > "$CHEZMOI_LOG"
  run_make "$target" > /dev/null
  log="$(cat "$CHEZMOI_LOG")"
  assert_contains "$log" "args=apply --force -S $REPO_ROOT" "$target llama chezmoi apply --force con el source del clon"
done

: > "$CHEZMOI_LOG"
run_make apply-nyxuri > /dev/null
assert_contains "$(cat "$CHEZMOI_LOG")" "profile=nyxuri" "apply-nyxuri pasa CHEZMOI_PROFILE=nyxuri"

# --- la ayuda avisa que apply pisa y apunta a lose ---
help_out="$(run_make help)"
assert_contains "$help_out" "overwrites local changes" "make help dice que apply sobrescribe cambios locales"
assert_contains "$help_out" "make lose" "make help menciona make lose"

out="$(run_make apply)"
assert_contains "$out" "make lose" "los Quick Actions de apply apuntan a make lose"

# --- safe sigue negándose con cambios locales y nunca pasa --force ---
cat > "$CHEZMOI_STATUS_FILE" << 'EOF'
MM .config/clavis/ui-preferences.json
EOF
: > "$CHEZMOI_LOG"
set +e
out="$(CHEZMOI_PROFILE=clavis run_make safe 2>&1)"
code=$?
set -e
assert_ne "0" "$code" "safe sale distinto de cero si lose no está vacío"
assert_contains "$out" ".config/clavis/ui-preferences.json" "safe lista lo que se perdería"
assert_not_contains "$(cat "$CHEZMOI_LOG")" "apply" "safe no llama apply con cambios locales"

: > "$CHEZMOI_STATUS_FILE"
: > "$CHEZMOI_LOG"
CHEZMOI_PROFILE=clavis run_make safe > /dev/null
assert_contains "$(cat "$CHEZMOI_LOG")" "apply" "safe aplica con lose vacío"
assert_not_contains "$(cat "$CHEZMOI_LOG")" "--force" "safe no pasa --force"

finish
