_df() {
  if [[ $# -ge 1 && -e "${@: -1}" ]]; then
    duf "${@: -1}"
  else
    duf
  fi
}

if command -v duf >/dev/null 2>&1; then
  alias df='_df'
fi
