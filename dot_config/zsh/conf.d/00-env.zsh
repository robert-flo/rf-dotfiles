#!/usr/bin/env zsh
# Base environment and XDG Base Directory Specification

add_to_path() {
  if [[ -d "$1" && ":$PATH:" != *":$1:"* ]]; then
    export PATH="$1:$PATH"
  fi
}

append_to_path() {
  if [[ -d "$1" && ":$PATH:" != *":$1:"* ]]; then
    export PATH="$PATH:$1"
  fi
}

# User local binaries
add_to_path "$HOME/.local/bin"

# XDG Base Directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-$XDG_DATA_HOME:/usr/local/share:/usr/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# XDG User Directories
if command -v xdg-user-dir >/dev/null 2>&1; then
  export XDG_DESKTOP_DIR="${XDG_DESKTOP_DIR:-$(xdg-user-dir DESKTOP)}"
  export XDG_DOWNLOAD_DIR="${XDG_DOWNLOAD_DIR:-$(xdg-user-dir DOWNLOAD)}"
  export XDG_TEMPLATES_DIR="${XDG_TEMPLATES_DIR:-$(xdg-user-dir TEMPLATES)}"
  export XDG_PUBLICSHARE_DIR="${XDG_PUBLICSHARE_DIR:-$(xdg-user-dir PUBLICSHARE)}"
  export XDG_DOCUMENTS_DIR="${XDG_DOCUMENTS_DIR:-$(xdg-user-dir DOCUMENTS)}"
  export XDG_MUSIC_DIR="${XDG_MUSIC_DIR:-$(xdg-user-dir MUSIC)}"
  export XDG_PICTURES_DIR="${XDG_PICTURES_DIR:-$(xdg-user-dir PICTURES)}"
  export XDG_VIDEOS_DIR="${XDG_VIDEOS_DIR:-$(xdg-user-dir VIDEOS)}"
fi

# Application XDG paths
export LESSHISTFILE="${LESSHISTFILE:-$XDG_STATE_HOME/less/history}"
export PARALLEL_HOME="${PARALLEL_HOME:-$XDG_CONFIG_HOME/parallel}"
export SCREENRC="${SCREENRC:-$XDG_CONFIG_HOME/screen/screenrc}"
export TERMINFO="${TERMINFO:-$XDG_DATA_HOME/terminfo}"
export TERMINFO_DIRS="${TERMINFO_DIRS:-$XDG_DATA_HOME/terminfo:/usr/share/terminfo}"
export WGETRC="${WGETRC:-$XDG_CONFIG_HOME/wgetrc}"
export PYTHON_HISTORY="${PYTHON_HISTORY:-$XDG_STATE_HOME/python_history}"

# Android & Java environment
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$HOME/.android}"
export ANDROID_PROJECTS_DIR="${ANDROID_PROJECTS_DIR:-/z/android-projects}"
append_to_path "$ANDROID_HOME/emulator"
append_to_path "$ANDROID_HOME/platform-tools"
append_to_path "$ANDROID_HOME/cmdline-tools/latest/bin"
