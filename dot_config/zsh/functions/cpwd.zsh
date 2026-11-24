# Copy current working directory to Wayland clipboard, collapsing $HOME to ~
cpwd() {
  printf '%s' "${PWD/#$HOME/~}" | wl-copy
}
