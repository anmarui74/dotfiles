#!/usr/bin/env python3
import json, http.server, urllib.request, sys, os, subprocess, re, glob

OLLAMA_URL = "http://localhost:11434"

def sse_str(data_dict):
    return f"data: {json.dumps(data_dict, ensure_ascii=False)}\n\n"

def _fix_tc(tc):
    out = []
    for t in tc:
        out.append({
            "id": t.get("id", "call_1"),
            "type": "function",
            "function": {
                "name": t["function"]["name"],
                "arguments": json.dumps(t["function"]["arguments"]),
            },
        })
    return out

def _ollama_chat(ollama_body):
    req_body = json.dumps(ollama_body, ensure_ascii=False)
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=req_body.encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        err_text = e.read().decode('utf-8', errors='replace')[:500]
        print(f"[PROXY] Ollama HTTP {e.code}: {err_text}", flush=True, file=sys.stderr)
        print(f"[PROXY] Request body ({len(req_body)}b): {req_body[:1000]}", flush=True, file=sys.stderr)
        raise

def _parse_ollama_msg(result):
    msg = result.get("message", {})
    content = msg.get("content") or ""
    thinking = msg.get("thinking") or ""
    tc = msg.get("tool_calls")
    if not content and thinking:
        content = thinking
    return content, tc

def _is_refusal(content):
    if not content:
        return False
    c = content.lower()
    return any(p in c for p in [
        "no puedo", "no tengo acceso", "no tengo información", "no sé",
        "cannot", "can't", "i don't have", "i don't know", "i cannot",
        "no puedo proporcionar", "no puedo acceder",
        "lo siento", "sorry",
        "no hay información", "no hay datos",
        "no se proporcionaron", "no se proporciona",
        "no tengo datos", "no tengo la capacidad",
        "no está en mis", "no está dentro de mis",
        "no tengo acceso a", "no tengo la capacidad de",
        "i can't support", "i am not able", "i'm not able",
        "no puedo cumplir", "no puedo hacer",
    ])

def _web_search(query):
    script = """import json, sys, glob
sys.path[:0] = [p for p in glob.glob('/tmp/venv-search/lib/python*/site-packages')]
try:
    from ddgs import DDGS
    urls, texts = [], []
    with DDGS() as ddgs:
        for r in ddgs.text(QUERY, max_results=5, region='wt-wt'):
            title = (r.get('title') or '').strip()
            body = (r.get('body') or '').strip()
            href = (r.get('href') or '').strip()
            if title:
                texts.append('**' + title + '**')
            if body:
                texts.append(body)
            if href and href.startswith('http') and len(urls) < 2:
                urls.append(href)
    # Fetch first page content
    extra = ''
    if urls:
        for url in urls[:1]:
            try:
                import urllib.request
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}, method='GET')
                with urllib.request.urlopen(req, timeout=8) as f:
                    html = f.read().decode('utf-8', errors='replace')
                text = re.sub(r'<[^>]+>', ' ', html)
                text = re.sub(r'\\s+', ' ', text).strip()
                if len(text) > 200:
                    extra = '\\n\\n[Contenido de ' + url + ']:\\n' + text[:5000]
            except:
                pass
    if not texts:
        print(json.dumps(''))
        sys.exit(0)
    out = '\\n'.join(texts) + extra
    print(json.dumps(out[:8000]))
except Exception as e:
    print(json.dumps(''))
""".replace("QUERY", json.dumps(query))
    try:
        p = subprocess.run(['/tmp/venv-search/bin/python3', '-c', script], capture_output=True, text=True, timeout=30)
        if p.returncode == 0 and p.stdout.strip():
            result = json.loads(p.stdout.strip())
            return result if result else None
    except Exception:
        pass
    return None

