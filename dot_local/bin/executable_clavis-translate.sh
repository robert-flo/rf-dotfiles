#!/usr/bin/env bash
# Clavis quick selection translator (English <-> Spanish)
set -euo pipefail

# Safely extract plain text from primary selection, falling back to standard clipboard
TEXT="$(wl-paste -p -t text/plain 2>/dev/null || true)"
if [[ -z "${TEXT// }" ]]; then
    TEXT="$(wl-paste -t text/plain 2>/dev/null || true)"
fi

if [[ -z "${TEXT// }" ]]; then
    notify-send -a "Traductor" -i "accessories-dictionary" \
        "Traductor ES ↔ EN" \
        "ℹ️ Para traducir: Selecciona cualquier texto con el ratón (o cópialo) y pulsa Super + Alt + E."
    exit 0
fi

# Detect language (force IPv4 with -4 to prevent IPv6 timeout)
DETECTED="$(trans -4 -brief -no-ansi -id "$TEXT" 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"

if [[ "$DETECTED" == "es" ]]; then
    TARGET_LANG="en"
    LANG_LABEL="Español ➔ Inglés"
else
    TARGET_LANG="es"
    LANG_LABEL="Inglés ➔ Español"
fi

# Translate with fast IPv4
TRANSLATED="$(trans -4 -brief -no-ansi :"$TARGET_LANG" "$TEXT" 2>/dev/null || true)"

if [[ -n "$TRANSLATED" ]]; then
    printf '%s' "$TRANSLATED" | wl-copy
    notify-send -a "Traductor" -i "accessories-dictionary" "🌐 $LANG_LABEL" "$TRANSLATED"
else
    notify-send -a "Traductor" -i "dialog-error" "Error de Traducción" "No se pudo traducir la selección."
fi
