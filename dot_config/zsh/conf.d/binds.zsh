#!/usr/bin/env zsh
# Key bindings for word navigation and line editing

[[ $- != *i* ]] && return

# Ctrl+Left / Ctrl+Right
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[5C" forward-word
bindkey "^[[5D" backward-word
bindkey "^[OC" forward-word
bindkey "^[OD" backward-word

# Home / End / Delete
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[OH" beginning-of-line
bindkey "^[OF" end-of-line
bindkey "^[[1~" beginning-of-line
bindkey "^[[4~" end-of-line
bindkey "^[[3~" delete-char
