function fastfetch --wraps=fastfetch --description 'Run fastfetch rotating sequentially through .icon logos'
    for arg in $argv
        switch $arg
            case --
                break
            case --logo '--logo=*' -l '-l*'
                command fastfetch $argv
                return $status
        end
    end

    set -l config_home "$XDG_CONFIG_HOME"
    if test -z "$config_home"
        set config_home "$HOME/.config"
    end
    set -l logo_dir "$config_home/fastfetch/logo"

    set -l logos
    if test -d "$logo_dir"
        set -l raw_logos "$logo_dir"/*.icon
        if test (count $raw_logos) -gt 0
            for f in (printf '%s\n' $raw_logos | LC_ALL=C sort)
                if test -f "$f"
                    set -a logos "$f"
                end
            end
        end
    end

    set -l total (count $logos)
    if test $total -eq 0
        command fastfetch $argv
        return $status
    end

    set -l cache_home "$XDG_CACHE_HOME"
    if test -z "$cache_home"
        set cache_home "$HOME/.cache"
    end
    set -l cache_dir "$cache_home/fastfetch"
    set -l index_file "$cache_dir/logo-index"

    set -l idx 0
    if test -r "$index_file"
        read -l raw_idx < "$index_file"
        if string match -qr '^[0-9]+$' -- "$raw_idx"
            set idx (math -- "$raw_idx + 0")
        end
    end

    set idx (math -- "$idx % $total")
    # Fish arrays are 1-indexed; persisted index is 0-indexed for bash parity.
    set -l logo $logos[(math -- "$idx + 1")]
    set -l next_idx (math -- "($idx + 1) % $total")

    if mkdir -p "$cache_dir" 2>/dev/null
        printf '%s\n' "$next_idx" > "$index_file" 2>/dev/null
    end

    command fastfetch --logo "$logo" --logo-type kitty $argv
end
