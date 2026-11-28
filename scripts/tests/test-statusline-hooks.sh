#!/usr/bin/env bash
# ==============================================================================
# test-statusline-hooks.sh — verifica que los hooks run_after de statusline
# (agy y cursor) corran en cada apply, reparen la configuración si la app
# recrea el JSON, conserven el resto de claves/permisos y sean idempotentes.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGY_HOOK="$REPO_ROOT/run_after_configure-agy-statusline.sh.tmpl"
CURSOR_HOOK="$REPO_ROOT/run_after_configure-cursor-statusline.sh.tmpl"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@" > /dev/null; then pass "$d"; else fail "$d"; fi; }

for tool in chezmoi jq; do
  command -v "$tool" >/dev/null || { echo "falta $tool" >&2; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fresh_home() { rm -rf "${WORK:?}/$1"; mkdir -p "$WORK/$1"; printf '%s' "$WORK/$1"; }
render_hook() {
  local tmpl="$1" h="$2" out="$3"
  HOME="$h" chezmoi execute-template --source="$REPO_ROOT" < "$tmpl" > "$out"
}

# --- Checks estáticos ---------------------------------------------------------
check "agy hook existe y es ejecutable" [ -x "$AGY_HOOK" ]
check "agy hook no es run_onchange" [ -z "$(basename "$AGY_HOOK" | grep -F onchange || true)" ]
check "agy hook sin rutas /home/ hardcodeadas" [ -z "$(grep -F '/home/' "$AGY_HOOK" || true)" ]
check "agy hook antiguo run_onchange eliminado" [ ! -e "$REPO_ROOT/run_onchange_after_configure-agy-statusline.sh.tmpl" ]

check "cursor hook existe y es ejecutable" [ -x "$CURSOR_HOOK" ]
check "cursor hook no es run_onchange" [ -z "$(basename "$CURSOR_HOOK" | grep -F onchange || true)" ]
check "cursor hook sin rutas /home/ hardcodeadas" [ -z "$(grep -F '/home/' "$CURSOR_HOOK" || true)" ]
check "cursor hook antiguo run_onchange eliminado" [ ! -e "$REPO_ROOT/run_onchange_after_configure-cursor-statusline.sh.tmpl" ]

# --- AGY: archivo ausente -----------------------------------------------------
h="$(fresh_home agy-missing)"
render_hook "$AGY_HOOK" "$h" "$h/hook.sh"
check "agy render sin placeholders" [ -z "$(grep -F '{{' "$h/hook.sh" || true)" ]
check "agy ausente: termina con 0" bash "$h/hook.sh"
cfg="$h/.gemini/antigravity-cli/settings.json"
check "agy ausente: crea settings.json con statusLine y colorScheme dark" \
  jq -e --arg cmd "$h/.config/agy/statusline.sh" \
  '.statusLine == {type: "command", command: $cmd, stack_with_default: false} and .colorScheme == "dark"' "$cfg"
check "agy ausente: permisos 600" [ "$(stat -c %a "$cfg")" == "600" ]

# --- AGY: archivo recreado sin statusLine (caso real) -------------------------
h="$(fresh_home agy-reset)"
mkdir -p "$h/.gemini/antigravity-cli"
cfg="$h/.gemini/antigravity-cli/settings.json"
cat > "$cfg" <<'JSON'
{
  "allowNonWorkspaceAccess": true,
  "toolPermission": "always-proceed",
  "trustedWorkspaces": ["/", "/tmp"]
}
JSON
chmod 600 "$cfg"
render_hook "$AGY_HOOK" "$h" "$h/hook.sh"
check "agy recreado: termina con 0" bash "$h/hook.sh"
check "agy recreado: inyecta statusLine" \
  jq -e --arg cmd "$h/.config/agy/statusline.sh" \
  '.statusLine == {type: "command", command: $cmd, stack_with_default: false}' "$cfg"
check "agy recreado: conserva claves existentes" \
  jq -e '.allowNonWorkspaceAccess == true and .toolPermission == "always-proceed" and (.trustedWorkspaces | length) == 2' "$cfg"
check "agy recreado: conserva permisos 600" [ "$(stat -c %a "$cfg")" == "600" ]

# --- AGY: idempotencia (no reescribe si ya coincide) --------------------------
inode1="$(stat -c %i "$cfg")"
sum1="$(sha256sum "$cfg")"
check "agy segunda corrida: termina con 0" bash "$h/hook.sh"
check "agy segunda corrida: mismo inode" [ "$inode1" == "$(stat -c %i "$cfg")" ]
check "agy segunda corrida: mismo contenido" [ "$sum1" == "$(sha256sum "$cfg")" ]

# --- AGY: JSON inválido no se trunca ------------------------------------------
h="$(fresh_home agy-invalid)"
mkdir -p "$h/.gemini/antigravity-cli"
cfg="$h/.gemini/antigravity-cli/settings.json"
printf '{"broken": ' > "$cfg"
bad_sum="$(sha256sum "$cfg")"
render_hook "$AGY_HOOK" "$h" "$h/hook.sh"
rc=0; bash "$h/hook.sh" >/dev/null 2>&1 || rc=$?
check "agy inválido: falla con código != 0" [ "$rc" -ne 0 ]
check "agy inválido: no modifica el archivo" [ "$bad_sum" == "$(sha256sum "$cfg")" ]

# --- CURSOR: dos archivos separados sin statusLine en ~/.cursor ---------------
h="$(fresh_home cursor-two-files)"
mkdir -p "$h/.cursor" "$h/.config/cursor"
echo '{"version":1,"attribution":{"attributeCommitsToAgent":false}}' > "$h/.cursor/cli-config.json"
echo '{"version":1}' > "$h/.config/cursor/cli-config.json"
chmod 644 "$h/.cursor/cli-config.json" "$h/.config/cursor/cli-config.json"
render_hook "$CURSOR_HOOK" "$h" "$h/hook.sh"
check "cursor render sin placeholders" [ -z "$(grep -F '{{' "$h/hook.sh" || true)" ]
check "cursor dos archivos: termina con 0" bash "$h/hook.sh"
check "cursor dos archivos: ~/.cursor/cli-config.json tiene statusLine" \
  jq -e --arg cmd "$h/.config/cursor/statusline.sh" '.statusLine == {type: "command", command: $cmd}' "$h/.cursor/cli-config.json"
check "cursor dos archivos: ~/.cursor conserva attribution" \
  jq -e '.attribution.attributeCommitsToAgent == false' "$h/.cursor/cli-config.json"
check "cursor dos archivos: ~/.config/cursor/cli-config.json tiene statusLine" \
  jq -e --arg cmd "$h/.config/cursor/statusline.sh" '.statusLine == {type: "command", command: $cmd}' "$h/.config/cursor/cli-config.json"

# --- CURSOR: idempotencia (no reescribe si ya coincide) -----------------------
c_inode1="$(stat -c %i "$h/.cursor/cli-config.json")"
c_inode2="$(stat -c %i "$h/.config/cursor/cli-config.json")"
check "cursor segunda corrida: termina con 0" bash "$h/hook.sh"
check "cursor segunda corrida: ~/.cursor mismo inode" [ "$c_inode1" == "$(stat -c %i "$h/.cursor/cli-config.json")" ]
check "cursor segunda corrida: ~/.config/cursor mismo inode" [ "$c_inode2" == "$(stat -c %i "$h/.config/cursor/cli-config.json")" ]

# --- CURSOR: archivo ausente crea symlink defensivo ---------------------------
h="$(fresh_home cursor-missing)"
render_hook "$CURSOR_HOOK" "$h" "$h/hook.sh"
check "cursor ausente: termina con 0" bash "$h/hook.sh"
check "cursor ausente: ~/.cursor/cli-config.json es symlink válido" [ -L "$h/.cursor/cli-config.json" ] && [ -e "$h/.cursor/cli-config.json" ]
check "cursor ausente: statusLine configurado" \
  jq -e --arg cmd "$h/.config/cursor/statusline.sh" '.statusLine == {type: "command", command: $cmd}' "$h/.cursor/cli-config.json"

# --- CURSOR: JSON inválido no se trunca ---------------------------------------
h="$(fresh_home cursor-invalid)"
mkdir -p "$h/.cursor"
printf '{"broken": ' > "$h/.cursor/cli-config.json"
bad_sum="$(sha256sum "$h/.cursor/cli-config.json")"
render_hook "$CURSOR_HOOK" "$h" "$h/hook.sh"
rc=0; bash "$h/hook.sh" >/dev/null 2>&1 || rc=$?
check "cursor inválido: falla con código != 0" [ "$rc" -ne 0 ]
check "cursor inválido: no modifica el archivo" [ "$bad_sum" == "$(sha256sum "$h/.cursor/cli-config.json")" ]

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
