#!/usr/bin/env python3
"""Proxy OpenCode ↔ Ollama: no-streaming interno, inyección de tools.
Parchea bug #34892: @ai-sdk/openai-compatible serializa tools con function.name=undefined.
"""
import json, http.server, urllib.request, sys, time, uuid, threading, subprocess, re, os

OLLAMA_BASE = "http://localhost:11434"
NUM_CTX_DEFAULT = 16384
NUM_PREDICT_DEFAULT = 8192
VRAM_THRESHOLD = 75
CHECK_INTERVAL = 2

# ── Tools de OpenCode (fallback para sortear bug #34892) ──
FALLBACK_TOOLS = [
    {"type":"function","function":{"name":"read","description":"Read file contents.","parameters":{"type":"object","properties":{"filePath":{"type":"string","description":"Absolute path."}},"required":["filePath"]}}},
    {"type":"function","function":{"name":"write","description":"Create or overwrite a file.","parameters":{"type":"object","properties":{"filePath":{"type":"string"},"content":{"type":"string"}},"required":["filePath","content"]}}},
    {"type":"function","function":{"name":"edit","description":"Replace exact text in a file.","parameters":{"type":"object","properties":{"filePath":{"type":"string"},"oldString":{"type":"string"},"newString":{"type":"string"}},"required":["filePath","oldString","newString"]}}},
    {"type":"function","function":{"name":"bash","description":"Execute a shell command.","parameters":{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}}},
    {"type":"function","function":{"name":"grep","description":"Search file contents with regex.","parameters":{"type":"object","properties":{"pattern":{"type":"string"},"path":{"type":"string"},"include":{"type":"string"}},"required":["pattern"]}}},
    {"type":"function","function":{"name":"glob","description":"Find files by glob pattern.","parameters":{"type":"object","properties":{"pattern":{"type":"string"},"path":{"type":"string"}},"required":["pattern"]}}},
    {"type":"function","function":{"name":"list_files","description":"List a directory.","parameters":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}}},
    {"type":"function","function":{"name":"task","description":"Launch a sub-agent.","parameters":{"type":"object","properties":{"description":{"type":"string"},"prompt":{"type":"string"},"subagent_type":{"type":"string"}},"required":["description","prompt"]}}},
    {"type":"function","function":{"name":"todowrite","description":"Update task list.","parameters":{"type":"object","properties":{"todos":{"type":"array","items":{"type":"object","properties":{"content":{"type":"string"},"status":{"type":"string"},"priority":{"type":"string"}}}},"description":{"type":"string"}},"required":["todos"]}}},
    {"type":"function","function":{"name":"question","description":"Ask the user.","parameters":{"type":"object","properties":{"questions":{"type":"array","items":{"type":"object","properties":{"question":{"type":"string"},"header":{"type":"string"},"options":{"type":"array"}}}},"description":{"type":"string"}},"required":["questions"]}}},
    {"type":"function","function":{"name":"fetch","description":"Fetch a URL.","parameters":{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}}},
    {"type":"function","function":{"name":"websearch","description":"Search the web.","parameters":{"type":"object","properties":{"query":{"type":"string"},"numResults":{"type":"number"}},"required":["query"]}}},
    {"type":"function","function":{"name":"search_files","description":"Recursively search files.","parameters":{"type":"object","properties":{"pattern":{"type":"string"},"path":{"type":"string"}},"required":["pattern","path"]}}},
]

_tools_cache = list(FALLBACK_TOOLS)
_has_mcp_tools = False

