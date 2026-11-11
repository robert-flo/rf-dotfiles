#!/usr/bin/env bash
# Clavis quick wallpaper/video slot switcher (1..9)
set -euo pipefail

SLOT="${1:-}"
if [[ -z "$SLOT" || ! "$SLOT" =~ ^[1-9]$ ]]; then
    echo "Usage: $0 <1-9>" >&2
    exit 1
fi

SEARCH_DIRS=(
    "/z/wallpaper-collection/favorites"
    "/z/wallpaper-collection"
    "${XDG_DATA_HOME:-$HOME/.local/share}/clavis/wallpapers/favorites"
    "${XDG_DATA_HOME:-$HOME/.local/share}/clavis/wallpapers"
)

EXTENSIONS=("png" "jpg" "jpeg" "webp" "mp4" "webm" "mkv")

FOUND=""
for dir in "${SEARCH_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for ext in "${EXTENSIONS[@]}"; do
        candidate="$dir/$SLOT.$ext"
        if [[ -f "$candidate" ]]; then
            FOUND="$candidate"
            break 2
        fi
    done
done

if [[ -z "$FOUND" ]]; then
    notify-send -a "Clavis" -i "dialog-warning" "Fondo de Pantalla" "No se encontró el archivo del slot $SLOT (ej. $SLOT.png o $SLOT.mp4 en /z/wallpaper-collection/favorites/)"
    exit 0
fi

BASENAME="$(basename "$FOUND")"
EXT="${FOUND##*.}"

case "${EXT,,}" in
    mp4|webm|mkv)
        # Video wallpaper via mpvpaper
        if command -v clavis-mpvpaper.sh >/dev/null 2>&1; then
            clavis-mpvpaper.sh apply "$FOUND"
        elif [[ -x "$HOME/.local/bin/clavis-mpvpaper.sh" ]]; then
            "$HOME/.local/bin/clavis-mpvpaper.sh" apply "$FOUND"
        fi
        notify-send -a "Clavis" -i "preferences-desktop-wallpaper" "Fondo Animado (Slot $SLOT)" "$BASENAME"
        ;;
    *)
        # Static image wallpaper via Quickshell
        if command -v clavis-mpvpaper.sh >/dev/null 2>&1; then
            clavis-mpvpaper.sh clear 2>/dev/null || true
        elif [[ -x "$HOME/.local/bin/clavis-mpvpaper.sh" ]]; then
            "$HOME/.local/bin/clavis-mpvpaper.sh" clear 2>/dev/null || true
        fi
        qs -c clavis ipc call wallpaper set "$FOUND" >/dev/null 2>&1 || true
        notify-send -a "Clavis" -i "preferences-desktop-wallpaper" "Fondo de Pantalla (Slot $SLOT)" "$BASENAME"
        ;;
esac
