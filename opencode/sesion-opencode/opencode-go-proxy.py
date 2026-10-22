#!/usr/bin/env python3
"""
opencode-go-proxy.py — Proxy local OpenAI-compatible para OpenCode Go

Permite usar los modelos de OpenCode Go (suscripción) desde clientes que NO
envían las cabeceras que el endpoint de OpenCode exige, como el plugin de IA de
ONLYOFFICE Desktop Editors.

Problema que resuelve:
    https://opencode.ai/inference/go/openai/v1/chat/completions devuelve
    400 {"type":"MissingSessionID"} si no llega la cabecera x-opencode-session.

Qué hace:
    - Escucha en 127.0.0.1:4002 (configurable)
    - Inyecta Authorization: Bearer <API key de auth.json>
    - Inyecta x-opencode-session (UUID estable por proceso)
    - Envía un User-Agent propio, como pide la documentación de Go
    - Añade cabeceras CORS (el plugin IA de OnlyOffice las necesita)
    - Reenvía SSE en streaming sin bufferizar

Uso:
    python3 opencode-go-proxy.py            # escucha en 4002
    python3 opencode-go-proxy.py 4003       # otro puerto
    OPENCODE_GO_SESSION=ses_xxx python3 opencode-go-proxy.py

Cliente (OnlyOffice): URL base http://localhost:4002/v1 , API key cualquiera.
"""
import json
import os
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPSTREAM = "https://opencode.ai/inference/go"
AUTH_FILE = os.path.expanduser("~/.local/share/opencode/auth.json")
USER_AGENT = "onlyoffice-ai-plugin/3.2 (+opencode-go-proxy/1.0)"
# Sesión estable: la documentación de Go pide un ID estable por conversación.
SESSION_ID = os.environ.get("OPENCODE_GO_SESSION") or f"ses_{uuid.uuid4().hex}"

# Modelos de Go servidos por /openai/v1/chat/completions (los únicos que valen
# para un cliente "OpenAI Compatible"). El resto usa /anthropic o /responses.
CHAT_MODELS = [
    "glm-5.3-flash",
    "deepseek-v4.1-flash",
    "kimi-k2.7-code",
    "mimo-v2.6-flash",
    "minimax-m3.1-flash-free",
    "longcat-2.0",
    "glm-5.3",
    "glm-5.2",
    "kimi-k3",
    "deepseek-v4-pro",
    "mimo-v2.6-pro",
    "mimo-v2.5",
    "mimo-v2.5-pro",
    "hy3",
    "hy4-preview",
    "step-5-preview",
    "longcat-2.5-preview-free",
    "beam-free",
]


def filter_models(body: bytes) -> bytes:
    """Deja solo los modelos que funcionan con /chat/completions, en orden de preferencia."""
    try:
        data = json.loads(body)
        items = {m.get("id"): m for m in data.get("data", [])}
        ordered = [items[mid] for mid in CHAT_MODELS if mid in items]
        for mid, item in items.items():          # añade los nuevos no listados
            if mid not in CHAT_MODELS:
                ordered.append(item)
        data["data"] = ordered
        return json.dumps(data).encode("utf-8")
    except Exception:  # noqa: BLE001
        return body


ENV_FILE = os.path.expanduser("~/.config/opencode/.env")


