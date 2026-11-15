#!/usr/bin/env bash
# Captura de pantalla interactiva con anotaciones (Satty)
# Selecciona área con slurp, abre satty y con Enter copia al portapapeles y guarda en /zt/

set -euo pipefail

mkdir -p /zt

GEOM=$(slurp 2>/dev/null) || exit 0
[[ -z "$GEOM" ]] && exit 0

exec grim -g "$GEOM" - | satty --filename -
