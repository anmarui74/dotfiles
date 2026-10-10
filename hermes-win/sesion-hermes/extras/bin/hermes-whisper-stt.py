#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Adaptador STT para Hermes en Windows: whisper.cpp CUDA (mismo motor que OpenCode).

Normaliza el audio a 16 kHz mono WAV con ffmpeg y transcribe con whisper-cli.exe
(modelo large-v3-turbo, GPU CUDA). Escribe el texto en --out (UTF-8 sin BOM).

Uso (lo llama Hermes como proveedor command):
  python hermes-whisper-stt.py --in <audio> --out <texto.txt> [--language es]
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile

HOME = os.path.expanduser("~")
WHISPER_CLI = os.path.join(HOME, ".local", "bin", "whisper.cpp-cuda", "Release", "whisper-cli.exe")
WHISPER_CLI_ALT = os.path.join(HOME, ".local", "bin", "whisper.cpp-cuda", "whisper-cli.exe")
FFMPEG = os.path.join(HOME, ".local", "bin", "ffmpeg", "bin", "ffmpeg.exe")
MODEL = os.path.join(HOME, ".local", "models", "whisper", "ggml-large-v3-turbo-q5_0.bin")
FFMPEG_FALLBACK = "ffmpeg"


def _first_existing(*paths: str) -> str:
    for path in paths:
        if path and os.path.isfile(path):
            return path
    return ""


def _run(cmd: list[str], what: str) -> None:
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if proc.returncode != 0:
        raise RuntimeError(
            f"{what} fallo (codigo {proc.returncode})\n"
            f"  cmd: {' '.join(cmd)}\n"
            f"  stderr: {(proc.stderr or '').strip()[:800]}")


def main() -> int:
    ap = argparse.ArgumentParser(description="STT whisper.cpp CUDA para Hermes")
    ap.add_argument("--in", dest="audio", required=True, help="audio de entrada")
    ap.add_argument("--out", dest="out", required=True, help="fichero de texto de salida")
    ap.add_argument("--language", default="es", help="idioma (es, en, auto...)")
    ap.add_argument("--model", default=MODEL, help="modelo ggml de whisper.cpp")
    ap.add_argument("--threads", default="8", help="hilos de whisper.cpp")
    args = ap.parse_args()

    whisper = _first_existing(WHISPER_CLI, WHISPER_CLI_ALT)
    if not whisper:
        print("ERROR: no encuentro whisper-cli.exe (whisper.cpp-cuda)", file=sys.stderr)
        return 2
    if not os.path.isfile(args.model):
        print(f"ERROR: no encuentro el modelo {args.model}", file=sys.stderr)
        return 2
    if not os.path.isfile(args.audio):
        print(f"ERROR: no existe el audio {args.audio}", file=sys.stderr)
        return 2
    ffmpeg = _first_existing(FFMPEG) or FFMPEG_FALLBACK

    with tempfile.TemporaryDirectory(prefix="hermes-stt-") as tmp:
        wav16 = os.path.join(tmp, "entrada.wav")
        _run([ffmpeg, "-hide_banner", "-loglevel", "error", "-i", args.audio,
              "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", "-y", wav16],
             "ffmpeg (normalizacion a 16 kHz mono)")
        base = os.path.join(tmp, "transcripcion")
        cmd = [whisper, "-m", args.model, "-f", wav16, "-l", args.language or "es",
               "-t", str(args.threads), "-nt", "-otxt", "-of", base]
        try:
            _run(cmd, "whisper-cli (transcripcion)")
        except RuntimeError:
            # Con -otxt el fichero puede existir pese a un aviso en stderr: se acepta
            # solo si hay texto util.
            if not os.path.isfile(base + ".txt"):
                raise
        txt_path = base + ".txt"
        text = ""
        if os.path.isfile(txt_path):
            with open(txt_path, "r", encoding="utf-8", errors="replace") as fh:
                text = fh.read().strip()

    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(text)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # Hermes muestra el stderr del comando
        print(f"ERROR STT: {exc}", file=sys.stderr)
        sys.exit(1)
