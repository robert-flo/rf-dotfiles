#!/usr/bin/env python3
"""
clavis-sticky-daemon.sh
Background daemon that ensures sticky windows follow the active workspace in Niri.
"""

import fcntl
import json
import os
import signal
import subprocess
import sys
import time

RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
LOCK_FILE = os.path.join(RUNTIME_DIR, "clavis-sticky-daemon.lock")
STATE_FILE = os.path.join(RUNTIME_DIR, "clavis-sticky-windows.json")


def acquire_lock():
    try:
        lock_fd = open(LOCK_FILE, "a+")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        lock_fd.seek(0)
        lock_fd.truncate()
        lock_fd.write(str(os.getpid()) + "\n")
        lock_fd.flush()
        return lock_fd
    except (BlockingIOError, OSError):
        sys.exit(0)


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


def query_workspaces():
    try:
        out = subprocess.check_output(["niri", "msg", "--json", "workspaces"], text=True)
        return json.loads(out)
    except Exception:
        return []


def query_windows():
    try:
        out = subprocess.check_output(["niri", "msg", "--json", "windows"], text=True)
        return json.loads(out)
    except Exception:
        return []


def relocate_sticky_windows(target_idx, target_ws_id):
    sticky = get_sticky_ids()
    if not sticky:
        return

    wins = query_windows()
    alive_windows = {w["id"]: w for w in wins}

    # Prune windows that no longer exist
    valid_sticky = sticky.intersection(alive_windows.keys())
    if len(valid_sticky) != len(sticky):
        save_sticky_ids(valid_sticky)

    for wid in valid_sticky:
        win = alive_windows[wid]
        if win.get("workspace_id") != target_ws_id:
            subprocess.run(
                [
                    "niri", "msg", "action", "move-window-to-workspace",
                    "--window-id", str(wid),
                    "--focus", "false",
                    str(target_idx)
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )


def main():
    lock_fd = acquire_lock()

    def handle_exit(sig, frame):
        try:
            lock_fd.close()
            if os.path.exists(LOCK_FILE):
                os.remove(LOCK_FILE)
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_exit)
    signal.signal(signal.SIGTERM, handle_exit)

    workspaces = {}
    active_ws_id = None
    active_ws_idx = None

    while True:
        try:
            proc = subprocess.Popen(
                ["niri", "msg", "--json", "event-stream"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )

            for line in proc.stdout:
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except Exception:
                    continue

                if "WorkspacesChanged" in event:
                    ws_list = event["WorkspacesChanged"].get("workspaces", [])
                    workspaces = {w["id"]: w for w in ws_list}
                    for w in ws_list:
                        if w.get("is_active") or w.get("is_focused"):
                            new_id = w["id"]
                            new_idx = w["idx"]
                            if new_idx != active_ws_idx:
                                active_ws_id = new_id
                                active_ws_idx = new_idx
                                relocate_sticky_windows(new_idx, new_id)
                            break

                elif "WorkspaceActivated" in event:
                    activated = event["WorkspaceActivated"]
                    if activated.get("focused", True):
                        ws_id = activated.get("id")
                        ws = workspaces.get(ws_id)
                        if not ws:
                            ws_list = query_workspaces()
                            workspaces = {w["id"]: w for w in ws_list}
                            ws = workspaces.get(ws_id)
                        if ws:
                            new_idx = ws.get("idx")
                            if new_idx and new_idx != active_ws_idx:
                                active_ws_id = ws_id
                                active_ws_idx = new_idx
                                relocate_sticky_windows(new_idx, ws_id)

                elif "WindowClosed" in event:
                    win_id = event["WindowClosed"].get("id")
                    sticky = get_sticky_ids()
                    if win_id in sticky:
                        sticky.discard(win_id)
                        save_sticky_ids(sticky)

                elif "WindowsChanged" in event:
                    win_list = event["WindowsChanged"].get("windows", [])
                    alive_ids = {w["id"]: w for w in win_list}
                    sticky = get_sticky_ids()
                    pruned = sticky.intersection(alive_ids)
                    if len(pruned) != len(sticky):
                        save_sticky_ids(pruned)

            proc.wait()
        except Exception:
            pass

        time.sleep(1)


if __name__ == "__main__":
    main()
