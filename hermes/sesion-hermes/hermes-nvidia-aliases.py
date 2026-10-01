#!/usr/bin/env python3
"""hermes-nvidia-aliases — recompone los alias NVIDIA de Hermes con el whitelist de OpenCode.

El whitelist vive en `~/.config/opencode/opencode.json` (`providers.nvidia.whitelist`) y lo
mantiene `check-nvidia-whitelist.sh` (timer quincenal, días 1 y 16). Este script traduce esa
lista a atajos de `/model` en Hermes:

  whitelist: nvidia/nemotron-3-ultra-550b-a55b  ->  alias `nvidia`
             openai/gpt-oss-20b                 ->  alias `gpt-oss`
             ...

Reglas:
  · Solo gestiona los alias que él mismo creó (estado en `state/nvidia-aliases.json`): nunca
    toca alias ajenos como `local` o `multimodal`.
  · Un alias desaparezido del whitelist se elimina SOLO si sigue apuntando a un modelo NVIDIA
    (si Antonio lo reapuntó a otra cosa, se respeta).
  · Los nombres conocidos están en NAME_MAP; para un modelo nuevo se deriva un nombre
    determinista y se avisa en el log para que Antonio lo revise.

Uso:
  hermes-nvidia-aliases                 # aplica los cambios
  hermes-nvidia-aliases --dry-run       # solo muestra qué haría
  hermes-nvidia-aliases --json          # salida para máquinas
  hermes-nvidia-aliases --whitelist F   # usa otro fichero (pruebas)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HOME = Path.home()
CONFIG_DIR = HOME / "Config" / "hermes"
STATE_FILE = CONFIG_DIR / "state" / "nvidia-aliases.json"
LOG_FILE = CONFIG_DIR / "logs" / "nvidia-aliases.log"
WHITELIST_FILES = (
    HOME / ".config" / "opencode" / "opencode.json",
    HOME / ".config" / "opencode" / "opencode-local.json",
    HOME / ".config" / "opencode" / "opencode-cloud.json",
)

# Nombres ya acordados con Antonio (los que existían a mano antes de este script).
NAME_MAP = {
    "nvidia/nemotron-3-ultra-550b-a55b": "nvidia",
    "nvidia/nemotron-3-super-120b-a12b": "nemotron-super",
    "nvidia/nemotron-3.5-lightning-30b-a3b": "lightning",
    "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning": "nano-omni",
    "openai/gpt-oss-20b": "gpt-oss",
    "meta/muse-glimmer-30b": "glimmer",
    "meta/llama-3.2-11b-vision-instruct": "vision",
}

_SUFIJOS = ("-instruct", "-reasoning", "-chat", "-it", "-hf", "-vl")


def log(texto: str) -> None:
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as fh:
        fh.write(f"[{datetime.now():%d/%m/%Y %H:%M:%S}] {texto}\n")


def leer_whitelist(ruta: Path | None) -> list[str]:
    """Ids del whitelist NVIDIA; busca en los perfiles de OpenCode si no se da ruta."""
    candidatos = (ruta,) if ruta else WHITELIST_FILES
    for fichero in candidatos:
        try:
            datos = json.loads(Path(fichero).expanduser().read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if not isinstance(datos, dict):
            continue
        for clave in ("providers", "provider"):
            bloque = datos.get(clave)
            if isinstance(bloque, dict) and isinstance(bloque.get("nvidia"), dict):
                lista = bloque["nvidia"].get("whitelist")
                if isinstance(lista, list):
                    limpia = [str(x).strip() for x in lista if str(x).strip()]
                    if limpia:
                        return limpia
    return []


def alias_para(modelo: str) -> tuple[str, bool]:
    """(alias, es_conocido) para un id del whitelist."""
    if modelo in NAME_MAP:
        return NAME_MAP[modelo], True
    base = modelo.split("/", 1)[-1].lower()
    for sufijo in _SUFIJOS:
        if base.endswith(sufijo):
            base = base[: -len(sufijo)]
    partes = [p for p in re.split(r"[-_]", base) if p]
    return "-".join(partes[:3]) or base, False


def binario_hermes() -> str:
    return os.environ.get("HERMES_BIN") or shutil.which("hermes") or str(
        HOME / ".hermes" / "hermes-agent" / ".hermes" / "bin" / "hermes"
    )


def _hermes(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [binario_hermes(), *args], capture_output=True, text=True, timeout=120
    )


def alias_actuales() -> dict[str, str]:
    """Alias de modelo definidos hoy en Hermes ({nombre: proveedor/modelo})."""
    res = _hermes("config", "get", "model.aliases")
    actuales: dict[str, str] = {}
    for linea in (res.stdout or "").splitlines():
        m = re.match(r"^\s*([A-Za-z0-9._-]+):\s*(\S+)\s*$", linea)
        if m and not m.group(1).startswith("#"):
            actuales[m.group(1)] = m.group(2)
    return actuales


def cargar_estado() -> dict:
    try:
        datos = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        return datos if isinstance(datos, dict) else {}
    except (OSError, ValueError):
        return {}


def guardar_estado(gestionados: dict[str, str]) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(
        json.dumps(
            {"gestionados": gestionados, "actualizado": datetime.now().isoformat(timespec="seconds")},
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )


def planificar(whitelist: list[str], actuales: dict[str, str], gestionados: dict[str, str]):
    """Devuelve (deseados, nuevos, retirados)."""
    deseados: dict[str, str] = {}
    nuevos: list[str] = []
    colisiones: list[str] = []
    for modelo in whitelist:
        alias, conocido = alias_para(modelo)
        if alias in deseados and deseados[alias] != modelo:
            colisiones.append(f"{modelo} (alias {alias} ya usado por {deseados[alias]})")
            continue
        deseados[alias] = modelo
        if not conocido:
            nuevos.append(f"{modelo} -> alias '{alias}' (nombre derivado, revísalo)")
    retirados = [
        alias
        for alias in gestionados
        if alias not in deseados and str(actuales.get(alias, "")).startswith("nvidia/")
    ]
    return deseados, nuevos, retirados, colisiones


def main() -> int:
    parser = argparse.ArgumentParser(description="Recompone los alias NVIDIA de Hermes con el whitelist de OpenCode")
    parser.add_argument("--dry-run", action="store_true", help="no aplica cambios, solo informa")
    parser.add_argument("--json", action="store_true", help="salida en JSON")
    parser.add_argument("--whitelist", type=Path, default=None, help="fichero de whitelist alternativo (pruebas)")
    args = parser.parse_args()

    whitelist = leer_whitelist(args.whitelist)
    if not whitelist:
        mensaje = "sin whitelist legible: no toco nada"
        log(f"⚠️  {mensaje}")
        print(f"⚠️  {mensaje}", file=sys.stderr)
        return 0

    actuales = alias_actuales()
    estado = cargar_estado()
    gestionados = dict(estado.get("gestionados") or {})
    # Los alias NVIDIA que ya existen y están en la lista se adoptan en la primera pasada.
    for alias, modelo in actuales.items():
        if modelo.startswith("nvidia/") and alias in {alias_para(m)[0] for m in whitelist}:
            gestionados.setdefault(alias, modelo)

    deseados, nuevos, retirados, colisiones = planificar(whitelist, actuales, gestionados)

    cambios: list[str] = []
    for alias, modelo in deseados.items():
        destino = f"nvidia/{modelo}"
        if actuales.get(alias) != destino:
            cambios.append(f"set {alias} -> {destino}")
    cambios += [f"unset {alias}" for alias in retirados]

    if args.json:
        print(json.dumps(
            {"whitelist": whitelist, "deseados": deseados, "cambios": cambios,
             "nuevos": nuevos, "retirados": retirados, "colisiones": colisiones,
             "aplicado": not args.dry_run},
            indent=2, ensure_ascii=False,
        ))
    else:
        print(f"whitelist: {len(whitelist)} modelos | alias deseados: {len(deseados)} | cambios: {len(cambios)}")
        for linea in cambios:
            print(f"  · {linea}")
        for aviso in nuevos:
            print(f"  ⚠️  modelo nuevo en el whitelist: {aviso}")
        for aviso in colisiones:
            print(f"  ⚠️  colisión de alias: {aviso}")
        if not cambios:
            print("  (ya estaba al día)")

    if args.dry_run:
        return 0

    for alias, modelo in deseados.items():
        destino = f"nvidia/{modelo}"
        if actuales.get(alias) != destino:
            res = _hermes("config", "set", f"model.aliases.{alias}", destino)
            if res.returncode != 0:
                log(f"❌ no pude fijar {alias}={destino}: {res.stderr.strip() or res.stdout.strip()}")
                print(f"❌ no pude fijar {alias}={destino}", file=sys.stderr)
                return 1
    for alias in retirados:
        res = _hermes("config", "unset", f"model.aliases.{alias}")
        if res.returncode != 0:
            log(f"❌ no pude borrar el alias {alias}: {res.stderr.strip() or res.stdout.strip()}")
            print(f"❌ no pude borrar el alias {alias}", file=sys.stderr)
            return 1

    guardar_estado(deseados)
    resumen = (
        f"whitelist={len(whitelist)} alias={len(deseados)} cambios={len(cambios)}"
        f"{' | ' + '; '.join(nuevos) if nuevos else ''}"
        f"{' | avisos: ' + '; '.join(colisiones) if colisiones else ''}"
    )
    log(f"✅ {resumen}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
