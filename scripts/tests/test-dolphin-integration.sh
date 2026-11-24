#!/usr/bin/env bash
# ==============================================================================
# test-dolphin-integration.sh — Integración de Dolphin en el perfil niri/Clavis (#200).
#
# Sin abrir ventanas. Verifica que los paquetes viven solo en el manifiesto único,
# que el prefijo del menú de aplicaciones solo llega al perfil clavis, que el script
# de ksycoca es inerte fuera de clavis y que la variable global del tema de Qt y el
# gestor de carpetas por defecto no cambian.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="$REPO_ROOT/.chezmoidata/packages.json"
ENV_FILE="$REPO_ROOT/dot_config/environment.d/40-xdg-menu.conf"
SCRIPT="$REPO_ROOT/run_onchange_after_03-rebuild-ksycoca.sh.tmpl"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@"; then pass "$d"; else fail "$d"; fi; }

for tool in chezmoi jq; do command -v "$tool" > /dev/null || { echo "falta $tool" >&2; exit 1; }; done

# --- Paquetes: solo en el manifiesto único -------------------------------------
# shellcheck disable=SC2016
in_manifest() { jq -e --arg p "$1" '.packages.official | index($p) != null' "$MANIFEST" > /dev/null; }
PKGS=(archlinux-xdg-menu breeze-icons dolphin ffmpegthumbs kde-cli-tools kdegraphics-thumbnailers)
for pkg in "${PKGS[@]}"; do
  check "$pkg está en packages.json (official)" in_manifest "$pkg"
  others="$(cd "$REPO_ROOT" && grep -rIl -w --exclude-dir=.git --exclude=.git --exclude-dir=tests --exclude=packages.json --exclude=AGENTS.md --exclude=40-xdg-menu.conf --exclude=run_onchange_after_03-rebuild-ksycoca.sh.tmpl -- "$pkg" . || true)"
  check "ningún otro archivo lista $pkg" [ -z "$others" ]
done
check "packages.json no repite paquetes" [ "$(jq -r '.packages | to_entries[] | .value[]' "$MANIFEST" | sort | uniq -d | wc -l)" -eq 0 ]

# --- Prefijo del menú: solo perfil clavis --------------------------------------
check "40-xdg-menu.conf fija XDG_MENU_PREFIX=arch-" grep -qx 'XDG_MENU_PREFIX=arch-' "$ENV_FILE"
check "40-xdg-menu.conf no lleva rutas /home/<user>" [ -z "$(grep -l '/home/' "$ENV_FILE" || true)" ]

managed() { CHEZMOI_PROFILE="$1" chezmoi managed --source="$REPO_ROOT" --include=files -p relative; }
# Sin esta precondición un chezmoi roto daría salida vacía y los negativos pasarían de más.
for profile in clavis clavis-upstream omarchy nyxuri; do
  check "chezmoi lista archivos gestionados en $profile" [ "$(managed "$profile" | wc -l)" -gt 10 ]
done
check "clavis gestiona 40-xdg-menu.conf" grep -qx '.config/environment.d/40-xdg-menu.conf' <(managed clavis)
for profile in clavis-upstream omarchy nyxuri; do
  check "$profile no recibe 40-xdg-menu.conf" [ -z "$(managed "$profile" | grep -x '.config/environment.d/40-xdg-menu.conf' || true)" ]
done

# --- Script de ksycoca: inerte fuera de clavis ---------------------------------
render() { CHEZMOI_PROFILE="$1" chezmoi execute-template --source="$REPO_ROOT" < "$SCRIPT"; }
for profile in clavis-upstream omarchy nyxuri; do
  check "ksycoca en $profile se renderiza vacío (chezmoi no lo ejecuta)" [ -z "$(render "$profile" | tr -d '[:space:]')" ]
done
rendered="$(render clavis)"
check "ksycoca en clavis no se renderiza vacío" [ -n "$rendered" ]
check "ksycoca en clavis empieza con shebang" [ "$(head -n 1 <<< "$rendered")" = '#!/usr/bin/env bash' ]
check "ksycoca en clavis es bash válido" bash -n <(printf '%s\n' "$rendered")
check "ksycoca en clavis usa el prefijo arch-" grep -q 'XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental' <<< "$rendered"
check "ksycoca en clavis no deja /home/<user>" [ -z "$(grep '/home/' <<< "$rendered" || true)" ]
if command -v shellcheck > /dev/null; then
  check "ksycoca en clavis pasa shellcheck" shellcheck <(printf '%s\n' "$rendered")
fi

# --- Lo que no debe cambiar ----------------------------------------------------
check "QT_QPA_PLATFORMTHEME sigue siendo gtk3" grep -qx 'QT_QPA_PLATFORMTHEME=gtk3' "$REPO_ROOT/dot_config/environment.d/qt-gtk3.conf"
check "solo qt-gtk3.conf asigna QT_QPA_PLATFORMTHEME" \
  [ "$(grep -rl '^QT_QPA_PLATFORMTHEME=' "$REPO_ROOT/dot_config" | wc -l)" -eq 1 ]
check "ningún archivo de dotfiles asigna Dolphin a inode/directory" \
  [ -z "$(grep -rIl --exclude-dir=.git -E 'inode/directory|org\.kde\.dolphin\.desktop' "$REPO_ROOT/dot_config" "$REPO_ROOT/dot_local" 2> /dev/null || true)" ]

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
