#!/usr/bin/env python3
"""Lector de Mensajes de Google para Hermes, sobre el perfil dedicado (CDP).

El navegador debe estar lanzado con `messages-hermes` (headless, puerto 9224).
La sesión está vinculada al móvil de Antonio; Google permite UN SOLO ordenador
activo a la vez, así que si Antonio abre la web en su Chrome, esta sesión cae.

Uso:
  messages-leer.py                       -> estado: URL, título y resumen
  messages-leer.py --conversaciones 15   -> lista de chats (nombre, extracto, fecha, no leído)
  messages-leer.py --buscar "loteria"    -> filtra la lista por nombre o extracto
  messages-leer.py --abrir "Amazon"      -> abre un chat (por nombre; o índice: --abrir 0)
  messages-leer.py --leer 20             -> últimos N mensajes del chat ABIERTO
  messages-leer.py --abrir 3 --leer 10   -> abre y lee en un paso
  messages-leer.py --js "<expresion>"    -> evalúa JS (depuración)
  messages-leer.py --navegar <url>       -> navega y espera

Solo lectura: no envía mensajes.
"""
import argparse
import json
import sys
import time
import urllib.request

import websocket  # websocket-client

PUERTO_DEF = 9224
SITIO = "messages.google.com"


def pestanas(puerto):
    with urllib.request.urlopen(f"http://127.0.0.1:{puerto}/json", timeout=5) as r:
        return json.load(r)


def elegir(puerto, contiene=SITIO):
    tabs = [t for t in pestanas(puerto) if t.get("type") == "page"]
    for t in tabs:
        if contiene in t.get("url", ""):
            return t
    return tabs[0] if tabs else None


class CDP:
    def __init__(self, ws_url):
        # suppress_origin: Chrome rechaza el Origin que no esté en --remote-allow-origins
        self.ws = websocket.create_connection(ws_url, suppress_origin=True, timeout=25)
        self.n = 0

    def cmd(self, method, **params):
        self.n += 1
        self.ws.send(json.dumps({"id": self.n, "method": method, "params": params}))
        while True:
            msg = json.loads(self.ws.recv())
            if msg.get("id") == self.n:
                if "error" in msg:
                    raise RuntimeError(msg["error"])
                return msg.get("result", {})

    def js(self, expr):
        r = self.cmd("Runtime.evaluate", expression=expr, returnByValue=True, awaitPromise=True)
        res = r.get("result", {})
        if res.get("subtype") == "error":
            raise RuntimeError(res.get("description"))
        return res.get("value")

    def clic_en(self, expr_selector):
        """Clic real (evento trusted) sobre el centro del primer elemento que case."""
        box = self.js(
            "(()=>{const e=%s;if(!e)return null;const r=e.getBoundingClientRect();"
            "return {x:r.x+r.width/2,y:r.y+r.height/2}})()" % expr_selector
        )
        if not box:
            return False
        x, y = box["x"], box["y"]
        self.cmd("Input.dispatchMouseEvent", type="mousePressed", x=x, y=y, button="left", clickCount=1)
        self.cmd("Input.dispatchMouseEvent", type="mouseReleased", x=x, y=y, button="left", clickCount=1)
        return True

    def cerrar(self):
        try:
            self.ws.close()
        except Exception:
            pass


JS_CONVERSACIONES = """(()=>{
  const items=[...document.querySelectorAll('mws-conversation-list-item')];
  return JSON.stringify(items.map((it,i)=>{
    const a=it.querySelector('a.list-item');
    const n=it.querySelector('[data-e2e-conversation-name]');
    const s=it.querySelector('mws-conversation-snippet');
    const t=it.querySelector('mws-relative-timestamp');
    return {
      i: i,
      nombre: (n?n.innerText:'').trim(),
      extracto: (s?s.innerText:'').replace(/\\s+/g,' ').trim(),
      fecha: (t?(t.innerText.trim().split('\\n').pop()||'').trim():''),
      no_leido: !!(a && a.getAttribute('data-e2e-is-unread')==='true'),
      fijado: !!(a && a.getAttribute('data-e2e-is-pinned')==='true'),
      href: a?a.getAttribute('href'):null
    };
  }));
})()"""

