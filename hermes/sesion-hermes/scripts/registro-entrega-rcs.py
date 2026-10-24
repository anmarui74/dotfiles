#!/usr/bin/env python3
"""Seguimiento del estado de entrega de los mensajes RCS a María (solo lectura).

Lee el hilo de María en Google Messages por CDP, compara el estado de cada mensaje
(Enviado / Entregado / Leído) con el guardado y anota los cambios. Si aparece un cambio
relevante (un mensaje pasa a «Leído»), lo imprime para que el cron lo avise por Telegram.

No envía nada. No abre la conversación de Alicia. Cierra el navegador si lo abrió él.

Uso:
    registro-entrega-rcs.py            # comprueba y anota
    registro-entrega-rcs.py --verbose  # imprime también los cambios menores
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

try:
    import websocket
except ModuleNotFoundError:
    # El Python del cron de Hermes no trae websocket; el del sistema sí.
    # Nos relanzamos con él (sin bucle: solo un reintento).
    _py = "/usr/bin/python3"
    _self = globals().get("__file__") or os.path.expanduser(
        "~/.hermes/scripts/registro-entrega-rcs.py")
    if sys.executable != _py and os.path.exists(_py):
        os.execv(_py, [_py, _self] + sys.argv[1:])
    raise

PUERTO = 9224
LANZADOR = os.path.expanduser("~/.local/bin/messages-hermes")
BASE = os.path.expanduser("~/.hermes/registro-comunicaciones")
ESTADO = os.path.join(BASE, "entrega-rcs.json")
LOG = os.path.join(BASE, "entrega-rcs.log")
REGISTRO = os.path.expanduser("~/documentacion legal/REGISTRO-COMUNICACIONES-HIJAS.md")
NOMBRE = "María Martinez Castillo"
ID_CONOCIDO = "CgiwiivKI7_c_RICNDg"

VERBOSE = "--verbose" in sys.argv


# ---------------------------------------------------------------- CDP
def hay_navegador():
    try:
        urllib.request.urlopen(f"http://127.0.0.1:{PUERTO}/json/version", timeout=2)
        return True
    except Exception:
        return False


def abrir_navegador():
    subprocess.Popen([LANZADOR], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    for _ in range(40):
        if hay_navegador():
            return True
        time.sleep(1)
    return False


def cerrar_navegador():
    subprocess.run(["pkill", "-TERM", "-f", "user-data-dir=.*messages-perfil"],
                   check=False, capture_output=True)
    time.sleep(2)


class Sesion:
    def __init__(self):
        tabs = json.load(urllib.request.urlopen(f"http://127.0.0.1:{PUERTO}/json", timeout=10))
        self.tab = [t for t in tabs if t.get("type") == "page"
                    and "messages.google.com" in t.get("url", "")][0]
        self.ws = websocket.create_connection(self.tab["webSocketDebuggerUrl"],
                                              suppress_origin=True, timeout=40)
        self._n = 0

    def cmd(self, m, **p):
        self._n += 1
        self.ws.send(json.dumps({"id": self._n, "method": m, "params": p}))
        while True:
            r = json.loads(self.ws.recv())
            if r.get("id") == self._n:
                return r.get("result", {})

    def js(self, e):
        return self.cmd("Runtime.evaluate", expression=e, returnByValue=True,
                        awaitPromise=True).get("result", {}).get("value")

    def cerrar(self):
        try:
            self.ws.close()
        except Exception:
            pass


def abrir_hilo(s):
    """Navega a la conversación de María; devuelve True si está abierta."""
    destino = None
    for _ in range(10):
        s.js("(()=>{const l=[...document.querySelectorAll('mws-conversation-list,[role=list],"
             "mws-conversations-list *')].filter(e=>e.scrollHeight>e.clientHeight+50);"
             "l.forEach(e=>e.scrollTop=e.scrollHeight);})()")
        time.sleep(0.5)
        destino = s.js("""(()=>{for(const a of document.querySelectorAll('a[href*="/web/conversations/"]')){
            if(((a.innerText||'').includes(%s))) return a.getAttribute('href');} return null;})()"""
                       % json.dumps(NOMBRE))
        if destino:
            break
    s.js(f"location.href={json.dumps(destino or '/web/conversations/' + ID_CONOCIDO)}")
    time.sleep(4)
    for _ in range(3):
        if (s.js("document.querySelectorAll('mws-message-wrapper').length") or 0) > 0:
            return True
        time.sleep(3)
    return False


def leer_estados(s):
    """Devuelve {clave: {fecha, hora, texto, estado, saliente}} del hilo abierto."""
    prev = -1
    for _ in range(25):
        n = s.js("document.querySelectorAll('mws-message-wrapper').length") or 0
        if n == prev:
            break
        prev = n
        s.js("(()=>{const c=[...document.querySelectorAll('mws-messages-list *,[role=main] *')]"
             ".filter(e=>e.scrollHeight>e.clientHeight+100)"
             ".sort((a,b)=>b.scrollHeight-a.scrollHeight);if(c.length)c[0].scrollTop=0;})()")
        time.sleep(0.7)
    raw = s.js("""
    (() => {
      const out=[];
      for(const w of document.querySelectorAll('mws-message-wrapper')){
        const et=w.querySelector('[aria-label]');
        out.push({out: w.getAttribute('is-outgoing')==='true',
                  label: et?et.getAttribute('aria-label'):'',
                  txt: ((w.querySelector('[data-e2e-text-message-content]')||{}).innerText||'').trim()});
      }
      return JSON.stringify(out);
    })()""")
    return json.loads(raw)


MESES = {"enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6, "julio": 7,
         "agosto": 8, "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12}
ESTADOS = ("Leído", "Entregado", "Enviado", "Enviando", "Fallido", "No entregado")


def normaliza(m):
    est = next((k for k in ESTADOS if k in m["label"]), "—")
    mm = re.search(r"el (\d{1,2}) de (\w+) de (\d{4}) a las (\d{1,2}:\d{2})", m["label"])
    if mm:
        d, mes, a, h = int(mm.group(1)), MESES[mm.group(2)], mm.group(3), mm.group(4)
        fecha, hora = f"{d:02d}/{mes:02d}/{a}", h
    else:
        fecha, hora = "??", "??"
    return {"fecha": fecha, "hora": hora, "estado": est,
            "saliente": bool(m["out"]), "texto": re.sub(r"\s+", " ", m["txt"])[:120]}


def main():
    propio = False
    if not hay_navegador():
        if not abrir_navegador():
            print("⚠️ Seguimiento RCS: no se pudo abrir el navegador de Mensajes")
            return 1
        propio = True
    try:
        s = Sesion()
        if not abrir_hilo(s):
            print("⚠️ Seguimiento RCS: no se pudo abrir el hilo de María")
            s.cerrar()
            return 1
        crudo = leer_estados(s)
        s.cerrar()
    finally:
        if propio:
            cerrar_navegador()

    ahora = {}
    for m in crudo:
        d = normaliza(m)
        if not d["saliente"]:
            continue
        ahora[f"{d['fecha']} {d['hora']}"] = d

    previo = {}
    if os.path.exists(ESTADO):
        try:
            previo = json.load(open(ESTADO, encoding="utf-8"))
        except Exception:
            previo = {}

    cambios = []
    for k, d in ahora.items():
        antes = previo.get(k, {}).get("estado")
        if antes and antes != d["estado"]:
            cambios.append((k, antes, d["estado"], d["texto"]))
        elif not antes and VERBOSE:
            cambios.append((k, "nuevo", d["estado"], d["texto"]))

    json.dump(ahora, open(ESTADO, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    leidos = sum(1 for d in ahora.values() if d["estado"] == "Leído")
    total = len(ahora)

    # regenerar el registro si hay cambios reales
    if cambios:
        regen = os.path.join(BASE, "gen-registro.py")
        if os.path.exists(regen):
            subprocess.run([sys.executable, regen], capture_output=True, check=False)

    with open(LOG, "a", encoding="utf-8") as f:
        f.write(time.strftime("%d/%m/%Y %H:%M") + f" · {leidos}/{total} leídos")
        for k, a, b, t in cambios:
            f.write(f" · {k}: {a} → {b}")
        f.write("\n")

    # el cron solo habla si algo cambió a «Leído»
    avisos = [c for c in cambios if c[2] == "Leído"]
    if avisos:
        lineas = [f"📩 María ha leído {len(avisos)} mensaje{'s' if len(avisos) != 1 else ''}:"]
        for k, a, b, t in avisos:
            lineas.append(f"· {k} — «{t[:60]}…»" if len(t) > 60 else f"· {k} — «{t}»")
        print("\n".join(lineas))
    elif VERBOSE:
        print(f"{leidos}/{total} leídos, sin cambios")
    return 0


if __name__ == "__main__":
    sys.exit(main())
