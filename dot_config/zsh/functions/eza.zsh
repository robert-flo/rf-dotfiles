if command -v eza >/dev/null 2>&1; then
  alias l='eza -lh --icons=auto' \
    la='eza -a --icons=auto' \
    ll='eza -lha --icons=auto --sort=name --group-directories-first' \
    lla='eza -lhag --icons=auto --sort=name --group-directories-first' \
    ld='eza -lhD --icons=auto' \
    lt='eza --icons=auto --tree'
fi
