#!/usr/bin/env bash
# Clavis multi-app scratchpad toggle
# Controls floating scratchpad lifecycle for Kitty/Ghostty and terminal utilities.
set -euo pipefail

TARGET_APP="${1:-kitty}"
TMUX_SESSION="scratch"

# Kitty accepts a bare app-id; Ghostty's --class must be a GTK Application ID
# (contains a '.') or it is ignored and the window keeps com.mitchellh.ghostty.
case "$TARGET_APP" in
    ghostty)
        APP_ID="com.clavis.scratchpad"
        ;;
    *)
        APP_ID="scratchpad"
        ;;
esac

LOCK_NAME=$(printf '%s' "$TARGET_APP" | tr -c 'a-zA-Z0-9_' '_')
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/clavis-${UID}-scratch-${LOCK_NAME}.lock"
flock -n 9 || exit 0

ACTIVE_WS=$(niri msg -j workspaces 2>/dev/null \
    | jq -r '(.[] | select(.is_focused == true) | .id) // (.[] | select(.is_active == true) | .id)' \
    | head -n1) || true

read -r win_id win_ws < <(niri msg -j windows 2>/dev/null \
    | jq -r --arg id "$APP_ID" \
        '.[] | select(.app_id == $id) | "\(.id) \(.workspace_id)"' \
    | head -n1) || true

spawn_kitty() {
    if command -v herdr >/dev/null 2>&1; then
        niri msg action spawn -- \
            kitty --app-id "$APP_ID" --title "Scratchpad" \
            herdr --session scratchpad
    elif command -v tmux >/dev/null 2>&1; then
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

spawn_ghostty() {
    # --class sets Wayland app-id; --title pins the window title.
    if command -v herdr >/dev/null 2>&1; then
        niri msg action spawn -- \
            ghostty --class="$APP_ID" --title=Scratchpad \
            -e herdr --session scratchpad
    elif command -v tmux >/dev/null 2>&1; then
        niri msg action spawn -- \
            ghostty --class="$APP_ID" --title=Scratchpad \
            -e tmux new-session -A -D -s "$TMUX_SESSION" \
            "fish -C 'function fish_greeting; end' -C 'set -g fish_history scratchpad'" \
            \; set-option status off \
            \; set-option mouse on \
            \; set-option history-limit 50000
    else
        niri msg action spawn -- \
            ghostty --class="$APP_ID" --title=Scratchpad
    fi
}

spawn_terminal() {
    case "$TARGET_APP" in
        ghostty) spawn_ghostty ;;
        *) spawn_kitty ;;
    esac
}

if [ -z "${win_id:-}" ]; then
    spawn_terminal
elif [ -n "$ACTIVE_WS" ] && [ -n "${win_ws:-}" ] && [ "$win_ws" != "$ACTIVE_WS" ]; then
    # Relocate from other workspace to current active workspace
    niri msg action close-window --id "$win_id"
    sleep 0.05
    spawn_terminal
else
    # On current workspace -> toggle off
    niri msg action close-window --id "$win_id"
fi
