# 🦙 Configuración de Ollama + Proxy

> **Fecha:** 26/07/2026 | **Usuario:** Antonio

---

## Índice

1. [Descripción general](#descripción-general)
2. [Proxy de Ollama (`ollama-proxy.py`)](#proxy-de-ollama)
3. [Configuración LiteLLM](#configuración-litellm)
4. [Variables de entorno](#variables-de-entorno)
5. [Modelos disponibles](#modelos-disponibles)
6. [Flujo de funcionamiento](#flujo-de-funcionamiento)
7. [Problemas conocidos y workarounds](#problemas-conocidos)

---

## Descripción general

Ollama es el **servidor de inferencia local** que se usó inicialmente antes de migrar a LM Studio. Actualmente **no está activo como provider principal** en OpenCode, pero los modelos siguen disponibles en el sistema vía Ollama (puerto `11434`).

El proxy de Ollama (`ollama-proxy.py`) está diseñado para **sortear el bug #34892** del SDK `@ai-sdk/openai-compatible`, que serializa `function.name` como `undefined` en las tool calls.

---

## Proxy de Ollama

### Archivo: `~/.config/opencode/ollama-proxy.py` (en Config/opencode/)

> ⚠️ Este archivo está en `~/Config/opencode/` (backup) pero **no** en `~/.config/opencode/` (activo), porque actualmente se usa LM Studio como provider principal.

### ¿Qué hace?

1. **Proxy HTTP** que se sitúa entre OpenCode y Ollama
2. Parchea el **bug #34892** de serialización de tools
3. Inyecta herramientas (tools) cuando OpenCode las envía rotas
4. Normaliza mensajes (tool_calls, content arrays)
5. Gestiona VRAM de la GPU (libera KV cache cuando supera el 75%)
6. Soporta streaming (SSE) y no-streaming

### Puertos

| Componente | Puerto |
|------------|--------|
| Ollama API | `11434` |
| Proxy Ollama | `4000` |

### Funcionamiento interno

```
OpenCode → http://localhost:4000/v1 (proxy) → http://localhost:11434/api/chat (Ollama)
```

### Workaround de tools (corazón del proxy)

```python
# Detectar bug #34892: function.name undefined
if not fn.get("name"):
    needs_injection = True
    reason = "tools con function.name vacío (bug #34892)"

if needs_injection:
    body["tools"] = _tools_cache  # Inyecta tools de fallback
```

El proxy tiene **15 herramientas predefinidas** de fallback (read, write, edit, bash, grep, glob, list_files, task, todowrite, question, fetch, websearch, search_files, etc.) y además descubre herramientas MCP automáticamente.

### Variables de entorno para Ollama

Del archivo `.env`:

```bash
OLLAMA_API_KEY=ollama
OLLAMA_PROXY_PORT=4000
```

---

## Configuración LiteLLM

### Archivo: `~/.config/opencode/litellm-config.yaml`

LiteLLM sirve como **capa de abstracción** para usar modelos de Ollama con interfaz OpenAI-compatible. Define 5 modelos:

```yaml
model_list:
  - model_name: modelo-llama3.1
    litellm_params:
      model: ollama/llama3.1:8b
      api_base: http://localhost:11434

  - model_name: modelo-gemma4
    litellm_params:
      model: ollama/gemma4:e4b
      api_base: http://localhost:11434

  - model_name: modelo-deepseek-r1
    litellm_params:
      model: ollama/deepseek-r1:8b
      api_base: http://localhost:11434

  - model_name: modelo-deepseek-v4-flash
    litellm_params:
      model: ollama/deepseek-v4-flash-stock:latest
      api_base: http://localhost:11434

  - model_name: modelo-qwen3.5
    litellm_params:
      model: ollama/qwen3.5:9b
      api_base: http://localhost:11434
```

| Modelo LiteLLM | Modelo Ollama | Uso |
|----------------|---------------|-----|
| `modelo-llama3.1` | `llama3.1:8b` | Texto general |
| `modelo-gemma4` | `gemma4:e4b` | Texto ligero |
| `modelo-deepseek-r1` | `deepseek-r1:8b` | Razonamiento |
| `modelo-deepseek-v4-flash` | `deepseek-v4-flash-stock:latest` | Rápido |
| `modelo-qwen3.5` | `qwen3.5:9b` | Tool calling |

---

## Modelos disponibles en Ollama

Modelos instalados localmente (vía `ollama list`):

| Modelo | Tamaño | Propósito |
|--------|--------|-----------|
| `llama3.1:8b` | ~4.7 GB | Texto general |
| `gemma4:e4b` | ~2.5 GB | Ligero/eficiente |
| `deepseek-r1:8b` | ~4.9 GB | Razonamiento |
| `deepseek-v4-flash-stock:latest` | ~4.1 GB | Respuesta rápida |
| `qwen3.5:9b` | ~5.2 GB | Tool calling (con funciones) |

---

## Flujo de funcionamiento

### Si estuviera activo:

1. **OpenCode** envía petición a `http://localhost:4000/v1/chat/completions`
2. **Proxy** recibe la petición, inspecciona las tools
3. **Proxy** detecta si las tools vienen rotas (bug #34892) y las inyecta
4. **Proxy** normaliza los mensajes (arrays de content, tool_calls)
5. **Proxy** reenvía a `http://localhost:11434/api/chat`
6. **Ollama** procesa con el modelo solicitado
7. **Proxy** recibe la respuesta, la envuelve en formato OpenAI, y la devuelve a OpenCode

### Gestión de VRAM:

- Cada 2 respuestas, el proxy consulta `nvidia-smi`
- Si la VRAM supera el 75%, libera la KV cache del modelo
- Esto evita saturaciones en generaciones largas

---

## Problemas conocidos

### Bug #34892 de `@ai-sdk/openai-compatible`

- **Problema:** El SDK serializa `function.name` como `undefined` en las tool calls
- **Síntoma:** OpenCode envía tools sin nombre de función
- **Solución (proxy):** El proxy detecta la ausencia de nombre y reemplaza TODAS las tools con su propio cache de herramientas
- **Solución (LM Studio):** Se usa `@ai-sdk/openai-compatible` v3.0.7 con el proxy `lmstudio-proxy.py` que no tiene este problema porque LM Studio maneja las tools correctamente

### Modelos de razonamiento (deepseek-r1)

- El proxy **no fuerza** `reasoning_effort=none` para no bloquear modelos con razonamiento interno
- Si se usa deepseek-r1, el thinking del modelo puede devolverse como contenido

---

## Comandos útiles

```bash
# Ver modelos disponibles en Ollama
ollama list

# Iniciar el proxy manualmente
python3 ~/Config/opencode/ollama-proxy.py 4000

# Probar el proxy
curl http://localhost:4000/v1/models

# Liberar modelo de la VRAM
ollama run qwen3.5:9b ""

# Ver VRAM
nvidia-smi
```

---

> **Nota:** Actualmente el provider activo es **LM Studio** (puerto 1234 + proxy 4001). La configuración de Ollama se mantiene como respaldo histórico.
