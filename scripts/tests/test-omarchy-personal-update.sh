#!/usr/bin/env bash
# ==============================================================================
# test-omarchy-personal-update.sh — Comportamiento externo del actualizador
# horario de [omarchy-personal] (scripts/omarchy-personal-update) y sus
# unidades systemd (HR-CLAVIS#237).
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UPDATER="$REPO_ROOT/scripts/omarchy-personal-update"
SERVICE_UNIT="$REPO_ROOT/scripts/systemd/omarchy-personal-update.service"
TIMER_UNIT="$REPO_ROOT/scripts/systemd/omarchy-personal-update.timer"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@"; then pass "$d"; else fail "$d"; fi; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

MOCK_BIN="$TMPDIR_TEST/bin"
mkdir -p "$MOCK_BIN"

# Enlazamos las utilidades mínimas que usa el script y el mock para correr con PATH aislado
for tool in awk bash cat cp mktemp rm; do
  ln -s "$(command -v "$tool")" "$MOCK_BIN/$tool"
done

cat >"$MOCK_BIN/pacman" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$MOCK_PACMAN_LOG"

cfg=""
prev=""
for arg in "$@"; do
  if [[ "$prev" == "--config" ]]; then
    cfg="$arg"
    break
  fi
  prev="$arg"
done

if [[ -n "$cfg" && -f "$cfg" ]]; then
  printf '%s\n' "$cfg" >> "$MOCK_CONFIG_PATHS"
  cp "$cfg" "$MOCK_LAST_CONFIG"
fi

case "${1:-}" in
  -Sy)
    exit 0
    ;;
  -Qu)
    if [[ -n "${MOCK_UPDATES:-}" ]]; then
      printf '%s\n' "$MOCK_UPDATES"
      exit 0
    fi
    exit 1
    ;;
  -S)
    exit 0
    ;;
  *)
    echo "unexpected pacman args: $*" >&2
    exit 99
    ;;
esac
MOCK
chmod +x "$MOCK_BIN/pacman"

# --- Archivos versionados y unidades systemd ----------------------------------
check "scripts/omarchy-personal-update existe y es ejecutable" [ -x "$UPDATER" ]
check "unidad .service existe" [ -f "$SERVICE_UNIT" ]
check "unidad .timer existe" [ -f "$TIMER_UNIT" ]
check ".service invoca /usr/local/bin/omarchy-personal-update" grep -qx 'ExecStart=/usr/local/bin/omarchy-personal-update' "$SERVICE_UNIT"
check ".timer apunta a omarchy-personal-update.service" grep -qx 'Unit=omarchy-personal-update.service' "$TIMER_UNIT"
check ".timer es horario (OnCalendar=hourly)" grep -qx 'OnCalendar=hourly' "$TIMER_UNIT"

# --- Escenario 1: salida 0 con db.lck presente --------------------------------
LOCK_FILE="$TMPDIR_TEST/db.lck"
CONF_FILE="$TMPDIR_TEST/omarchy-personal.conf"
: > "$LOCK_FILE"
printf '[omarchy-personal]\nServer = https://example.invalid/\n' > "$CONF_FILE"

LOG1="$TMPDIR_TEST/log1"
: > "$LOG1"
rc=0
out1="$(PATH="$MOCK_BIN" PACMAN_DB_LOCK="$LOCK_FILE" OMARCHY_PERSONAL_CONF="$CONF_FILE" \
  MOCK_PACMAN_LOG="$LOG1" MOCK_CONFIG_PATHS="$TMPDIR_TEST/cfg1" MOCK_LAST_CONFIG="$TMPDIR_TEST/last1" \
  "$UPDATER" 2>&1)" || rc=$?
check "db.lck presente: sale con código 0" [ "$rc" -eq 0 ]
check "db.lck presente: informa que pacman está bloqueado" grep -qi 'bloqueado' <<< "$out1"
check "db.lck presente: no invoca pacman" [ ! -s "$LOG1" ]

# --- Escenario 2: salida 0 sin omarchy-personal.conf --------------------------
rm -f "$LOCK_FILE"
MISSING_CONF="$TMPDIR_TEST/no-existe.conf"
LOG2="$TMPDIR_TEST/log2"
: > "$LOG2"
rc=0
out2="$(PATH="$MOCK_BIN" PACMAN_DB_LOCK="$LOCK_FILE" OMARCHY_PERSONAL_CONF="$MISSING_CONF" \
  MOCK_PACMAN_LOG="$LOG2" MOCK_CONFIG_PATHS="$TMPDIR_TEST/cfg2" MOCK_LAST_CONFIG="$TMPDIR_TEST/last2" \
  "$UPDATER" 2>&1)" || rc=$?
