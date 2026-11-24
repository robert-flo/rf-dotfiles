#!/usr/bin/env bash
# Costuras de make morning / lose / pull / status / diff.
# Interfaz pública: salida y código de salida de make, con un git temporal
# y un chezmoi falso. No se miran funciones internas del Makefile.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

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

finish() {
  printf '  %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
  if [[ "$FAIL_COUNT" -ne 0 ]]; then
    exit 1
  fi
}

git_id() {
  local repo="$1"
  git -C "$repo" config user.name "Roberto Flores"
  git -C "$repo" config user.email "25asab015@ujmd.edu.sv"
}

# Deja prod e invoker en el primer commit, y origin/master un commit adelante.
make_git_fixture() {
  local root="$1"
  git init -q -b master "$root/seed"
  git_id "$root/seed"
  printf 'uno\n' > "$root/seed/README"
  git -C "$root/seed" add README
  git -C "$root/seed" commit -q -m 'uno'
  git init -q --bare "$root/remote.git"
  git -C "$root/seed" remote add origin "$root/remote.git"
  git -C "$root/seed" push -q -u origin master
  git clone -q "$root/remote.git" "$root/prod"
  git_id "$root/prod"
  git clone -q "$root/remote.git" "$root/invoker"
  git_id "$root/invoker"
  printf 'dos\n' >> "$root/seed/README"
  git -C "$root/seed" commit -q -am 'dos'
  git -C "$root/seed" push -q origin master
}

write_fake_chezmoi() {
  local bin="$1"
  cat > "$bin/chezmoi" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'profile=%s args=%s\n' "${CHEZMOI_PROFILE-}" "$*" >> "${CHEZMOI_LOG:?}"
cmd=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --color=*|--no-pager|--file) shift ;;
    -S) shift 2 ;;
    *) cmd="$1"; shift; break ;;
  esac
done
case "$cmd" in
  source-path) printf '%s\n' "${CHEZMOI_SOURCE:?}" ;;
  status)
    if [[ -f "${CHEZMOI_STATUS_FILE:-}" ]]; then
      cat "$CHEZMOI_STATUS_FILE"
    fi
    ;;
  diff) printf 'DIFF\n' ;;
  apply)
    printf 'apply\n' >> "${CHEZMOI_ACTIONS:?}"
    printf 'apply-profile=%s\n' "${CHEZMOI_PROFILE-}" >> "${CHEZMOI_ACTIONS:?}"
    ;;
  execute-template) printf 'true\n' ;;
  *) ;;
esac
EOF
  chmod +x "$bin/chezmoi"
}

write_fake_sudo() {
  local bin="$1" code="$2"
  cat > "$bin/sudo" << EOF
#!/usr/bin/env bash
exit $code
EOF
  chmod +x "$bin/sudo"
}

run_make() {
  local invoker="$1"
  shift
  make -C "$invoker" -f "$REPO_ROOT/Makefile" -I "$REPO_ROOT" "$@"
}

# --- morning ---
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
make_git_fixture "$tmp"
mkdir -p "$tmp/bin"
write_fake_chezmoi "$tmp/bin"
write_fake_sudo "$tmp/bin" 0
export PATH="$tmp/bin:$PATH"
cat > "$tmp/status.txt" << 'EOF'
MM .config/clavis/ui-preferences.json
 D .config/zed/settings.json
A  .config/fish/config.fish
 R run_onchange_after_02-install-system-tools.sh
EOF
export CHEZMOI_LOG="$tmp/chezmoi.log"
export CHEZMOI_SOURCE="$tmp/prod"
export CHEZMOI_STATUS_FILE="$tmp/status.txt"
export CHEZMOI_ACTIONS="$tmp/actions.log"
: > "$CHEZMOI_LOG"
: > "$CHEZMOI_ACTIONS"

local_commit="$(git -C "$tmp/prod" rev-parse HEAD)"
out="$(CHEZMOI_PROFILE=clavis run_make "$tmp/invoker" morning)"
assert_contains "$out" "commit: $local_commit" "morning muestra el commit de la copia de producción"
assert_contains "$out" "behind: 1" "morning dice que la copia va un commit atrás de origin/master"
assert_contains "$out" "ahead: 0" "morning dice que la copia no va adelante de origin/master"
assert_contains "$out" "same: no" "morning dice que el commit no es el de origin/master"
assert_contains "$out" "fetch: yes" "morning pudo hacer fetch"
assert_contains "$out" "profile: clavis" "morning usa CHEZMOI_PROFILE cuando está puesto"
assert_contains "$out" "sudo: yes" "morning dice que sudo -n alcanza"
assert_contains "$out" ".config/clavis/ui-preferences.json" "morning lista un archivo del home que el apply pisaría"
assert_contains "$out" "run_onchange_after_02-install-system-tools.sh" "morning lista un script de sistema que se volvería a correr"

