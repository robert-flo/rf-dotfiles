# Fuzzy helpers (fzf)

_fuzzy_open_in_editor() {
  local selected_file="$1"
  if [[ -n "$selected_file" && -f "$selected_file" ]]; then
    "${EDITOR:-nvim}" "$selected_file"
  else
    return 1
  fi
}

_fuzzy_change_directory() {
  local initial_query="$1"
  local selected_dir
  local -a fzf_options=(
    '--preview=ls -p {}'
    '--preview-window=right:60%'
    '--height=80%'
    '--layout=reverse'
    '--cycle'
  )
  local max_depth=7

  [[ -n "$initial_query" ]] && fzf_options+=("--query=$initial_query")

  selected_dir=$(find . -maxdepth "$max_depth" \( -name .git -o -name node_modules -o -name .venv -o -name target -o -name .cache \) -prune -o -type d -print 2>/dev/null | fzf "${fzf_options[@]}")

  if [[ -n "$selected_dir" && -d "$selected_dir" ]]; then
    cd "$selected_dir" || return 1
  else
    return 1
  fi
}

_fuzzy_edit_search_file_content() {
  local selected_file
  local preview_cmd='cat {}'
  command -v bat >/dev/null 2>&1 && preview_cmd='bat --color always --style=plain --paging=never {}'

  local -a fzf_options=(
    '--height=80%'
    '--layout=reverse'
    '--cycle'
    '--preview-window=right:60%'
    "--preview=$preview_cmd"
  )

  if command -v rg >/dev/null 2>&1; then
    selected_file=$(rg --files-with-matches --ignore-case "${1:-}" . 2>/dev/null | fzf "${fzf_options[@]}")
  else
    selected_file=$(grep -irl "${1:-}" ./ 2>/dev/null | fzf "${fzf_options[@]}")
  fi

  _fuzzy_open_in_editor "$selected_file" || echo "No file selected or search returned no results."
}

_fuzzy_edit_search_file() {
  local initial_query="$1"
  local selected_file
  local -a fzf_options=(
    '--height=80%'
    '--layout=reverse'
    '--preview-window=right:60%'
    '--cycle'
  )
  local max_depth=5

  [[ -n "$initial_query" ]] && fzf_options+=("--query=$initial_query")

  selected_file=$(find . -maxdepth "$max_depth" -type f 2>/dev/null | fzf "${fzf_options[@]}")
  _fuzzy_open_in_editor "$selected_file"
}

_fuzzy_search_cmd_history() {
  local selected
  setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases noglob nobash_rematch 2>/dev/null

  local fzf_query=""
  if [[ -n "$1" ]]; then
    fzf_query="--query=${(qqq)1}"
  else
    fzf_query="--query=${(qqq)LBUFFER}"
  fi

  if zmodload -F zsh/parameter p:{commands,history} 2>/dev/null && (( ${+commands[perl]} )); then
    selected="$(printf '%s\t%s\000' "${(kv)history[@]}" |
      perl -0 -ne 'if (!$seen{(/^\s*[0-9]+\**\t(.*)/s, $1)}++) { s/\n/\n\t/g; print; }' |
      FZF_DEFAULT_OPTS=$(__fzf_defaults "" "-n2..,.. --scheme=history --bind=ctrl-r:toggle-sort --wrap-sign '\t↳ ' --highlight-line ${FZF_CTRL_R_OPTS-} $fzf_query +m --read0") \
      FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd))"
  else
    selected="$(fc -rl 1 | __fzf_exec_awk '{ cmd=$0; sub(/^[ \t]*[0-9]+\**[ \t]+/, "", cmd); if (!seen[cmd]++) print $0 }' |
      FZF_DEFAULT_OPTS=$(__fzf_defaults "" "-n2..,.. --scheme=history --bind=ctrl-r:toggle-sort --wrap-sign '\t↳ ' --highlight-line ${FZF_CTRL_R_OPTS-} $fzf_query +m") \
      FZF_DEFAULT_OPTS_FILE='' $(__fzfcmd))"
  fi
  local ret=$?
  if [[ -n "$selected" ]]; then
    if [[ $(__fzf_exec_awk '{print $1; exit}' <<< "$selected") =~ ^[1-9][0-9]* ]]; then
      zle vi-fetch-history -n "$MATCH"
    else
      LBUFFER="$selected"
    fi
  fi
  return $ret
}

alias ffec='_fuzzy_edit_search_file_content' \
  ffcd='_fuzzy_change_directory' \
  ffe='_fuzzy_edit_search_file' \
  ffch='_fuzzy_search_cmd_history'
