#!/usr/bin/env bash
# install-helix-tools (oxfmt) e install-hunk (hunk): node antes que la herramienta,
# idempotentes y con la política de fallo de make apply (RF_APPLY_FULL=1 sale != 0;
# chezmoi directo avisa y sale 0). Interfaz pública: salida, código de salida y las
# llamadas que reciben un mise falso.
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

REAL_CHEZMOI="$(command -v chezmoi || true)"
if [[ -z "$REAL_CHEZMOI" ]]; then
  printf '  [SKIP] sin chezmoi real para renderizar los scripts\n'
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

# mise falso. Estado en $MISE_STATE/node (node instalado). Cada llamada se anota.
#   MISE_FAIL_INSTALL=1  `mise install` falla (exit 7)
#   MISE_FAIL_USE=1      `mise use` falla (exit 9)
#   `mise use` exige node instalado, como el mise real con locked_scopes.
cat > "$tmp/bin/mise" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${MISE_LOG:?}"
case "$1" in
  where)
    [[ -f "${MISE_STATE:?}/node" ]] && exit 0
    exit 1
    ;;
  install)
    if [[ "${MISE_FAIL_INSTALL:-0}" == 1 ]]; then exit 7; fi
    : > "${MISE_STATE:?}/node"
    ;;
  use)
    if [[ "${MISE_FAIL_USE:-0}" == 1 ]]; then exit 9; fi
    if [[ ! -f "${MISE_STATE:?}/node" ]]; then
      echo "mise ERROR failed to resolve configured install dependency 'node@latest' while offline" >&2
      exit 1
    fi
    ;;
esac
EOF
chmod +x "$tmp/bin/mise"
export MISE_LOG="$tmp/mise.log" MISE_STATE="$tmp/state"

render() {
  "$REAL_CHEZMOI" execute-template -S "$REPO_ROOT" < "$REPO_ROOT/$1.tmpl" > "$tmp/$1"
}

# run_script <script> [VAR=valor...]: deja la salida en $out y el código en $code.
run_script() {
  local script="$1"
  shift
  set +e
  out="$(env -u RF_APPLY_FULL -u MISE_FAIL_INSTALL -u MISE_FAIL_USE "$@" PATH="$tmp/bin:$PATH" bash "$tmp/$script" 2>&1)"
  code=$?
  set -e
}

reset_state() {
  rm -rf "$MISE_STATE"
  mkdir -p "$MISE_STATE"
  : > "$MISE_LOG"
}

for pair in "run_onchange_after_install-helix-tools.sh:oxfmt" "run_onchange_after_install-hunk.sh:hunk"; do
  script="${pair%%:*}"
  tool="${pair##*:}"
  render "$script"
  printf '== %s (%s)\n' "$script" "$tool"

  # Usuario nuevo: sin node. node se instala antes que la herramienta.
  reset_state
  run_script "$script" RF_APPLY_FULL=1
  assert_eq "0" "$code" "$tool: usuario sin node, make apply sale 0"
  assert_not_contains "$out" "Aviso" "$tool: sin avisos de fallo"
  assert_eq $'where node@latest\ninstall --quiet node@latest\nuse -g --quiet '"$tool"'@latest' "$(cat "$MISE_LOG")" "$tool: node se instala antes que la herramienta"

  # Segunda corrida: node ya está, no hay trabajo redundante.
  : > "$MISE_LOG"
  run_script "$script" RF_APPLY_FULL=1
  assert_eq "0" "$code" "$tool: segunda corrida sale 0"
  assert_not_contains "$(cat "$MISE_LOG")" "install" "$tool: segunda corrida no reinstala node"
  assert_contains "$(cat "$MISE_LOG")" "use -g --quiet $tool@latest" "$tool: segunda corrida mantiene la herramienta"

  # La instalación de la herramienta falla.
  reset_state
  : > "$MISE_STATE/node"
  run_script "$script" RF_APPLY_FULL=1 MISE_FAIL_USE=1
  assert_ne "0" "$code" "$tool: make apply sale != 0 si falla la instalación"
  assert_contains "$out" "apply completo" "$tool: explica que es un fallo de apply completo"
  assert_contains "$out" "código 9" "$tool: conserva el código de mise"
  run_script "$script" MISE_FAIL_USE=1
  assert_eq "0" "$code" "$tool: chezmoi directo sigue tolerante si falla"
  assert_contains "$out" "Aviso" "$tool: chezmoi directo avisa del fallo"

  # La instalación de node falla.
  reset_state
  run_script "$script" RF_APPLY_FULL=1 MISE_FAIL_INSTALL=1
  assert_ne "0" "$code" "$tool: make apply sale != 0 si falla node"
  assert_contains "$out" "node" "$tool: nombra a node en el error"
  assert_not_contains "$(cat "$MISE_LOG")" "use" "$tool: sin node no intenta instalar la herramienta"
  run_script "$script" MISE_FAIL_INSTALL=1
  assert_eq "0" "$code" "$tool: chezmoi directo sigue tolerante si falla node"
  assert_contains "$out" "Aviso" "$tool: chezmoi directo avisa si falla node"

  # Sin mise: se omite sin fallar, también en make apply.
  set +e
  out="$(RF_APPLY_FULL=1 PATH=/nonexistent "$BASH" "$tmp/$script" 2>&1)"
  code=$?
  set -e
  assert_eq "0" "$code" "$tool: sin mise sale 0"
  assert_contains "$out" "Omitiendo" "$tool: sin mise conserva el aviso de omitir"
done

finish
