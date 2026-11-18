function envsource --description 'Load environment variables from a .env file'
    for line in (cat $argv | string match -rv '^\s*(#|$)')
        set -l clean (string replace -r '^export\s+' '' -- $line)
        set -l item (string split -m 1 '=' -- $clean)
        if test (count $item) -eq 2
            set -gx $item[1] (string trim -c '\'"' -- $item[2])
            echo "Exported key $item[1]"
        end
    end
end
