#!/usr/bin/env python3
"""WhatsApp del perfil dedicado de Hermes (CDP local).

  python wa-leer.py                      -> lista de chats (nombre, hora, ultimo mensaje)
  python wa-leer.py --abrir Papa         -> abre el chat y volca los ultimos mensajes
  python wa-leer.py --abrir Papa -n 20   -> los ultimos 20 mensajes
  python wa-leer.py --puerto 9223 ...

Requiere `websocket-client` y el navegador abierto con el lanzador (whatsapp-hermes,
puerto 9222 por defecto). Un mensaje es TUYO si lleva data-pre-plain-text; los
recibidos no lo llevan en chats individuales.
"""
import argparse
import json
import sys
import time
import urllib.request

import websocket  # websocket-client


class Wa:
    def __init__(self, puerto=9222):
        with urllib.request.urlopen(f"http://127.0.0.1:{puerto}/json/list", timeout=5) as r:
            paginas = json.load(r)
        pag = next((t for t in paginas if t.get("type") == "page" and "whatsapp" in (t.get("url") or "")), None)
        if not pag:
            raise SystemExit("No hay pestaña de WhatsApp: lanza antes el lanzador (whatsapp-hermes)")
        # suppress_origin: Chrome rechaza el handshake con un Origin no permitido
        self.ws = websocket.create_connection(pag["webSocketDebuggerUrl"], timeout=25, suppress_origin=True)
        self.n = 0

    def cmd(self, method, **params):
        self.n += 1
        self.ws.send(json.dumps({"id": self.n, "method": method, "params": params}))
        while True:
            m = json.loads(self.ws.recv())
            if m.get("id") == self.n:
                return m

    def js(self, expr):
        res = self.cmd("Runtime.evaluate", expression=expr, returnByValue=True, awaitPromise=True).get("result", {})
        if "exceptionDetails" in res:
            return "EXC: " + json.dumps(res["exceptionDetails"])[:200]
        return res.get("result", {}).get("value")

    def clic(self, x, y):
        for tipo in ("mousePressed", "mouseReleased"):
            self.cmd("Input.dispatchMouseEvent", type=tipo, x=x, y=y, button="left", clickCount=1, buttons=1)

    def chats(self):
        return json.loads(self.js("""(() => {
          const items = [...document.querySelectorAll('[data-testid^="list-item-"]')];
          return JSON.stringify(items.map(it => {
            const t = s => { const e = it.querySelector(s); return e ? (e.innerText || '').trim() : ''; };
            return {titulo: t('[data-testid="cell-frame-title"]'),
                    hora: t('[data-testid="cell-frame-primary-detail"]'),
                    ultimo: t('[data-testid="cell-frame-secondary"]')};
          }).filter(c => c.titulo));
        })()""") or "[]")

    def abrir(self, nombre):
        d = self.js("""(() => {
          const obj = %s;
          const it = [...document.querySelectorAll('[data-testid^="list-item-"]')].find(e => {
            const t = e.querySelector('[data-testid="cell-frame-title"]');
            return ((t ? t.innerText : e.innerText) || '').toLowerCase().includes(obj);
          });
          if (!it) return null;
          const r = it.getBoundingClientRect();
          return JSON.stringify({x: Math.round(r.x + 60), y: Math.round(r.y + r.height / 2)});
        })()""" % json.dumps(nombre.lower()))
        if not d or d == "null":
            return False
        c = json.loads(d)
        self.clic(c["x"], c["y"])
        time.sleep(3)
        return True

    def mensajes(self, n=12):
        datos = self.js(r"""(() => {
          const main = document.querySelector('#main');
          if (!main) return '[]';
          const out = [];
          for (const caja of main.querySelectorAll('[data-testid="msg-container"]')) {
            const t = caja.querySelector('span.selectable-text');
            if (!t) continue;                       // separadores de fecha, avisos, etc.
            const pre = caja.querySelector('[data-pre-plain-text]');
            const crudo = pre ? pre.getAttribute('data-pre-plain-text') : '';
            const m = crudo.match(/^\[([^\]]*)\]\s*([^:]*):/);
            out.push({hora: m ? m[1] : crudo,
                      autor: m ? m[2].trim() : '',
                      saliente: !!caja.querySelector('.message-out'),
                      texto: (t.innerText || '').trim().slice(0, 300)});
          }
          return JSON.stringify(out.slice(-%d));
        })()""" % n)
        return json.loads(datos if isinstance(datos, str) else "[]")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--puerto", type=int, default=9222)
    ap.add_argument("--abrir")
    ap.add_argument("-n", "--mensajes", type=int, default=12)
    a = ap.parse_args()

    wa = Wa(a.puerto)
    if a.abrir:
        if not wa.abrir(a.abrir):
            raise SystemExit("No encuentro el chat: " + a.abrir)
        cab = (wa.js("(document.querySelector('#main header')||{}).innerText || '?'") or "?").split("\n")[0]
        print("== " + cab)
        for m in wa.mensajes(a.mensajes):
            autor = m.get("autor") or ("yo" if m.get("saliente") else "?")
            print(f"[{m.get('hora','')}] {autor}: {m['texto']}")
        return

    chats = wa.chats()
    print("CHATS:", len(chats))
    for c in chats:
        print(f"- {c['titulo']} | {c['hora']} | {c['ultimo'][:120]}")


if __name__ == "__main__":
    main()
