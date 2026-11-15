function yazi
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
    or return
    command yazi $argv --cwd-file "$tmp"
    if test -s "$tmp"
        set -l cwd (string collect < "$tmp")
        if test -n "$cwd"; and test "$cwd" != "$PWD"; and test -d "$cwd"
            cd -- "$cwd"
        end
    end
    rm -f -- "$tmp"
end
