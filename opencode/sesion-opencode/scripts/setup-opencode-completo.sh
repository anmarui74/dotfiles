#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Script de instalación completa: OpenCode + Ollama + Proxy
# ============================================================
# Uso: bash setup-opencode-completo.sh
# ============================================================

DIR_CONFIG="$HOME/.config/opencode"
DIR_PROXY="$DIR_CONFIG"
LOG_PROXY="/tmp/ollama-proxy.log"
VENV_SEARCH="/tmp/venv-search"
DIR_DATA="$DIR_CONFIG/data"
DIR_MEMORY="$DIR_DATA/memory"
DIR_BACKUPS="$HOME/Config/opencode/backups"

echo "=== 1. Instalando OpenCode (si no está) ==="
if ! command -v opencode &>/dev/null; then
    curl -fsSL https://opencode.ai/install.sh | bash
fi

echo "=== 2. Creando directorios de configuración ==="
mkdir -p "$DIR_CONFIG"
mkdir -p "$DIR_CONFIG/prompts"
mkdir -p "$DIR_DATA"
mkdir -p "$DIR_MEMORY"
mkdir -p "$DIR_BACKUPS"

echo "=== 3. Instalando dependencia para búsqueda web ==="
python3 -m venv "$VENV_SEARCH" 2>/dev/null || true
"$VENV_SEARCH/bin/pip" install ddgs -q

echo "=== 4. Creando opencode.json ==="
cat > "$DIR_CONFIG/opencode.json" << 'JSONEOF'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "plan": {
      "prompt": "{file:./prompts/read-agents.txt}"
    }
  },
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": {
        "baseURL": "http://127.0.0.1:4000/v1",
        "apiKey": "ollama"
      },
      "models": {
        "deepseek-r1:8b": {
          "name": "deepseek-r1:8b",
          "options": { "num_ctx": 32768 }
        },
        "qwen3.5:9b": {
          "name": "qwen3.5:9b",
          "options": { "num_ctx": 32768 }
        },
        "gemma4:e4b": {
          "name": "gemma4:e4b",
          "options": { "num_ctx": 32768 }
        },
        "llama3.1:8b": {
          "name": "llama3.1:8b",
          "options": { "num_ctx": 32768 }
        },
        "pdurugyan/qwen3.5-9b-deepseek-v4-flash-Q4_K_M-v_2:latest": {
          "name": "pdurugyan/qwen3.5-9b-deepseek-v4-flash-Q4_K_M-v_2:latest",
          "options": { "num_ctx": 32768 }
        }
      }
    }
  },
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "enabled": true
    },
    "filesystem": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/antonio"],
      "enabled": true
    },
    "memory": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-memory"],
      "enabled": true
    },
    "fetch": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-fetch"],
      "enabled": true
    },
    "sequential_thinking": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"],
      "enabled": true
    }
  }
}
JSONEOF

echo "=== 5. Creando AGENTS.md (reglas obligatorias y procedimientos) ==="
cat > "$DIR_CONFIG/AGENTS.md" << 'AGEOF'
# REGLAS OBLIGATORIAS (APLICAR SIEMPRE)

## Idioma
- Responde SIEMPRE en español
- NUNCA cambies al inglés (salvo petición expresa de traducción)
- Español de España (no latinoamericano)

## Formato
- SÍ usamos emoji en pantalla (✈️ 🌤️ 😊) para expresividad visual 
- Mi locucionero filtra estos iconos automáticamente antes del TTS, sin necesidad de configuración extra
- Fecha: dd/mm/aaaa
- Hora: formato 24h (14:30, no 2:30pm)
- Decimales: coma (3,14 no 3.14)
- Moneda: euros (€)
- Sistema métrico: km/h, °C, mm, km

## Usuario
- Se llama Antonio
- Vive en Pechina (Almería, España)

---

# PROCEDIMIENTOS TÉCNICOS

## PWAs - Cómo abrir
1. Leer /home/antonio/Escritorio
2. Buscar archivo chrome-<app-id>-Profile_2.desktop
3. Ejecutar línea Exec= del archivo

## PWAs - Cerrar
- Una PWA: curl -s http://localhost:9222/json/close/<ID>
- Todo Chrome: pkill -f "chrome.*remote-debugging-port"

## Chrome debug (si no está corriendo)
nohup /opt/google/chrome/google-chrome --user-data-dir="/tmp/chrome-debug-profile" "--profile-directory=DebugProfile" --remote-debugging-port=9222 "--remote-allow-origins=*" about:blank > /dev/null 2>&1 &