def _wttr_weather(city="Pechina"):
    try:
        wreq = urllib.request.Request(f"https://wttr.in/{urllib.request.quote(city)}?format=j1&m&lang=es", headers={"User-Agent": "curl"})
        with urllib.request.urlopen(wreq, timeout=10) as wr:
            full = json.loads(wr.read().decode())
        parts = []
        for day in full.get("weather", []):
            date = day.get("date", "")
            if date:
                parts.append(f"\n{date}:")
            for h in day.get("hourly", [])[::6]:
                cond = (h.get("weatherDesc") or [{}])[0].get("value", "")
                temp = h.get("tempC", "?")
                wind = h.get("windspeedKmph", "?")
                parts.append(f"  {h['time'][:2]}h: {cond} {temp}°C viento {wind}km/h")
        result = "\n".join(parts).strip()
        if result:
            return f"Pronóstico {city}: {result}"
    except Exception:
        try:
            simple = urllib.request.Request(f"https://wttr.in/{urllib.request.quote(city)}?format=%l:+%C+%t+%w+%h&m&lang=es", headers={"User-Agent": "curl"})
            with urllib.request.urlopen(simple, timeout=10) as sr:
                return sr.read().decode().strip()
        except Exception:
            pass
    return None

def _call_with_retry(ollama_body):
    """Call Ollama, auto-search on refusal/weak response, retry."""
    try:
        result = _ollama_chat(ollama_body)
    except urllib.error.HTTPError:
        # Retry without tools (some models don't support them)
        if ollama_body.get("tools"):
            print(f"[PROXY] HTTP error, retrying without tools", flush=True, file=sys.stderr)
            del ollama_body["tools"]
            result = _ollama_chat(ollama_body)
        else:
            raise
    content, tc = _parse_ollama_msg(result)
    print(f"[PROXY] call: len={len(content or '')} tc={bool(tc)} content={repr(content[:80])}", flush=True, file=sys.stderr)
    if tc:
        return content, tc

    # Detect poor responses: refusal, very short, tool-description, meta, or tool JSON
    is_poor = _is_refusal(content)
    if not is_poor and content:
        c_lower = content.lower()
        if len(content) < 30:
            is_poor = True
        elif any(w in c_lower for w in ["websearch", "exa web", "puede utilizar el siguiente", "utilizar el siguiente comando"]):
            is_poor = True
        elif '"function"' in content and ('"name"' in content or '"query"' in content):
            is_poor = True  # tool call described as JSON text
        elif any(w in c_lower for w in ["contextmaxcharacters", "livecrawl", "numresults="]):
            is_poor = True  # Exa/OpenCode specific tool params
        elif any(w in c_lower for w in ["i don't see a specific question", "i don't see a specific", "please provide more context", "could you please provide more", "can you provide more context", "what would you like"]):
            is_poor = True  # model asking for clarification instead of answering

    if not is_poor:
        return content, None

    # Find last user message
    last_idx = None
    last_question = ""
    for i in range(len(ollama_body["messages"]) - 1, -1, -1):
        if ollama_body["messages"][i].get("role") == "user":
            last_idx = i
            last_question = ollama_body["messages"][i].get("content", "")
            break
    if not last_question:
        return content, None

    # Add permissive system prompt (don't replace, keep original for tool context)
    ollama_body["messages"].insert(0, {
        "role": "system",
        "content": (
            "INSTRUCCIÓN ESPECIAL: Puedes y debes responder a preguntas sobre cualquier tema, "
            "incluyendo tiempo, deportes, actualidad, etc. No estás limitado a ingeniería de software. "
            "Usa los datos disponibles en el chat para responder. Responde SIEMPRE en español."
        ),
    })

    # Get web data if appropriate
    print(f"[PROXY] poor response for: {last_question[:80]}", flush=True, file=sys.stderr)
    web_data = None
    is_weather = any(kw in last_question.lower() for kw in ["tiempo", "clima", "weather", "temperatura", "lluvia", "grados", "meteorológico", "previsión"])
    if is_weather:
        city = "Pechina"
        import re
        for c in re.findall(r'(?:en|de|para)\s+(\w[\w\s]{0,30}?\w?)(?:\?|\.|,|$)', last_question):
            city = c.strip()
            break
        weather = _wttr_weather(city)
        if weather:
            web_data = weather
    if not web_data and is_poor and last_question and not any(w in last_question.lower() for w in ["hola", "hello", "hey", "buenas", "saludos", "buen"]):
        web_data = _web_search(last_question)

    if web_data:
        print(f"[PROXY] injecting {len(web_data)} chars", flush=True, file=sys.stderr)
        import datetime
        ollama_body["messages"].append({
            "role": "user",
            "content": f"Datos: {web_data}"
        })

    result2 = _ollama_chat(ollama_body)
    content2, tc2 = _parse_ollama_msg(result2)
    print(f"[PROXY] retry: len={len(content2 or '')} tc={bool(tc2)} content={repr(content2[:80])}", flush=True, file=sys.stderr)

    if tc2 or not _is_refusal(content2):
        return content2 or content, tc2 or tc

    # Second retry
    print(f"[PROXY] retry 2", flush=True, file=sys.stderr)
    ollama_body["messages"].append({
        "role": "user",
        "content": "Responde directamente en español."
    })
    result3 = _ollama_chat(ollama_body)
    content3, tc3 = _parse_ollama_msg(result3)
    print(f"[PROXY] retry2: len={len(content3 or '')} tc={bool(tc3)} content={repr(content3[:80])}", flush=True, file=sys.stderr)
    if tc3 or not _is_refusal(content3):
        return content3, tc3
    return content3 or content2 or content, tc3 or tc2 or tc