def _try_discover_mcp():
    """Intenta descubrir herramientas de MCP servers (opcional)."""
    global _tools_cache, _has_mcp_tools
    discovered = []
    servers = [
        ("npx", "-y", "@modelcontextprotocol/server-filesystem", os.path.expanduser("~")),
    ]
    for cmd_parts in servers:
        try:
            proc = subprocess.Popen(
                list(cmd_parts), stdin=subprocess.PIPE,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            req = json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/list"})
            out, _ = proc.communicate(input=req, timeout=15)
            if out:
                result = json.loads(out)
                for tool in result.get("result",{}).get("tools",[]):
                    discovered.append({
                        "type":"function",
                        "function":{
                            "name": tool["name"],
                            "description": tool.get("description",""),
                            "parameters": tool.get("inputSchema",{"type":"object","properties":{}}),
                        }
                    })
        except Exception:
            pass

    if discovered:
        seen = {t["function"]["name"] for t in FALLBACK_TOOLS}
        for t in discovered:
            if t["function"]["name"] not in seen:
                _tools_cache.append(t)
                seen.add(t["function"]["name"])
        _has_mcp_tools = True
        print(f"[proxy] +{len(discovered)} MCP tools descubiertas", flush=True)

    print(f"[proxy] Tools cargadas: {len(_tools_cache)} ({len(FALLBACK_TOOLS)} fallback + {len(discovered)} MCP)", flush=True)

# Lanzar descubrimiento MCP en bg al importar
threading.Thread(target=_try_discover_mcp, daemon=True).start()

# ── Gestión VRAM ──
_resp_counter = {}
_counter_lock = threading.Lock()

def _get_vram_usage() -> float:
    try:
        r = subprocess.run(["nvidia-smi","--query-gpu=memory.used,memory.total","--format=csv,noheader,nounits"],
                          capture_output=True, text=True, timeout=5)
        if r.returncode != 0: return 0.0
        parts = r.stdout.strip().split(",")
        if len(parts) >= 2:
            used, total = float(parts[0].strip()), float(parts[1].strip())
            return (used/total)*100 if total > 0 else 0.0
    except: pass
    return 0.0

def _cleanup_model(model):
    try:
        req = urllib.request.Request(f"{OLLAMA_BASE}/api/generate",
            data=json.dumps({"model":model,"prompt":"","keep_alive":0}).encode(),
            headers={"Content-Type":"application/json"})
        with urllib.request.urlopen(req, timeout=10): pass
        print(f"[proxy] KV cache liberada para {model}", flush=True)
    except: pass

def _check_vram_and_clean(model):
    vram = _get_vram_usage()
    if vram <= 0: return
    if vram >= VRAM_THRESHOLD:
        print(f"[proxy] VRAM {vram:.0f}% > {VRAM_THRESHOLD}% -> limpiando {model}", flush=True)
        _cleanup_model(model)

# ── Normalizar mensajes ──
def _normalize_messages(messages):
    for m in messages:
        c = m.get("content")
        if isinstance(c, list):
            texts = []
            for part in c:
                if isinstance(part, dict):
                    t = part.get("type")
                    if t == "text": texts.append(part.get("text",""))
                    elif t == "tool_result": texts.append(str(part.get("content","")))
                    else: texts.append(str(part.get("text","") or ""))
                else: texts.append(str(part))
            m["content"] = "\n".join(texts) if texts else ""
        tc = m.get("tool_calls")
        if tc:
            for t in tc:
                func = t.get("function",{})
                args = func.get("arguments")
                if isinstance(args, str):
                    try: func["arguments"] = json.loads(args)
                    except: pass

# ── Proxy HTTP ──
class Proxy(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    def _json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type","application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())
    def _sse(self, data):
        self.wfile.write(f"data: {json.dumps(data, ensure_ascii=False)}\n\n".encode())
        self.wfile.flush()

    def do_GET(self):
        if self.path in ("/v1/models","/models"):
            req = urllib.request.Request(f"{OLLAMA_BASE}/api/tags")
            with urllib.request.urlopen(req) as r:
                data = json.load(r)
            models = {"object":"list","data":[]}
            for m in data.get("models",[]):
                models["data"].append({"id":m["name"],"object":"model"})
            self._json(models)
        else:
            self._json({"error":"not found"},404)

    def do_POST(self):
        path = self.path
        if "/v1/responses" in path: path = "/v1/chat/completions"
        if "/chat/completions" not in path:
            return self._json({"error":"not found"},404)
        self._handle()

    def _handle(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length",0)))
        body = json.loads(raw)
        model = body.get("model","")
        want_stream = body.get("stream",False)
        messages = body.get("messages",[])

        # ═══ WORKAROUND: Inyectar tools si OpenCode las envía rotas ═══
        raw_tools = body.get("tools")
        needs_injection = False
        reason = ""

        if "tools" not in body:
            needs_injection = True
            reason = "no envió tools"
        elif isinstance(raw_tools, list):
            if len(raw_tools) == 0:
                needs_injection = True
                reason = "envió tools vacías"
            else:
                # Detectar bug #34892: function.name undefined
                for t in raw_tools:
                    fn = t.get("function",{})
                    if not fn.get("name"):
                        needs_injection = True
                        reason = "tools con function.name vacío (bug #34892)"
                        break

        if needs_injection:
            body["tools"] = _tools_cache
            print(f"[proxy] ⚡ WORKAROUND ({reason}) -> inyectadas {len(_tools_cache)} tools", flush=True)

        _normalize_messages(messages)

        ctx = body.get("options",{}).get("num_ctx") or NUM_CTX_DEFAULT
        np = min(body.get("max_tokens", NUM_PREDICT_DEFAULT), 8192)

        ollama_body = {
            "model": model, "stream": False,
            "messages": messages, "keep_alive": "10m",
            "options": {"num_ctx": ctx, "num_predict": np},
        }
        final_tools = body.get("tools")
        if final_tools and isinstance(final_tools, list) and len(final_tools) > 0:
            ollama_body["tools"] = final_tools
            # NO forzamos reasoning_effort=none para no bloquear modelos con razonamiento

        print(f"[proxy] model={model} tools={'yes' if ollama_body.get('tools') else 'no'} stream={want_stream} msgs={len(messages)} ctx={ctx}", flush=True)

        try:
            req_str = json.dumps(ollama_body, ensure_ascii=False)
            req = urllib.request.Request(f"{OLLAMA_BASE}/api/chat",
                data=req_str.encode(), headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req, timeout=600) as r:
                result = json.load(r)
        except urllib.error.HTTPError as e:
            err = e.read().decode("utf-8",errors="replace")[:500]
            print(f"[proxy] HTTP {e.code}: {err}", flush=True, file=sys.stderr)
            fname = f"/tmp/proxy-error-{uuid.uuid4().hex[:8]}.json"
            with open(fname,"w") as f: f.write(req_str)
            print(f"[proxy] Body guardado en {fname}", flush=True)
            return self._json({"error":f"HTTP {e.code}: {err}"},502)
        except Exception as e:
            print(f"[proxy] Error: {e}", flush=True, file=sys.stderr)
            return self._json({"error":str(e)},500)

        msg = result.get("message",{})
        content = msg.get("content") or ""
        thinking = msg.get("thinking") or ""
        tc = msg.get("tool_calls")

        if not content and not tc and thinking:
            content = thinking
        if tc and thinking and not content:
            content = thinking

        tool_calls = None
        if tc:
            tool_calls = [
                {"id": t.get("id",f"call_{i}"), "type":"function",
                 "function":{"name":t["function"]["name"], "arguments":json.dumps(t["function"]["arguments"])}}
                for i,t in enumerate(tc)
            ]

        _check_vram_and_clean(model)
        with _counter_lock:
            _resp_counter[model] = _resp_counter.get(model,0) + 1
            if _resp_counter[model] >= CHECK_INTERVAL:
                _resp_counter[model] = 0
                threading.Thread(target=_check_vram_and_clean, args=(model,), daemon=True).start()

        if want_stream:
            self._send_stream(model, content, tool_calls)
        else:
            self._send_single(model, content, tool_calls)

    def _send_single(self, model, content, tool_calls):
        choice = {"index":0, "message":{"role":"assistant","content":content},
                  "finish_reason":"tool_calls" if tool_calls else "stop"}
        if tool_calls:
            choice["message"]["tool_calls"] = tool_calls
        self._json({"id":"chatcmpl-1","object":"chat.completion","choices":[choice],"model":model})

    def _send_stream(self, model, content, tool_calls):
        self.close_connection = True
        self.send_response(200)
        self.send_header("Content-Type","text/event-stream")
        self.send_header("Cache-Control","no-cache")
        self.end_headers()
        self.wfile.flush()
        try:
            if tool_calls:
                # Enviar thinking como contenido primero (si existe)
                if content:
                    for i in range(0, len(content), 40):
                        self._sse({"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{
                            "index":0,"delta":{"content":content[i:i+40]},"finish_reason":None}],"model":model})
                        time.sleep(0.003)
                    # Chunk separador antes de tool_calls
                    self._sse({"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{
                        "index":0,"delta":{"content":""},"finish_reason":None}],"model":model})
                for i, tc in enumerate(tool_calls):
                    # Chunk nombre
                    self._sse({"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{
                        "index":0, "delta":{"role":"assistant","content":null,"tool_calls":[{
                            "index":i, "id":tc.get("id",f"call_{i}"), "type":"function",
                            "function":{"name":tc["function"]["name"],"arguments":""}
                        }]}, "finish_reason":None
                    }],"model":model})
                    # Chunk argumentos
                    self._sse({"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{
                        "index":0, "delta":{"tool_calls":[{"index":i,"function":{"arguments":tc["function"]["arguments"]}}]},
                        "finish_reason":None
                    }],"model":model})
                # Final
                self._sse({"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{
                    "index":0,"delta":{},"finish_reason":"tool_calls"}],"model":model})
            else:
                content = content or ""
                for i in range(0, len(content), 20):
                    self._sse({"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{
                        "index":0,"delta":{"content":content[i:i+20]},"finish_reason":None}],"model":model})
                    time.sleep(0.005)
                self._sse({"id":"chatcmpl-1","object":"chat.completion.chunk","choices":[{
                    "index":0,"delta":{},"finish_reason":"stop"}],"model":model})
        except: pass
        try:
            self.wfile.write(b"data: [DONE]\n\n"); self.wfile.flush()
        except: pass
        try: self.connection.shutdown(__import__("socket").SHUT_WR)
        except: pass

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4000
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), Proxy)
    print(f"Proxy en http://127.0.0.1:{port}", flush=True)
    print(f"Tools: {len(_tools_cache)} ({'con MCP' if _has_mcp_tools else 'solo fallback'})", flush=True)
    server.serve_forever()
