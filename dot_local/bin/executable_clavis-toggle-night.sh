#!/usr/bin/env bash
# Clavis Night Mode / Eye Care toggle
set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/clavis/display-color.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat <<'EOF' > "$CONFIG_FILE"
{
  "gamma": 1,
  "contrast": 1,
  "dimming": 1,
  "nightEnabled": false,
  "nightTemperature": 4000,
  "dayTemperature": 6500,
  "useIP": false,
  "mode": "fixed",
  "start": 1200,
  "end": 420,
  "transition": 30,
  "latitude": null,
  "longitude": null
}
EOF
fi

# Toggle nightEnabled atomically using python
STATUS=$(python3 -c "
import json

path = '$CONFIG_FILE'
try:
    with open(path, 'r') as f:
        data = json.load(f)
except Exception:
    data = {}

current = data.get('nightEnabled', False)
data['nightEnabled'] = not current

with open(path, 'w') as f:
    json.dump(data, f, indent=2)

print('ON' if data['nightEnabled'] else 'OFF')
")

if [[ "$STATUS" == "ON" ]]; then
    notify-send -a "Clavis" -i "nightlight" "Cuidado Ocular" "Modo Noche Activado (4000 K)"
else
    notify-send -a "Clavis" -i "nightlight" "Cuidado Ocular" "Modo Noche Desactivado"
fi
