#!/usr/bin/env bash
# Television (tv) in Kitty Dark Scratchpad
exec kitty -o include=themes/dark-test.conf --app-id scratchpad --title "Television (tv)" -e tv "$@"
