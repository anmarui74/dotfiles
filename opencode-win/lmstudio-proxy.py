#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
lmstudio-proxy.py - Proxy OpenAI-compatible para LM Studio (Windows).

Escucha en 127.0.0.1:4001 (configurable) y reenvia las peticiones a LM Studio
(por defecto 127.0.0.1:1234). Anade metricas de rendimiento (tokens/s, TTFT,
latencia) y guarda un historico en metrics.json.

Variables de entorno:
  PROXY_HOST           (def 127.0.0.1)
  PROXY_PORT           (def 4001)
  LMSTUDIO_UPSTREAM    (def http://127.0.0.1:1234)
  METRICS_EXPORT_PATH  (def <dir-del-script>/data/metrics.json)
  ENABLE_METRICS       (def true)

Solo usa la libreria estandar de Python (no requiere pip install).
"""
from __future__ import annotations

import json
import os
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
HOST = os.environ.get("PROXY_HOST", "127.0.0.1")
PORT = int(os.environ.get("PROXY_PORT", "4001"))
UPSTREAM = os.environ.get("LMSTUDIO_UPSTREAM", "http://127.0.0.1:1234").rstrip("/")
METRICS_PATH = os.environ.get(
    "METRICS_EXPORT_PATH", os.path.join(BASE_DIR, "data", "metrics.json")
)
ENABLE_METRICS = os.environ.get("ENABLE_METRICS", "true").lower() in (
    "1",
    "true",
    "yes",
    "on",
)

_lock = threading.Lock()
HOP_BY_HOP = {
    "host",
    "content-length",
    "connection",
    "accept-encoding",
    "keep-alive",
    "transfer-encoding",
    "upgrade",
    "proxy-connection",
    "te",
    "trailer",
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def _load_metrics() -> dict:
    try:
        with open(METRICS_PATH, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return {"requests": []}


def _save_metrics(data: dict) -> None:
    try:
        os.makedirs(os.path.dirname(METRICS_PATH), exist_ok=True)
        tmp = METRICS_PATH + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)
        os.replace(tmp, METRICS_PATH)
    except Exception:
        pass


def _record(entry: dict) -> None:
    if not ENABLE_METRICS:
        return
    with _lock:
        data = _load_metrics()
        reqs = data.setdefault("requests", [])
        reqs.append(entry)
        data["requests"] = reqs[-500:]
        data["last"] = entry
        data["total_requests"] = len(data["requests"])
        tps = [
            r["tokens_per_second"]
            for r in data["requests"]
            if r.get("tokens_per_second")
        ]
        data["average_tokens_per_second"] = (
            round(sum(tps) / len(tps), 2) if tps else None
        )
        _save_metrics(data)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "lmstudio-proxy/1.0"

    def log_message(self, *args):  # silencio: no ensuciar la consola
        pass

    # -- utilidades -------------------------------------------------------
    def _send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _do_proxy(self) -> None:
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        payload = None
        if body:
            try:
                payload = json.loads(body.decode("utf-8"))
            except Exception:
                payload = None
        is_chat = "chat/completions" in self.path
        stream = bool(isinstance(payload, dict) and payload.get("stream"))
        model = payload.get("model") if isinstance(payload, dict) else None

        url = UPSTREAM + self.path
        req = urllib.request.Request(url, data=body, method=self.command)
        for key, value in self.headers.items():
            if key.lower() in HOP_BY_HOP:
                continue
            req.add_header(key, value)
        req.add_header("Accept-Encoding", "identity")

        start = time.perf_counter()
        try:
            upstream = urllib.request.urlopen(req, timeout=600)
        except urllib.error.HTTPError as exc:
            err_body = exc.read()
            self.send_response(exc.code)
            for key, value in exc.headers.items():
                if key.lower() in HOP_BY_HOP:
                    continue
                self.send_header(key, value)
            self.send_header("Content-Length", str(len(err_body)))
            self.end_headers()
            self.wfile.write(err_body)
            return
        except Exception as exc:
            self._send_json(502, {"error": {"message": f"upstream error: {exc}"}})
            return

        ctype = upstream.headers.get("Content-Type", "")
        if stream and "text/event-stream" in ctype:
            self._relay_stream(upstream, start, model)
        else:
            self._relay_full(upstream, start, model, is_chat, ctype)

    def _relay_stream(self, upstream, start, model) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True

        first_chunk_at = None
        completion_tokens = 0
        usage = None
        buffer = ""
        try:
            for raw in upstream:
                if first_chunk_at is None:
                    first_chunk_at = time.perf_counter()
                self.wfile.write(raw)
                self.wfile.flush()
                buffer += raw.decode("utf-8", "replace")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line.startswith("data:"):
                        continue
                    data = line[5:].strip()
                    if not data or data == "[DONE]":
                        continue
                    try:
                        obj = json.loads(data)
                    except Exception:
                        continue
                    if obj.get("usage"):
                        usage = obj["usage"]
                    for choice in obj.get("choices") or []:
                        delta = choice.get("delta") or {}
                        if delta.get("content"):
                            completion_tokens += 1
        except Exception:
            pass

        elapsed = time.perf_counter() - start
        ttft = (first_chunk_at - start) if first_chunk_at else None
        if usage:
            completion_tokens = usage.get("completion_tokens", completion_tokens)
        tps = None
        if completion_tokens and elapsed > 0:
            gen_time = elapsed - (ttft or 0)
            if gen_time > 0:
                tps = round(completion_tokens / gen_time, 2)
        _record(
            {
                "timestamp": _now_iso(),
                "model": model,
                "stream": True,
                "prompt_tokens": (usage or {}).get("prompt_tokens"),
                "completion_tokens": completion_tokens or None,
                "ttft_ms": round(ttft * 1000) if ttft else None,
                "latency_ms": round(elapsed * 1000),
                "tokens_per_second": tps,
            }
        )

    def _relay_full(self, upstream, start, model, is_chat, ctype) -> None:
        data = upstream.read()
        elapsed = time.perf_counter() - start
        if is_chat and "application/json" in ctype:
            try:
                obj = json.loads(data.decode("utf-8"))
                usage = obj.get("usage") or {}
                completion = usage.get("completion_tokens")
                prompt = usage.get("prompt_tokens")
                tps = (
                    round(completion / elapsed, 2)
                    if completion and elapsed > 0
                    else None
                )
                if tps is not None:
                    obj["stats"] = {
                        "tokens_per_second": tps,
                        "prompt_tokens": prompt,
                        "completion_tokens": completion,
                        "latency_ms": round(elapsed * 1000),
                    }
                    data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
                _record(
                    {
                        "timestamp": _now_iso(),
                        "model": model,
                        "stream": False,
                        "prompt_tokens": prompt,
                        "completion_tokens": completion,
                        "latency_ms": round(elapsed * 1000),
                        "tokens_per_second": tps,
                    }
                )
            except Exception:
                pass

        self.send_response(upstream.status)
        self.send_header("Content-Type", ctype or "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    # -- verbos HTTP ------------------------------------------------------
    def do_GET(self):
        if self.path.rstrip("/") in ("/health", "/proxy/health"):
            self._send_json(200, {"status": "ok", "upstream": UPSTREAM, "port": PORT})
            return
        self._do_proxy()

    def do_POST(self):
        self._do_proxy()

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Content-Length", "0")
        self.end_headers()


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"[lmstudio-proxy] escuchando en http://{HOST}:{PORT} -> {UPSTREAM}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