def _from_env_file(var: str) -> str:
    """Lee una variable suelta del .env de OpenCode (sin cargar todo el fichero)."""
    try:
        with open(ENV_FILE, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith(f"{var}="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
    except OSError:
        pass
    return ""


def load_api_key() -> str:
    # 1) variable de entorno  2) clave dedicada del .env  3) auth.json de OpenCode
    key = os.environ.get("OPENCODE_GO_API_KEY", "")
    if key:
        return key
    key = _from_env_file("OPENCODE_GO_ONLYOFFICE_KEY")
    if key:
        return key
    try:
        with open(AUTH_FILE, encoding="utf-8") as fh:
            return json.load(fh)["opencode-go"]["key"]
    except Exception as exc:  # noqa: BLE001
        print(f"❌ No pude leer la API key de {ENV_FILE} ni de {AUTH_FILE}: {exc}",
              file=sys.stderr)
        sys.exit(1)


API_KEY = load_api_key()


def log(msg: str) -> None:
    print(f"[{time.strftime('%d/%m/%Y %H:%M:%S')}] {msg}", flush=True)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "opencode-go-proxy/1.0"

    # ── utilidades ────────────────────────────────────────────────
    def _cors(self, preflight: bool = False) -> None:
        # Reflejamos el Origin cuando existe (permite credenciales) y '*' si no.
        origin = self.headers.get("Origin")
        if origin:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Access-Control-Allow-Credentials", "true")
            self.send_header("Vary", "Origin")
        else:
            self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        # Reflejamos los headers pedidos: nunca nos quedamos cortos.
        requested = self.headers.get("Access-Control-Request-Headers")
        self.send_header(
            "Access-Control-Allow-Headers",
            requested or "Content-Type, Authorization, x-api-key, X-Requested-With, x-opencode-session",
        )
        self.send_header("Access-Control-Max-Age", "86400")
        self.send_header("Access-Control-Expose-Headers", "*")
        # Chrome/CEF exige permiso explícito para acceder a localhost (Private Network Access).
        if preflight and self.headers.get("Access-Control-Request-Private-Network") == "true":
            self.send_header("Access-Control-Allow-Private-Network", "true")

    def _upstream_path(self, path: str) -> str:
        # /v1/chat/completions -> .../go/openai/v1/chat/completions
        if path.startswith("/v1/"):
            return f"{UPSTREAM}/openai{path}"
        if path.startswith("/models"):
            return f"{UPSTREAM}/v1/models"
        return f"{UPSTREAM}/openai{path}"

    def log_message(self, fmt, *args):  # silencia el log por defecto
        log(f"{self.command} {self.path} -> {args[1] if len(args) > 1 else ''}")

    # ── preflight ────────────────────────────────────────────────
    def do_OPTIONS(self):  # noqa: N802
        self.send_response(204)
        self._cors(preflight=True)
        self.send_header("Content-Length", "0")
        self.end_headers()
        log(f"preflight Origin={self.headers.get('Origin')!r} "
            f"ReqHeaders={self.headers.get('Access-Control-Request-Headers')!r} "
            f"PNA={self.headers.get('Access-Control-Request-Private-Network')!r}")

    # ── GET (lista de modelos) ───────────────────────────────────
    def do_GET(self):  # noqa: N802
        if self.path.rstrip("/") in ("/v1/models", "/models"):
            try:
                req = urllib.request.Request(
                    f"{UPSTREAM}/v1/models",
                    headers={"Authorization": f"Bearer {API_KEY}",
                             "User-Agent": USER_AGENT},
                )
                with urllib.request.urlopen(req, timeout=30) as resp:
                    body = resp.read()
                body = filter_models(body)
                self.send_response(200)
                self._cors()
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            except Exception as exc:  # noqa: BLE001
                self._error(502, f"Error consultando modelos: {exc}")
                return
        if self.path.rstrip("/") in ("/health", "/"):
            body = b'{"status":"ok"}'
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self._error(404, "Ruta no encontrada")

    # ── POST (chat completions) ──────────────────────────────────
    def do_POST(self):  # noqa: N802
        # El SDK de OpenAI intenta /v1/responses primero. OpenCode Go no lo
        # ofrece para estos modelos: responder 404 hace que el cliente caiga
        # de inmediato a /chat/completions en vez de esperar un 400.
        if self.path.rstrip("/").endswith("/responses"):
            self._error(404, "Endpoints /responses no soportado; usa /v1/chat/completions")
            return
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        try:
            payload = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            self._error(400, "JSON inválido")
            return

        stream = bool(payload.get("stream"))
        model = payload.get("model", "?")
        log(f"→ modelo={model} stream={stream}")

        headers = {
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
            "Accept": "text/event-stream" if stream else "application/json",
            "User-Agent": USER_AGENT,
            "x-opencode-session": SESSION_ID,
        }
        req = urllib.request.Request(
            f"{UPSTREAM}/openai/v1/chat/completions",
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        )

        try:
            resp = urllib.request.urlopen(req, timeout=600)
        except urllib.error.HTTPError as exc:
            body = exc.read()
            log(f"← HTTP {exc.code}: {body[:300]!r}")
            self.send_response(exc.code)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        except Exception as exc:  # noqa: BLE001
            self._error(502, f"Error conectando con OpenCode Go: {exc}")
            return

        if not stream:
            try:
                body = resp.read()
            finally:
                resp.close()
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        # ── streaming SSE con chunked encoding ───────────────────
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Accel-Buffering", "no")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()
        try:
            while True:
                chunk = resp.read(512)
                if not chunk:
                    break
                self.wfile.write(f"{len(chunk):X}\r\n".encode() + chunk + b"\r\n")
                self.wfile.flush()
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            log("Cliente desconectado durante el stream")
        finally:
            resp.close()

    def _error(self, code: int, msg: str) -> None:
        body = json.dumps({"error": {"message": msg, "type": "proxy_error"}}).encode()
        self.send_response(code)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else int(os.environ.get("OPENCODE_GO_PORT", 4002))
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    log(f"✅ opencode-go-proxy escuchando en http://localhost:{port}/v1")
    log(f"   upstream: {UPSTREAM}/openai/v1 | sesión: {SESSION_ID}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        log("Detenido por el usuario")
    finally:
        srv.server_close()


if __name__ == "__main__":
    main()
