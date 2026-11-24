#!/usr/bin/env zsh
# Zinit plugin manager setup

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
fi
if [[ ! -d "$ZINIT_HOME/.git" ]]; then
  git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

if [[ -r "${ZINIT_HOME}/zinit.zsh" ]]; then
  source "${ZINIT_HOME}/zinit.zsh"

  # Plugins
  zinit load zdharma-continuum/history-search-multi-word
  zinit light zsh-users/zsh-autosuggestions
  zinit light zdharma-continuum/fast-syntax-highlighting
  zinit light zsh-users/zsh-completions
  zinit light zsh-users/zsh-history-substring-search
  zinit snippet OMZP::git
  zinit light hlissner/zsh-autopair
  zinit light Aloxaf/fzf-tab
  zinit light djui/alias-tips
fi