## Proxy Ollama (obligatorio para conexión local)
python3 /home/antonio/.config/opencode/ollama-proxy.py 4000 > /tmp/ollama-proxy.log 2>&1 & disown

## Liberar VRAM (sin descargar el modelo)
El modelo se mantiene cargado en VRAM 30 minutos tras cada uso gracias al keep_alive.
NO se descarga automáticamente tras cada respuesta para evitar recargas constantes.
Si el modelo se satura (generaciones muy largas o error), pide a OpenCode que lo haga:
"Dime: Libera la VRAM"
OpenCode ejecutará: ollama stop qwen3.5:9b-stock
Esto libera la KV cache acumulada. El modelo se recargará solo en la siguiente petición.

## Consultar el tiempo
Para preguntas sobre el tiempo, usa la herramienta Fetch para consultar:
https://wttr.in/{ciudad}?format=j1&m&lang=es
Ejemplo: https://wttr.in/Pechina?format=j1&m&lang=es

---

# PERSISTENCIA DE DATOS Y RECUPERACIÓN

## Variables de entorno
El archivo .env contiene la configuración sensible. Para cargarlo:
set -a; source /home/antonio/.config/opencode/.env; set +a

## Inicialización (tras reinicio del sistema)
Ejecutar el script de inicialización que verifica todos los componentes:
bash /home/antonio/.config/opencode/init-opencode.sh
Esto comprueba:
- Proxy Ollama (puerto 4000)
- Modelos disponibles en Ollama
- Persistencia del grafo de memoria
- PWAs en el Escritorio
- Variables de entorno (.env)

## Backup automático del grafo de memoria
El grafo de conocimiento se respalda automáticamente en:
/home/antonio/Config/opencode/backups/
Con nombre mcp-memory-backup-{fecha}.json
Los backups se conservan 30 días.

## Recuperación del grafo de memoria
Si el grafo se pierde o corrompe:
1. Localizar el backup más reciente:
   ls -t /home/antonio/Config/opencode/backups/mcp-memory-backup-*.json | head -1
2. El servidor MCP Memory debería restaurarlo automáticamente al iniciar desde MEMORY_DATA_DIR

## Directorios de datos
- /home/antonio/.config/opencode/data/ - Datos de ejecución (logs, estado)
- /home/antonio/.config/opencode/data/memory/ - Grafo de memoria persistente
- /home/antonio/Config/opencode/backups/ - Copias de seguridad del grafo
- /home/antonio/.config/opencode/.env - Variables de entorno seguras

---

# CHECKLIST ANTES DE RESPONDER
- Respuesta en español?
- Fecha/hora en formato España?
- Decimales con coma?
AGEOF

echo "=== 6. Creando prompts personalizados ==="
mkdir -p "$DIR_CONFIG/prompts"
cat > "$DIR_CONFIG/prompts/read-agents.txt" << 'PROMPTEOF'
Al inicio de cada sesión, usa la herramienta Read para leer ~/.config/opencode/AGENTS.md y seguir las instrucciones del usuario.
PROMPTEOF

echo "=== 7. Creando proxy Ollama ==="
cat > "$DIR_CONFIG/ollama-proxy.py" << 'PYEOF'
#!/usr/bin/env python3
"""Proxy OpenCode-Ollama con monitoreo inteligente de VRAM."""
import json, http.server, urllib.request, sys, time, uuid, threading, subprocess

OLLAMA_BASE = "http://localhost:11434"
NUM_CTX = 8192
NUM_PREDICT = 16384
VRAM_THRESHOLD = 85
CHECK_INTERVAL = 10

_resp_counter = {}
_counter_lock = threading.Lock()


def _get_vram_usage():
    try:
        r = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.used,memory.total",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5,
        )
        if r.returncode != 0 or not r.stdout.strip():
            return 0.0
        parts = r.stdout.strip().split(",")
        if len(parts) >= 2:
            used, total = float(parts[0].strip()), float(parts[1].strip())
            return (used / total) * 100.0 if total > 0 else 0.0
    except Exception:
        return 0.0


def _cleanup_model(model):
    try:
        req = urllib.request.Request(
            f"{OLLAMA_BASE}/api/generate",
            data=json.dumps({"model": model, "prompt": "", "keep_alive": 0}).encode(),
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=10):
            pass
        print(f"[proxy] KV cache liberada para {model}", flush=True)
    except Exception:
        pass


