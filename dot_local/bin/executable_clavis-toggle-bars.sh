#!/usr/bin/env bash
# Clavis Zen / Immersive Mode: Toggle top bar and bottom dock
set -euo pipefail

python3 - << 'EOF'
import json
import os
import subprocess
import sys
import tempfile

cfg_path = os.path.expanduser("~/.config/clavis/config.json")
dock_path = os.path.expanduser("~/.config/clavis/dock.json")

def atomic_write_json(path, data):
    dir_name = os.path.dirname(path)
    os.makedirs(dir_name, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=dir_name, delete=False, encoding="utf-8") as tf:
        json.dump(data, tf, indent=2, ensure_ascii=False)
        tf.write("\n")
        temp_path = tf.name
    os.replace(temp_path, path)

# Read current state
bar_enabled = True
cfg = {}
if os.path.exists(cfg_path):
    try:
        with open(cfg_path, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        bar_enabled = cfg.get("bar", {}).get("enabled", True)
    except Exception as e:
        print(f"Error reading {cfg_path}: {e}", file=sys.stderr)

dock = {}
if os.path.exists(dock_path):
    try:
        with open(dock_path, "r", encoding="utf-8") as f:
            dock = json.load(f)
    except Exception as e:
        print(f"Error reading {dock_path}: {e}", file=sys.stderr)

new_state = not bar_enabled

# Update config.json (Bar and Keystone central island)
if "bar" not in cfg:
    cfg["bar"] = {}
cfg["bar"]["enabled"] = new_state

if "keystone" not in cfg:
    cfg["keystone"] = {}
cfg["keystone"]["enabled"] = new_state

try:
    atomic_write_json(cfg_path, cfg)
except Exception as e:
    print(f"Error writing {cfg_path}: {e}", file=sys.stderr)

# Update dock.json
if "options" not in dock:
    dock["options"] = {}
dock["options"]["enabled"] = new_state
try:
    atomic_write_json(dock_path, dock)
except Exception as e:
    print(f"Error writing {dock_path}: {e}", file=sys.stderr)

# Notification
if new_state:
    subprocess.run([
        "notify-send", "-a", "Clavis", "-i", "preferences-system-windows", "-t", "3",
        "Modo Normal", "Barra, Isla y Dock restaurados"
    ], check=False)
else:
    subprocess.run([
        "notify-send", "-a", "Clavis", "-i", "preferences-desktop-display", "-t", "3",
        "Modo Inmersivo", "Barra, Isla y Dock ocultos"
    ], check=False)
EOF
