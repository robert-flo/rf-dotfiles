#!/usr/bin/env bash
# La cubeta 3p se muestra como Claude y GPT. Las claves del JSON no cambian.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/dot_config/agy/executable_statusline.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@" > /dev/null; then pass "$d"; else fail "$d"; fi; }

check "el script existe y es ejecutable" [ -x "$SCRIPT" ]

payload='{"model":{"display_name":"Gemini 3.8 Flash (Medium)","effort":"medium"},"context_window":{"used_percentage":2},"workspace":{"current_dir":"/tmp/rf-dotfiles"},"quota":{"gemini-5h":{"remaining_fraction":0,"reset_in_seconds":6300},"gemini-weekly":{"remaining_fraction":0.74,"reset_in_seconds":590400},"3p-5h":{"remaining_fraction":1},"3p-weekly":{"remaining_fraction":0.4}}}'
out="$(printf '%s' "$payload" | "$SCRIPT")"
plain="$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')"

check "nombra Claude y GPT en la ventana de 5h" grep -q 'Claude y GPT, 5h disp.: 100%' <<<"$plain"
check "nombra Claude y GPT en la semanal" grep -q 'Claude y GPT, semanal disp.: 40%' <<<"$plain"
check "no imprime la etiqueta 3p" bash -c '! grep -q "3p" <<<"$plain"'

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
