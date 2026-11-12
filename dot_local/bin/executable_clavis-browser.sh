#!/usr/bin/env bash
# Clavis default browser launcher
set -euo pipefail

if command -v zen-browser >/dev/null 2>&1; then
    exec zen-browser "$@"
elif command -v google-chrome >/dev/null 2>&1; then
    exec google-chrome "$@"
elif command -v chromium >/dev/null 2>&1; then
    exec chromium "$@"
else
    exec xdg-open "about:blank"
fi
