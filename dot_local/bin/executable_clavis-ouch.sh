#!/usr/bin/env bash
# Ouch Helper in Kitty Dark Scratchpad
exec kitty -o include=themes/dark-test.conf --app-id scratchpad --title "Ouch Compression" -e bash -c 'ouch --help ; echo ; read -p "Presiona Enter para salir..."'
