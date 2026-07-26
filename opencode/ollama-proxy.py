#!/usr/bin/env python3
"""Proxy OpenCode ↔ Ollama: no-streaming interno, contexto grande, maneja thinking."""
import json, http.server, urllib.request, sys, time, uuid

OLLAMA_BASE = "http://localhost:11434"
NUM_CTX = 16384
NUM_PREDICT = 8192


class Proxy(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def _json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())

    def _sse(self, data):
        self.wfile.write(f"data: {json.dumps(data, ensure_ascii=False)}\n\n".encode())
        self.wfile.flush()

    def do_GET(self):
        if self.path in ("/v1/models", "/models"):
            req = urllib.request.Request(f"{OLLAMA_BASE}/api/tags")
            with urllib.request.urlopen(req) as r:
                data = json.load(r)
            models = {"object": "list", "data": []}
            for m in data.get("models", []):
                models["data"].append({"id": m["name"], "object": "model"})
            self._json(models)
        else:
            self._json({"error": "not found"}, 404)

    def do_POST(self):
        if "/chat/completions" not in self.path:
            return self._json({"error": "not found"}, 404)

        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        body = json.loads(raw)
        model = body.get("model", "")
        want_stream = body.get("stream", False)
        messages = body.get("messages", [])

        # Convertir arguments de tool_calls en mensajes (OpenAI los envia como string,
        # Ollama los espera como objeto)
        for m in messages:
            tc = m.get("tool_calls")
            if tc:
                for t in tc:
                    func = t.get("function", {})
                    args = func.get("arguments")
                    if isinstance(args, str):
                        try:
                            func["arguments"] = json.loads(args)
                        except json.JSONDecodeError:
                            pass

        # Siempre no-streaming con Ollama para robustez en tool_calls
        ollama_body = {
            "model": model,
            "stream": False,
            "messages": messages,
            "keep_alive": "30m",
            "options": {
                "num_ctx": NUM_CTX,
                "num_predict": body.get("max_tokens", NUM_PREDICT),
            },
        }
        if "tools" in body:
            ollama_body["tools"] = body["tools"]

        # Llamar a Ollama
        print(f"[proxy] model={model} tools={'yes' if 'tools' in body else 'no'} stream={want_stream} msgs={len(messages)}", flush=True)
        try:
            req_body = json.dumps(ollama_body, ensure_ascii=False)
            req = urllib.request.Request(
                f"{OLLAMA_BASE}/api/chat",
                data=req_body.encode(),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=600) as r:
                result = json.load(r)
        except urllib.error.HTTPError as e:
            err_text = e.read().decode("utf-8", errors="replace")[:500]
            print(f"[proxy] HTTP {e.code}: {err_text}", flush=True, file=sys.stderr)
            print(f"[proxy] body({len(req_body)}b): {req_body[:2000]}", flush=True, file=sys.stderr)
            # Guardar body para inspeccion
            fname = f"/tmp/proxy-error-{uuid.uuid4().hex[:8]}.json"
            with open(fname, "w") as f:
                f.write(req_body)
            print(f"[proxy] Body guardado en {fname}", flush=True, file=sys.stderr)
            return self._json({"error": f"HTTP {e.code}: {err_text}"}, 502)
        except Exception as e:
            print(f"[proxy] Error: {e}", flush=True, file=sys.stderr)
            return self._json({"error": str(e)}, 500)

        msg = result.get("message", {})
        content = msg.get("content") or ""
        thinking = msg.get("thinking") or ""
        tc = msg.get("tool_calls")

        # Modelos de razonamiento: usar thinking como content si no hay
        if not content and thinking:
            content = thinking

        # Convertir tool_calls a formato OpenAI
        tool_calls = None
        if tc:
            tool_calls = [
                {
                    "id": t.get("id", f"call_{i}"),
                    "type": "function",
                    "function": {
                        "name": t["function"]["name"],
                        "arguments": json.dumps(t["function"]["arguments"]),
                    },
                }
                for i, t in enumerate(tc)
            ]

        if want_stream:
            self._send_stream(model, content, tool_calls)
        else:
            self._send_single(model, content, tool_calls)

    def _send_single(self, model, content, tool_calls):
        choice = {
            "index": 0,
            "message": {"role": "assistant", "content": content},
            "finish_reason": "tool_calls" if tool_calls else "stop",
        }
        if tool_calls:
            choice["message"]["tool_calls"] = tool_calls
        self._json({
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "choices": [choice],
            "model": model,
        })

    def _send_stream(self, model, content, tool_calls):
        self.close_connection = True
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.flush()

        try:
            if tool_calls:
                # Enviar tool_calls como un solo chunk
                delta = {"role": "assistant", "tool_calls": tool_calls}
                chunk = {
                    "id": "chatcmpl-1",
                    "object": "chat.completion.chunk",
                    "choices": [{"index": 0, "delta": delta, "finish_reason": "tool_calls"}],
                    "model": model,
                }
                self._sse(chunk)
            else:
                content = content or ""
                # Enviar en chunks de 20 caracteres (para feedback progresivo)
                chunk_size = 20
                for i in range(0, len(content), chunk_size):
                    delta = {"content": content[i:i+chunk_size]}
                    chunk = {
                        "id": "chatcmpl-1",
                        "object": "chat.completion.chunk",
                        "choices": [{"index": 0, "delta": delta, "finish_reason": None}],
                        "model": model,
                    }
                    self._sse(chunk)
                    time.sleep(0.005)
                # Chunk final
                chunk = {
                    "id": "chatcmpl-1",
                    "object": "chat.completion.chunk",
                    "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
                    "model": model,
                }
                self._sse(chunk)
        except Exception:
            pass

        try:
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
        except Exception:
            pass

        try:
            self.connection.shutdown(__import__("socket").SHUT_WR)
        except Exception:
            pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4000
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), Proxy)
    print(f"Proxy en http://127.0.0.1:{port}", flush=True)
    server.serve_forever()
