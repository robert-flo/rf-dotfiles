#!/usr/bin/env zsh
# Interactive workstation tools parity with Fish (rf-common.fish)

[[ $- != *i* ]] && return

# Tooling integrations
command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v pay-respects >/dev/null 2>&1 && eval "$(pay-respects zsh --alias f)"
command -v elio >/dev/null 2>&1 && eval "$(elio shell init zsh)"

# ravn-sessionizer on Alt+s
if command -v ravn-sessionizer >/dev/null 2>&1; then
  __ravn_sessionizer_pick() {
    ravn-sessionizer
    zle reset-prompt
  }
  zle -N __ravn_sessionizer_pick
  bindkey -M emacs '^[s' __ravn_sessionizer_pick
fi

# try (/zt) and personal projects (~/Work)
export TRY_PATH="/zt"
export TRY_PROJECTS="$HOME/Work"
if command -v try >/dev/null 2>&1; then
  eval "$(SHELL=zsh try init /zt)"
fi

# Cursor API key if present
if [[ -r "$HOME/.config/cursor/api-key" ]]; then
  export CURSOR_API_KEY="$(<"$HOME/.config/cursor/api-key")"
  CURSOR_API_KEY="${CURSOR_API_KEY%%$'\n'}"
fi

# Workstation aliases
alias agy="$HOME/.local/bin/agy"
alias cursor-agent="$HOME/.local/bin/cursor-agent"
alias claude-yolo="claude --dangerously-skip-permissions"
alias cz="chezmoi"
alias pn="pnpm"

# Terminal polarity helpers (RF_TERM_THEME contract)
term-light() {
  export RF_TERM_THEME="light"
  export COLORFGBG="0;15"
  export BAT_THEME="ansi"
  export GLAMOUR_STYLE="light"
}

term-dark() {
  export RF_TERM_THEME="dark"
  export COLORFGBG="15;0"
  export BAT_THEME="ansi"
  export GLAMOUR_STYLE="dark"
}
