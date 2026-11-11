#!/usr/bin/env bash
# Clavis wrapper for Orbit Radial Launcher
set -euo pipefail

CANDIDATES=(
    "$HOME/.config/noctalia/tools/orbit-launcher.py"
    "/opt/src/nyxuri/plugins/noctalia/tools/orbit-launcher.py"
    "/usr/local/bin/orbit-launcher"
)

TARGET=""
for c in "${CANDIDATES[@]}"; do
    if [[ -f "$c" ]]; then
        TARGET="$c"
        break
    fi
done

if [[ -n "$TARGET" ]]; then
    exec python3 "$TARGET" "$@"
else
    # Fallback to fuzzel if Orbit launcher is unavailable
    exec fuzzel
fi
