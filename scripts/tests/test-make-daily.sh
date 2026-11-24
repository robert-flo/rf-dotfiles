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

assert_true() {
  local msg="$1"
  shift
  if "$@"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [PASS] %s\n' "$msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL] %s\n' "$msg" >&2
  fi
}

assert_false() {
  local msg="$1"
  shift
  if "$@"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL] %s\n' "$msg" >&2
  else
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [PASS] %s\n' "$msg"
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
src=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --color=*|--no-pager|--file) shift ;;
    -S) src="$2"; shift 2 ;;
    *) cmd="$1"; shift; break ;;
  esac
done
# Como el chezmoi real: una fuente que no existe es un error, no una lista vacía.
if [[ "$cmd" == status || "$cmd" == diff ]] && [[ -n "$src" && ! -d "$src" ]]; then
  printf 'chezmoi: stat %s: no such file or directory\n' "$src" >&2
  exit 1
fi
case "$cmd" in
  source-path) printf '%s\n' "${CHEZMOI_SOURCE:?}" ;;
  status)
    if [[ -n "${CHEZMOI_STATUS_FAIL:-}" ]]; then
      printf 'chezmoi: boom simulado\n' >&2
      exit "$CHEZMOI_STATUS_FAIL"
    fi
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
out="$(run_make "$tmp/invoker" lose 2>&1)"
code=$?
set -e
assert_eq "0" "$code" "lose sale 0 si hay archivos: la guía no es un error de make"
assert_not_contains "$out" "Error 1" "lose no imprime Error 1"
assert_contains "$out" "Qué hacer ahora" "lose dice qué hacer cuando hay archivos"
assert_contains "$out" "make diff" "lose apunta a make diff"
assert_contains "$out" "chezmoi re-add" "lose apunta a re-add"
assert_contains "$out" "make apply" "lose apunta a make apply"
assert_contains "$out" ".config/clavis/ui-preferences.json" "lose lista ui-preferences"
assert_contains "$out" ".config/zed/settings.json" "lose lista settings de zed"
assert_not_contains "$out" ".config/fish/config.fish" "lose no lista un archivo que no cambia"
assert_not_contains "$out" "run_onchange_after_02-install-system-tools.sh" "lose no lista scripts que solo se volverían a correr"

: > "$tmp/status.txt"
set +e
out="$(run_make "$tmp/invoker" lose 2>&1)"
code=$?
set -e
assert_eq "0" "$code" "lose sale cero cuando el status está vacío"
assert_contains "$out" "nada que perder" "lose vacío dice que no hay nada que perder"
assert_contains "$out" "make safe" "lose vacío apunta a make safe"
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

# --- sin ~/.local/share/chezmoi (niri-classic): source-path apunta a un directorio inexistente ---
# El invocador es un clon de rf-dotfiles (trae .chezmoiignore.tmpl): de ahí se cae.
git -C "$tmp/invoker" reset -q --hard "$old_inv"
: > "$tmp/invoker/.chezmoiignore.tmpl"
export CHEZMOI_SOURCE="$tmp/no-existe/chezmoi"
export RF_CENTRAL_SOURCE="$tmp/central-ausente"
cat > "$tmp/status.txt" << 'EOF_STATUS'
 M .config/zed/settings.json
EOF_STATUS
: > "$CHEZMOI_LOG"

out="$(run_make "$tmp/invoker" morning 2>&1)"
assert_contains "$out" "commit: " "sin enlace de chezmoi, morning funciona con el clon invocador"
assert_contains "$out" "uso $tmp/invoker" "morning avisa que usa el clon invocador"
assert_contains "$out" ".config/zed/settings.json" "morning sigue listando lo que se pisaría"
assert_contains "$out" "$tmp/no-existe/chezmoi) no existe" "morning dice qué fuente declarada no existe"

: > "$CHEZMOI_LOG"
run_make "$tmp/invoker" status >/dev/null 2>&1
assert_contains "$(cat "$CHEZMOI_LOG")" "-S $tmp/invoker" "sin enlace, status lee el clon invocador"
: > "$CHEZMOI_LOG"
run_make "$tmp/invoker" diff >/dev/null 2>&1
assert_contains "$(cat "$CHEZMOI_LOG")" "-S $tmp/invoker" "sin enlace, diff lee el clon invocador"

set +e
out="$(run_make "$tmp/invoker" lose 2>/dev/null)"
code=$?
set -e
assert_contains "$out" ".config/zed/settings.json" "sin enlace, lose lista los archivos desde el clon invocador"
assert_eq "0" "$code" "sin enlace, lose sale 0 con archivos: muestra la guía"
assert_contains "$out" "Qué hacer ahora" "sin enlace, lose dice qué hacer"

run_make "$tmp/invoker" pull >/dev/null 2>&1
assert_eq "$remote_tip" "$(git -C "$tmp/invoker" rev-parse HEAD)" "sin enlace, pull actualiza el clon invocador"

