#!/usr/bin/env bash
# Helpers de los targets diarios del Makefile. La costura pública es make.
set -euo pipefail

usage() {
  printf 'usage: %s profile|sudo-state|source|lose-paths|script-paths\n' "$(basename "$0")" >&2
  exit 2
}

# Misma cascada que .chezmoiignore.tmpl (bloque «Auto-detect profile»).
# Vive acá porque morning tiene que decir el perfil sin renderizar la plantilla.
rf_profile() {
  if [[ -n "${CHEZMOI_PROFILE:-}" ]]; then
    printf '%s\n' "$CHEZMOI_PROFILE"
    return
  fi
  case "$(id -un)" in
    niri|niri-classic|niri-test|sura) printf '%s\n' clavis ;;
    nyxuri|nyxuri-test|nyxuri-legacy) printf '%s\n' nyxuri ;;
    niri-upstream) printf '%s\n' clavis-upstream ;;
    *) printf '%s\n' omarchy ;;
  esac
}

rf_sudo_state() {
  if sudo -n true >/dev/null 2>&1; then
    printf '%s\n' yes
  else
    printf '%s\n' no
  fi
}

# Lee `chezmoi status` por stdin. Emite "lose<TAB>path" o "script<TAB>path".
# La segunda columna M o D es un archivo del home que apply modificaría o borraría.
# R es un script que se volvería a correr.
rf_classify() {
  local line col2 path
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ ${#line} -ge 3 ]] || continue
    col2="${line:1:1}"
    path="${line:3}"
    case "$col2" in
      M|D) printf 'lose\t%s\n' "$path" ;;
      R) printf 'script\t%s\n' "$path" ;;
      *) ;;
    esac
  done
}

rf_paths() {
  local want="$1" row kind path
  rf_classify | while IFS= read -r row; do
    kind="${row%%$'\t'*}"
    path="${row#*$'\t'}"
    if [[ "$kind" == "$want" ]]; then
      printf '%s\n' "$path"
    fi
  done
}

[[ $# -ge 1 ]] || usage
case "$1" in
  profile) rf_profile ;;
  sudo-state) rf_sudo_state ;;
  source) "${CHEZMOI:-chezmoi}" source-path ;;
  lose-paths) rf_paths lose ;;
  script-paths) rf_paths script ;;
  *) usage ;;
esac
