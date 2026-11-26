#!/usr/bin/env bash
# ravn-webapps se actualiza en cada apply: los .desktop no viven en los dotfiles.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/run_before_01-upgrade-ravn-webapps.sh.tmpl"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@" > /dev/null; then pass "$d"; else fail "$d"; fi; }

check "la plantilla existe y es ejecutable" [ -x "$SCRIPT" ]
check "corre en cada apply, no solo cuando cambia el texto" [ "$(basename "$SCRIPT")" = "run_before_01-upgrade-ravn-webapps.sh.tmpl" ]
check "no es run_onchange" [ -z "$(printf '%s' "$(basename "$SCRIPT")" | grep -F onchange || true)" ]
check "refresca la base y actualiza solo ravn-webapps" grep -q 'pacman -Sy --needed --noconfirm ravn-webapps' "$SCRIPT"
check "un fallo de pacman no aborta el apply" grep -q 'el apply sigue' "$SCRIPT"
check "sin rutas /home/<user> hardcodeadas" [ -z "$(grep -F '/home/' "$SCRIPT" || true)" ]

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
