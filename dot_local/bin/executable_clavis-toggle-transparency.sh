#!/usr/bin/env bash
# Clavis Visual Effects: Toggle between Opaque and Glassy Blur modes
set -euo pipefail

NIRI_CLAVIS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/niri/clavis"
ACTIVE_EFFECTS="$NIRI_CLAVIS_DIR/effects.kdl"
OPAQUE_EFFECTS="$NIRI_CLAVIS_DIR/effects_opaque.kdl"
GLASSY_EFFECTS="$NIRI_CLAVIS_DIR/effects_glassy.kdl"

mkdir -p "$NIRI_CLAVIS_DIR"

# Determinar estado actual comparando con el perfil Glassy
IS_GLASSY=false
if [[ -f "$ACTIVE_EFFECTS" ]] && cmp -s "$ACTIVE_EFFECTS" "$GLASSY_EFFECTS"; then
    IS_GLASSY=true
fi

if [[ "$IS_GLASSY" == "true" ]]; then
    # Conmutar a Opaco
    cp -f "$OPAQUE_EFFECTS" "$ACTIVE_EFFECTS"
    niri msg action load-config-file 2>/dev/null || true
    notify-send -a "Clavis" -i "preferences-system-windows" -t 2500 \
        "Efectos Visuales" "Modo Opaco Activado (Rendimiento estándar)"
else
    # Conmutar a Glassy Blur
    cp -f "$GLASSY_EFFECTS" "$ACTIVE_EFFECTS"
    niri msg action load-config-file 2>/dev/null || true
    notify-send -a "Clavis" -i "preferences-desktop-display" -t 2500 \
        "Efectos Visuales" "Modo Translúcido Activado (Glassy Blur)"
fi
