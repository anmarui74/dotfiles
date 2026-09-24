#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
kokoro-server.py - Servidor TTS persistente con Kokoro ONNX en GPU (CUDA).

Carga el modelo Kokoro v1.0 UNA sola vez y atiende peticiones HTTP locales.
Asi se evita recargar el modelo en cada locucion:

    arranque en frio (kokoro-tts.py) : ~2.0 s por locucion
    servidor persistente             : ~0.2-0.4 s por locucion

Endpoints (solo escucha en 127.0.0.1):
    GET  /health   -> {"ok": true, "voice": "...", "providers": [...]}
    POST /tts      -> body JSON {"text","voice","speed","lang"} -> WAV (audio/wav)
    POST /shutdown -> detiene el servidor

Uso:
    python kokoro-server.py --port 4210

Requiere el venv de voz con: kokoro-onnx, onnxruntime-gpu y las librerias
nvidia-cudnn-cu12 / nvidia-cublas-cu12 / nvidia-cuda-runtime-cu12.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys
import threading
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

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
    """Hace visibles todas las DLLs de CUDA/cuDNN instaladas por pip (nvidia-*)."""
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

# Estado global del servidor (modelo cargado una sola vez)
_lock = threading.Lock()
_kokoro = None
_default_voice = "ef_dora"


def _split_chunks(text: str) -> list[tuple[str, float]]:
    """Separa el texto en fragmentos y calcula la pausa posterior de cada uno."""
    pause_para = float(os.environ.get("SPEAK_PAUSE", "0.8"))
    pause_sent = float(os.environ.get("SPEAK_PAUSE_SENT", "0.35"))
    pause_clause = float(os.environ.get("SPEAK_PAUSE_CLAUSE", "0.3"))

    chunks: list[tuple[str, float]] = []
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
    return chunks


def synthesize(text: str, voice: str, speed: float, lang: str = "es") -> bytes | None:
    """Sintetiza el texto y devuelve los bytes de un WAV mono 16-bit."""
    text = clean_tts_text(text or "")
    if not text:
        return None

    chunks = _split_chunks(text)
    if not chunks:
        return None

    # kokoro-onnx no es thread-safe: serializar la sintesis
    with _lock:
        pieces = []
        sr = 24000
        for idx, (seg, pa) in enumerate(chunks):
            s, sr = _kokoro.create(seg, voice=voice, speed=speed, lang=lang)
            pieces.append(np.asarray(s, dtype=np.float32))
            if idx < len(chunks) - 1 and pa > 0:
                pieces.append(np.zeros(int(sr * pa), dtype=np.float32))
        samples = np.concatenate(pieces) if len(pieces) > 1 else pieces[0]

    samples = np.clip(np.asarray(samples, dtype=np.float32), -1.0, 1.0)
    pcm = (samples * 32767.0).astype(np.int16)

    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(int(sr))
        w.writeframes(pcm.tobytes())
    return buf.getvalue()


class Handler(BaseHTTPRequestHandler):
    server_version = "kokoro-tts/1.0"

    def log_message(self, fmt, *args):  # silenciar el log por defecto
        pass

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.split("?")[0] == "/health":
            try:
                providers = list(_kokoro.sess.get_providers()) if _kokoro else []
            except Exception:
                providers = []
            self._json(200, {"ok": _kokoro is not None, "voice": _default_voice, "providers": providers})
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        path = self.path.split("?")[0]
        if path == "/shutdown":
            self._json(200, {"ok": True})
            threading.Thread(target=self.server.shutdown, daemon=True).start()
            return
        if path != "/tts":
            self._json(404, {"error": "not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            data = json.loads(self.rfile.read(length) or b"{}")
        except Exception as e:
            self._json(400, {"error": f"bad request: {e}"})
            return

        text = data.get("text", "")
        voice = data.get("voice") or _default_voice
        try:
            speed = float(data.get("speed", 1.0))
        except Exception:
            speed = 1.0
        lang = data.get("lang", "es")

        try:
            wav_bytes = synthesize(text, voice, speed, lang)
        except Exception as e:
            self._json(500, {"error": f"synth failed: {e}"})
            return

        if not wav_bytes:
            self._json(400, {"error": "empty text"})
            return

        self.send_response(200)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(len(wav_bytes)))
        self.end_headers()
        self.wfile.write(wav_bytes)


def load_model(model: str, voices: str, voice: str) -> None:
    global _kokoro, _default_voice
    if not os.path.isfile(model):
        raise SystemExit(f"ERROR: no existe el modelo Kokoro: {model}")
    if not os.path.isfile(voices):
        raise SystemExit(f"ERROR: no existe el archivo de voces: {voices}")

    if "CUDAExecutionProvider" in ort.get_available_providers():
        os.environ.setdefault("ONNX_PROVIDER", "CUDAExecutionProvider")

    from kokoro_onnx import Kokoro

    _kokoro = Kokoro(model, voices)
    _default_voice = voice
    try:
        used = _kokoro.sess.get_providers()
    except Exception:
        used = ["?"]
    print(f"[kokoro-server] modelo cargado | voz={voice} | providers={used}", flush=True)


def main() -> int:
    ap = argparse.ArgumentParser(description="Servidor TTS Kokoro (GPU) persistente para OpenCode")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=int(os.environ.get("KOKORO_TTS_PORT", "4210")))
    ap.add_argument("--voice", default=os.environ.get("SPEAK_VOICE_KOKORO", "ef_dora"))
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--voices", default=DEFAULT_VOICES)
    args = ap.parse_args()

    load_model(args.model, args.voices, args.voice)

    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    srv.daemon_threads = True
    print(f"[kokoro-server] escuchando en http://{args.host}:{args.port}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
