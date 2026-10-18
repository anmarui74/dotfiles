#!/usr/bin/env python3
"""Explorador del DOM de WhatsApp Web (perfil dedicado de Hermes) para el envío.

Uso: wa-explorar.py [--puerto 9222]
Solo lee: no escribe ni envía nada.
"""
import argparse
import json
import sys
import time
import urllib.request

import websocket


def pestanas(puerto):
    with urllib.request.urlopen(f"http://127.0.0.1:{puerto}/json", timeout=5) as r:
        return json.load(r)


class CDP:
    def __init__(self, ws):
        self.ws = websocket.create_connection(ws, suppress_origin=True, timeout=25)
        self.n = 0

    def cmd(self, method, **params):
        self.n += 1
        self.ws.send(json.dumps({"id": self.n, "method": method, "params": params}))
        while True:
            m = json.loads(self.ws.recv())
            if m.get("id") == self.n:
                if "error" in m:
                    raise RuntimeError(m["error"])
                return m.get("result", {})

    def js(self, expr):
        r = self.cmd("Runtime.evaluate", expression=expr, returnByValue=True, awaitPromise=True)
        return r.get("result", {}).get("value")

    def cerrar(self):
        try:
            self.ws.close()
        except Exception:
            pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--puerto", type=int, default=9222)
    a = ap.parse_args()

    tabs = [t for t in pestanas(a.puerto) if t.get("type") == "page" and "whatsapp" in (t.get("url") or "")]
    if not tabs:
        print("No hay pestaña de WhatsApp en el puerto", a.puerto)
        return 1
    c = CDP(tabs[0]["webSocketDebuggerUrl"])
    try:
        print("URL:", c.js("location.href"))
        print("\n=== chats que parecen 'yo mismo' / guardados ===")
        print(c.js("""JSON.stringify([...document.querySelectorAll('[data-testid^="list-item-"]')]
            .map(e => (e.innerText || '').split('\\n')[0])
            .filter(t => /tú|tu mismo|guardado|mensajes guardados|antonio/i.test(t)))"""))
        print("\n=== buscador: candidatos ===")
        print(c.js("""JSON.stringify([...document.querySelectorAll('div[contenteditable="true"], input')]
            .map(e => ({tag: e.tagName, testid: e.getAttribute('data-testid'), aria: e.getAttribute('aria-label'),
                        title: e.getAttribute('title'), role: e.getAttribute('role')})).slice(0, 12))"""))
        print("\n=== compositor (footer) ===")
        print(c.js("""JSON.stringify([...document.querySelectorAll('[data-testid="conversation-compose-box-input"], footer [contenteditable="true"], [data-testid="conversation-footer"] [contenteditable="true"]')]
            .map(e => ({tag: e.tagName, testid: e.getAttribute('data-testid'), aria: e.getAttribute('aria-label'),
                        contenido: (e.innerText || '').slice(0, 40)})))"""))
        print("\n=== ¿hay chat abierto ahora? ===")
        print(c.js("""JSON.stringify({cabecera: (document.querySelector('#main header')||{}).innerText || null})"""))
        print("\n=== primeras 5 filas de la lista (formato) ===")
        print(c.js("""JSON.stringify([...document.querySelectorAll('[data-testid^="list-item-"]')].slice(0,5)
            .map(e => ({testid: e.getAttribute('data-testid'), texto: (e.innerText||'').replace(/\\n/g,' | ').slice(0,90)})))"""))
    finally:
        c.cerrar()
    return 0


if __name__ == "__main__":
    sys.exit(main())
