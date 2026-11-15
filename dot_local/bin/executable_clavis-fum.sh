#!/usr/bin/env bash
# Fum MPRIS Player in Kitty Dark Scratchpad
exec kitty -o include=themes/dark-test.conf --app-id scratchpad --title "Fum MPRIS Player" -e fum "$@"
