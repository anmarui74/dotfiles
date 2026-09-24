#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
kokoro-tts.py - Sintesis de voz con Kokoro ONNX en GPU (CUDA) para Windows.

Equivalente al speak-kokoro-gpu de Linux. Carga el modelo Kokoro v1.0 con
onnxruntime-gpu (CUDAExecutionProvider) y genera un WAV.

Uso:
  python kokoro-tts.py --text "Hola" --voice ef_dora --out salida.wav
  python kokoro-tts.py --list-voices

Requiere el venv de voz con: kokoro-onnx, onnxruntime-gpu y las librerias
nvidia-cudnn-cu12 / nvidia-cublas-cu12 / nvidia-cuda-runtime-cu12.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import wave

# --- Limpieza de texto: quitar emojis, ANSI y dibujos de caja --------------
_ANSI_RE = re.compile(r"\x1b\[[0-9;]*[a-zA-Z]")
_BOX_RE = re.compile(r"[\u2500-\u257f\u2580-\u259f]")
_EMOJI_RE = re.compile(
    "[\U0001F000-\U0001FAFF\u2190-\u21FF\u2300-\u23FF\u25A0-\u25FF"
    "\u2600-\u27BF\u2900-\u297F\u2B00-\u2BFF\u3030\u303D\u3297\u3299"
    "\uFE00-\uFE0F\u200D]+"
)


def clean_tts_text(text: str) -> str:
    """Quita emojis, ANSI, dibujos de caja y marcas markdown residuales."""
    text = _ANSI_RE.sub("", text)
    text = _BOX_RE.sub("", text)
    text = _EMOJI_RE.sub("", text)
    text = re.sub(r"[*_`~#>|]+", " ", text)
    # IMPORTANTE: conservar los saltos de linea (pausas entre parrafos/lineas)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


# --- Hacer visibles las DLLs de CUDA/cuDNN instaladas por pip ---------------
def _register_nvidia_dlls() -> list[str]:
    """Hace visibles todas las DLLs de CUDA/cuDNN instaladas por pip (nvidia-*).

    onnxruntime-gpu busca sus dependencias (cublasLt, cudnn, cufft, curand,
    cusolver, cusparse...) en el PATH del proceso, asi que anadimos todos los
    subdirectorios 'nvidia/*/bin' tanto a PATH como a add_dll_directory.
    """
    site = os.path.join(sys.prefix, "Lib", "site-packages")
    nvidia = os.path.join(site, "nvidia")
    added: list[str] = []
    if os.path.isdir(nvidia):
        for sub in sorted(os.listdir(nvidia)):
            d = os.path.join(nvidia, sub, "bin")
            if os.path.isdir(d):
                try:
                    os.add_dll_directory(d)
                except Exception:
                    pass
                added.append(d)
    if added:
        os.environ["PATH"] = os.pathsep.join(added) + os.pathsep + os.environ.get("PATH", "")
    return added


_register_nvidia_dlls()

import numpy as np  # noqa: E402
import onnxruntime as ort  # noqa: E402

DEFAULT_MODEL = os.path.join(
    os.path.expanduser("~"), ".local", "models", "kokoro", "kokoro-v1.0.onnx"
)
DEFAULT_VOICES = os.path.join(
    os.path.expanduser("~"), ".local", "models", "kokoro", "voices-v1.0.bin"
)
# Voces espanolas habituales de Kokoro
SPANISH_VOICES = ["ef_dora", "em_alex", "em_santa", "ef_dora"]


