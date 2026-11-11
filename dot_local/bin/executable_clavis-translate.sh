#!/usr/bin/env bash
# Clavis quick selection translator (English <-> Spanish)
set -euo pipefail

TEXT="$(wl-paste -p 2>/dev/null || true)"
if [[ -z "${TEXT// }" ]]; then
    TEXT="$(wl-paste 2>/dev/null || true)"
fi

if [[ -z "${TEXT// }" ]]; then
    notify-send -a "Traductor" -i "accessories-dictionary" "Traductor" "No hay texto seleccionado en el portapapeles."
    exit 0
fi

# Trim text if too long for notification title
PREVIEW="${TEXT:0:80}"
[[ ${#TEXT} -gt 80 ]] && PREVIEW="${PREVIEW}..."

# Detect language
DETECTED="$(trans -brief -no-ansi -id "$TEXT" 2>/dev/null | head -n1 | tr -d '[:space:]')"

if [[ "$DETECTED" == "es" ]]; then
    TARGET_LANG="en"
    LANG_LABEL="Español ➔ Inglés"
else
    TARGET_LANG="es"
    LANG_LABEL="Inglés ➔ Español"
fi

TRANSLATED="$(trans -brief -no-ansi :"$TARGET_LANG" "$TEXT" 2>/dev/null || true)"

if [[ -n "$TRANSLATED" ]]; then
    # Copy translation to clipboard
    printf '%s' "$TRANSLATED" | wl-copy
    notify-send -a "Traductor" -i "accessories-dictionary" "🌐 $LANG_LABEL" "$TRANSLATED"
else
    notify-send -a "Traductor" -i "dialog-error" "Error de Traducción" "No se pudo traducir la selección."
fi
