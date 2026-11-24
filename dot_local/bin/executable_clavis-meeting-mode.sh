#!/usr/bin/env bash
# Clavis Meeting Mode: Toggle de silencio total (Input + Output)
set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/clavis-meeting-mode.state"

is_active=false
if [[ -f "$STATE_FILE" ]]; then
    is_active=true
fi

if [[ "$is_active" == "true" ]]; then
    # --- DESACTIVAR MODO VIDEOLLAMADA (TODO LIBRE) ---
    rm -f "$STATE_FILE"

    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null || true
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0 2>/dev/null || true

    notify-send \
        -a "Clavis" \
        -i "audio-volume-high" \
        -u normal \
        -h boolean:transient:true \
        -h string:x-canonical-private-synchronous:clavis-meeting-mode \
        "Modo Videollamada: DESACTIVADO" \
        "🔊 Audio y Micrófono de la PC LIBRES"
else
    # --- ACTIVAR MODO VIDEOLLAMADA (MUTE TOTAL) ---
    touch "$STATE_FILE"

    wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 2>/dev/null || true
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1 2>/dev/null || true

    notify-send \
        -a "Clavis" \
        -i "audio-volume-muted" \
        -u critical \
        -h boolean:transient:true \
        -h string:x-canonical-private-synchronous:clavis-meeting-mode \
        "Modo Videollamada: MUTE TOTAL" \
        "🔇 Micrófono y Salida silenciados • Cero fugas de audio"
fi