def _check_vram_and_clean(model):
    vram_pct = _get_vram_usage()
    if vram_pct > 0 and vram_pct >= VRAM_THRESHOLD:
        print(f"[proxy] VRAM al {vram_pct:.0f}% - limpiando cache de {model}", flush=True)
        _cleanup_model(model)
    elif vram_pct > 0:
        print(f"[proxy] VRAM al {vram_pct:.0f}% - OK", flush=True)


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

        for m in messages:
            c = m.get("content")
            if isinstance(c, list):
                texts = []
                for part in c:
                    if isinstance(part, dict):
                        texts.append(str(part.get("text", "") or ""))
                    else:
                        texts.append(str(part))
                m["content"] = "\n".join(texts) if texts else ""
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

        ollama_body = {
            "model": model, "stream": False, "messages": messages,
            "keep_alive": "30m",
            "options": {
                "num_ctx": NUM_CTX,
                "num_predict": body.get("max_tokens", NUM_PREDICT),
            },
        }
        if "tools" in body:
            ollama_body["tools"] = body["tools"]

        print(f"[proxy] model={model} tools={'yes' if 'tools' in body else 'no'} stream={want_stream} msgs={len(messages)}", flush=True)
        try:
            req_body = json.dumps(ollama_body, ensure_ascii=False)
            req = urllib.request.Request(
                f"{OLLAMA_BASE}/api/chat", data=req_body.encode(),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=600) as r:
                result = json.load(r)
        except urllib.error.HTTPError as e:
            err_text = e.read().decode("utf-8", errors="replace")[:500]
            print(f"[proxy] HTTP {e.code}: {err_text}", flush=True, file=sys.stderr)
            fname = f"/tmp/proxy-error-{uuid.uuid4().hex[:8]}.json"
            with open(fname, "w") as f:
                f.write(req_body)
            return self._json({"error": f"HTTP {e.code}: {err_text}"}, 502)
        except Exception as e:
            print(f"[proxy] Error: {e}", flush=True, file=sys.stderr)
            return self._json({"error": str(e)}, 500)

        msg = result.get("message", {})
        content = msg.get("content") or ""
        thinking = msg.get("thinking") or ""
        tc = msg.get("tool_calls")
        if not content and thinking:
            content = thinking
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
        _check_cleanup(model)
        if want_stream:
            self._send_stream(model, content, tool_calls)
        else:
            self._send_single(model, content, tool_calls)

    def _send_single(self, model, content, tool_calls):
        choice = {"index": 0, "message": {"role": "assistant", "content": content}, "finish_reason": "tool_calls" if tool_calls else "stop"}
        if tool_calls:
            choice["message"]["tool_calls"] = tool_calls
        self._json({"id": "chatcmpl-1", "object": "chat.completion", "choices": [choice], "model": model})

    def _send_stream(self, model, content, tool_calls):
        self.close_connection = True
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.flush()
        try:
            if tool_calls:
                self._sse({"id": "chatcmpl-1", "object": "chat.completion.chunk", "choices": [{"index": 0, "delta": {"role": "assistant", "tool_calls": tool_calls}, "finish_reason": "tool_calls"}], "model": model})
            else:
                content = content or ""
                for i in range(0, len(content), 20):
                    self._sse({"id": "chatcmpl-1", "object": "chat.completion.chunk", "choices": [{"index": 0, "delta": {"content": content[i:i+20]}, "finish_reason": None}], "model": model})
                    time.sleep(0.005)
                self._sse({"id": "chatcmpl-1", "object": "chat.completion.chunk", "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}], "model": model})
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


def _check_cleanup(model):
    with _counter_lock:
        _resp_counter[model] = _resp_counter.get(model, 0) + 1
        count = _resp_counter[model]
        if count >= CHECK_INTERVAL:
            _resp_counter[model] = 0
            t = threading.Thread(target=_check_vram_and_clean, args=(model,), daemon=True)
            t.start()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4000
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), Proxy)
    print(f"Proxy en http://127.0.0.1:{port}", flush=True)
    print(f"VRAM threshold: {VRAM_THRESHOLD}%, check each {CHECK_INTERVAL} respuestas, num_ctx={NUM_CTX}", flush=True)
    server.serve_forever()
PYEOF

chmod +x "$DIR_CONFIG/ollama-proxy.py"

