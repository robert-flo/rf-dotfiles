#!/usr/bin/env bash
# Bottom (btm) in Kitty Dark Scratchpad
exec kitty -o include=themes/dark-test.conf --app-id scratchpad --title "Bottom (btm)" -e btm "$@"