JS_MENSAJES = """(()=>{
  const w=[...document.querySelectorAll('mws-message-wrapper')];
  return JSON.stringify(w.map(m=>{
    const p=m.querySelector('mws-message-part-content, mws-text-message-part');
    const st=m.querySelector('mws-message-status');
    const txt=(p?p.innerText:m.innerText).replace(/\\s+/g,' ').trim();
    return {
      id: m.getAttribute('msg-id'),
      saliente: m.getAttribute('is-outgoing')==='true',
      no_leido: m.getAttribute('is-unread')==='true',
      texto: txt,
      estado: (st?st.innerText:'').trim()
    };
  }).filter(m=>m.texto));
})()"""


def abre_conversacion(c, quien):
    """Abre un chat por índice (número) o por texto del nombre. Devuelve el nombre abierto."""
    if quien.isdigit():
        selector = f"document.querySelectorAll('mws-conversation-list-item')[{int(quien)}]"
    else:
        q = json.dumps(quien.lower())
        selector = ("[...document.querySelectorAll('mws-conversation-list-item')]"
                    f".find(it=>it.innerText.toLowerCase().includes({q}))")
    if not c.clic_en(selector):
        return None
    time.sleep(3.5)
    return c.js("(()=>{const sel=document.querySelector("
                "'mws-conversation-list-item a[aria-selected=\"true\"] [data-e2e-conversation-name], "
                "mws-conversation-list-item.selected [data-e2e-conversation-name]');"
                "if(sel) return sel.innerText.trim();"
                "const h=document.querySelector('mws-conversation-header');"
                "return h?h.innerText.trim():document.title})()")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--puerto", type=int, default=PUERTO_DEF)
    ap.add_argument("--js", default=None)
    ap.add_argument("--navegar", default=None)
    ap.add_argument("--espera", type=float, default=7.0)
    ap.add_argument("--conversaciones", type=int, default=None, metavar="N")
    ap.add_argument("--buscar", default=None, metavar="TEXTO")
    ap.add_argument("--abrir", default=None, metavar="NOMBRE|INDICE")
    ap.add_argument("--leer", type=int, default=None, metavar="N")
    args = ap.parse_args()

    tab = elegir(args.puerto)
    if not tab:
        print(f"No hay pestañas en el puerto {args.puerto}. Lanza antes: messages-hermes", file=sys.stderr)
        return 1

    c = CDP(tab["webSocketDebuggerUrl"])
    try:
        if args.navegar:
            c.cmd("Page.enable")
            c.cmd("Page.navigate", url=args.navegar)
            time.sleep(args.espera)

        if args.js:
            print(json.dumps(c.js(args.js), ensure_ascii=False, indent=2))
            return 0

        if args.abrir is not None:
            abierto = abre_conversacion(c, args.abrir)
            print(f"Abierto: {abierto}" if abierto else "No encuentro esa conversación")
            if abierto and args.leer is None:
                return 0

        if args.conversaciones is not None or args.buscar is not None:
            convs = json.loads(c.js(JS_CONVERSACIONES))
            if args.buscar:
                q = args.buscar.lower()
                convs = [x for x in convs if q in x["nombre"].lower() or q in x["extracto"].lower()]
            limite = args.conversaciones or 15
            print(f"Conversaciones: {len(convs)} (mostrando {min(limite, len(convs))})")
            for x in convs[:limite]:
                marca = " ●" if x["no_leido"] else ""
                fija = " 📌" if x["fijado"] else ""
                print(f"[{x['i']:>2}] {x['nombre'][:28]:<28}{fija}{marca} {x['fecha']:<8} {x['extracto'][:70]}")
            return 0

        if args.leer is not None:
            msgs = json.loads(c.js(JS_MENSAJES))
            if not msgs:
                print("No hay mensajes visibles (¿hay un chat abierto? usa --abrir)")
                return 0
            for m in msgs[-args.leer:]:
                quien = "Tú " if m["saliente"] else "   "
                nuevo = "●" if m["no_leido"] else " "
                print(f"{nuevo} {quien}| {m['texto'][:150]}")
            print(f"({len(msgs)} mensajes en el hilo; los antiguos solo aparecen al hacer scroll)")
            return 0

        # estado
        print("URL:   ", c.js("location.href"))
        print("TITULO:", c.js("document.title"))
        convs = json.loads(c.js(JS_CONVERSACIONES))
        no_leidos = [x for x in convs if x["no_leido"]]
        print(f"Conversaciones visibles: {len(convs)}  |  sin leer: {len(no_leidos)}")
        for x in convs[:8]:
            print(f"  {'●' if x['no_leido'] else ' '} {x['nombre'][:30]:<30} {x['fecha']:<8} {x['extracto'][:60]}")
        return 0
    finally:
        c.cerrar()


if __name__ == "__main__":
    sys.exit(main())