out="$(
  unset CHEZMOI_PROFILE
  run_make "$tmp/invoker" morning
)"
if [[ "$(id -un)" == "niri" ]]; then
  assert_contains "$out" "profile: clavis" "sin CHEZMOI_PROFILE, niri resuelve clavis"
else
  assert_contains "$out" "profile: " "morning imprime el perfil resuelto para $(id -un)"
fi

write_fake_sudo "$tmp/bin" 1
out="$(CHEZMOI_PROFILE=omarchy run_make "$tmp/invoker" morning)"
assert_contains "$out" "sudo: no" "morning dice que sudo -n no alcanza"
assert_contains "$out" "profile: omarchy" "morning respeta CHEZMOI_PROFILE=omarchy"

# --- lose ---
set +e
out="$(run_make "$tmp/invoker" lose)"
code=$?
set -e
assert_ne "0" "$code" "lose sale distinto de cero si hay archivos"
assert_contains "$out" ".config/clavis/ui-preferences.json" "lose lista ui-preferences"
assert_contains "$out" ".config/zed/settings.json" "lose lista settings de zed"
assert_not_contains "$out" ".config/fish/config.fish" "lose no lista un archivo que no cambia"
assert_not_contains "$out" "run_onchange_after_02-install-system-tools.sh" "lose no lista scripts que solo se volverían a correr"

: > "$tmp/status.txt"
set +e
out="$(run_make "$tmp/invoker" lose)"
code=$?
set -e
assert_eq "0" "$code" "lose sale cero cuando el status está vacío"
assert_not_contains "$out" ".config/" "lose vacío no imprime archivos del home"

# --- pull ---
old_prod="$(git -C "$tmp/prod" rev-parse HEAD)"
old_inv="$(git -C "$tmp/invoker" rev-parse HEAD)"
remote_tip="$(git -C "$tmp/seed" rev-parse HEAD)"
assert_ne "$remote_tip" "$old_prod" "el fixture deja la copia detrás del remoto"
: > "$CHEZMOI_ACTIONS"
DRY_RUN=1 run_make "$tmp/invoker" pull >/dev/null
assert_eq "$old_prod" "$(git -C "$tmp/prod" rev-parse HEAD)" "DRY_RUN=1 no mueve la copia de producción"
assert_eq "$old_inv" "$(git -C "$tmp/invoker" rev-parse HEAD)" "DRY_RUN=1 no mueve el clon invocador"
assert_not_contains "$(cat "$CHEZMOI_ACTIONS")" "apply" "DRY_RUN pull no llama apply"

run_make "$tmp/invoker" pull >/dev/null
assert_eq "$remote_tip" "$(git -C "$tmp/prod" rev-parse HEAD)" "pull deja la copia de producción en el commit del remoto"
assert_eq "$remote_tip" "$(git -C "$tmp/invoker" rev-parse HEAD)" "pull deja el otro clon en el commit del remoto"
assert_not_contains "$(cat "$CHEZMOI_ACTIONS")" "apply" "pull no invoca apply"
out="$(run_make "$tmp/invoker" morning)"
assert_contains "$out" "same: yes" "morning dice que la copia quedó en el mismo commit que origin/master"
assert_contains "$out" "behind: 0" "morning dice behind 0 cuando los commits coinciden"
assert_contains "$out" "ahead: 0" "morning dice ahead 0 cuando los commits coinciden"

git -C "$tmp/invoker" reset -q --hard "$old_inv"
export CHEZMOI_SOURCE="$tmp/invoker"
export GIT_LOG="$tmp/git.log"
: > "$GIT_LOG"
cat > "$tmp/bin/git" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${GIT_LOG:?}"
exec /usr/bin/git "$@"
EOF
chmod +x "$tmp/bin/git"
run_make "$tmp/invoker" pull >/dev/null
pulls="$(grep -c 'pull --rebase --autostash' "$GIT_LOG" || true)"
assert_eq "1" "$pulls" "si la copia y el clon son el mismo directorio, pull corre una sola vez"
assert_eq "$remote_tip" "$(git -C "$tmp/invoker" rev-parse HEAD)" "ese único pull deja el clon en el remoto"

# --- status / diff usan la copia de producción, no el directorio invocador ---
export CHEZMOI_SOURCE="$tmp/prod"
: > "$CHEZMOI_LOG"
run_make "$tmp/invoker" status >/dev/null
status_log="$(cat "$CHEZMOI_LOG")"
assert_contains "$status_log" "status" "status invoca chezmoi status"
assert_contains "$status_log" "-S $tmp/prod" "status usa la copia de producción"
assert_not_contains "$status_log" "-S $tmp/invoker" "status no usa el directorio invocador"

: > "$CHEZMOI_LOG"
run_make "$tmp/invoker" diff >/dev/null
diff_log="$(cat "$CHEZMOI_LOG")"
assert_contains "$diff_log" "diff" "diff invoca chezmoi diff"
assert_contains "$diff_log" "-S $tmp/prod" "diff usa la copia de producción"
assert_not_contains "$diff_log" "-S $tmp/invoker" "diff no usa el directorio invocador"