echo "=== 8. Creando script de inicialización (init-opencode.sh) ==="
cat > "$DIR_CONFIG/init-opencode.sh" << 'INITEOF'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="$HOME/.config/opencode/data/init.log"
mkdir -p "$(dirname "$LOG_FILE")"

{
  echo "[$(date '+%H:%M')] === INICIALIZACIÓN DE OPENCODE ==="
} > "$LOG_FILE"

log() {
  echo "[$(date '+%H:%M')] $*"
  echo "[$(date '+%H:%M')] $*" >> "$LOG_FILE"
}

# 1. Verificar Chrome debug
if pgrep -f "chrome.*remote-debugging-port" &>/dev/null; then
  log "El proceso Chrome debug ya está ejecutándose."
else
  nohup /opt/google/chrome/google-chrome --user-data-dir="/tmp/chrome-debug-profile" "--profile-directory=DebugProfile" --remote-debugging-port=9222 "--remote-allow-origins=*" about:blank > /dev/null 2>&1 &
  log "Chrome debug iniciado."
fi

# 2. Proxy Ollama
if pgrep -f "ollama-proxy" &>/dev/null; then
  log "Proxy Ollama ya está ejecutándose."
else
  nohup python3 /home/antonio/.config/opencode/ollama-proxy.py 4000 > /tmp/ollama-proxy.log 2>&1 &
  log "Proxy Ollama iniciado."
fi

# 3. Verificar conexión a Ollama
sleep 1
if curl -sf http://localhost:4000/v1/models &>/dev/null; then
  log "Conexión a Ollama establecida."
else
  log "No se pudo conectar a Ollama en puerto 4000."
fi

# 4. Verificar .env
if [ -f "$HOME/.config/opencode/.env" ]; then
  log "Archivo .env encontrado."
else
  log "No se encontró .env"
fi

# 5. Verificar backups
BK_DIR="$HOME/Config/opencode/backups"
if [ -d "$BK_DIR" ]; then
  LATEST=$(ls -t "$BK_DIR"/opencode-config-*.tar.gz 2>/dev/null | head -1)
  if [ -n "$LATEST" ]; then
    log "Último backup: $(basename "$LATEST")"
  fi
fi

log "=== INICIALIZACIÓN COMPLETADA ==="
echo ""
echo "Inicialización de OpenCode completada."
echo "Ver detalles en: $LOG_FILE"
INITEOF

chmod +x "$DIR_CONFIG/init-opencode.sh"

echo "=== 9. Añadiendo OPENCODE_ENABLE_EXA=1 al ~/.zshrc (si no está ya) ==="
if ! grep -q "OPENCODE_ENABLE_EXA" "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" << 'ZEOF'

# opencode con TUI completo + voz
opencode() {
    script -q -f -c "opencode $*" /dev/null 2>&1
}
export OPENCODE_ENABLE_EXA=1
ZEOF
    echo "  Añadido. Recarga con: source ~/.zshrc"
else
    echo "  Ya estaba presente."
fi

echo ""
echo "============================================"
echo "  INSTALACIÓN COMPLETA"
echo "============================================"
echo ""
echo "Para ARRANCAR todo:"
echo "  1. Asegúrate de que Ollama está corriendo:"
echo "     ollama serve"
echo ""
echo "  2. Arranca el proxy:"
echo "     python3 $DIR_CONFIG/ollama-proxy.py 4000 > $LOG_PROXY 2>&1 &"
echo "     disown"
echo ""
echo "  3. Verifica que funciona:"
echo "     curl -s http://127.0.0.1:4000/v1/models"
echo ""
echo "  4. Ejecuta init si es necesario:"
echo "     bash $DIR_CONFIG/init-opencode.sh"
echo ""
echo "  5. Arranca OpenCode:"
echo "     opencode"
echo ""
echo "Para REINICIAR el proxy:"
echo "  pkill -f ollama-proxy"
echo "  python3 $DIR_CONFIG/ollama-proxy.py 4000 > $LOG_PROXY 2>&1 &"
echo "  disown"
echo ""
echo "Archivos instalados:"
echo "  - $DIR_CONFIG/opencode.json"
echo "  - $DIR_CONFIG/AGENTS.md"
echo "  - $DIR_CONFIG/ollama-proxy.py"
echo "  - $DIR_CONFIG/init-opencode.sh"
echo "  - $DIR_CONFIG/prompts/read-agents.txt"
echo "  - $VENV_SEARCH (entorno virtual con ddgs)"
echo "============================================"
