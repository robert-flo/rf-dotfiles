#!/usr/bin/env bash
# Las máscaras de mako, swaync y dunst solo se aplican en clavis.
# El script de apply para esos daemons y no corre en omarchy.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/run_onchange_after_mask-notification-daemons.sh.tmpl"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@" > /dev/null; then pass "$d"; else fail "$d"; fi; }

command -v chezmoi > /dev/null || { echo "falta chezmoi" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

render() {
  CHEZMOI_PROFILE="$1" chezmoi execute-template --source="$REPO_ROOT" < "$SCRIPT" > "$WORK/script.sh"
}

check "la plantilla existe y es ejecutable" [ -x "$SCRIPT" ]
check "la plantilla no lleva rutas /home/<user> hardcodeadas" [ -z "$(grep -F '/home/' "$SCRIPT" || true)" ]

for unit in mako swaync dunst; do
  target="$REPO_ROOT/dot_config/systemd/user/symlink_${unit}.service"
  check "máscara de ${unit} apunta a /dev/null" [ "$(cat "$target")" = "/dev/null" ]
done

render clavis
check "render clavis sin placeholders" [ -z "$(grep -F '{{' "$WORK/script.sh" || true)" ]
check "render clavis para los tres daemons" grep -q 'systemctl --user stop mako.service swaync.service dunst.service' "$WORK/script.sh"

render omarchy
check "render omarchy sin placeholders" [ -z "$(grep -F '{{' "$WORK/script.sh" || true)" ]
check "render omarchy no para daemons" [ -z "$(grep -F 'systemctl --user stop' "$WORK/script.sh" || true)" ]
check "render omarchy sale sin hacer nada" grep -qx 'exit 0' "$WORK/script.sh"

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
