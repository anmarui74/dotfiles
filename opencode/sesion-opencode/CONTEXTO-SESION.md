# Contexto de la sesión - OpenCode + Ollama + Proxy

## Resumen
Configuración de OpenCode v1.17.18 con modelos locales Ollama a través de un proxy Python que traduce el formato OpenAI (`/v1/chat/completions`) al formato nativo de Ollama (`/api/chat`). El proxy incluye auto-search: cuando el modelo local responde con una negativa, busca automáticamente en internet y reintenta.

## Problemas resueltos

### 1. "QUEUED" (mensajes atascados)
- **Causa**: El SDK `@ai-sdk/openai-compatible` (v3.0.7) no detectaba el fin del stream SSE.
- **Solución**: `protocol_version = "HTTP/1.0"` + `self.close_connection = True` + `self.connection.shutdown(SHUT_WR)`.

### 2. Auto-search (búsqueda web automática)
- **Causa**: El modelo local no sabe cosas recientes.
- **Solución**: Cuando el modelo responde con negativa:
  1. Detecta patrones de negativa (español/inglés)
  2. Busca en DuckDuckGo (ddgs) + extrae contenido de 1ª página
  3. Para tiempo usa `wttr.in` (JSON multi-día)
  4. Inserta system msg permisivo + datos como user msg
  5. Reintenta (hasta 2 veces)

### 3. "No output" en saludos
- **Causa**: "minimize output tokens" del prompt.
- **Solución**: Detectar respuestas < 30 chars como pobres y retry.

### 4. Descripciones de herramientas
- **Causa**: Modelo describe websearch en vez de responder.
- **Solución**: Detectar `"function"`, `contextMaxCharacters`, `livecrawl`, etc.

### 5. Deepseek-r1:8b error 400 (contexto insuficiente)
- **Causa**: OpenCode no envía `options.num_ctx` al proxy. Ollama usaba default 4096.
- **Solución**: Proxy añade `num_ctx: 32768` automáticamente si no está presente.

### 6. Deepseek-r1:8b error 400 por tools
- **Causa**: Algunos modelos no soportan tool_calls.
- **Solución**: Proxy detecta HTTP 400, quita tools y reintenta.

## Archivos

### `config/opencode.json`
Provider `@ai-sdk/openai-compatible` → `http://127.0.0.1:4000/v1`. Modelos con num_ctx 32768.

### `config/AGENTS.md`
Idioma español, PWAs desde escritorio, proxy startup, auto-search, usuario en Pechina.
Incluye sección 💻 **Consultar hardware del sistema**: cuando el usuario pregunte
por CPU/RAM/GPU/etc., leer `data/hardware/index.json` en vez de ejecutar comandos.

### `scripts/ollama-proxy.py` (~390 líneas)
- Traduce OpenAI ↔ Ollama
- Stream SSE con HTTP/1.0 + shutdown
- Auto-search (ddgs + wttr.in)
- Tool calls forwarding
- options.num_ctx automático (32768)
- Reintento sin tools si error 400

### `scripts/setup-opencode-completo.sh`
Script de instalación todo-en-uno. Incluye:
- AGENTS.md con instrucción hardware
- init-opencode.sh con check_hardware
- .env con HARDWARE_INDEX_PATH
- Copia `data/hardware/index.json` y `hardware-query.sh` desde backup

### `data/hardware/index.json`
Inventario completo del sistema (18 secciones):
CPU (Zen4, vulnerabilidades), RAM (DDR5@6000, SPD temps, ZRAM),
motherboard (MSI X870, BIOS), GPU NVIDIA (Ada, 16GB, runtime),
iGPU AMD, displays (2× LG HDR 4K), audio (6 tarjetas, mic TONOR),
USB (webcam, Xbox, Logitech), storage (6 dispositivos, dual boot),
network (WiFi 7, BT 5.4, VMware, Docker), sensores, kernel boot.

### `hardware-query.sh`
Consulta rápida: `source hardware-query.sh && hw_query status|cpu|gpu|ram|...

## Dependencias
- **ddgs**: DuckDuckGo Search (`/tmp/venv-search/`)
- **wttr.in**: API meteorológica (sin API key)
- **Ollama**: `http://localhost:11434`
- **OpenCode**: `@ai-sdk/openai-compatible`

## Cómo probar
```bash
python3 scripts/ollama-proxy.py 4000 > /tmp/ollama-proxy.log 2>&1 &
curl -s http://127.0.0.1:4000/v1/models
opencode
```
