#!/usr/bin/env bash
set -euo pipefail

# 1. Recargar configuración activa de Niri si el compositor está en ejecución
if command -v niri &>/dev/null; then
    niri msg action load-config-file &>/dev/null || true
fi

# 2. Recargar definiciones de servicios systemd a nivel de usuario
systemctl --user daemon-reload || true

# 3. Reiniciar la shell de Clavis (Quickshell) si el servicio está activo o habilitado
if systemctl --user is-active clavis-shell.service &>/dev/null || systemctl --user is-enabled clavis-shell.service &>/dev/null; then
    systemctl --user restart clavis-shell.service || true
fi

# 4. Notificación visual temporal sincronizada
if command -v notify-send &>/dev/null; then
    notify-send \
        -a "Clavis" \
        -i "software-update-available" \
        -t 2 \
        -h boolean:transient:true \
        -h string:x-canonical-private-synchronous:clavis-desktop-reload \
        "Escritorio Clavis" \
        "Niri y Shell recargados correctamente en caliente"
fi
