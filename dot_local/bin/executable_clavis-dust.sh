#!/usr/bin/env bash
# Dust in Kitty Dark Scratchpad
exec kitty -o include=themes/dark-test.conf --app-id scratchpad --title "Dust Disk Usage" -e bash -c 'dust -r ; echo ; read -p "Presiona Enter para salir..."'
