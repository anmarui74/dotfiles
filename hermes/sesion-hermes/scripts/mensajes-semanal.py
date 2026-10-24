#!/usr/bin/env python3
"""Puente del cron: ejecuta el orquestador de mensajes semanales del disco compartido.

El cron de Hermes solo admite scripts dentro de ~/.hermes/scripts/, así que este puente
lanza el orquestador compartido (una sola copia para Linux y Windows):
    <comun>/mensajes-semanal/mensajes-semanal.py
"""
import os
import runpy
import sys

MARCADOR = ".hermes-sync"

# El intérprete con el que corre el cron puede no traer websocket-client (CDP). Si falta,
# relanzarse con el del sistema; si no, el job sale con código 1 y el aviso de error llega
# a Telegram con un traceback que parece un fallo del envío.
try:
    import websocket  # noqa: F401
except ModuleNotFoundError:
    if sys.executable != "/usr/bin/python3" and os.path.exists("/usr/bin/python3"):
        os.execv("/usr/bin/python3", ["/usr/bin/python3", os.path.abspath(__file__)] + sys.argv[1:])
    raise


def carpeta_compartida():
    candidatos = ["/mnt/seagate/HermesSync", os.path.expanduser("~/HermesSync")]
    candidatos += [f"{L}:\\HermesSync" for L in "DEFGHIJKLMNOPQRSTUVWXYZ"]
    for base in candidatos:
        try:
            if os.path.exists(os.path.join(base, MARCADOR)):
                return base
        except OSError:
            continue
    return None


comun = carpeta_compartida()
if not comun:
    print("ERROR: no encuentro la carpeta compartida del dual boot", file=sys.stderr)
    sys.exit(1)

orquestador = os.path.join(comun, "mensajes-semanal", "mensajes-semanal.py")
if not os.path.exists(orquestador):
    print(f"ERROR: no encuentro el orquestador en {orquestador}", file=sys.stderr)
    sys.exit(1)

sys.argv = [orquestador] + sys.argv[1:]
try:
    runpy.run_path(orquestador, run_name="__main__")
except SystemExit:
    raise
except Exception as exc:  # noqa: BLE001 - se convierte en aviso legible, no en traceback
    import traceback
    from datetime import datetime

    traza = traceback.format_exc()
    destino = os.path.expanduser("~/.hermes/logs/mensajes-semanal-errores.log")
    try:
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        with open(destino, "a", encoding="utf-8") as f:
            f.write(f"\n=== {datetime.now():%d/%m/%Y %H:%M:%S} ===\n{traza}")
    except OSError:
        pass
    print(f"⚠️ Mensajes semanales: la pasada ha fallado ({type(exc).__name__}: {exc}). "
          "Se reintenta en la próxima hora y a las 20:45 hay una pasada de última hora.")
    sys.exit(0)
