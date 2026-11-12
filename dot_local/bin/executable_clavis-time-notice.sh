#!/usr/bin/env bash
# Clavis quick time & date OSD notice
set -euo pipefail

FECHA="$(date '+%A, %d de %B de %Y')"
HORA="$(date '+%I:%M:%S %p')"

notify-send -a "Reloj" -i "preferences-system-time" -t 3 \
    "🕒 $HORA" \
    "$FECHA"
