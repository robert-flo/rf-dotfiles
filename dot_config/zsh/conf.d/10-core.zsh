#!/usr/bin/env zsh
# Core interactive Zsh setup: history, cached compinit, user, plugins, prompt, functions, completions

[[ $- != *i* ]] && return

# History configuration
export HISTFILE="${HISTFILE:-$ZDOTDIR/.zsh_history}"
export HISTSIZE=10000
export SAVEHIST=10000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY APPEND_HISTORY

export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Add custom completions directory to fpath before compinit
fpath=("$ZDOTDIR/completions" "${fpath[@]}")

_load_compinit() {
  autoload -Uz compinit
  setopt EXTENDED_GLOB

  local zcompdump="${ZDOTDIR}/.zcompdump"
  if [[ ! -f "$zcompdump" || -n ${zcompdump}(#qN.mh+24) ]]; then
    compinit -u -d "$zcompdump"
  else
    compinit -u -C -d "$zcompdump"
  fi

  _comp_options+=(globdots)
}

_load_functions() {
  for file in "${ZDOTDIR:-$HOME/.config/zsh}/functions/"*.zsh(N); do
    [ -r "$file" ] && source "$file"
  done
}

_load_completions() {
  for file in "${ZDOTDIR:-$HOME/.config/zsh}/completions/"*.zsh(N); do
    [ -r "$file" ] && source "$file"
  done
}

# Optional user customization (loaded before plugins so user can set plugin/prompt vars)
[ -r "$ZDOTDIR/user.zsh" ] && source "$ZDOTDIR/user.zsh"

_load_compinit

# Plugin manager (Zinit)
[ -r "$ZDOTDIR/plugin.zsh" ] && source "$ZDOTDIR/plugin.zsh"

# Prompt (Starship)
[ -r "$ZDOTDIR/prompt.zsh" ] && source "$ZDOTDIR/prompt.zsh"

_load_functions
_load_completions
