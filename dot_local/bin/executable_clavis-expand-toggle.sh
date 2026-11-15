#!/usr/bin/env python3
import json
import os
import subprocess
import sys

STATE_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/tmp/runtime-{os.getuid()}")
os.makedirs(STATE_DIR, exist_ok=True)
STATE_FILE = os.path.join(STATE_DIR, "niri-expand-toggle.json")

def get_focused_window():
    try:
        out = subprocess.check_output(["niri", "msg", "-j", "windows"], stderr=subprocess.DEVNULL)
        windows = json.loads(out)
        for w in windows:
            if w.get("is_focused"):
                return w
    except Exception:
        pass
    return None

def main():
    focused = get_focused_window()
    if not focused or "layout" not in focused or not focused["layout"]:
        subprocess.run(["niri", "msg", "action", "expand-column-to-available-width"])
        return

    wid = focused["id"]
    current_w = focused["layout"]["tile_size"][0]

    # Check if we have saved state for this window and it is currently expanded
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                state = json.load(f)
            if state.get("id") == wid and abs(state.get("expanded_w", 0) - current_w) < 5:
                # Restore to original width
                orig_w = int(round(state["orig_w"]))
                subprocess.run(["niri", "msg", "action", "set-column-width", str(orig_w)])
                os.remove(STATE_FILE)
                return
        except Exception:
            if os.path.exists(STATE_FILE):
                os.remove(STATE_FILE)

    # Perform expand
    subprocess.run(["niri", "msg", "action", "expand-column-to-available-width"])

    # Check new width
    focused_after = get_focused_window()
    if focused_after and "layout" in focused_after and focused_after["layout"]:
        new_w = focused_after["layout"]["tile_size"][0]
        if new_w - current_w > 5:
            # It actually expanded! Save the state
            try:
                with open(STATE_FILE, "w") as f:
                    json.dump({"id": wid, "orig_w": current_w, "expanded_w": new_w}, f)
            except Exception:
                pass

if __name__ == "__main__":
    main()
