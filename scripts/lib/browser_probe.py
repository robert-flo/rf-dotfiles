#!/usr/bin/env python3
"""Sondas de browser-flags-bench: miden en el navegador ya lanzado (solo stdlib).

  gpu     --port P                       estado de chrome://gpu (decode, raster, GL) y perfiles VA-API
  video   --port P --profile D --url U --warmup S --seconds S --windows N [--youtube] [--inject FILE.js]
                                         reproduce U y mide decoder, fotogramas y CPU (mediana de N ventanas)
  typing  --port P --url U               escribe á é ñ (wtype directo y Unicode de fcitx5) y cuenta los
                                         eventos de composición (>0 = Chrome usa text-input por Wayland)
  stable  --port P                       sesión viva: pestaña responde y el proceso GPU sigue vivo

Todas imprimen un único objeto JSON por stdout.
"""
import argparse
import json
import os
import statistics
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cdp  # noqa: E402

CLK = os.sysconf("SC_CLK_TCK")


def find_tab(port, needle="", timeout=15):
    """Primera pestaña de tipo page cuya URL contiene needle (vacío = cualquiera)."""
    end = time.time() + timeout
    while time.time() < end:
        for t in cdp.http_json(port, "/json"):
            if t.get("type") == "page" and needle in t.get("url", ""):
                return t
        time.sleep(0.3)
    raise RuntimeError(f"no apareció la pestaña {needle or '(cualquiera)'}")


def niri_windows():
    try:
        out = subprocess.run(["niri", "msg", "-j", "windows"], capture_output=True, text=True, check=True).stdout
        return json.loads(out)
    except (OSError, subprocess.CalledProcessError, ValueError):
        return None


def proc_table():
    table = {}
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            with open(f"/proc/{pid}/stat") as fh:
                raw = fh.read()
            rest = raw[raw.rindex(")") + 2 :].split()
            table[int(pid)] = (int(rest[1]), int(rest[11]) + int(rest[12]))
        except (OSError, ValueError, IndexError):
            continue
    return table  # pid -> (ppid, ticks)


def root_pid(profile):
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as fh:
                args = fh.read().split(b"\0")
        except OSError:
            continue
        joined = b" ".join(args)
        if f"--user-data-dir={profile}".encode() in joined and b"--type=" not in joined:
            return int(pid)
    raise RuntimeError("no encontré el proceso principal del navegador")


def tree_ticks(root):
    table = proc_table()
    kids = {}
    for pid, (ppid, _) in table.items():
        kids.setdefault(ppid, []).append(pid)
    seen, stack = {}, [root]
    while stack:
        pid = stack.pop()
        if pid in seen or pid not in table:
            continue
        seen[pid] = table[pid][1]
        stack.extend(kids.get(pid, []))
    return seen


def sys_busy():
    with open("/proc/stat") as fh:
        f = list(map(int, fh.readline().split()[1:]))
    idle = f[3] + f[4]
    return sum(f) - idle, sum(f)


def wayland_native(root):
    """True si niri lista una ventana cuyo pid está en el árbol del navegador (cliente Wayland nativo)."""
    wins = niri_windows()
    if wins is None:
        return None
    tree = tree_ticks(root)
    return any(w.get("pid") in tree for w in wins)


def gpu_pids(port):
    ws = cdp.browser_ws(port)
    info = ws.call("SystemInfo.getProcessInfo")
    ws.close()
    return sorted(p["id"] for p in info.get("processInfo", []) if p.get("type") == "GPU")


def drain(ws, seconds, props):
    end = time.time() + seconds
    ws.sock.settimeout(0.5)
    while time.time() < end:
        try:
            msg = ws.recv()
        except (OSError, TimeoutError):
            continue
        if msg.get("method") == "Media.playerPropertiesChanged":
            for p in msg["params"]["properties"]:
                props[p["name"]] = p["value"]
        elif msg.get("method") == "Inspector.targetCrashed":
            props["_crashed"] = True


