#!/usr/bin/env bash
# El .desktop de SPlayer pide un icono que el tema no encuentra.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/run_before_02-splayer-desktop.sh.tmpl"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@" > /dev/null; then pass "$d"; else fail "$d"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat >"$WORK/src.desktop" <<'EOF'
[Desktop Entry]
Name=SPlayer-Next
Exec=/usr/local/bin/splayer-next %U
Icon=splayer-next
StartupWMClass=top.imsyy.splayer_next
EOF

run() {
  SPLAYER_DESKTOP_SRC="$1" SPLAYER_DESKTOP_DEST="$WORK/dest.desktop" bash "$SCRIPT"
}

check "la plantilla existe y es ejecutable" [ -x "$SCRIPT" ]
check "corre en cada apply" [ "$(basename "$SCRIPT")" = "run_before_02-splayer-desktop.sh.tmpl" ]
check "sin rutas /home/<user>" [ -z "$(grep -F '/home/' "$SCRIPT" || true)" ]

run "$WORK/src.desktop"
check "corrige el nombre del icono" grep -qx 'Icon=SPlayer-Next' "$WORK/dest.desktop"
check "apunta al binario del paquete" grep -qx 'Exec=/usr/bin/splayer-next %U' "$WORK/dest.desktop"
check "conserva la clase de ventana" grep -qx 'StartupWMClass=top.imsyy.splayer_next' "$WORK/dest.desktop"
check "marca la copia como nuestra" grep -qxF '# rf-dotfiles: icono SPlayer-Next y Exec en /usr/bin' "$WORK/dest.desktop"

run "$WORK/src.desktop"
check "la segunda corrida deja el archivo igual" grep -qx 'Icon=SPlayer-Next' "$WORK/dest.desktop"

cat >"$WORK/src.desktop" <<'EOF'
[Desktop Entry]
Name=SPlayer-Next
Exec=/usr/bin/splayer-next %U
Icon=SPlayer-Next
EOF
run "$WORK/src.desktop"
check "quita la copia cuando el paquete ya está bien" [ ! -f "$WORK/dest.desktop" ]

printf 'a mano\n' >"$WORK/dest.desktop"
run "$WORK/src.desktop"
check "no borra un .desktop que no escribimos nosotros" grep -qx 'a mano' "$WORK/dest.desktop"

printf '%s\n' '# rf-dotfiles: icono SPlayer-Next y Exec en /usr/bin' >"$WORK/dest.desktop"
run "$WORK/missing.desktop"
check "sin paquete quita nuestra copia" [ ! -f "$WORK/dest.desktop" ]

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