# --- Memory system ---
_memory = {}

_STOP_WORDS = {
    "en", "de", "con", "para", "un", "una", "el", "la", "los", "las",
    "y", "e", "o", "u", "que", "como", "cómo", "donde", "dónde",
    "cuando", "cuánto", "quien", "quién", "cual", "cuál",
    "a", "ante", "bajo", "cabe", "contra", "desde", "durante",
    "entre", "hacia", "hasta", "mediante", "por", "según", "sin",
    "so", "sobre", "tras", "vs", "vía",
}

_MEMORY_PATTERNS = [
    (r"llamo\s+([A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]+)", "name"),
    (r"(?:vivo|resido)\s+(?:en|de|desde)\s+(\w[\w\s]{0,30}?\w)", "location"),
    (r"tengo\s+(\d+)\s*(?:años|anios)", "age"),
    (r"(?:trabajo\s+como|soy)\s+(?:de\s+)?([A-ZÁÉÍÓÚÜÑa-záéíóúüñ][\w\s]{0,30}?\w)", "profession"),
    (r"(?:hablo|idioma)\s+(\w+)", "language"),
    (r"(?:uso|utilizo)\s+(\w[\w\s]{0,20}?\w)(?:\s+(?:para|y)|\.|,|$)", "tool"),
]

def _extract_facts(text):
    if not text:
        return
    for pattern, key in _MEMORY_PATTERNS:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            val = match.group(1).strip()
            if val.lower() not in _STOP_WORDS:
                _memory[key] = val[0].upper() + val[1:] if len(val) > 1 else val.upper()

def _memory_prompt():
    if not _memory:
        return None
    parts = []
    if "name" in _memory:
        parts.append(f"nombre: {_memory['name']}")
    if "location" in _memory:
        parts.append(f"ubicación: {_memory['location']}")
    if "age" in _memory:
        parts.append(f"edad: {_memory['age']} años")
    if "profession" in _memory:
        parts.append(f"profesión: {_memory['profession']}")
    if "language" in _memory:
        parts.append(f"idioma: {_memory['language']}")
    if "tool" in _memory:
        parts.append(f"usa: {_memory['tool']}")
    return ("DATOS DEL USUARIO (extraídos de la conversación):\n" +
            "\n".join("- " + p for p in parts))