# Sin clon invocador válido cae a la copia central.
mkdir -p "$tmp/central" "$tmp/plain"
: > "$tmp/central/.chezmoiignore.tmpl"
export RF_CENTRAL_SOURCE="$tmp/central"
: > "$CHEZMOI_LOG"
run_make "$tmp/plain" status >/dev/null 2>&1 || true
rm -f "$tmp/invoker/.chezmoiignore.tmpl"
assert_contains "$(cat "$CHEZMOI_LOG")" "-S $tmp/central" "si el invocador no es un clon de dotfiles, usa la copia central"

# --- lose no miente cuando chezmoi falla ---
export CHEZMOI_SOURCE="$tmp/prod"
export CHEZMOI_STATUS_FAIL=7
: > "$tmp/status.txt"
set +e
out="$(run_make "$tmp/invoker" lose 2>&1)"
code=$?
set -e
assert_eq "2" "$code" "make lose con chezmoi roto falla (make propaga el 3 como Error 3 = exit 2 de make)"
assert_contains "$out" "chezmoi status falló (rc=7)" "lose dice el error real de chezmoi y su rc"
assert_contains "$out" "boom simulado" "lose muestra el stderr de chezmoi"
assert_not_contains "$out" "✓ nada que perder" "lose no declara «nada que perder» si chezmoi falló"
assert_not_contains "$out" "Qué hacer ahora" "lose no da la guía de archivos si chezmoi falló"
set +e
CHEZMOI_STATUS_FAIL=7 "$REPO_ROOT/scripts/rf-make-daily.sh" lose >/dev/null 2>&1
code=$?
set -e
assert_eq "3" "$code" "rf-make-daily.sh lose usa el código 3 para el error de chezmoi (distinto del 1 de «hay archivos»)"

printf 'MM .config/zed/settings.json\n' > "$tmp/status.txt"
unset CHEZMOI_STATUS_FAIL
set +e
"$REPO_ROOT/scripts/rf-make-daily.sh" lose >/dev/null 2>&1
code=$?
set -e
assert_eq "1" "$code" "con archivos que se pisarían, lose conserva el código 1"

# Con todo roto (sin fuente en ningún lado) lose falla con mensaje, sin lista inventada.
export CHEZMOI_SOURCE="$tmp/no-existe/chezmoi"
export RF_CENTRAL_SOURCE="$tmp/central-ausente"
: > "$CHEZMOI_ACTIONS"
set +e
out="$(cd "$tmp/plain" && "$REPO_ROOT/scripts/rf-make-daily.sh" lose 2>&1)"
code=$?
set -e
assert_eq "3" "$code" "sin ninguna fuente, lose sale con 3"
assert_contains "$out" "no encuentro la fuente de chezmoi" "sin ninguna fuente, lose explica qué falta"
assert_not_contains "$out" ".config/zed/settings.json" "sin ninguna fuente, lose no lista archivos"
set +e
out="$(run_make "$tmp/plain" safe 2>&1)"
code=$?
set -e
assert_ne "0" "$code" "make safe se detiene si lose no pudo averiguar nada"
assert_not_contains "$(cat "$CHEZMOI_ACTIONS")" "apply" "make safe no aplica si lose falló"

# --- enlace ~/.local/share/chezmoi -> copia central ---
export RF_CENTRAL_SOURCE="$tmp/central"
export RF_SOURCE_LINK="$tmp/home/.local/share/chezmoi"
export CHEZMOI_PROFILE=clavis
DRY_RUN=1 "$REPO_ROOT/scripts/rf-make-daily.sh" source-link > "$tmp/link.out"
assert_contains "$(cat "$tmp/link.out")" "[dry-run] ln -s $tmp/central $RF_SOURCE_LINK" "DRY_RUN=1 solo dice qué enlace crearía"
assert_false "DRY_RUN=1 no crea ni el directorio padre del enlace" test -e "$tmp/home"
"$REPO_ROOT/scripts/rf-make-daily.sh" source-link >/dev/null
assert_eq "$tmp/central" "$(readlink "$RF_SOURCE_LINK")" "source-link crea el enlace hacia la copia central"
"$REPO_ROOT/scripts/rf-make-daily.sh" source-link >/dev/null
assert_eq "$tmp/central" "$(readlink "$RF_SOURCE_LINK")" "source-link es idempotente"

rm -f "$RF_SOURCE_LINK"
mkdir -p "$RF_SOURCE_LINK"
printf 'mio\n' > "$RF_SOURCE_LINK/archivo"
"$REPO_ROOT/scripts/rf-make-daily.sh" source-link >/dev/null
assert_true "source-link nunca pisa un directorio real" test -d "$RF_SOURCE_LINK" -a ! -L "$RF_SOURCE_LINK" -a -f "$RF_SOURCE_LINK/archivo"

rm -rf "$RF_SOURCE_LINK"
ln -s "$tmp/otro-lado-roto" "$RF_SOURCE_LINK"
"$REPO_ROOT/scripts/rf-make-daily.sh" source-link >/dev/null
assert_eq "$tmp/otro-lado-roto" "$(readlink "$RF_SOURCE_LINK")" "source-link respeta un enlace existente aunque esté roto"

