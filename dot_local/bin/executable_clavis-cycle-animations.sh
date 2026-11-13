#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
STATE_FILE="$CONFIG_DIR/.animation-preset"
TARGET_FILE="$CONFIG_DIR/animations.kdl"

CURRENT="A"
if [[ -f "$STATE_FILE" ]]; then
    CURRENT=$(cat "$STATE_FILE" 2>/dev/null || echo "A")
fi

case "$CURRENT" in
    A)
        NEXT="B"
        TITLE="Modo B: Cinemática Fluida"
        DESC="Curva cúbica suave (350 ms, ease-out-cubic)"
        ICON="media-playback-start"
        CONTENT='// Modo B: Cinemática Fluida (Ultra Smooth)
animations {
    horizontal-view-movement {
        duration-ms 350
        curve "ease-out-cubic"
    }
    window-movement {
        duration-ms 350
        curve "ease-out-cubic"
    }
}'
        ;;
    B)
        NEXT="C"
        TITLE="Modo C: Snappy Inercial"
        DESC="Resorte con inercia elegante y sin oscilación"
        ICON="system-run"
        CONTENT='// Modo C: Snappy Inercial (Con peso, sin rebote)
animations {
    horizontal-view-movement {
        spring damping-ratio=0.94 stiffness=520 epsilon=0.0001
    }
    window-movement {
        spring damping-ratio=0.94 stiffness=550 epsilon=0.0001
    }
}'
        ;;
    *)
        NEXT="A"
        TITLE="Modo A: Elástica Dinámica (Default)"
        DESC="Resorte físico orgánico con sutil rebote (bouncy)"
        ICON="view-restore"
        CONTENT='// Modo A: Elástica Dinámica (Predeterminado)
animations {
    horizontal-view-movement {
        spring damping-ratio=0.82 stiffness=650 epsilon=0.0001
    }
    window-movement {
        spring damping-ratio=0.85 stiffness=700 epsilon=0.0001
    }
}'
        ;;
esac

echo "$CONTENT" > "$TARGET_FILE"
echo "$NEXT" > "$STATE_FILE"

# Recargar configuración activa de Niri si está en ejecución
if command -v niri &>/dev/null; then
    niri msg action load-config-file &>/dev/null || true
fi

# Notificación visual temporal sincronizada
if command -v notify-send &>/dev/null; then
    notify-send \
        --app-name="Clavis Motion" \
        --icon="$ICON" \
        --expire-time=2200 \
        --hint="string:x-canonical-private-synchronous:niri-animation-mode" \
        "Animación Niri" \
        "<b>$TITLE</b>\n$DESC"
fi
