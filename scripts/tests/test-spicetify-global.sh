#!/usr/bin/env bash
# Spotify es una instalación global (/opt/spotify): el primer usuario con Spicetify la parchea
# y el segundo ya no puede hacer `spicetify backup` (no queda ningún *.spa que copiar). El
# script run_onchange_after_install-spicetify debe reconocer «ya parcheado, sin backup propio»,
# decirlo y salir 0 (también con RF_APPLY_FULL=1) sin tocar el parche. Ramas cubiertas:
# parcheado, limpio, mixto, sin prefs, con backup propio y apply completo sin sudo.
# Interfaz pública: salida y código de salida del script renderizado, lo que recibe un
# spicetify falso (que imita src/status/spotify de v2.46.x) y el árbol de Spotify falso.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPL="$REPO_ROOT/run_onchange_after_install-spicetify.sh.tmpl"

PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [PASS] %s\n' "$msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL] %s (no contiene %q)\n' "$msg" "$needle" >&2
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [PASS] %s\n' "$msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL] %s (contiene %q inesperadamente)\n' "$msg" "$needle" >&2
  fi
}

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [PASS] %s\n' "$msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL] %s (esperado=%q, actual=%q)\n' "$msg" "$expected" "$actual" >&2
  fi
}

assert_ne() {
  local unexpected="$1" actual="$2" msg="$3"
  if [[ "$unexpected" != "$actual" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '  [PASS] %s\n' "$msg"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf '  [FAIL] %s (no debía ser %q)\n' "$msg" "$actual" >&2
  fi
}

finish() {
  printf '  %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
  if [[ "$FAIL_COUNT" -ne 0 ]]; then
    exit 1
  fi
}

if ! command -v chezmoi >/dev/null 2>&1; then
  printf '  [SKIP] sin chezmoi real para renderizar el script\n'
  exit 0
fi

tmp="$(mktemp -d)"
cleanup() {
  chmod -R u+rwX "$tmp" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/bin"
export SPOTIFY_DIR="$tmp/spotify"
export SPICETIFY_LOG="$tmp/spicetify.log"
export SUDO_LOG="$tmp/sudo.log"

# spicetify falso, mismo criterio que v2.46.x: `backup` copia los *.spa y, si no hay ninguno,
# falla con «Failed to backup app files»; `apply` exige el backup propio ([Backup] with=...);
# `backup apply` sobre Spotify limpio deja Apps solo con carpetas (xpui/, login/), o sea parcheado.
# SPICETIFY_APPLY_FAIL=1 hace fallar `apply`.
cat > "$tmp/bin/spicetify" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SPICETIFY_LOG:?}"
apps="${SPOTIFY_DIR:?}/Apps"
config="${SPICETIFY_CONFIG_FILE:?}"
backup() {
  if ! compgen -G "$apps/*.spa" > /dev/null; then
    echo "Failed to backup app files" >&2
    echo "Reinstall Spotify and try again" >&2
    return 1
  fi
  # Como spicetify: la versión del backup sale de app.last-launched-version en prefs.
  local ver
  ver="$(sed -n 's/^app.last-launched-version="\(.*\)"/\1/p' "$(dirname "$config")/../spotify/prefs")"
  printf '\n[Backup]\nversion = %s\nwith    = 2.46.7\n' "$ver" >> "$config"
}
apply() {
  if [[ "${SPICETIFY_APPLY_FAIL:-0}" == 1 ]]; then return 1; fi
  if ! grep -q '^with' "$config"; then
    echo 'Preprocessed Spotify data is outdated.' >&2
    return 1
  fi
  if compgen -G "$apps/*.spa" > /dev/null; then
    rm -f "$apps"/*.spa
    mkdir -p "$apps/xpui" "$apps/login"
  fi
}
case "$*" in
  "backup apply") backup && apply ;;
  "apply") apply ;;
  *) echo "spicetify falso: no sé $*" >&2; exit 2 ;;
esac
EOF
cat > "$tmp/bin/sudo" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${SUDO_LOG:?}"
[[ "${SUDO_MODE:-nopass}" == nopass ]] && exit 0
exit 1
EOF
chmod +x "$tmp/bin/spicetify" "$tmp/bin/sudo"
export PATH="$tmp/bin:$PATH"

# Un «usuario» = un HOME con su config-xpui.ini (con o sin [Backup]) y su script renderizado.
make_user() {
  local name="$1" with_backup="$2" home="$tmp/home-$1"
  mkdir -p "$home/.config/spicetify"
  {
    printf '[Setting]\nspotify_path = %s\nprefs_path = %s/.config/spotify/prefs\n' "$SPOTIFY_DIR" "$home"
    printf '[Patch]\n'
    if [[ "$with_backup" == yes ]]; then
      printf '\n[Backup]\nversion = 1.3.8.620\nwith    = 2.46.7\n'
    fi
  } > "$home/.config/spicetify/config-xpui.ini"
  HOME="$home" chezmoi execute-template -S "$REPO_ROOT" < "$TMPL" > "$home/install-spicetify.sh"
}

# Spotify falso: stock = xpui.spa y login.spa; patched = xpui/ y login/; mixed = ambos.
make_spotify() {
  chmod -R u+rwX "$SPOTIFY_DIR" 2>/dev/null || true
  rm -rf "$SPOTIFY_DIR"
  mkdir -p "$SPOTIFY_DIR/Apps"
  # El binario falso responde --version como el real (SPOTIFY_VERSION_FAIL=1 lo hace fallar).
  cat > "$SPOTIFY_DIR/spotify" << 'EOS'
#!/usr/bin/env bash
[[ "${SPOTIFY_VERSION_FAIL:-0}" == 1 ]] && exit 1
echo "Spotify version 1.3.8.620.gdeadbeef, Copyright (c) 2026, Spotify Ltd"
EOS
  chmod +x "$SPOTIFY_DIR/spotify"
  case "$1" in
    stock) : > "$SPOTIFY_DIR/Apps/xpui.spa"; : > "$SPOTIFY_DIR/Apps/login.spa" ;;
    patched) mkdir -p "$SPOTIFY_DIR/Apps/xpui" "$SPOTIFY_DIR/Apps/login"; echo patch > "$SPOTIFY_DIR/Apps/xpui/index.html" ;;
    mixed) : > "$SPOTIFY_DIR/Apps/xpui.spa"; mkdir -p "$SPOTIFY_DIR/Apps/xpui"; echo patch > "$SPOTIFY_DIR/Apps/xpui/index.html" ;;
  esac
}

# Huella del árbol: nombre, tamaño, permisos y mtime de cada entrada.
snapshot() {
  find "$SPOTIFY_DIR" -printf '%p %y %m %s %T@\n' | sort
}

# run_user <nombre> [VAR=valor…]: corre el script de ese usuario; deja $out y $code.
run_user() {
  local name="$1"; shift
  : > "$SPICETIFY_LOG"
  : > "$SUDO_LOG"
  set +e
  out="$(env HOME="$tmp/home-$name" SPICETIFY_CONFIG_FILE="$tmp/home-$name/.config/spicetify/config-xpui.ini" "$@" bash "$tmp/home-$name/install-spicetify.sh" 2>&1)"
  code=$?
  set -e
}

# --- control: el spicetify falso reproduce el fallo real sobre un Spotify ya parcheado ---
make_spotify patched
make_user control no
set +e
SPICETIFY_CONFIG_FILE="$tmp/home-control/.config/spicetify/config-xpui.ini" spicetify backup apply > /dev/null 2>&1
code=$?
set -e
assert_ne "0" "$code" "control: backup apply sobre Spotify parcheado falla (el fallo de niri-classic)"

# --- parcheado y sin backup propio: sale 0, lo dice y no toca nada ---
make_spotify patched
make_user classic no
before="$(snapshot)"
run_user classic
assert_eq "0" "$code" "parcheado sin backup propio: rc 0"
assert_contains "$out" "ya está parcheado" "parcheado: el script lo dice"
assert_eq "" "$(cat "$SPICETIFY_LOG")" "parcheado: no corre spicetify (ni backup ni apply ni restore)"
assert_eq "$before" "$(snapshot)" "parcheado: el árbol de Spotify queda idéntico (nombre, tamaño, permisos, mtime)"
assert_eq "no" "$([[ -e "$tmp/home-classic/.config/spotify/prefs" ]] && echo si || echo no)" "parcheado: no crea prefs que no hacen falta"
run_user classic
assert_eq "0" "$code" "parcheado: segunda corrida seguida, rc 0"
assert_eq "$before" "$(snapshot)" "parcheado: segunda corrida tampoco toca el parche"
assert_eq "" "$(cat "$SUDO_LOG")" "parcheado: no pide sudo ni cambia permisos"

# --- parcheado con RF_APPLY_FULL=1, sin sudo y sin permiso de escritura: sigue siendo «ya hecho» ---
make_spotify patched
make_user classic no
if [[ "$EUID" -ne 0 ]]; then
  chmod -R a-w "$SPOTIFY_DIR"
  before="$(snapshot)"
  run_user classic SUDO_MODE=deny RF_APPLY_FULL=1
  assert_eq "0" "$code" "parcheado + RF_APPLY_FULL=1 sin sudo: rc 0 (no es falta de sudo)"
  assert_not_contains "$out" "ERROR" "parcheado + RF_APPLY_FULL=1: sin error"
  assert_eq "$before" "$(snapshot)" "parcheado + RF_APPLY_FULL=1: parche intacto"
fi

# --- Spotify limpio, usuario sin prefs: primer usuario aplica bien, el segundo no rompe ---
make_spotify stock
make_user niri no
make_user classic no
run_user niri
assert_eq "0" "$code" "limpio sin prefs: primer usuario, rc 0"
assert_eq "backup apply" "$(cat "$SPICETIFY_LOG")" "limpio: el primer usuario hace backup apply"
assert_eq "si" "$([[ -f "$tmp/home-niri/.config/spotify/prefs" ]] && echo si || echo no)" "limpio sin prefs: crea prefs para spicetify"
assert_eq 'app.last-launched-version="1.3.8.620.gdeadbeef"' "$(cat "$tmp/home-niri/.config/spotify/prefs")" "limpio sin prefs: siembra la versión de Spotify (el backup no queda con versión vacía)"
assert_contains "$(cat "$tmp/home-niri/.config/spicetify/config-xpui.ini")" "version = 1.3.8.620.gdeadbeef" "limpio sin prefs: el backup registra esa versión"
assert_contains "$(cat "$tmp/home-niri/.config/spicetify/config-xpui.ini")" "[Backup]" "limpio: el primer usuario queda con su backup"
assert_eq "no" "$(compgen -G "$SPOTIFY_DIR/Apps/*.spa" > /dev/null && echo si || echo no)" "limpio: tras el primer usuario Spotify queda parcheado"
before="$(snapshot)"
run_user classic
assert_eq "0" "$code" "segundo usuario tras el primero: rc 0"
assert_contains "$out" "ya está parcheado" "segundo usuario: dice que ya está parcheado"
assert_eq "" "$(cat "$SPICETIFY_LOG")" "segundo usuario: no corre spicetify"
assert_eq "$before" "$(snapshot)" "segundo usuario: no toca el parche del primero"
run_user classic
assert_eq "0" "$code" "segundo usuario: segunda corrida seguida, rc 0"

# --- el primer usuario, con backup propio y Spotify parcheado, re-aplica con apply y sigue andando ---
run_user niri
assert_eq "0" "$code" "primer usuario otra vez (parcheado + backup propio): rc 0"
assert_eq "apply" "$(cat "$SPICETIFY_LOG")" "primer usuario: solo spicetify apply (sin backup apply)"
assert_contains "$out" "Aplicando tema y extensiones" "primer usuario: flujo normal de re-aplicar"

# --- con backup propio y Spotify parcheado, si apply falla no se intenta backup apply (no hay .spa) ---
run_user niri SPICETIFY_APPLY_FAIL=1
assert_ne "0" "$code" "parcheado + backup propio + apply falla: el fallo se propaga"
assert_eq "apply" "$(cat "$SPICETIFY_LOG")" "parcheado + backup propio: no cae a backup apply"

# --- con backup propio y Spotify limpio (reinstalado): apply falla y se rehace con backup apply ---
make_spotify stock
run_user niri SPICETIFY_APPLY_FAIL=1
assert_eq "apply
backup apply" "$(cat "$SPICETIFY_LOG")" "limpio + backup propio: conserva el fallback apply || backup apply"

# --- limpio con prefs que ya traen versión: no se pisa ni se duplica ---
make_spotify stock
make_user withprefs no
mkdir -p "$tmp/home-withprefs/.config/spotify"
printf 'app.last-launched-version="9.9.9.1.gabc"\n' > "$tmp/home-withprefs/.config/spotify/prefs"
run_user withprefs
assert_eq "0" "$code" "limpio con prefs: rc 0"
assert_eq 'app.last-launched-version="9.9.9.1.gabc"' "$(cat "$tmp/home-withprefs/.config/spotify/prefs")" "limpio con prefs: conserva su versión, sin duplicar"

# --- limpio sin prefs y el binario no responde --version: sigue sin sembrar nada ---
make_spotify stock
make_user nover no
run_user nover SPOTIFY_VERSION_FAIL=1
assert_eq "0" "$code" "limpio sin prefs y sin --version: rc 0"
assert_eq "" "$(cat "$tmp/home-nover/.config/spotify/prefs")" "limpio sin prefs y sin --version: prefs queda vacío"
assert_eq "backup apply" "$(cat "$SPICETIFY_LOG")" "limpio sin prefs y sin --version: igual hace backup apply"

# --- mixto (reinstalación sobre carpetas viejas): Spicetify lo deja respaldar ---
make_spotify mixed
make_user mixed no
run_user mixed
assert_eq "0" "$code" "mixto sin backup propio: rc 0"
assert_eq "backup apply" "$(cat "$SPICETIFY_LOG")" "mixto: es respaldable, flujo normal backup apply"

# --- RF_APPLY_FULL=1 sin sudo y sin escritura sobre Spotify limpio: sigue fallando ---
if [[ "$EUID" -ne 0 ]]; then
  make_spotify stock
  make_user full no
  chmod -R a-w "$SPOTIFY_DIR"
  run_user full SUDO_MODE=deny RF_APPLY_FULL=1
  assert_ne "0" "$code" "limpio + RF_APPLY_FULL=1 sin sudo ni escritura: falla"
  assert_contains "$out" "apply completo" "limpio + RF_APPLY_FULL=1: explica por qué falla"
  assert_eq "" "$(cat "$SPICETIFY_LOG")" "limpio + RF_APPLY_FULL=1: no corre spicetify"
  run_user full SUDO_MODE=deny
  assert_eq "0" "$code" "limpio sin RF_APPLY_FULL sigue tolerante: rc 0"
  assert_contains "$out" "omitiendo Spicetify" "limpio sin RF_APPLY_FULL: conserva el aviso de omitir"
fi

# --- Spotify ausente: sigue omitiendo ---
chmod -R u+rwX "$SPOTIFY_DIR"
rm -rf "$SPOTIFY_DIR"
run_user classic
assert_eq "0" "$code" "sin Spotify: rc 0"
assert_contains "$out" "no existe" "sin Spotify: conserva el aviso"

finish