def cmd_gpu(a):
    page = cdp.new_page(a.port, "chrome://gpu")
    time.sleep(3)
    ws = cdp.WS(page["webSocketDebuggerUrl"])
    text = ws.call("Runtime.evaluate", {"expression": cdp.DEEP_TEXT, "returnByValue": True})["result"]["value"]
    ws.close()
    cdp.http_json(a.port, f"/json/close/{page['id']}")
    lines = text.split("\n")
    out = {}
    for key in ("Canvas", "Compositing", "Rasterization", "Video Decode", "Video Encode", "WebGL"):
        if key + ":" in lines:
            out[key.lower().replace(" ", "_")] = lines[lines.index(key + ":") + 1]
    if "GL_RENDERER" in lines:
        out["gl_renderer"] = lines[lines.index("GL_RENDERER") + 2] if lines[lines.index("GL_RENDERER") + 1] == ":" else lines[lines.index("GL_RENDERER") + 1]
    decode = []
    if "Video Acceleration Information" in lines:
        i = lines.index("Video Acceleration Information")
        decode = [ln for ln in lines[i + 1 : i + 60] if ln.startswith(("Decode ", "Encode "))]
    out["va_profiles"] = decode
    print(json.dumps(out))
    return 0


def js(ws, expr):
    return ws.call("Runtime.evaluate", {"expression": expr, "returnByValue": True, "awaitPromise": True}).get("result", {}).get("value")


def prepare_youtube(ws, props):
    """Silencia, pide 1080p, espera a que terminen los anuncios y devuelve a qué hora quedó listo."""
    end = time.time() + 25
    while time.time() < end:
        drain(ws, 0.5, props)
        if js(ws, "typeof movie_player !== 'undefined' && typeof movie_player.getStatsForNerds === 'function'"):
            break
    js(ws, "movie_player.mute(); movie_player.setPlaybackQualityRange('hd1080'); movie_player.playVideo()")
    end = time.time() + 60
    ready = False
    while time.time() < end:
        drain(ws, 0.5, props)
        if js(ws, "document.querySelector('.html5-video-player.ad-showing')"):
            js(ws, "(document.querySelector('.ytp-skip-ad-button, .ytp-ad-skip-button-modern')||{click(){}}).click()")
            continue
        if js(ws, "(movie_player.getStatsForNerds().resolution||'').startsWith('1920x1080')"):
            ready = True
            break
        js(ws, "movie_player.setPlaybackQualityRange('hd1080')")
    drain(ws, 3, props)
    return ready


def cmd_video(a):
    page = find_tab(a.port)
    ws = cdp.WS(page["webSocketDebuggerUrl"])
    ws.call("Page.enable")
    ws.call("Media.enable")
    ws.call("Page.bringToFront")
    if a.inject:
        with open(a.inject, encoding="utf-8") as fh:
            ws.call("Page.addScriptToEvaluateOnNewDocument", {"source": fh.read()})
    ws.call("Page.navigate", {"url": a.url})
    props = {}
    root = root_pid(a.profile)
    gpu_before = gpu_pids(a.port)
    drain(ws, a.warmup, props)
    yt_ready = prepare_youtube(ws, props) if a.youtube else None

    quality_js = (
        "(()=>{const v=document.querySelector('video');const q=v.getVideoPlaybackQuality();"
        "return {t:v.currentTime,paused:v.paused,w:v.videoWidth,h:v.videoHeight,total:q.totalVideoFrames,dropped:q.droppedVideoFrames}})()"
    )
    q0 = js(ws, quality_js)
    samples, sys_samples = [], []
    last = tree_ticks(root)
    wall = 0.0
    for _ in range(a.windows):
        total = 0
        busy0, all0 = sys_busy()
        t0 = time.time()
        while time.time() - t0 < a.seconds:
            drain(ws, 0.5, props)
            cur = tree_ticks(root)
            for pid, ticks in cur.items():
                total += ticks - last.get(pid, 0)
                last[pid] = ticks
        span = time.time() - t0
        wall += span
        busy1, all1 = sys_busy()
        samples.append(round(100.0 * total / CLK / span, 1))
        sys_samples.append(round(100.0 * (busy1 - busy0) / max(all1 - all0, 1), 1))
    native = wayland_native(root)

    q = js(ws, quality_js)
    nerds = js(ws, "typeof movie_player!=='undefined' ? movie_player.getStatsForNerds() : null") if a.youtube else None
    shot = ws.call("Page.captureScreenshot", {"format": "png"})["data"]
    ws.close()
    gpu_after = gpu_pids(a.port)
    track = {}
    try:
        track = json.loads(props.get("kVideoTracks", "[]"))[0]
    except (ValueError, IndexError):
        pass
    print(
        json.dumps(
            {
                "decoder": props.get("kVideoDecoderName", "?"),
                "youtube_codecs": (nerds or {}).get("codecs"),
                "youtube_resolution": (nerds or {}).get("resolution"),
                "platform_decoder": props.get("kIsPlatformVideoDecoder", "?"),
                "codec": track.get("codec", "?"),
                "profile": track.get("profile", "?"),
                "resolution": props.get("kResolution", "?"),
                "cpu_browser_pct_core": statistics.median(samples),
                "cpu_browser_samples": samples,
                "cpu_system_pct": statistics.median(sys_samples),
                "wayland_native": native,
                "frames_total": q["total"],
                "frames_dropped": q["dropped"],
                "youtube_ready": yt_ready,
                "window_frames": q["total"] - q0["total"],
                "window_dropped": q["dropped"] - q0["dropped"],
                "playing": (not q["paused"]) and q["t"] > 1.0,
                "screenshot_bytes": len(shot) * 3 // 4,
                "gpu_pid_stable": gpu_before == gpu_after and bool(gpu_after),
                "crashed": bool(props.get("_crashed")),
                "wall_s": round(wall, 1),
            }
        )
    )
    return 0


