#!/usr/bin/env python3
"""Puente del cron: ejecuta el orquestador de mensajes semanales del disco compartido.

El cron de Hermes solo admite scripts dentro de <perfil>/scripts/, así que este puente
lanza el orquestador compartido (una sola copia para Linux y Windows):
    <comun>/mensajes-semanal/mensajes-semanal.py

Dos protecciones aprendidas el 23/10/2026 (las mismas que en Linux):
  * El intérprete con el que corre el cron puede no traer websocket-client (CDP), que es
    lo que usa el envío por WhatsApp. Si falta, este puente se relanza con el python de
    %LOCALAPPDATA%\\hermes\\tools, que sí lo tiene.
  * Si el orquestador revienta, no se suelta el traceback a Telegram: se guarda en
    <perfil>/logs/mensajes-semanal-errores.log y se avisa en una línea.
"""
import glob
import os
import subprocess
import sys

MARCADOR = ".hermes-sync"
PERFIL = os.path.join(os.environ.get("LOCALAPPDATA") or os.path.expanduser("~"), "hermes")
LOG = os.path.join(PERFIL, "logs", "mensajes-semanal-errores.log")


def tiene_websocket(exe):
    """True si ese intérprete puede importar websocket-client."""
    if not exe or not os.path.exists(exe):
        return False
    try:
        r = subprocess.run([exe, "-c", "import websocket"], capture_output=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return False
    return r.returncode == 0


def python_valido():
    """El actual si sirve; si no, el python de tools del perfil de Hermes."""
    if tiene_websocket(sys.executable):
        return sys.executable
    candidatos = sorted(glob.glob(os.path.join(PERFIL, "tools", "python-*", "python.exe")),
                        reverse=True)
    for exe in candidatos:
        if tiene_websocket(exe):
            return exe
    return None


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


def main():
    exe = python_valido()
    if not exe:
        print("⚠️ Mensajes semanales: ningún python del equipo puede importar websocket-client; "
              "el envío por WhatsApp no puede salir. Hay que instalarlo.")
        return 0

    # Relanzarse una sola vez con el intérprete bueno (nunca en bucle).
    if os.path.normcase(exe) != os.path.normcase(sys.executable):
        return subprocess.call([exe, os.path.abspath(__file__)] + sys.argv[1:])

    comun = carpeta_compartida()
    if not comun:
        print("⚠️ Mensajes semanales: no encuentro la carpeta compartida del dual boot.")
        return 0

    orquestador = os.path.join(comun, "mensajes-semanal", "mensajes-semanal.py")
    if not os.path.exists(orquestador):
        print(f"⚠️ Mensajes semanales: no encuentro el orquestador en {orquestador}.")
        return 0

    sys.argv = [orquestador] + sys.argv[1:]
    import runpy
    try:
        runpy.run_path(orquestador, run_name="__main__")
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001 - se convierte en aviso legible, no en traceback
        import traceback
        from datetime import datetime

        traza = traceback.format_exc()
        try:
            os.makedirs(os.path.dirname(LOG), exist_ok=True)
            with open(LOG, "a", encoding="utf-8") as f:
                f.write(f"\n=== {datetime.now():%d/%m/%Y %H:%M:%S} ===\n{traza}")
        except OSError:
            pass
        print(f"⚠️ Mensajes semanales: la pasada ha fallado ({type(exc).__name__}: {exc}). "
              "Se reintenta en la próxima hora y a las 20:45 hay una pasada de última hora.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
