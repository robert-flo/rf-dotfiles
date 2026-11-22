#!/usr/bin/env bash
# Captura de pantalla interactiva con anotaciones (Satty)
# Selecciona área con slurp, abre satty y con Enter copia al portapapeles y guarda en /zt/

set -euo pipefail

mkdir -p /zt

# Velo oscuro y borde dorado grueso: el cruz de slurp se pierde sobre fondos claros.
GEOM=$(slurp -b '#00000066' -c '#ffd700ff' -w 3 2>/dev/null) || exit 0
[[ -z "$GEOM" ]] && exit 0

exec grim -g "$GEOM" - | satty --filename -
