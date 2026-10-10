#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Adaptador TTS para Hermes en Windows: Kokoro v1.0 ONNX en GPU (CUDA).

Reutiliza el stack de voz que ya existe para OpenCode:
  1. Servidor persistente (kokoro-server.py, puerto 4210) si esta vivo: el modelo
     ya esta cargado en la GPU (~0,2-0,4 s por locucion).
  2. Si no, kokoro-tts.py con el venv de voz (carga el modelo, ~2 s).

Escribe el WAV en --out. Lo llama Hermes como proveedor command de TTS.

Uso:
  python hermes-kokoro-tts.py --text-file <texto.txt> --out <salida.wav> --voice ef_dora
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

HOME = os.path.expanduser("~")
VOICE_VENV_PY = os.path.join(HOME, ".config", "opencode", "voice", "venv", "Scripts", "python.exe")
KOKORO_TTS = os.path.join(HOME, ".config", "opencode", "voice", "kokoro-tts.py")
KOKORO_SERVER = os.path.join(HOME, ".config", "opencode", "voice", "kokoro-server.py")
DEFAULT_VOICE = "ef_dora"
PORT = int(os.environ.get("KOKORO_TTS_PORT") or "4210")
MIN_BYTES = 2000  # un WAV de voz real supera de sobra esto


def _server_alive(port: int, timeout: float = 2.0) -> bool:
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8", "replace")).get("ok") is True
    except Exception:
        return False


def _start_server(port: int, wait: float = 25.0) -> bool:
    """Levanta el servidor persistente (el mismo que usa OpenCode) y espera a que cargue.

    Sin el, cada locucion recarga el modelo en la GPU (~4 s); con el, ~0,5 s.
    Se lanza SIN ventana (pythonw + CREATE_NO_WINDOW + SW_HIDE): un python.exe de
    consola con DETACHED_PROCESS abre una ventana cuyo titulo es la ruta del
    ejecutable (y esa ruta esta dentro de .config\\opencode, de ahi la confusion de
    ver "una ventana de OpenCode").
    """
    if not os.path.isfile(VOICE_VENV_PY) or not os.path.isfile(KOKORO_SERVER):
        return False
    pyw = os.path.join(os.path.dirname(VOICE_VENV_PY), "pythonw.exe")
    python_exe = pyw if os.path.isfile(pyw) else VOICE_VENV_PY
    startupinfo = subprocess.STARTUPINFO()
    startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startupinfo.wShowWindow = 0  # SW_HIDE
    try:
        subprocess.Popen([python_exe, KOKORO_SERVER, "--port", str(port)],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         stdin=subprocess.DEVNULL, startupinfo=startupinfo,
                         creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                         close_fds=True)
    except Exception as exc:
        print(f"AVISO TTS: no pude arrancar el servidor Kokoro: {exc}", file=sys.stderr)
        return False
    import time
    deadline = time.time() + wait
    while time.time() < deadline:
        if _server_alive(port, 1.0):
            return True
        time.sleep(0.5)
    return False


def _synth_via_server(text: str, voice: str, speed: float, out: str, port: int) -> None:
    body = json.dumps({"text": text, "voice": voice, "speed": speed}).encode("utf-8")
    req = urllib.request.Request(f"http://127.0.0.1:{port}/tts", data=body,
                                headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = resp.read()
    with open(out, "wb") as fh:
        fh.write(data)


def _synth_via_script(text: str, voice: str, speed: float, out: str) -> None:
    if not os.path.isfile(VOICE_VENV_PY):
        raise RuntimeError(f"no encuentro el venv de voz: {VOICE_VENV_PY}")
    if not os.path.isfile(KOKORO_TTS):
        raise RuntimeError(f"no encuentro {KOKORO_TTS}")
    import tempfile
    with tempfile.TemporaryDirectory(prefix="hermes-tts-") as tmp:
        txt = os.path.join(tmp, "texto.txt")
        with open(txt, "w", encoding="utf-8", newline="") as fh:
            fh.write(text)
        cmd = [VOICE_VENV_PY, KOKORO_TTS, "--file", txt, "--voice", voice,
               "--speed", str(speed), "--out", out, "--quiet"]
        proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if proc.returncode != 0:
            raise RuntimeError(f"kokoro-tts.py fallo (codigo {proc.returncode}): "
                               f"{(proc.stderr or '').strip()[:600]}")


def _speed_value(raw: str) -> float:
    """Acepta --speed vacio (Hermes renderiza {speed} como '' si no esta configurado)."""
    text = str(raw).strip()
    return float(text) if text else 1.0


def main() -> int:
    ap = argparse.ArgumentParser(description="TTS Kokoro GPU (CUDA) para Hermes")
    ap.add_argument("--text-file", required=True, help="fichero UTF-8 con el texto a locutar")
    ap.add_argument("--out", required=True, help="WAV de salida")
    ap.add_argument("--voice", default=DEFAULT_VOICE, help="voz de Kokoro (p. ej. ef_dora)")
    ap.add_argument("--speed", type=_speed_value, default=1.0, help="velocidad (1.0 = normal)")
    ap.add_argument("--no-server", action="store_true",
                    help="no arrancar el servidor persistente; usar kokoro-tts.py directamente")
    args = ap.parse_args()

    with open(args.text_file, "r", encoding="utf-8", errors="replace") as fh:
        text = fh.read().strip()
    if not text:
        print("ERROR TTS: texto vacio", file=sys.stderr)
        return 1

    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    if os.path.exists(args.out):
        os.remove(args.out)

    errors = []
    used = ""
    if not args.no_server and not _server_alive(PORT):
        if _start_server(PORT):
            print(f"servidor Kokoro arrancado en :{PORT}", file=sys.stderr)
    if _server_alive(PORT):
        try:
            _synth_via_server(text, args.voice, args.speed, args.out, PORT)
            used = f"servidor Kokoro :{PORT}"
        except Exception as exc:
            errors.append(f"servidor :{PORT}: {exc}")
    if not used or not os.path.isfile(args.out):
        try:
            _synth_via_script(text, args.voice, args.speed, args.out)
            used = "kokoro-tts.py (venv de voz)"
        except Exception as exc:
            errors.append(f"script: {exc}")

    size = os.path.getsize(args.out) if os.path.isfile(args.out) else 0
    if size < MIN_BYTES:
        print("ERROR TTS: audio no generado o sospechosamente pequeno "
              f"({size} bytes). Intentos: {'; '.join(errors) or 'ninguno'}", file=sys.stderr)
        return 1
    print(f"OK TTS Kokoro GPU via {used}: {size} bytes -> {args.out}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"ERROR TTS: {exc}", file=sys.stderr)
        sys.exit(1)
