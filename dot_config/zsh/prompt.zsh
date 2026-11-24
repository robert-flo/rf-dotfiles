#!/usr/bin/env zsh
# Prompt configuration (Starship)

export STARSHIP_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/starship"
export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship/starship.toml"

# Guard against pure Linux TTY (no Nerd Font glyphs)
[[ "$TERM" == "linux" ]] && return

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
