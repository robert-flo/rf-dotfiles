#!/usr/bin/env python3
"""Sondas de electron-flags-bench: miden en una app Electron/CEF ya lanzada (solo stdlib).

  info    --port P                  proceso principal, sus argumentos reales y si es cliente Wayland nativo
  typing  --port P --title T        escribe á é ñ en el editor/campo de la ventana T (wtype y Unicode de fcitx5)
                                    y cuenta eventos de composición (>0 = IME por text-input de Wayland)
  cpu     --port P [--load]         CPU del árbol de procesos (mediana de N ventanas); --load añade una
                                    animación sintética para que el compositor trabaje

Todas imprimen un único objeto JSON por stdout. Reutiliza los helpers de browser_probe.
"""
import argparse
import json
import os
import statistics
import subprocess
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import browser_probe as bp  # noqa: E402
import cdp  # noqa: E402

# Texto visible según el tipo de app: editor Monaco (VS Code y forks) o campo <input id=t>.
READ_TEXT = (
    "(()=>{const e=document.querySelector('.monaco-editor .view-lines');"
    "if(e)return e.innerText.replace(/[\\u00a0\\u200c\\u200b]/g,' ');"
    "const t=document.getElementById('t');return t?t.value:null})()"
)
COUNT_COMPOSITION = (
    "window.__comp=0;for(const e of ['compositionstart','compositionupdate','compositionend'])"
    "document.addEventListener(e,()=>window.__comp++,true)"
)


def split_cmdline(raw):
    """Argumentos de /proc/PID/cmdline: por NUL; si el proceso lo reescribió con espacios, por espacios."""
    parts = [x for x in raw.decode(errors="replace").split("\0") if x]
    return parts[0].split() if len(parts) == 1 else parts


def main_pid(port):
    """Proceso principal (sin --type=) que lleva --remote-debugging-port=PORT; el de menor PID si hay varios."""
    needle = f"--remote-debugging-port={port}"
    for pid in sorted(int(x) for x in os.listdir("/proc") if x.isdigit()):
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as fh:
                args = split_cmdline(fh.read())
        except OSError:
            continue
        if needle in args and not any(a.startswith("--type=") for a in args):
            return pid, args
    raise RuntimeError("no encontré el proceso principal de la app")


def cmd_info(a):
    pid, args = main_pid(a.port)
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{a.port}/json/version", timeout=5) as r:
            version = json.load(r).get("Browser")
    except (OSError, ValueError):
        version = None
    print(json.dumps({"pid": pid, "args": args, "wayland_native": bp.wayland_native(pid), "browser": version}))
    return 0


def read_text(ws):
    return bp.js(ws, READ_TEXT)


def focus_for_typing(ws, title):
    """Enfoca la ventana en niri, espera a que la página tenga el foco y hace clic en el editor/campo."""
    # Antigravity IDE muestra una bienvenida modal en el primer arranque de un perfil nuevo.
    if bp.js(ws, "(()=>{const b=[...document.querySelectorAll('button')].find(x=>/^get started$/i.test(x.innerText.trim()));if(b){b.click();return true}return false})()"):
        time.sleep(2)
    focused = bp.focus_window(title, wait=30)
    end = time.time() + 15
    while time.time() < end and not bp.js(ws, "document.hasFocus()"):
        time.sleep(0.3)
    box = bp.js(
        ws,
        "(()=>{const e=document.querySelector('.monaco-editor .view-lines')||document.getElementById('t');"
        "if(!e)return null;const r=e.getBoundingClientRect();return [r.x+40,r.y+Math.min(r.height/2,20)]})()",
    )
    if box:
        for kind in ("mousePressed", "mouseReleased"):
            ws.call("Input.dispatchMouseEvent", {"type": kind, "x": box[0], "y": box[1], "button": "left", "clickCount": 1})
    time.sleep(0.8)
    return focused and bool(bp.js(ws, "document.hasFocus()"))


