if status is-interactive; and command -q fzf
    set -gx FZF_DEFAULT_OPTS "--reverse --height 40% --border"
    fzf --fish | source
end
