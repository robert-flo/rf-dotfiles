#!/usr/bin/env bash
# run_after_monocode-opencode: fija solo el proveedor; no toca el resto de la base.
# run_before_00-linuxmobile-repo: agrega el repo una vez.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS_COUNT=0
FAIL_COUNT=0

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

finish() {
  printf '  %s passed, %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
  if [[ "$FAIL_COUNT" -ne 0 ]]; then
    exit 1
  fi
}

REAL_CHEZMOI="$(command -v chezmoi || true)"
if [[ -z "$REAL_CHEZMOI" ]]; then
  printf '  [SKIP] sin chezmoi real para renderizar los scripts\n'
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

"$REAL_CHEZMOI" execute-template -S "$REPO_ROOT" < "$REPO_ROOT/run_after_monocode-opencode.sh.tmpl" > "$tmp/pin.sh"
chmod +x "$tmp/pin.sh"
"$REAL_CHEZMOI" execute-template -S "$REPO_ROOT" < "$REPO_ROOT/run_before_00-linuxmobile-repo.sh.tmpl" > "$tmp/repo.sh"
chmod +x "$tmp/repo.sh"

python3 - "$tmp/mono.db" << 'PY'
import json, sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("create table settings (key text primary key, value text not null)")
workspace = {
    "window": {"size": [1, 2]},
    "preferences": {"default_provider": None, "binary_paths": {}, "theme": "dark"},
}
con.execute("insert into settings values ('workspace', ?)", (json.dumps(workspace),))
con.commit()
PY

out="$(MONOCODE_DB="$tmp/mono.db" MONOCODE_OPENCODE_BIN="/tmp/shim/opencode" bash "$tmp/pin.sh" 2>&1)"
assert_contains "$out" "proveedor por defecto opencode" "primera corrida fija el proveedor"
python3 - "$tmp/mono.db" << 'PY'
import json, sqlite3, sys
con = sqlite3.connect(sys.argv[1])
data = json.loads(con.execute("select value from settings where key='workspace'").fetchone()[0])
prefs = data["preferences"]
assert data["window"]["size"] == [1, 2], data
assert prefs["theme"] == "dark", prefs
assert prefs["default_provider"] == "opencode", prefs
assert prefs["binary_paths"]["opencode"] == "/tmp/shim/opencode", prefs
print("ok")
PY
assert_eq "ok" "ok" "la base conserva ventana y tema"

out="$(MONOCODE_DB="$tmp/mono.db" MONOCODE_OPENCODE_BIN="/tmp/shim/opencode" bash "$tmp/pin.sh" 2>&1)"
assert_contains "$out" "ya usa opencode" "segunda corrida no reescribe"

out="$(MONOCODE_DB="$tmp/no-such.db" MONOCODE_OPENCODE_BIN="/tmp/shim/opencode" bash "$tmp/pin.sh" 2>&1)"
code=$?
assert_eq "0" "$code" "sin base sale 0"
assert_contains "$out" "todavía no tiene base" "sin base lo dice"

printf 'Server = https://otro\n' > "$tmp/pacman.conf"
mkdir -p "$tmp/pacman.d"
out="$(LINUXMOBILE_PACMAN_CONF="$tmp/pacman.conf" LINUXMOBILE_MIRRORLIST="$tmp/pacman.d/linuxmobile-mirrorlist" bash "$tmp/repo.sh" 2>&1)"
assert_contains "$out" "+= [linuxmobile]" "agrega el repo si falta"
count="$(grep -c '^\[linuxmobile\]' "$tmp/pacman.conf")"
assert_eq "1" "$count" "una sola sección"
out="$(LINUXMOBILE_PACMAN_CONF="$tmp/pacman.conf" LINUXMOBILE_MIRRORLIST="$tmp/pacman.d/linuxmobile-mirrorlist" bash "$tmp/repo.sh" 2>&1)"
assert_contains "$out" "ya incluye [linuxmobile]" "segunda corrida no duplica"
assert_contains "$out" "ya estaba" "el mirrorlist no se reescribe"
count="$(grep -c '^\[linuxmobile\]' "$tmp/pacman.conf")"
assert_eq "1" "$count" "sigue una sola sección"

finish
