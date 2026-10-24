#!/usr/bin/env python3
"""Centinela del envío semanal: última oportunidad dentro de la ventana (20:45).

Qué hace:
  1. Si el plan de esta semana ya está completo (WhatsApp y SMS), calla y sale.
  2. Si el día planificado ya llegó (o no hay plan), fuerza el envío con `--ahora` usando
     el python del perfil de Hermes, que sí trae websocket-client.
  3. Si la pasada normal hubiera fallado, este envío la sustituye y avisa por Telegram.
  4. Si tampoco puede, suelta un aviso claro (sin traceback) para que se arregle a mano.

Uso:
  mensajes-semanal-centinela.py            # modo real
  mensajes-semanal-centinela.py --simular  # no envía, cuenta lo que haría

Variables para probar con estados falsos: MENSAJES_SEMANAL_ESTADO, MENSAJES_SEMANAL_ORQUESTADOR
"""
import glob
import json
import os
import subprocess
import sys
from datetime import date

MARCADOR = ".hermes-sync"
SIMULAR = "--simular" in sys.argv[1:]
PERFIL = os.path.join(os.environ.get("LOCALAPPDATA") or os.path.expanduser("~"), "hermes")


def tiene_websocket(exe):
    if not exe or not os.path.exists(exe):
        return False
    try:
        r = subprocess.run([exe, "-c", "import websocket"], capture_output=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return False
    return r.returncode == 0


def python_valido():
    if tiene_websocket(sys.executable):
        return sys.executable
    for exe in sorted(glob.glob(os.path.join(PERFIL, "tools", "python-*", "python.exe")),
                      reverse=True):
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


def salir_si_todo_hecho(plan, semana):
    return bool(plan and plan.get("semana") == semana
                and plan.get("whatsapp", {}).get("hecho")
                and plan.get("sms", {}).get("hecho"))


def main():
    exe = python_valido()
    if not exe:
        print("⚠️ Mensajes semanales: ningún python del equipo puede importar websocket-client; "
              "el envío de última hora no puede salir.")
        return 0

    ruta_estado = os.environ.get("MENSAJES_SEMANAL_ESTADO")
    comun = carpeta_compartida()
    if not ruta_estado:
        if not comun:
            print("⚠️ Mensajes semanales: no encuentro la carpeta compartida del dual boot; "
                  "no puedo comprobar el envío de esta semana.")
            return 0
        ruta_estado = os.path.join(comun, "mensajes-semanal", "estado.json")
    orquestador = os.environ.get("MENSAJES_SEMANAL_ORQUESTADOR") or os.path.join(
        comun or "", "mensajes-semanal", "mensajes-semanal.py")

    try:
        with open(ruta_estado, encoding="utf-8") as f:
            estado = json.load(f)
    except OSError as exc:
        print(f"⚠️ Mensajes semanales: no puedo leer el estado ({exc.strerror}); "
              "no se ha comprobado el envío de esta semana.")
        return 0

    hoy = date.today()
    semana = f"{hoy.isocalendar()[0]}-W{hoy.isocalendar()[1]:02d}"
    plan = estado.get("plan")

    if salir_si_todo_hecho(plan, semana):
        return 0                                    # nada que hacer: silencio

    # Si la fecha planificada aún no ha llegado (aunque sea de la semana siguiente), no se adelanta.
    if plan and str(plan.get("dia", "")) > hoy.isoformat():
        return 0

    if not os.path.exists(orquestador):
        print(f"⚠️ Mensajes semanales: no encuentro el orquestador en {orquestador}.")
        return 0

    orden = [exe, orquestador, "--ahora"] + (["--simular"] if SIMULAR else [])
    try:
        r = subprocess.run(orden, capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=900)
    except subprocess.TimeoutExpired:
        print("⚠️ Mensajes semanales: el envío de última hora se quedó colgado (15 min) "
              "y no se ha podido completar.")
        return 0

    salida = (r.stdout or "").strip()
    if r.returncode != 0:
        lineas = [l for l in (r.stderr or "").strip().splitlines() if l.strip()]
        motivo = lineas[-1][:300] if lineas else f"código de salida {r.returncode}"
        print("⚠️ Mensajes semanales: el envío de última hora tampoco ha salido "
              f"({motivo}). Esta semana no se ha enviado; hay que arreglarlo a mano.")
        return 0

    if salida:
        etiqueta = "⏰ Prueba simulada" if SIMULAR else "⏰ Envío de última hora (la pasada normal no lo hizo)"
        print(f"{etiqueta}:\n{salida}")
    else:
        # El orquestador no dijo nada: releer el estado para contar la verdad.
        try:
            with open(ruta_estado, encoding="utf-8") as f:
                nuevo = json.load(f).get("plan") or {}
        except OSError:
            nuevo = {}
        faltan = [k for k in ("whatsapp", "sms") if not nuevo.get(k, {}).get("hecho")]
        if faltan:
            print("⚠️ Mensajes semanales: la pasada de última hora no ha enviado "
                  f"({', '.join(faltan)} sin hacer) y no ha dado motivo. Revisar el log.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
