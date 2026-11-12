#!/usr/bin/env python3
"""
clavis-sticky-toggle.sh
Toggles sticky (always-on-top floating window that follows workspaces) on focused window.
"""

import json
import os
import subprocess
import sys

RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
LOCK_FILE = os.path.join(RUNTIME_DIR, "clavis-sticky-daemon.lock")
STATE_FILE = os.path.join(RUNTIME_DIR, "clavis-sticky-windows.json")


def is_daemon_running():
    if not os.path.exists(LOCK_FILE):
        return False
    try:
        with open(LOCK_FILE, "r") as f:
            pid_str = f.read().strip()
            if not pid_str:
                return False
            pid = int(pid_str)
        os.kill(pid, 0)
        return True
    except (ValueError, ProcessLookupError, OSError):
        return False


def ensure_daemon():
    if not is_daemon_running():
        subprocess.Popen(
            ["clavis-sticky-daemon.sh"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )


def get_sticky_ids():
    if not os.path.exists(STATE_FILE):
        return set()
    try:
        with open(STATE_FILE, "r") as f:
            data = json.load(f)
            return set(data.get("sticky_ids", []))
    except Exception:
        return set()


def save_sticky_ids(sticky_ids):
    tmp = f"{STATE_FILE}.tmp.{os.getpid()}"
    try:
        with open(tmp, "w") as f:
            json.dump({"sticky_ids": sorted(list(sticky_ids))}, f)
        os.replace(tmp, STATE_FILE)
    except Exception:
        pass


def notify(title, msg, icon="preferences-system-windows"):
    try:
        subprocess.run(
            ["notify-send", "-t", "3", "-a", "Niri", "-i", icon, title, msg],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except Exception:
        pass


def main():
    ensure_daemon()

    try:
        out = subprocess.check_output(["niri", "msg", "--json", "focused-window"], text=True)
        win = json.loads(out)
    except Exception:
        notify("Ventanas", "No se detectó ninguna ventana activa", "dialog-warning")
        sys.exit(0)

    if not win or "id" not in win:
        notify("Ventanas", "No se detectó ninguna ventana activa", "dialog-warning")
        sys.exit(0)

    wid = win["id"]
    title = win.get("title") or win.get("app_id") or "Ventana"
    if len(title) > 32:
        title = title[:29] + "..."

    sticky = get_sticky_ids()

    if wid in sticky:
        sticky.discard(wid)
        save_sticky_ids(sticky)
        notify("Ventana Desanclada", f"{title} ya no seguirá los escritorios", "window-restore")
    else:
        if not win.get("is_floating"):
            subprocess.run(
                ["niri", "msg", "action", "move-window-to-floating"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        sticky.add(wid)
        save_sticky_ids(sticky)
        notify("Ventana Anclada (Sticky)", f"{title} te seguirá a todos los escritorios", "window-pin")


if __name__ == "__main__":
    main()
