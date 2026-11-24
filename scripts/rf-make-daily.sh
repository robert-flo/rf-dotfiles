#!/usr/bin/env bash
# Helpers de los targets diarios del Makefile. La costura pública es make.
set -euo pipefail

usage() {
  printf 'usage: %s profile|sudo-state|source|source-link|lose|lose-paths|script-paths|apply|sudo-keepalive\n' "$(basename "$0")" >&2
  exit 2
}

# Códigos de salida de `lose`: 1 = hay archivos que un apply pisaría (lo usa make safe);
# 3 = no se pudo averiguar (chezmoi falló o no hay fuente). 2 es del uso incorrecto.
RF_EXIT_LOSE_FILES=1
RF_EXIT_LOSE_ERROR=3

# Copia central de producción: a donde apunta ~/.local/share/chezmoi en niri.
RF_CENTRAL_SOURCE="${RF_CENTRAL_SOURCE:-/z/rf-dotfiles}"

# Un directorio es fuente de chezmoi de este repo si trae la plantilla de exclusiones.
rf_is_source() {
  [[ -f "$1/.chezmoiignore.tmpl" ]]
}

# La fuente que chezmoi lee. Primero lo que declara `chezmoi source-path` si existe
# (en niri, ~/.local/share/chezmoi -> la copia central). Se devuelve la ruta canónica
# (readlink -f): un run_onchange que incluye .chezmoi.sourceDir cambia de hash si -S
# es el enlace y el apply se hizo por la ruta real, y status lo lista como R.
# En un usuario sin ese enlace (niri-classic) ese directorio no existe y todo fallaba:
# se cae al repo desde el que se corre make y, después, a la copia central. Esos
# fallbacks no se canonicalizan: make apply usa el directorio tal cual se invocó.
# Si nada sirve, error claro.
rf_source() {
  local declared="" candidate
  declared="$("${CHEZMOI_BIN:-chezmoi}" source-path 2>/dev/null)" || declared=""
  if [[ -n "$declared" && -d "$declared" ]]; then
    printf '%s\n' "$(readlink -f -- "$declared")"
    return 0
  fi
  for candidate in "$PWD" "$RF_CENTRAL_SOURCE"; do
    if rf_is_source "$candidate"; then
      printf '↪ la fuente de chezmoi (%s) no existe; uso %s (make apply crea el enlace)\n' \
        "${declared:-sin source-path}" "$candidate" >&2
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '✗ no encuentro la fuente de chezmoi: source-path=%s no existe y ni %s ni %s son un clon de rf-dotfiles.\n' \
    "${declared:-<chezmoi falló>}" "$PWD" "$RF_CENTRAL_SOURCE" >&2
  printf '  Corré make desde un clon de rf-dotfiles o creá el enlace: ln -s %s ~/.local/share/chezmoi\n' \
    "$RF_CENTRAL_SOURCE" >&2
  return 1
}