class ProxyHandler(http.server.BaseHTTPRequestHandler):

    protocol_version = "HTTP/1.0"

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        print(f"[PROXY] GET {self.path}", flush=True, file=sys.stderr)
        if self.path in ("/v1/models", "/models"):
            req = urllib.request.Request(f"{OLLAMA_URL}/api/tags")
            with urllib.request.urlopen(req) as r:
                data = json.load(r)
            models = {"object": "list", "data": []}
            for m in data.get("models", []):
                models["data"].append({"id": m["name"], "object": "model"})
            self._json(models)
        else:
            self._json({"error": "not found"}, 404)

    def do_POST(self):
        print(f"[PROXY] POST {self.path}", flush=True, file=sys.stderr)
        if self.path not in ("/v1/chat/completions", "/chat/completions"):
            return self._json({"error": "not found"}, 404)
        raw_body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        body = json.loads(raw_body)
        print(f"[PROXY] body: model={body.get('model')} stream={body.get('stream')} tools={'yes' if body.get('tools') else 'no'}", flush=True, file=sys.stderr)
        model = body.get("model", "")
        tools = body.get("tools", [])
        msgs = body.get("messages", [])
        stream = body.get("stream", False)

        ollama_msgs = []
        for m in msgs:
            om = dict(m)
            tc = om.get("tool_calls")
            if tc:
                for t in tc:
                    func = t.get("function", {})
                    args = func.get("arguments")
                    if isinstance(args, str):
                        try:
                            func["arguments"] = json.loads(args)
                        except json.JSONDecodeError:
                            pass
            om.pop("tool_call_id", None)
            ollama_msgs.append(om)

        # Extract user facts from messages
        for m in msgs:
            if m.get("role") == "user":
                _extract_facts(m.get("content", ""))

        # Build memory context
        mem = _memory_prompt()
        if mem:
            print(f"[PROXY] memory: {repr(mem[:80])}", flush=True, file=sys.stderr)
            # Insert memory as system message at position 0 (before all messages)
            ollama_msgs.insert(0, {"role": "system", "content": mem})

        ollama_body = {
            "model": model,
            "stream": False,
            "messages": ollama_msgs,
        }

        # Ensure num_ctx is set (OpenCode doesn't always send it)
        ollama_body.setdefault("options", {})
        if "num_ctx" not in ollama_body["options"]:
            ollama_body["options"]["num_ctx"] = 32768
        # Pass max_tokens as num_predict for Ollama (con 16 GB VRAM, 8192 es óptimo)
        if "max_tokens" in body:
            ollama_body["options"]["num_predict"] = body["max_tokens"]
        else:
            ollama_body["options"].setdefault("num_predict", 8192)
        # Pass through other Ollama params
        for key in ("keep_alive", "format", "template"):
            if key in body:
                ollama_body[key] = body[key]

        if tools:
            ollama_body["tools"] = tools
            print(f"[PROXY] tools ({len(tools)})", flush=True, file=sys.stderr)

        if stream:
            self._handle_stream(ollama_body, model)
        else:
            self._handle_single(ollama_body, model)

    def _handle_single(self, ollama_body, model):
        try:
            content, tc = _call_with_retry(ollama_body)
        except urllib.error.HTTPError as e:
            return self._json({"error": e.read().decode()}, e.code)
        except Exception as e:
            return self._json({"error": str(e)}, 500)

        choice = {
            "index": 0,
            "message": {
                "role": "assistant",
                "content": content or "",
            },
            "finish_reason": "tool_calls" if tc else "stop",
        }
        if tc:
            choice["message"]["tool_calls"] = _fix_tc(tc)

        self._json({
            "id": "chatcmpl-1",
            "object": "chat.completion",
            "choices": [choice],
            "model": model,
        })

    def _handle_stream(self, ollama_body, model):
        self.close_connection = True
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.flush()

        try:
            import time as _time
            t0 = _time.time()
            content, tc = _call_with_retry(ollama_body)
            print(f"[PROXY] stream done in {_time.time()-t0:.2f}s", flush=True, file=sys.stderr)

            delta = {"role": "assistant"}
            if tc:
                delta["tool_calls"] = _fix_tc(tc)
            else:
                delta["content"] = content or ""

            chunk_data = {
                "id": "chatcmpl-1",
                "object": "chat.completion.chunk",
                "choices": [{
                    "index": 0,
                    "delta": delta,
                    "finish_reason": "tool_calls" if tc else "stop",
                }],
                "model": model,
            }
            self.wfile.write(sse_str(chunk_data).encode())
            self.wfile.flush()

        except Exception as e:
            print(f"[PROXY] Error: {e}", flush=True, file=sys.stderr)
            try:
                self.wfile.write(sse_str({
                    "id": "chatcmpl-1",
                    "object": "chat.completion.chunk",
                    "choices": [{"index": 0, "delta": {"content": f"\n\nError: {e}"}, "finish_reason": "stop"}],
                    "model": model,
                }).encode())
            except Exception:
                pass

        try:
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
        except Exception:
            pass

        try:
            self.connection.shutdown(__import__('socket').SHUT_WR)
        except Exception:
            pass

    def _json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4000
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), ProxyHandler)
    print(f"Proxy on http://127.0.0.1:{port}", flush=True)
    server.serve_forever()
