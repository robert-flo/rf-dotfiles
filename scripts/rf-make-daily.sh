#!/usr/bin/env bash
# Helpers de los targets diarios del Makefile. La costura pública es make.
set -euo pipefail

usage() {
  printf 'usage: %s profile|sudo-state|source|lose|lose-paths|script-paths|apply|sudo-keepalive\n' "$(basename "$0")" >&2
  exit 2
}

# Misma cascada que .chezmoiignore.tmpl (bloque «Auto-detect profile»).
# Vive acá porque morning tiene que decir el perfil sin renderizar la plantilla.
rf_source() {
  "${CHEZMOI_BIN:-chezmoi}" source-path
}

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

# Imprime los archivos que se perderían y sale 1 si hay alguno.
rf_lose() {
  local source_dir paths
  source_dir="$(rf_source)"
  paths="$("${CHEZMOI_BIN:-chezmoi}" --color=false status -S "$source_dir" | rf_paths lose)"
  if [[ -n "$paths" ]]; then
    printf '%s\n' "$paths"
    exit 1
  fi
}

# --- apply completo (make apply / apply-<perfil>) ---------------------------

# Mantiene vivo el permiso de sudo mientras viva el proceso $1. Se lanza como
# `rf-make-daily.sh sudo-keepalive <pid>` para poder identificarlo con pgrep.
rf_sudo_keepalive() {
  local parent="$1" tick=0 sleeper=""
  trap '[[ -z "$sleeper" ]] || kill "$sleeper" 2>/dev/null; exit 0' TERM INT HUP
  while kill -0 "$parent" 2>/dev/null; do
    sleep 5 &
    sleeper=$!
    wait "$sleeper" || true
    tick=$((tick + 1))
    if (( tick % 6 == 0 )); then
      sudo -n -v 2>/dev/null || exit 0
    fi
  done
}

# Pide sudo una sola vez, antes de tocar nada. Falla con un mensaje claro si no
# hay contraseña posible (sin terminal y sin sudo sin contraseña).
rf_sudo_acquire() {
  if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
    return 0
  fi
  if ! ( exec </dev/tty ) 2>/dev/null; then
    cat >&2 << 'EOF_MSG'
✗ apply necesita sudo y no hay forma de pedirlo: no hay terminal y sudo exige contraseña.
  No se tocó nada. Qué hacer:
    • corré make apply desde una terminal interactiva (pedirá la contraseña una vez), o
    • configurá sudo sin contraseña para este usuario, o
    • usá make safe (aplica solo el home y no corre tareas de root).
EOF_MSG
    return 1
  fi
  if ! sudo -v; then
    printf '✗ apply necesita sudo y no se pudo obtener. No se tocó nada.\n' >&2
    return 1
  fi
}

# Hace que chezmoi vea como "nunca ejecutados" todos los run_onchange_* del perfil.
# En chezmoi 2.73 el estado de un run_onchange vive en el bucket entryState, con la
# ruta absoluta del script como clave (scriptState es solo de run_once_*).
# Verificado con chezmoi real: borrar scriptState NO re-ejecuta nada.
rf_reset_script_state() {
  local source_dir="$1"
  shift
  local scripts script
  scripts="$("$@" managed -S "$source_dir" --include=scripts --path-style=absolute)"
  while IFS= read -r script; do
    [[ -n "$script" ]] || continue
    "$@" state delete --bucket=entryState --key="$script"
  done <<< "$scripts"
}

# Para el trap de rf_apply: global a propósito, el trap de EXIT corre fuera de la función.
RF_KEEPALIVE_PID=""
rf_apply_cleanup() {
  if [[ -n "$RF_KEEPALIVE_PID" ]]; then
    kill "$RF_KEEPALIVE_PID" 2>/dev/null || true
    wait "$RF_KEEPALIVE_PID" 2>/dev/null || true
    RF_KEEPALIVE_PID=""
  fi
}

# apply <source> [perfil]: apply completo, el repo gana y se aplica el 100 %:
#   1. sudo una sola vez (sudo -v) con keepalive que no sobrevive al apply;
#   2. borra el estado de los scripts de chezmoi, así TODOS los run_onchange_*
#      se re-ejecutan (un paquete borrado a mano se reinstala, etc.);
#   3. chezmoi apply --force con RF_APPLY_FULL=1: los scripts que se saltarían
#      sin sudo fallan en vez de omitir.
# DRY_RUN=1 solo imprime: no pide sudo ni toca el estado de chezmoi.
rf_apply() {
  local source_dir="$1" profile="${2:-}" chezmoi="${CHEZMOI_BIN:-chezmoi}"
  local -a prefix=()
  if [[ -n "$profile" ]]; then
    prefix=(env "CHEZMOI_PROFILE=$profile")
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    printf '  ▶ [dry-run] sudo -v (una sola vez, con keepalive; no se ejecuta)\n'
    printf '  ▶ [dry-run] %s state delete --bucket=entryState --key=<cada run_onchange_*> (re-ejecuta todos)\n' "$chezmoi"
    printf '  ▶ [dry-run] RF_APPLY_FULL=1 %s%s apply --force -S %s\n' "${prefix[*]:+${prefix[*]} }" "$chezmoi" "$source_dir"
    return 0
  fi

  rf_sudo_acquire || exit 1

  local rc=0
  RF_KEEPALIVE_PID=""
  trap rf_apply_cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM HUP
  if [[ $EUID -ne 0 ]]; then
    "$0" sudo-keepalive "$$" &
    RF_KEEPALIVE_PID=$!
  fi

  rf_reset_script_state "$source_dir" "${prefix[@]}" "$chezmoi"
  RF_APPLY_FULL=1 "${prefix[@]}" "$chezmoi" apply --force -S "$source_dir" || rc=$?
  exit "$rc"
}

[[ $# -ge 1 ]] || usage
case "$1" in
  profile) rf_profile ;;
  sudo-state) rf_sudo_state ;;
  source) rf_source ;;
  lose) rf_lose ;;
  lose-paths) rf_paths lose ;;
  script-paths) rf_paths script ;;
  apply) [[ $# -ge 2 ]] || usage; rf_apply "$2" "${3:-}" ;;
  sudo-keepalive) [[ $# -eq 2 ]] || usage; rf_sudo_keepalive "$2" ;;
  *) usage ;;
esac