# Deja ~/.local/share/chezmoi -> copia central si falta. Solo en el perfil clavis (niri,
# niri-classic y sus usuarios de prueba): los otros perfiles no se tocan. Nunca pisa
# nada: si ya hay un directorio, un archivo o un enlace (aunque roto) en esa ruta, no
# la toca. DRY_RUN=1 solo imprime.
rf_ensure_source_link() {
  local link="${RF_SOURCE_LINK:-$HOME/.local/share/chezmoi}" target="$RF_CENTRAL_SOURCE"
  if [[ "$(rf_profile)" != clavis ]]; then
    return 0
  fi
  if [[ -e "$link" || -L "$link" ]]; then
    return 0
  fi
  if ! rf_is_source "$target"; then
    printf '  ! no creo %s: %s no es una copia de rf-dotfiles\n' "$link" "$target" >&2
    return 0
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    printf '  ▶ [dry-run] ln -s %s %s\n' "$target" "$link"
    return 0
  fi
  mkdir -p "$(dirname "$link")"
  ln -s "$target" "$link"
  printf '  ✓ enlace creado: %s -> %s\n' "$link" "$target"
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

# Imprime los archivos que se perderían y sale 1 si hay alguno. Si chezmoi falla
# (o no hay fuente) no inventa una lista: dice el error real y sale 3. Cada paso va
# aparte a propósito: dentro de `$(a | b)` el fallo de `a` se perdería o se confundiría
# con el «hay archivos».
# Global a propósito: el trap de EXIT corre fuera de la función.
RF_LOSE_ERR_FILE=""
rf_lose() {
  local source_dir status_text paths rc=0
  source_dir="$(rf_source)" || exit "$RF_EXIT_LOSE_ERROR"
  RF_LOSE_ERR_FILE="$(mktemp)"
  trap 'rm -f "$RF_LOSE_ERR_FILE"' EXIT
  status_text="$("${CHEZMOI_BIN:-chezmoi}" --color=false status -S "$source_dir" 2>"$RF_LOSE_ERR_FILE")" || rc=$?
  if (( rc != 0 )); then
    printf '✗ lose: chezmoi status falló (rc=%s) con -S %s; no sé qué archivos se pisarían.\n' "$rc" "$source_dir" >&2
    cat "$RF_LOSE_ERR_FILE" >&2
    exit "$RF_EXIT_LOSE_ERROR"
  fi
  paths="$(printf '%s\n' "$status_text" | rf_paths lose)"
  if [[ -n "$paths" ]]; then
    printf '%s\n' "$paths"
    exit "$RF_EXIT_LOSE_FILES"
  fi
}

# --- apply completo (make apply / apply-<perfil>) ---------------------------

RF_KEEPALIVE_TICK=5          # segundos entre revisiones de que el apply sigue vivo
RF_KEEPALIVE_REFRESH_TICKS=6 # cada cuántas revisiones se renueva sudo (30 s)

# Mantiene vivo el permiso de sudo mientras viva el proceso $1. Se lanza como
# `rf-make-daily.sh sudo-keepalive <pid>` para poder identificarlo con pgrep.
rf_sudo_keepalive() {
  local parent="$1" tick=0 sleeper=""
  trap '[[ -z "$sleeper" ]] || kill "$sleeper" 2>/dev/null; exit 0' TERM INT HUP
  while kill -0 "$parent" 2>/dev/null; do
    sleep "$RF_KEEPALIVE_TICK" &
    sleeper=$!
    wait "$sleeper" || true
    tick=$((tick + 1))
    if (( tick % RF_KEEPALIVE_REFRESH_TICKS == 0 )); then
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
    rf_ensure_source_link
    return 0
  fi

  rf_sudo_acquire || exit 1
  rf_ensure_source_link

  local rc=0
  RF_KEEPALIVE_PID=""
  trap rf_apply_cleanup EXIT
  if [[ $EUID -ne 0 ]]; then
    "$0" sudo-keepalive "$$" &
    RF_KEEPALIVE_PID=$!
  fi

  rf_reset_script_state "$source_dir" "${prefix[@]}" "$chezmoi"
  # chezmoi corre en segundo plano para poder reenviarle la señal: bash difiere los
  # traps mientras espera a un hijo en primer plano, y un kill al script dejaría
  # el apply (y los scripts de root) corriendo. <&0 conserva stdin; el reenvío es
  # TERM porque los procesos en segundo plano de un shell no interactivo ignoran INT.
  local child interrupted=0
  RF_APPLY_FULL=1 "${prefix[@]}" "$chezmoi" apply --force -S "$source_dir" <&0 &
  child=$!
  # shellcheck disable=SC2064 # se expande ahora a propósito: $child ya existe
  trap "interrupted=130; kill -TERM $child 2>/dev/null || true" INT
  # shellcheck disable=SC2064
  trap "interrupted=143; kill -TERM $child 2>/dev/null || true" TERM HUP
  wait "$child" || rc=$?
  while kill -0 "$child" 2>/dev/null; do
    wait "$child" || rc=$?
  done
  if (( interrupted != 0 )); then
    rc=$interrupted
  fi
  exit "$rc"
}

[[ $# -ge 1 ]] || usage
case "$1" in
  profile) rf_profile ;;
  sudo-state) rf_sudo_state ;;
  source) rf_source ;;
  source-link) rf_ensure_source_link ;;
  lose) rf_lose ;;
  lose-paths) rf_paths lose ;;
  script-paths) rf_paths script ;;
  apply) [[ $# -ge 2 ]] || usage; rf_apply "$2" "${3:-}" ;;
  sudo-keepalive) [[ $# -eq 2 ]] || usage; rf_sudo_keepalive "$2" ;;
  *) usage ;;
esac
