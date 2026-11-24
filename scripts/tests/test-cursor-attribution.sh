#!/usr/bin/env bash
# ==============================================================================
# test-cursor-attribution.sh — run_onchange_after_configure-cursor-attribution
# (HR-CLAVIS#208): attribution.attributeCommitsToAgent/attributePRsToAgent en
# false en el cli-config.json de Cursor, sin pisar el resto, idempotente y sin
# truncar un JSON inválido. Renderiza la plantilla con chezmoi contra un HOME
# temporal; no toca el HOME real.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/run_onchange_after_configure-cursor-attribution.sh.tmpl"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@" > /dev/null; then pass "$d"; else fail "$d"; fi; }

for tool in chezmoi jq; do command -v "$tool" > /dev/null || { echo "falta $tool" >&2; exit 1; }; done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# fresh_home <nombre>: HOME limpio en $WORK/<nombre>; render_to lo renderiza; run_script lo ejecuta.
fresh_home() { rm -rf "${WORK:?}/$1"; mkdir -p "$WORK/$1"; printf '%s' "$WORK/$1"; }
render_to() { HOME="$1" chezmoi execute-template --source="$REPO_ROOT" < "$SCRIPT" > "$1/script.sh"; }
run_script() { HOME="$1" bash "$1/script.sh"; }
run_quiet() { run_script "$1" > /dev/null; }
contains() { [[ "$1" == *"$2"* ]]; }
not_contains() { [[ "$1" != *"$2"* ]]; }
attr_false() { jq -e '.attribution.attributeCommitsToAgent == false and .attribution.attributePRsToAgent == false' "$1" > /dev/null; }

check "la plantilla existe y es ejecutable" [ -x "$SCRIPT" ]
check "la plantilla no lleva rutas /home/<user> hardcodeadas" [ -z "$(grep -F '/home/' "$SCRIPT" || true)" ]

# --- 1. archivo inexistente: se crea con attribution en false -------------------
h="$(fresh_home missing)"
render_to "$h"
check "render sin placeholders sin resolver" [ -z "$(grep -F '{{' "$h/script.sh" || true)" ]
check "archivo inexistente: el script termina con 0" run_quiet "$h"
check "archivo inexistente: ~/.cursor/cli-config.json existe" [ -e "$h/.cursor/cli-config.json" ]
check "archivo inexistente: attribution false/false" attr_false "$h/.cursor/cli-config.json"

# --- 2. attribution en true, resto intacto, formato de niri ---------------------
h="$(fresh_home true)"
mkdir -p "$h/.cursor"
cat > "$h/.cursor/cli-config.json" <<'JSON'
{
  "version": 1,
  "model": { "modelId": "gpt-5", "displayName": "GPT-5" },
  "permissions": { "allow": ["Shell(ls)"], "deny": [] },
  "attribution": { "attributeCommitsToAgent": true, "attributePRsToAgent": true, "otra": 7 },
  "statusLine": { "type": "command", "command": "/x/statusline.sh" }
}
JSON
chmod 600 "$h/.cursor/cli-config.json"
before_rest="$(jq -S 'del(.attribution.attributeCommitsToAgent, .attribution.attributePRsToAgent)' "$h/.cursor/cli-config.json")"
render_to "$h"
check "true->false: el script termina con 0" run_quiet "$h"
check "true->false: attribution false/false" attr_false "$h/.cursor/cli-config.json"
after_rest="$(jq -S 'del(.attribution.attributeCommitsToAgent, .attribution.attributePRsToAgent)' "$h/.cursor/cli-config.json")"
check "true->false: el resto del JSON (incluida otra clave de attribution) no cambió" [ "$before_rest" == "$after_rest" ]
check "true->false: conserva el modo del archivo" [ "$(stat -c %a "$h/.cursor/cli-config.json")" == "600" ]
check "true->false: no deja temporales" [ -z "$(find "$h" -name '*.tmp.*' || true)" ]

# --- 3. idempotencia: la segunda corrida no escribe -----------------------------
sum1="$(sha256sum "$h/.cursor/cli-config.json")"
inode1="$(stat -c %i "$h/.cursor/cli-config.json")"
out2="$(run_script "$h")"
check "segunda corrida: contenido idéntico" [ "$sum1" == "$(sha256sum "$h/.cursor/cli-config.json")" ]
check "segunda corrida: no reescribe el archivo (mismo inode)" [ "$inode1" == "$(stat -c %i "$h/.cursor/cli-config.json")" ]
check "segunda corrida: avisa que ya estaba desactivada" contains "$out2" "ya tiene la atribución desactivada"

# --- 4. JSON sin attribution ----------------------------------------------------
h="$(fresh_home noattr)"
mkdir -p "$h/.cursor"
echo '{"version":1,"model":{"modelId":"x"}}' > "$h/.cursor/cli-config.json"
render_to "$h"
check "sin attribution: el script termina con 0" run_quiet "$h"
check "sin attribution: attribution false/false" attr_false "$h/.cursor/cli-config.json"
check "sin attribution: conserva version y model" jq -e '.version == 1 and .model.modelId == "x"' "$h/.cursor/cli-config.json"