rm -f "$RF_SOURCE_LINK"
out="$(DRY_RUN=1 run_make "$tmp/invoker" apply 2>&1)"
assert_contains "$out" "[dry-run] ln -s $tmp/central $RF_SOURCE_LINK" "DRY_RUN apply anuncia el enlace"
assert_false "DRY_RUN apply no crea el enlace" test -e "$RF_SOURCE_LINK" -o -L "$RF_SOURCE_LINK"

# Los otros perfiles (omarchy, nyxuri) no reciben el enlace.
for other in omarchy nyxuri; do
  CHEZMOI_PROFILE="$other" "$REPO_ROOT/scripts/rf-make-daily.sh" source-link >/dev/null
  assert_false "el perfil $other no recibe el enlace" test -e "$RF_SOURCE_LINK" -o -L "$RF_SOURCE_LINK"
done
unset RF_SOURCE_LINK RF_CENTRAL_SOURCE

# --- status usa la ruta canónica de la fuente, no el enlace ---
# chezmoi guarda el hash del script ya renderizado. Si el script incluye
# .chezmoi.sourceDir, -S con el enlace y -S con la ruta real no son el mismo
# script: tras un apply por la ruta real, status por el enlace lista R.
canon="$tmp/canon-real"
canon_link="$tmp/canon-link"
canon_dest="$tmp/canon-dest"
canon_state="$tmp/canon-state.boltdb"
canon_cfg="$tmp/canon-chezmoi.toml"
mkdir -p "$canon" "$canon_dest"
printf 'original\n' > "$canon/dot_probe"
cat > "$canon/run_onchange_after_probe.sh.tmpl" << 'EOF'
#!/bin/sh
# {{ .chezmoi.sourceDir }}
exit 0
EOF
git -C "$canon" init -q -b master
git_id "$canon"
git -C "$canon" add dot_probe run_onchange_after_probe.sh.tmpl
git -C "$canon" commit -q -m 'fuente'
ln -s "$canon" "$canon_link"
: > "$canon_cfg"
/usr/bin/chezmoi --config "$canon_cfg" --color=false --refresh-externals=never \
  --persistent-state "$canon_state" -D "$canon_dest" apply --force -S "$canon" >/dev/null
printf 'cambiado\n' > "$canon_dest/.probe"
cat > "$tmp/bin/chezmoi-canon" << EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == source-path ]]; then
  printf '%s\n' '$canon_link'
  exit 0
fi
exec /usr/bin/chezmoi --config '$canon_cfg' --color=false --refresh-externals=never \\
  --persistent-state '$canon_state' -D '$canon_dest' "\$@"
EOF
chmod +x "$tmp/bin/chezmoi-canon"
out="$(CHEZMOI_BIN="$tmp/bin/chezmoi-canon" run_make "$tmp/invoker" status 2>&1)"
assert_contains "$out" "MM .probe" "status sigue mostrando MM si el archivo del home difiere"
assert_not_contains "$out" "probe.sh" "status no lista como R un script ya corrido por la ruta canónica"
out="$(CHEZMOI_BIN="$tmp/bin/chezmoi-canon" run_make "$tmp/invoker" morning 2>&1)"
assert_contains "$out" ".probe" "morning sigue listando el archivo del home que difiere"
assert_not_contains "$out" "probe.sh" "morning no lista el script cuando la fuente es el enlace a la ruta canónica"
out="$(CHEZMOI_BIN="$tmp/bin/chezmoi-canon" run_make "$tmp/invoker" diff 2>&1)"
assert_contains "$out" ".probe" "diff sigue mostrando el archivo del home que difiere"
assert_not_contains "$out" "new file" "diff no lista como archivo nuevo un script cuyo estado está en la ruta canónica"
assert_not_contains "$out" "probe.sh" "diff no nombra el script cuando la fuente es el enlace a la ruta canónica"

# --- safe / root pasan -S canónico (el enlace no sirve para renderizar) ---
safe_link="$tmp/safe-link"
ln -s "$tmp/prod" "$safe_link"
safe_real="$(readlink -f -- "$safe_link")"
export CHEZMOI_SOURCE="$safe_link"
: > "$tmp/status.txt"
: > "$CHEZMOI_ACTIONS"
out="$(DRY_RUN=1 CHEZMOI_PROFILE=clavis run_make "$tmp/invoker" safe 2>&1)"
assert_contains "$out" "apply -S $safe_real" "DRY_RUN safe muestra apply -S con la ruta canónica"
assert_not_contains "$out" "apply -S $safe_link" "DRY_RUN safe no pasa el enlace a apply -S"
out="$(DRY_RUN=1 run_make "$tmp/invoker" root 2>&1)"
assert_contains "$out" "execute-template --file $safe_real/" "DRY_RUN root renderiza desde la ruta canónica"
assert_contains "$out" "-S $safe_real" "DRY_RUN root pasa -S canónico"
assert_not_contains "$out" "-S $safe_link" "DRY_RUN root no pasa el enlace a -S"

finish
