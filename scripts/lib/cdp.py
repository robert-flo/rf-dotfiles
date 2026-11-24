#!/usr/bin/env python3
"""Cliente mínimo de Chrome DevTools Protocol (solo stdlib) para browser-flags-bench.

Biblioteca (la usa browser_probe.py) y un único subcomando de CLI:
  cdp.py version PORT        imprime Browser.getVersion como JSON
"""
import base64
import http.client
import json
import os
import socket
import struct
import sys
import urllib.parse


class WS:
    def __init__(self, url):
        u = urllib.parse.urlparse(url)
        self.sock = socket.create_connection((u.hostname, u.port), timeout=15)
        key = base64.b64encode(os.urandom(16)).decode()
        path = u.path + (("?" + u.query) if u.query else "")
        self.sock.sendall(
            (
                f"GET {path} HTTP/1.1\r\nHost: {u.hostname}:{u.port}\r\n"
                f"Upgrade: websocket\r\nConnection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
            ).encode()
        )
        resp = b""
        while b"\r\n\r\n" not in resp:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise RuntimeError("handshake websocket cerrado")
            resp += chunk
        if b" 101 " not in resp.split(b"\r\n", 1)[0]:
            raise RuntimeError("handshake websocket rechazado: " + resp[:80].decode(errors="replace"))
        self.buf = resp.split(b"\r\n\r\n", 1)[1]
        self.next_id = 0

    def _read(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise RuntimeError("websocket cerrado")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def send(self, obj):
        data = json.dumps(obj).encode()
        header = bytearray([0x81])
        n = len(data)
        if n < 126:
            header.append(0x80 | n)
        elif n < 65536:
            header.append(0x80 | 126)
            header += struct.pack(">H", n)
        else:
            header.append(0x80 | 127)
            header += struct.pack(">Q", n)
        mask = os.urandom(4)
        header += mask
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
        self.sock.sendall(bytes(header) + masked)

    def recv(self):
        payload = b""
        while True:
            b0, b1 = self._read(2)
            fin, opcode = b0 & 0x80, b0 & 0x0F
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._read(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._read(8))[0]
            chunk = self._read(n)
            if opcode == 0x8:
                raise RuntimeError("websocket cerrado por el navegador")
            if opcode in (0x1, 0x0):
                payload += chunk
                if fin:
                    return json.loads(payload.decode())

    def call(self, method, params=None):
        self.next_id += 1
        mid = self.next_id
        self.send({"id": mid, "method": method, "params": params or {}})
        while True:
            msg = self.recv()
            if msg.get("id") == mid:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg.get("result", {})

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


def http_json(port, path, method="GET"):
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=15)
    conn.request(method, path)
    resp = conn.getresponse()
    body = resp.read().decode()
    conn.close()
    try:
        return json.loads(body)
    except ValueError:
        return body


def browser_ws(port):
    return WS(http_json(port, "/json/version")["webSocketDebuggerUrl"])


def new_page(port, url):
    quoted = urllib.parse.quote(url, safe="")
    return http_json(port, f"/json/new?{quoted}", "PUT")


DEEP_TEXT = """
(() => {
  const out = [];
  const walk = (n) => {
    if (n.nodeType === Node.TEXT_NODE) { const t = n.textContent.trim(); if (t) out.push(t); return; }
    if (n.shadowRoot) walk(n.shadowRoot);
    for (const c of n.childNodes) walk(c);
  };
  walk(document.documentElement);
  return out.join('\\n');
})()
"""


def main(argv):
    if len(argv) != 3 or argv[1] != "version":
        print(__doc__, file=sys.stderr)
        return 2
    print(json.dumps(browser_ws(int(argv[2])).call("Browser.getVersion")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