# --- 5. JSON inválido: falla con mensaje claro y sin truncar --------------------
h="$(fresh_home invalid)"
mkdir -p "$h/.cursor"
printf '{"version": 1, "model": ' > "$h/.cursor/cli-config.json"
invalid_sum="$(sha256sum "$h/.cursor/cli-config.json")"
render_to "$h"
rc=0
err="$(run_script "$h" 2>&1 > /dev/null)" || rc=$?
check "JSON inválido: sale distinto de 0" [ "$rc" -ne 0 ]
check "JSON inválido: el mensaje nombra el archivo y dice que no es JSON válido" contains "$err" "$h/.cursor/cli-config.json no es un JSON válido"
check "JSON inválido: el archivo queda byte a byte igual" [ "$invalid_sum" == "$(sha256sum "$h/.cursor/cli-config.json")" ]

# --- 6. un inválido en el otro archivo no deja el primero a medias --------------
h="$(fresh_home mixed)"
mkdir -p "$h/.cursor" "$h/.config/cursor"
echo '{"attribution":{"attributeCommitsToAgent":true,"attributePRsToAgent":true}}' > "$h/.cursor/cli-config.json"
printf 'no es json' > "$h/.config/cursor/cli-config.json"
mixed_sum="$(sha256sum "$h/.cursor/cli-config.json")"
render_to "$h"
rc=0
run_script "$h" > /dev/null 2>&1 || rc=$?
check "uno válido y otro inválido: sale distinto de 0" [ "$rc" -ne 0 ]
check "uno válido y otro inválido: no se modificó ninguno" [ "$mixed_sum" == "$(sha256sum "$h/.cursor/cli-config.json")" ]

# --- 7. ambos archivos distintos (niri): los dos quedan en false ----------------
h="$(fresh_home both)"
mkdir -p "$h/.cursor" "$h/.config/cursor"
echo '{"a":1,"attribution":{"attributeCommitsToAgent":true,"attributePRsToAgent":true}}' > "$h/.cursor/cli-config.json"
echo '{"statusLine":{"type":"command"}}' > "$h/.config/cursor/cli-config.json"
render_to "$h"
check "dos archivos: el script termina con 0" run_quiet "$h"
check "dos archivos: ~/.cursor en false" attr_false "$h/.cursor/cli-config.json"
check "dos archivos: ~/.config/cursor en false" attr_false "$h/.config/cursor/cli-config.json"
check "dos archivos: conservan sus claves propias" jq -e '.a == 1' "$h/.cursor/cli-config.json"
check "dos archivos: statusLine intacto" jq -e '.statusLine.type == "command"' "$h/.config/cursor/cli-config.json"

# --- 8. solo existe ~/.config/cursor (niri-classic): se enlaza y se arregla -----
h="$(fresh_home classic)"
mkdir -p "$h/.config/cursor"
echo '{"statusLine":{"type":"command","command":"/x"}}' > "$h/.config/cursor/cli-config.json"
render_to "$h"
check "solo ~/.config/cursor: el script termina con 0" run_quiet "$h"
check "solo ~/.config/cursor: ~/.cursor/cli-config.json es symlink al real" [ "$(readlink -f "$h/.cursor/cli-config.json")" == "$(readlink -f "$h/.config/cursor/cli-config.json")" ]
check "solo ~/.config/cursor: attribution false/false por ~/.cursor" attr_false "$h/.cursor/cli-config.json"
check "solo ~/.config/cursor: el symlink sigue siendo symlink tras escribir" [ -L "$h/.cursor/cli-config.json" ]
check "solo ~/.config/cursor: statusLine intacto" jq -e '.statusLine.command == "/x"' "$h/.config/cursor/cli-config.json"

# --- 9b. attribution que no es objeto: mensaje claro, archivo intacto -----------
h="$(fresh_home attrtype)"
mkdir -p "$h/.cursor"
echo '{"version":1,"attribution":true}' > "$h/.cursor/cli-config.json"
attrtype_sum="$(sha256sum "$h/.cursor/cli-config.json")"
render_to "$h"
rc=0
err="$(run_script "$h" 2>&1 > /dev/null)" || rc=$?
check "attribution no objeto: sale distinto de 0" [ "$rc" -ne 0 ]
check "attribution no objeto: mensaje claro" contains "$err" 'la clave "attribution" de'
check "attribution no objeto: sin errores crudos de jq" not_contains "$err" "Cannot index"
check "attribution no objeto: archivo intacto" [ "$attrtype_sum" == "$(sha256sum "$h/.cursor/cli-config.json")" ]

# --- 9. symlink roto en ~/.cursor -----------------------------------------------
h="$(fresh_home dangling)"
mkdir -p "$h/.cursor"
ln -s ../.config/cursor/cli-config.json "$h/.cursor/cli-config.json"
render_to "$h"
check "symlink roto: el script termina con 0" run_quiet "$h"
check "symlink roto: attribution false/false" attr_false "$h/.cursor/cli-config.json"

printf '  %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
