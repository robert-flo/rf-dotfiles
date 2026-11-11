#!/usr/bin/env bash
# Clavis multi-app scratchpad toggle
# Controls floating scratchpad lifecycle for Kitty and terminal utilities.
set -euo pipefail

TARGET_APP="${1:-kitty}"
APP_ID="scratchpad"
TMUX_SESSION="scratch"

LOCK_NAME=$(printf '%s' "$TARGET_APP" | tr -c 'a-zA-Z0-9_' '_')
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/clavis-${UID}-scratch-${LOCK_NAME}.lock"
flock -n 9 || exit 0

ACTIVE_WS=$(niri msg -j workspaces 2>/dev/null \
    | jq -r '(.[] | select(.is_focused == true) | .id) // (.[] | select(.is_active == true) | .id)' \
    | head -n1)

read -r win_id win_ws < <(niri msg -j windows 2>/dev/null \
    | jq -r --arg id "$APP_ID" \
        '.[] | select(.app_id == $id) | "\(.id) \(.workspace_id)"' \
    | head -n1)

spawn_kitty() {
    if command -v tmux >/dev/null 2>&1; then
        niri msg action spawn -- \
            kitty --app-id "$APP_ID" --title "Scratchpad" \
            tmux new-session -A -D -s "$TMUX_SESSION" \
            "fish -C 'function fish_greeting; end' -C 'set -g fish_history scratchpad'" \
            \; set-option status off \
            \; set-option mouse on \
            \; set-option history-limit 50000
    else
        niri msg action spawn -- \
            kitty --app-id "$APP_ID" --title "Scratchpad"
    fi
}

if [ -z "${win_id:-}" ]; then
    spawn_kitty
elif [ -n "$ACTIVE_WS" ] && [ -n "${win_ws:-}" ] && [ "$win_ws" != "$ACTIVE_WS" ]; then
    # Relocate from other workspace to current active workspace
    niri msg action close-window --id "$win_id"
    sleep 0.05
    spawn_kitty
else
    # On current workspace -> toggle off
    niri msg action close-window --id "$win_id"
fi
