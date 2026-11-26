#!/usr/bin/env bash
set -euo pipefail

# 1. Detener daemons que reclaman org.freedesktop.Notifications por activación D-Bus
systemctl --user stop mako.service swaync.service dunst.service 2>/dev/null || true
pkill -x mako 2>/dev/null || true
pkill -x swaync 2>/dev/null || true
pkill -x dunst 2>/dev/null || true

# 2. Recargar configuración activa de Niri si el compositor está en ejecución
if command -v niri &>/dev/null; then
    niri msg action load-config-file &>/dev/null || true
fi

# 3. Recargar definiciones de servicios systemd a nivel de usuario
systemctl --user daemon-reload || true

# 4. Reiniciar la shell de Clavis (Quickshell) y su servidor de notificaciones integrado
if systemctl --user is-active clavis-shell.service &>/dev/null || systemctl --user is-enabled clavis-shell.service &>/dev/null; then
    systemctl --user restart clavis-shell.service || true
fi

# 5. Esperar a que Clavis tome posesión del bus D-Bus de notificaciones (org.freedesktop.Notifications)
for _ in {1..30}; do
    owner=$(dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.GetNameOwner string:org.freedesktop.Notifications 2>/dev/null | grep -o ':[0-9.]*' || true)
    if [ -n "$owner" ]; then
        pid=$(dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.GetConnectionUnixProcessID string:"$owner" 2>/dev/null | awk '{print $NF}' || true)
        if [ -n "$pid" ] && ! ps -p "$pid" -o comm= 2>/dev/null | grep -Eq 'mako|swaync|dunst'; then
            break
        fi
    fi
    sleep 0.1
done

# Asegurarse de que ningún daemon ajeno haya revivido durante la transición
pkill -x mako 2>/dev/null || true
pkill -x swaync 2>/dev/null || true
pkill -x dunst 2>/dev/null || true

# 6. Notificación visual temporal sincronizada a través de Clavis
if command -v notify-send &>/dev/null; then
    notify-send \
        -a "Clavis" \
        -i "software-update-available" \
        -t 2 \
        -h boolean:transient:true \
        -h string:x-canonical-private-synchronous:clavis-desktop-reload \
        "Escritorio Clavis" \
        "Niri, Shell y Notificaciones recargados correctamente en caliente"
fi