check "sin omarchy-personal.conf: sale con código 0" [ "$rc" -eq 0 ]
check "sin omarchy-personal.conf: imprime mensaje claro" grep -q "$MISSING_CONF" <<< "$out2"
check "sin omarchy-personal.conf: no invoca pacman" [ ! -s "$LOG2" ]

# --- Escenario 3: sin actualizaciones pendientes ------------------------------
LOG3="$TMPDIR_TEST/log3"
CFG_PATHS3="$TMPDIR_TEST/cfg3"
LAST_CFG3="$TMPDIR_TEST/last3"
: > "$LOG3"
: > "$CFG_PATHS3"
rc=0
out3="$(PATH="$MOCK_BIN" PACMAN_DB_LOCK="$LOCK_FILE" OMARCHY_PERSONAL_CONF="$CONF_FILE" \
  MOCK_PACMAN_LOG="$LOG3" MOCK_CONFIG_PATHS="$CFG_PATHS3" MOCK_LAST_CONFIG="$LAST_CFG3" \
  "$UPDATER" 2>&1)" || rc=$?
check "sin updates: sale con código 0" [ "$rc" -eq 0 ]
check "sin updates: invoca pacman -Sy y -Qu (sin -S)" [ "$(wc -l < "$LOG3")" -eq 2 ]
check "sin updates: primera llamada es -Sy --config <tmp> --noconfirm" grep -qE '^-Sy --config [^ ]+ --noconfirm$' <(sed -n '1p' "$LOG3")
check "sin updates: segunda llamada es -Qu --config <tmp>" grep -qE '^-Qu --config [^ ]+$' <(sed -n '2p' "$LOG3")
check "sin updates: informa que está al día" grep -qi 'al día' <<< "$out3"
tmpconf3="$(head -n 1 "$CFG_PATHS3")"
check "sin updates: limpia la configuración temporal al salir" [ ! -e "$tmpconf3" ]

# --- Escenario 4: con actualizaciones pendientes ------------------------------
LOG4="$TMPDIR_TEST/log4"
CFG_PATHS4="$TMPDIR_TEST/cfg4"
LAST_CFG4="$TMPDIR_TEST/last4"
: > "$LOG4"
: > "$CFG_PATHS4"
rc=0
out4="$(PATH="$MOCK_BIN" PACMAN_DB_LOCK="$LOCK_FILE" OMARCHY_PERSONAL_CONF="$CONF_FILE" \
  MOCK_PACMAN_LOG="$LOG4" MOCK_CONFIG_PATHS="$CFG_PATHS4" MOCK_LAST_CONFIG="$LAST_CFG4" \
  MOCK_UPDATES=$'herdr 0.1.0-1 -> 0.2.0-1\nravn-trio 0.1.13-1 -> 0.1.14-1' \
  "$UPDATER" 2>&1)" || rc=$?
check "con updates: sale con código 0" [ "$rc" -eq 0 ]
check "con updates: invoca exactamente -Sy, -Qu y -S" [ "$(wc -l < "$LOG4")" -eq 3 ]
check "con updates: -Sy usa --config temporal y --noconfirm" grep -qE '^-Sy --config [^ ]+ --noconfirm$' <(sed -n '1p' "$LOG4")
check "con updates: -Qu usa --config temporal" grep -qE '^-Qu --config [^ ]+$' <(sed -n '2p' "$LOG4")
check "con updates: -S instala solo paquetes listados con --noconfirm --needed" grep -qE '^-S --config [^ ]+ --noconfirm --needed herdr ravn-trio$' <(sed -n '3p' "$LOG4")
check "con updates: todas las llamadas usan el mismo tmpconf" [ "$(sort -u "$CFG_PATHS4" | wc -l)" -eq 1 ]
check "con updates: tmpconf incluye únicamente OMARCHY_PERSONAL_CONF" [ "$(grep -c -E '^Include[[:space:]]*=' "$LAST_CFG4")" -eq 1 ]
check "con updates: tmpconf apunta a OMARCHY_PERSONAL_CONF" grep -qx "Include     = $CONF_FILE" "$LAST_CFG4"
check "con updates: tmpconf no incluye core/extra/omarchy" [ -z "$(grep -E '^\[(core|extra|omarchy)\]' "$LAST_CFG4" || true)" ]
tmpconf4="$(head -n 1 "$CFG_PATHS4")"
check "con updates: limpia la configuración temporal al salir" [ ! -e "$tmpconf4" ]
check "con updates: imprime paquetes a actualizar" grep -q 'herdr ravn-trio' <<< "$out4"

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