def main() -> int:
    ap = argparse.ArgumentParser(description="Kokoro TTS (GPU) para OpenCode")
    ap.add_argument("--text", help="Texto a sintetizar")
    ap.add_argument("--file", help="Fichero de texto UTF-8 (alternativa a --text/stdin)")
    ap.add_argument("--voice", default=os.environ.get("SPEAK_VOICE_KOKORO", "ef_dora"))
    ap.add_argument("--lang", default="es")
    ap.add_argument("--speed", type=float, default=float(os.environ.get("SPEAK_SPEED", "1.0")))
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--voices", default=DEFAULT_VOICES)
    ap.add_argument("--out", default="kokoro-out.wav")
    ap.add_argument("--list-voices", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(args.model):
        print(f"ERROR: no existe el modelo Kokoro: {args.model}", file=sys.stderr)
        return 2
    if not os.path.isfile(args.voices):
        print(f"ERROR: no existe el archivo de voces: {args.voices}", file=sys.stderr)
        return 2

    # Forzar GPU: kokoro-onnx usa la variable de entorno ONNX_PROVIDER si esta definida
    if "CUDAExecutionProvider" in ort.get_available_providers():
        os.environ.setdefault("ONNX_PROVIDER", "CUDAExecutionProvider")
    if not args.quiet:
        print(f"[kokoro] providers: {ort.get_available_providers()} | usando: {os.environ.get('ONNX_PROVIDER', 'auto')}", file=sys.stderr)

    from kokoro_onnx import Kokoro
    kokoro = Kokoro(args.model, args.voices)

    if not args.quiet:
        try:
            used = kokoro.sess.get_providers()
        except Exception:
            used = ["?"]
        print(f"[kokoro] sesion ONNX usando: {used}", file=sys.stderr)

    if args.list_voices:
        for v in sorted(kokoro.get_voices()):
            print(v)
        return 0

    if args.file:
        try:
            with open(args.file, "r", encoding="utf-8-sig") as fh:
                args.text = fh.read()
        except Exception as e:
            print(f"ERROR: no se pudo leer {args.file}: {e}", file=sys.stderr)
            return 2
    if not args.text:
        try:
            args.text = sys.stdin.buffer.read().decode("utf-8", "replace")
        except Exception:
            args.text = ""
    if not args.text or not args.text.strip():
        print("ERROR: falta texto (--text, --file o stdin)", file=sys.stderr)
        return 2

    text = clean_tts_text(args.text)
    if not text:
        if not args.quiet:
            print("[kokoro] texto vacio tras limpiar (solo emojis/simbolos)", file=sys.stderr)
        return 0

    # Separar en fragmentos (por parrafo y por puntuacion) y anadir silencios
    #   SPEAK_PAUSE         -> pausa al final de parrafo/linea (por defecto 0.8 s)
    #   SPEAK_PAUSE_SENT    -> pausa tras . ! ?            (por defecto 0.35 s)
    #   SPEAK_PAUSE_CLAUSE  -> pausa tras : ; — y guiones  (por defecto 0.3 s)
    pause_para = float(os.environ.get("SPEAK_PAUSE", "0.8"))
    pause_sent = float(os.environ.get("SPEAK_PAUSE_SENT", "0.35"))
    pause_clause = float(os.environ.get("SPEAK_PAUSE_CLAUSE", "0.3"))

    chunks = []  # lista de (texto, pausa_despues)
    for para in re.split(r"\n+", text):
        para = para.strip()
        if not para:
            continue
        parts = [p.strip() for p in re.split(r"(?<=[.!?:;])\s+|\s*[—–]\s+", para) if p.strip()]
        if not parts:
            parts = [para]
        for j, p in enumerate(parts):
            if j == len(parts) - 1:
                pa = pause_para
            elif p.endswith((".", "!", "?")):
                pa = pause_sent
            elif p.endswith((":", ";", "—", "–")):
                pa = pause_clause
            else:
                pa = 0.0
            chunks.append((p, pa))

    pieces = []
    sr = 24000
    for idx, (seg, pa) in enumerate(chunks):
        s, sr = kokoro.create(seg, voice=args.voice, speed=args.speed, lang=args.lang)
        pieces.append(np.asarray(s, dtype=np.float32))
        if idx < len(chunks) - 1 and pa > 0:
            pieces.append(np.zeros(int(sr * pa), dtype=np.float32))
    samples = np.concatenate(pieces) if len(pieces) > 1 else pieces[0]

    samples = np.clip(np.asarray(samples, dtype=np.float32), -1.0, 1.0)
    pcm = (samples * 32767.0).astype(np.int16)
    with wave.open(args.out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(int(sr))
        w.writeframes(pcm.tobytes())

    if not args.quiet:
        print(f"[kokoro] generado {args.out} ({len(samples)/sr:.2f}s, {sr} Hz, voz {args.voice})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
