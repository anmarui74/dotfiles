#!/usr/bin/env python3
"""Proxy OpenCode ↔ LM Studio - VERSIÓN QUE FUNCIONA + MÉTRICAS
Reenvía peticiones a LM Studio (localhost:1234). Además:
- Registra métricas por request (tiempo, tokens, tok/s) en METRICS_EXPORT_PATH
- Inyecta `stats.tokens_per_second` en respuestas no-streaming
"""
import json
import os
import re
import threading
import time
import urllib.request
import http.server
import sys

LM = "http://localhost:1234"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4001

CONFIG_DIR = os.path.dirname(os.path.abspath(__file__))
METRICS_LOCK = threading.Lock()
MAX_RECORDS = 500


def load_env(path):
    """Carga variables KEY=VALUE de un .env simple (para METRICS)."""
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                k = k.strip()
                v = v.strip().strip('"').strip("'")
                if k:
                    os.environ.setdefault(k, v)
    except OSError:
        pass


load_env(os.path.join(CONFIG_DIR, ".env"))


def env_bool(name, default):
    val = os.environ.get(name)
    if val is None:
        return default
    return val.strip().lower() in ("1", "true", "yes", "on")


ENABLE_METRICS = env_bool("ENABLE_METRICS", True)
METRICS_PATH = os.environ.get("METRICS_EXPORT_PATH") or os.path.join(CONFIG_DIR, "data", "metrics.json")


def record_metric(model, prompt_tokens, completion_tokens, elapsed_s, stream):
    if not ENABLE_METRICS:
        return
    tps = (completion_tokens / elapsed_s) if elapsed_s > 0 else 0
    entry = {
        "ts": time.time(),
        "time": time.strftime("%d/%m/%Y %H:%M:%S"),
        "model": model,
        "stream": bool(stream),
        "elapsed_s": round(elapsed_s, 3),
        "prompt_tokens": int(prompt_tokens or 0),
        "completion_tokens": int(completion_tokens or 0),
        "tokens_per_second": round(tps, 2),
    }
    try:
        with METRICS_LOCK:
            data = {"updated_at": entry["time"], "count": 0, "records": []}
            try:
                with open(METRICS_PATH) as f:
                    loaded = json.load(f)
                if isinstance(loaded, dict):
                    data = loaded
            except (OSError, ValueError):
                pass
            records = data.get("records", [])
            if not isinstance(records, list):
                records = []
            records.append(entry)
            data["records"] = records[-MAX_RECORDS:]
            data["count"] = len(data["records"])
            data["updated_at"] = entry["time"]
            os.makedirs(os.path.dirname(METRICS_PATH), exist_ok=True)
            with open(METRICS_PATH, "w") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
    except OSError:
        pass


def parse_sse_usage(buf):
    """Extrae el usage (tokens) del último chunk data: {...} de un buffer SSE.
    Si el servidor no reporta usage (LM Studio), estima tokens = chars / 4."""
    if not buf:
        return None
    try:
        text = buf.decode("utf-8", errors="ignore")
    except Exception:
        return None
    usage = None
    chars = 0
    for m in re.finditer(r'data:\s*(\{.*?\})\s*\n', text, re.DOTALL):
        try:
            obj = json.loads(m.group(1))
        except ValueError:
            continue
        if not isinstance(obj, dict):
            continue
        if isinstance(obj.get("usage"), dict):
            usage = obj["usage"]
        try:
            delta = obj.get("choices", [{}])[0].get("delta", {})
            chars += len(delta.get("content") or "") + len(delta.get("reasoning_content") or "")
        except Exception:
            pass
    if usage is not None:
        return usage
    estimated = {"prompt_tokens": 0, "completion_tokens": max(1, round(chars / 4))}
    return estimated


class Proxy(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, format, *args):
        pass

    def do_GET(self):
        try:
            r = urllib.request.urlopen(urllib.request.Request(f"{LM}{self.path}"), timeout=5)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(r.read())
        except Exception:
            self.send_error(502)

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        body = json.loads(raw)
        model = body.get("model", "")
        if model.startswith("lmstudio/"):
            body["model"] = model[len("lmstudio/"):]

        msgs = body.get('messages', [])
        if not any(m.get('role') == 'user' for m in msgs):
            body['messages'].append({'role': 'user', 'content': '(cont.)'})

        start = time.time()
        try:
            r = urllib.request.urlopen(urllib.request.Request(
                f"{LM}{self.path}", data=json.dumps(body).encode(),
                headers={"Content-Type": "application/json"}), timeout=300)

            is_stream = body.get("stream", False)
            if is_stream:
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Cache-Control", "no-cache")
                self.end_headers()
                buf = b""
                while True:
                    chunk = r.read(65536)
                    if not chunk:
                        break
                    buf += chunk
                    self.wfile.write(chunk)
                    self.wfile.flush()
                elapsed = time.time() - start
                usage = parse_sse_usage(buf)
                if usage:
                    record_metric(model, usage.get("prompt_tokens"), usage.get("completion_tokens"), elapsed, True)
            else:
                resp = r.read()
                elapsed = time.time() - start
                try:
                    obj = json.loads(resp)
                    usage = obj.get("usage") or {}
                    tps = None
                    if elapsed > 0 and usage.get("completion_tokens"):
                        tps = round(usage["completion_tokens"] / elapsed, 2)
                    obj["stats"] = {"tokens_per_second": tps}
                    resp = json.dumps(obj).encode()
                    record_metric(model, usage.get("prompt_tokens"), usage.get("completion_tokens"), elapsed, False)
                except ValueError:
                    pass
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(resp)
        except Exception as e:
            self.send_error(502, str(e)[:200])


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Proxy).serve_forever()
