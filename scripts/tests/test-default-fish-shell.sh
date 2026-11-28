#!/usr/bin/env bash
# ==============================================================================
# test-default-fish-shell.sh — verifica que Ghostty, Kitty y bashrc garanticen
# fish como shell interactiva en niri/niri-classic/niri-test sin afectar a
# rollo ni niri-upstream, y sin depender de ~/.bashrc para Ghostty/Kitty.
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GHOSTTY_TMPL="$REPO_ROOT/dot_config/ghostty/config.tmpl"
KITTY_TMPL="$REPO_ROOT/dot_config/kitty/robert.conf.tmpl"
BASHRC_TMPL="$REPO_ROOT/dot_bashrc.tmpl"
RF_COMMON_FISH="$REPO_ROOT/dot_config/fish/conf.d/rf-common.fish"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  [PASS] %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf '  [FAIL] %s\n' "$1" >&2; }
check() { local d="$1"; shift; if "$@" > /dev/null; then pass "$d"; else fail "$d"; fi; }

for tool in chezmoi fish; do
  command -v "$tool" >/dev/null || { echo "falta $tool" >&2; exit 1; }
done

FISH_BIN="$(command -v fish)"

render_for_user() {
  local tmpl="$1" user="$2"
  chezmoi execute-template --source="$REPO_ROOT" \
    --override-data "{\"chezmoi\":{\"username\":\"$user\",\"homeDir\":\"/tmp/$user\"}}" \
    < "$tmpl"
}

check "dot_config/ghostty/config.tmpl existe" [ -f "$GHOSTTY_TMPL" ]
check "dot_config/ghostty/config (sin .tmpl) fue eliminado" [ ! -e "$REPO_ROOT/dot_config/ghostty/config" ]
check "ghostty template sin rutas /home/ hardcodeadas" [ -z "$(grep -F '/home/' "$GHOSTTY_TMPL" || true)" ]
check "kitty template sin rutas /home/ hardcodeadas" [ -z "$(grep -F '/home/' "$KITTY_TMPL" || true)" ]

for u in niri niri-classic niri-test; do
  g_out="$(render_for_user "$GHOSTTY_TMPL" "$u")"
  k_out="$(render_for_user "$KITTY_TMPL" "$u")"
  b_out="$(render_for_user "$BASHRC_TMPL" "$u")"

  check "ghostty ($u): fija command = $FISH_BIN" grep -qxF "command = $FISH_BIN" <<<"$g_out"
  check "ghostty ($u): sin placeholders" bash -c '! grep -qF "{{" <<<"$1"' _ "$g_out"
  check "kitty ($u): fija shell $FISH_BIN" grep -qxF "shell $FISH_BIN" <<<"$k_out"
  check "kitty ($u): sin placeholders" bash -c '! grep -qF "{{" <<<"$1"' _ "$k_out"
  check "bashrc ($u): conserva exec fish" grep -qF 'exec fish $LOGIN_OPTION' <<<"$b_out"
done

for u in rollo nyxuri niri-upstream; do
  g_out="$(render_for_user "$GHOSTTY_TMPL" "$u")"
  check "ghostty ($u): no fuerza command = fish" bash -c '! grep -qE "^command =" <<<"$1"' _ "$g_out"
done

k_up="$(render_for_user "$KITTY_TMPL" "niri-upstream")"
check "kitty (niri-upstream): no fuerza shell fish" bash -c '! grep -qE "^shell " <<<"$1"' _ "$k_up"

check "rf-common.fish incluye shims de mise" grep -qF '$HOME/.local/share/mise/shims' "$RF_COMMON_FISH"
check "rf-common.fish sintaxis válida en fish" fish -n "$RF_COMMON_FISH"

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