def cmd_typing(a):
    page = bp.find_tab(a.port, "")
    ws = cdp.WS(page["webSocketDebuggerUrl"])
    time.sleep(a.settle)
    bp.js(ws, COUNT_COMPOSITION)
    focused = focus_for_typing(ws, a.title)
    base = read_text(ws) or ""
    # wtype pierde el primer carácter no ASCII de cada invocación: se antepone un espacio de sacrificio.
    subprocess.run(["wtype", " áéñ"], check=False)
    time.sleep(1.0)
    first = read_text(ws) or ""
    direct = (first[len(base) :] if first.startswith(base) else first).strip()
    for hexcode in ("e1", "e9", "f1"):  # á é ñ por el módulo Unicode de fcitx5 (Ctrl+Alt+Shift+U)
        subprocess.run(["wtype", "-M", "ctrl", "-M", "alt", "-M", "shift", "-k", "u", "-m", "shift", "-m", "alt", "-m", "ctrl"], check=False)
        time.sleep(1.0)
        subprocess.run(["wtype", hexcode], check=False)
        time.sleep(0.8)
        subprocess.run(["wtype", "-k", "Return"], check=False)
        time.sleep(0.8)
    last = read_text(ws) or ""
    fcitx = (last[len(first) :] if last.startswith(first) else last).replace("\n", "").strip()
    comp = bp.js(ws, "window.__comp")
    diag = None
    if not direct:
        diag = bp.js(
            ws,
            "(()=>{const a=document.activeElement;return {active:a&&(a.tagName+'.'+a.className).slice(0,80),focus:document.hasFocus(),"
            "editors:document.querySelectorAll('.monaco-editor').length,title:document.title,"
            "dialog:[...document.querySelectorAll('.monaco-dialog-box,.modal,[role=dialog]')].map(e=>e.innerText.slice(0,80))}})()",
        )
    ws.close()
    print(
        json.dumps(
            {
                "window_focused": focused,
                "direct": direct,
                "direct_ok": direct.endswith("áéñ"),
                "fcitx5_unicode": fcitx,
                "fcitx5_unicode_ok": fcitx.endswith("áéñ"),
                "composition_events": comp,
                **({"diag": diag} if diag else {}),
            }
        )
    )
    return 0


LOAD_JS = (
    "(()=>{const d=document.createElement('div');d.style.cssText='position:fixed;inset:0;z-index:99999;"
    "background:linear-gradient(90deg,#f0f,#0ff,#ff0,#f0f);background-size:200% 100%;opacity:.5;"
    "animation:benchslide 1s linear infinite;will-change:transform';"
    "const s=document.createElement('style');s.textContent='@keyframes benchslide{from{background-position:0 0}to{background-position:200% 0}}';"
    "document.head.appendChild(s);document.body.appendChild(d)})()"
)


def cmd_cpu(a):
    pid, _ = main_pid(a.port)
    if a.load:
        ws = cdp.WS(bp.find_tab(a.port, "")["webSocketDebuggerUrl"])
        bp.js(ws, LOAD_JS)
        ws.close()
    time.sleep(a.warmup)
    samples, sys_samples = [], []
    last = bp.tree_ticks(pid)
    for _ in range(a.windows):
        total, t0 = 0, time.time()
        busy0, all0 = bp.sys_busy()
        while time.time() - t0 < a.seconds:
            time.sleep(0.5)
            for p, ticks in bp.tree_ticks(pid).items():
                total += ticks - last.get(p, 0)
                last[p] = ticks
        span = time.time() - t0
        busy1, all1 = bp.sys_busy()
        samples.append(round(100.0 * total / bp.CLK / span, 1))
        sys_samples.append(round(100.0 * (busy1 - busy0) / max(all1 - all0, 1), 1))
    print(
        json.dumps(
            {
                "cpu_pct_core": statistics.median(samples),
                "cpu_samples": samples,
                "cpu_system_pct": statistics.median(sys_samples),
                "load": a.load,
                "processes": len(bp.tree_ticks(pid)),
            }
        )
    )
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("info", "typing", "cpu"):
        s = sub.add_parser(name)
        s.add_argument("--port", type=int, required=True)
        if name == "typing":
            s.add_argument("--title", required=True, help="trozo del título de la ventana para enfocarla")
            s.add_argument("--settle", type=float, default=2)
        if name == "cpu":
            s.add_argument("--load", action="store_true")
            s.add_argument("--warmup", type=float, default=4)
            s.add_argument("--seconds", type=float, default=8)
            s.add_argument("--windows", type=int, default=3)
    a = p.parse_args()
    return {"info": cmd_info, "typing": cmd_typing, "cpu": cmd_cpu}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