saved_url="$(git -C "$tmp/prod" remote get-url origin)"
git -C "$tmp/prod" remote set-url origin "$tmp/no-such-remote.git"
out="$(run_make "$tmp/invoker" morning)"
assert_contains "$out" "fetch: no" "morning sigue cuando el fetch no puede"
assert_contains "$out" "commit: " "sin fetch, morning igual muestra el commit local"
assert_contains "$out" "profile: " "sin fetch, morning igual muestra el perfil"
git -C "$tmp/prod" remote set-url origin "$saved_url"

# --- safe ---
cat > "$tmp/status.txt" << 'EOF'
MM .config/clavis/ui-preferences.json
 D .config/zed/settings.json
A  .config/fish/config.fish
 R run_onchange_after_02-install-system-tools.sh
EOF
: > "$CHEZMOI_ACTIONS"
set +e
out="$(CHEZMOI_PROFILE=clavis run_make "$tmp/invoker" safe)"
code=$?
set -e
assert_ne "0" "$code" "safe sale distinto de cero si hay archivos que perder"
assert_contains "$out" ".config/clavis/ui-preferences.json" "safe imprime la lista de lose"
assert_contains "$out" ".config/zed/settings.json" "safe imprime settings de zed"
assert_not_contains "$(cat "$CHEZMOI_ACTIONS")" "apply" "safe no llama apply si hay algo que perder"

: > "$tmp/status.txt"
: > "$CHEZMOI_ACTIONS"
: > "$CHEZMOI_LOG"
DRY_RUN=1 run_make "$tmp/invoker" safe >/dev/null
assert_not_contains "$(cat "$CHEZMOI_ACTIONS")" "apply" "DRY_RUN safe no llama apply"

: > "$CHEZMOI_ACTIONS"
: > "$CHEZMOI_LOG"
set +e
out="$(
  unset CHEZMOI_PROFILE
  run_make "$tmp/invoker" safe
)"
code=$?
set -e
assert_eq "0" "$code" "safe aplica cuando el status está vacío"
assert_contains "$(cat "$CHEZMOI_ACTIONS")" "apply" "safe llama apply con status vacío"
assert_contains "$(cat "$CHEZMOI_ACTIONS")" "apply-profile=clavis" "safe aplica con el perfil resuelto de niri"
assert_contains "$(cat "$CHEZMOI_LOG")" "-S $tmp/prod" "safe usa la copia de producción como source"
assert_not_contains "$(cat "$CHEZMOI_LOG")" "-S $tmp/invoker" "safe no aplica desde el directorio invocador"

# --- root ---
packages_tmpl="run_onchange_before_01-install-packages.sh.tmpl"
tools_tmpl="run_onchange_after_02-install-system-tools.sh.tmpl"
write_fake_sudo "$tmp/bin" 1
: > "$CHEZMOI_LOG"
: > "$CHEZMOI_ACTIONS"
set +e
out="$(run_make "$tmp/invoker" root)"
code=$?
set -e
assert_ne "0" "$code" "root sale distinto de cero si no hay sudo -n"
assert_contains "$out" "sudo: no" "root dice que sudo -n no está"
assert_contains "$out" "no instalada" "root no pretende que la raíz quedó instalada"
assert_not_contains "$(cat "$CHEZMOI_LOG")" "execute-template" "sin sudo, root no dispara scripts"
assert_not_contains "$(cat "$CHEZMOI_ACTIONS")" "apply" "sin sudo, root no aplica el home"

write_fake_sudo "$tmp/bin" 0
: > "$CHEZMOI_LOG"
: > "$CHEZMOI_ACTIONS"
out="$(DRY_RUN=1 run_make "$tmp/invoker" root)"
assert_contains "$out" "$packages_tmpl" "DRY_RUN root imprime el script de paquetes"
assert_contains "$out" "$tools_tmpl" "DRY_RUN root imprime el script de herramientas"
assert_not_contains "$(cat "$CHEZMOI_LOG")" "execute-template" "DRY_RUN root no ejecuta los scripts"
assert_not_contains "$(cat "$CHEZMOI_ACTIONS")" "apply" "DRY_RUN root no aplica el home"

: > "$CHEZMOI_LOG"
: > "$CHEZMOI_ACTIONS"
run_make "$tmp/invoker" root >/dev/null
root_log="$(cat "$CHEZMOI_LOG")"
assert_contains "$root_log" "execute-template" "root dispara execute-template"
assert_contains "$root_log" "$tmp/prod/$packages_tmpl" "root dispara el script de paquetes de la copia de producción"
assert_contains "$root_log" "$tmp/prod/$tools_tmpl" "root dispara el script de herramientas y el hook"
assert_not_contains "$(cat "$CHEZMOI_ACTIONS")" "apply" "root no aplica el árbol del home"

finish
