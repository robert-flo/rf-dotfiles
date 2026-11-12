#!/usr/bin/env bash
# Clavis: Toggle maximize-to-edges across all windows in active workspace
set -euo pipefail

python3 - << 'EOF'
import json
import subprocess
import sys

try:
    ws_raw = subprocess.check_output(["niri", "msg", "--json", "workspaces"])
    ws_data = json.loads(ws_raw)
except Exception as e:
    sys.exit(0)

active_ws = next((w for w in ws_data if w.get("is_focused")), None) or next((w for w in ws_data if w.get("is_active")), None)
if not active_ws:
    sys.exit(0)

ws_id = active_ws.get("id")
out_name = active_ws.get("output", "")

try:
    outputs_raw = subprocess.check_output(["niri", "msg", "--json", "outputs"])
    outputs_data = json.loads(outputs_raw)
    out_cfg = outputs_data.get(out_name, {}).get("logical", {"width": 1920, "height": 1080})
    screen_w, screen_h = out_cfg["width"], out_cfg["height"]
except Exception:
    screen_w, screen_h = 1920, 1080

try:
    win_raw = subprocess.check_output(["niri", "msg", "--json", "windows"])
    win_data = json.loads(win_raw)
except Exception:
    sys.exit(0)

ws_windows = [
    w for w in win_data
    if w.get("workspace_id") == ws_id and not w.get("is_floating") and not w.get("is_minimized")
]

if not ws_windows:
    sys.exit(0)

init_focused = next((w["id"] for w in ws_windows if w.get("is_focused")), ws_windows[0]["id"])

def is_maximized(w):
    sz = w.get("layout", {}).get("tile_size", [0, 0])
    return sz[0] >= screen_w - 2 and sz[1] >= screen_h - 2

any_not_max = any(not is_maximized(w) for w in ws_windows)
target_action = "maximize" if any_not_max else "restore"

for w in ws_windows:
    if target_action == "maximize":
        if not is_maximized(w):
            subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(w["id"])], check=False)
            subprocess.run(["niri", "msg", "action", "maximize-window-to-edges"], check=False)
    else:
        if is_maximized(w):
            subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(w["id"])], check=False)
            subprocess.run(["niri", "msg", "action", "maximize-window-to-edges"], check=False)

if init_focused:
    subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(init_focused)], check=False)

if target_action == "maximize":
    subprocess.run([
        "notify-send", "-a", "Clavis", "-i", "preferences-desktop-display", "-t", "3",
        "Pantalla Completa", "Todas las ventanas a bordes físicos"
    ], check=False)
else:
    subprocess.run([
        "notify-send", "-a", "Clavis", "-i", "preferences-system-windows", "-t", "3",
        "Modo Mosaico", "Ventanas restauradas con gaps"
    ], check=False)
EOF