def focus_window(title_hint):
    for w in niri_windows() or []:
        if title_hint in (w.get("title") or ""):
            r = subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(w["id"])], capture_output=True)
            return r.returncode == 0
    return False


def field_value(ws):
    return ws.call("Runtime.evaluate", {"expression": "document.getElementById('t').value", "returnByValue": True})["result"]["value"]


def cmd_typing(a):
    page = find_tab(a.port, a.url)
    ws = cdp.WS(page["webSocketDebuggerUrl"])
    ws.call("Page.bringToFront")
    time.sleep(1.5)
    focused = focus_window("bench-typing")
    time.sleep(0.8)
    ws.call("Runtime.evaluate", {"expression": "(()=>{const e=document.getElementById('t');e.value='';e.focus()})()"})
    # wtype pierde el primer carácter no ASCII de cada invocación (el mapa de teclas nuevo
    # llega tarde al cliente): se antepone un espacio de sacrificio y se compara con strip().
    subprocess.run(["wtype", " áéñ"], check=False)
    time.sleep(0.8)
    direct = field_value(ws).strip()
    ws.call("Runtime.evaluate", {"expression": "document.getElementById('t').value=''"})
    for hexcode in ("e1", "e9", "f1"):  # á é ñ por el módulo Unicode de fcitx5 (Ctrl+Alt+Shift+U)
        subprocess.run(["wtype", "-M", "ctrl", "-M", "alt", "-M", "shift", "-k", "u", "-m", "shift", "-m", "alt", "-m", "ctrl"], check=False)
        time.sleep(0.5)
        subprocess.run(["wtype", hexcode], check=False)
        time.sleep(0.3)
        subprocess.run(["wtype", "-k", "Return"], check=False)
        time.sleep(0.5)
    fcitx = field_value(ws)
    comp = ws.call("Runtime.evaluate", {"expression": "window.comp", "returnByValue": True})["result"]["value"]
    ws.close()
    print(
        json.dumps(
            {
                "window_focused": focused,
                "direct": direct,
                "direct_ok": direct == "áéñ",
                "fcitx5_unicode": fcitx,
                "fcitx5_unicode_ok": fcitx == "áéñ",
                "composition_events": comp,
            }
        )
    )
    return 0


def cmd_stable(a):
    page = find_tab(a.port)
    ws = cdp.WS(page["webSocketDebuggerUrl"])
    val = ws.call("Runtime.evaluate", {"expression": "1+1", "returnByValue": True})["result"]["value"]
    ws.close()
    print(json.dumps({"responsive": val == 2, "gpu_process": bool(gpu_pids(a.port))}))
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("gpu", "video", "typing", "stable"):
        s = sub.add_parser(name)
        s.add_argument("--port", type=int, required=True)
        if name == "video":
            s.add_argument("--profile", required=True)
            s.add_argument("--url", required=True)
            s.add_argument("--warmup", type=float, default=4)
            s.add_argument("--seconds", type=float, default=8)
            s.add_argument("--windows", type=int, default=3)
            s.add_argument("--youtube", action="store_true", help="la URL es de YouTube: silencia y pide 1080p")
            s.add_argument("--inject", help="archivo JS que se inyecta antes de cada documento nuevo de la pestaña")
        if name == "typing":
            s.add_argument("--url", required=True)
    a = p.parse_args()
    return {"gpu": cmd_gpu, "video": cmd_video, "typing": cmd_typing, "stable": cmd_stable}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
