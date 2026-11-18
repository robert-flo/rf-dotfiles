function _list_repo_directories
    for root in /z-home-repos/HR-CLAVIS /z/repos /z-drive/tries $HOME/Work
        if test -d $root
            fd -HI -t d -t f --max-depth 3 --exclude .pj '^\.git$' $root 2>/dev/null \
                | string replace -r '/\.git/?$' ''
        end
    end
    printf '%s\n' $HOME/.config
    ls -ad $PWD/*/ 2>/dev/null | string replace -r '/$' ''
end

function fzf_change_directory
    set -l selection (_list_repo_directories | awk '!a[$0]++' | fzf --layout reverse)
    if test -n "$selection"; and test -d "$selection"
        builtin cd "$selection"
        commandline -r ''
        commandline -f repaint
    else
        commandline ''
    end
end
