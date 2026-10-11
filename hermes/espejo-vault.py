#!/usr/bin/env python3
"""Espeja los markdown de configuración de Hermes en el vault de Obsidian.

Lo llama `hermes-espejo-vault.service`, que dispara `hermes-espejo-vault.path` cada vez que
cambia alguno de los orígenes; también se puede lanzar a mano (`espejo-vault`).

Reglas (skill `obsidian-espejo-config`):
  - La nota es el contenido del origen, **verbatim**, con una línea en blanco delante.
  - El emparejamiento origen → nota es **explícito** (mapa de abajo): así no se inventan
    nombres ni se cuelan ficheros que, por convención, no van al vault.
  - Solo se escribe si el contenido difiere, para no tocar MEGA en balde.
  - Antes de escribir se busca material sensible (claves de API): si aparece algo, se salta
    ese fichero y se anota en el log, sin publicar nada.

Los markdown de OpenCode y MiMoCode no se tocan aquí: su espejo necesita reescritura de
enlaces y lo cubren el cron semanal «Espejo Obsidian al dia» y sus `check-setup`.

Salida: 0 siempre salvo error de entorno; los avisos van al log.
"""
from __future__ import annotations

import datetime
import pathlib
import re
import sys

HOME = pathlib.Path.home()
VAULT = HOME / "MEGA/Obsidian/Obsidian/armarui74"
LOG = HOME / "Config/hermes/logs/espejo-vault.log"

# (nota del vault, origen). El nombre de la nota lleva el fichero origen, como manda la
# convención del vault; el mapa es explícito para no depender de heurísticas.
MAPA = [
    # --- Hermes (Linux) ---
    ("Hermes/💻 Manual de Hermes — AGENTS.md",
     "Config/hermes/AGENTS.md"),
    ("Hermes/💻 Sistema — Inventario del equipo · SISTEMA-CACHYOS.md",
     "Config/hermes/SISTEMA-CACHYOS.md"),
    ("Hermes/💻 Identidad de Hermes — SOUL.md",
     "Config/hermes/sesion-hermes/SOUL.md"),
    ("Hermes/💻 Dual boot — Ajustes de Linux en Windows · PARA-WINDOWS-ajustes-linux.md",
     "Config/hermes/dual-boot/windows/PARA-WINDOWS-ajustes-linux.md"),
    ("Hermes/💻 Dual boot — Backup en Windows · PARA-WINDOWS-backup.md",
     "Config/hermes/dual-boot/windows/PARA-WINDOWS-backup.md"),
    ("Hermes/💻 Dual boot — Estado compartido · LEEME-comun.md",
     "Config/hermes/dual-boot/windows/LEEME-comun.md"),
    ("Hermes/💻 Dual boot — Motor de fusión · PARA-WINDOWS-motor-fusion.md",
     "Config/hermes/dual-boot/windows/PARA-WINDOWS-motor-fusion.md"),
    ("Hermes/💻 Dual boot — Windows · LEEME-WINDOWS.md",
     "Config/hermes/dual-boot/windows/LEEME-WINDOWS.md"),
    # --- Hermes en Windows (esquema replicado en ~/Config/Hermes-Win) ---
    ("Hermes-win/💻 Manual de Hermes en Windows — AGENTS-WIN.md",
     "Config/Hermes-Win/AGENTS-WIN.md"),
    ("Hermes-win/💻 Sistema — Inventario del equipo en Windows · SISTEMA-WINDOWS.md",
     "Config/Hermes-Win/SISTEMA-WINDOWS.md"),
]

# Frontera de credenciales (skill `obsidian-espejo-config`): si un origen contiene algo así,
# no se publica en el vault y se deja constancia en el log.
SECRETOS = re.compile(
    r"(nvapi-[A-Za-z0-9_-]{10,}|oc_sk_[A-Za-z0-9_-]{10,}|sk-[A-Za-z0-9]{25,}"
    r"|API_KEY=[A-Za-z0-9_-]{15,}|BEGIN [A-Z ]*PRIVATE KEY)"
)


def log(msg: str) -> None:
    linea = f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}  {msg}"
    print(linea)
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a", encoding="utf-8") as fh:
            fh.write(linea + "\n")
    except OSError:
        pass


def main() -> int:
    if not VAULT.is_dir():
        log(f"el vault no existe ({VAULT}); nada que hacer")
        return 0

    escritas = revisadas = avisos = 0
    for nota_rel, origen_rel in MAPA:
        nota = VAULT / nota_rel
        origen = HOME / origen_rel
        if not origen.is_file():
            log(f"AVISO: origen ausente {origen_rel}")
            avisos += 1
            continue
        if not nota.is_file():
            log(f"AVISO: sin nota en el vault para {nota_rel} (no la creo)")
            avisos += 1
            continue
        revisadas += 1
        texto = origen.read_text(encoding="utf-8")
        if SECRETOS.search(texto):
            log(f"AVISO: {origen.name} parece llevar claves; no lo publico")
            avisos += 1
            continue
        deseado = ("\n" + texto).encode("utf-8")
        try:
            actual = nota.read_bytes()
        except OSError as exc:
            log(f"AVISO: no puedo leer {nota.name}: {exc}")
            avisos += 1
            continue
        if actual == deseado:
            continue
        try:
            nota.write_bytes(deseado)
            escritas += 1
            log(f"refrescada: {nota_rel}")
        except OSError as exc:
            log(f"AVISO: no puedo escribir {nota.name}: {exc}")
            avisos += 1

    if escritas or avisos:
        log(f"fin: {revisadas} notas revisadas, {escritas} refrescadas, {avisos} avisos")
    else:
        log(f"fin: {revisadas} notas revisadas, todas al dia")
    return 0


if __name__ == "__main__":
    sys.exit(main())
