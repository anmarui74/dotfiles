# 📋 Los Dos Perfiles de `opencode.json` en Windows

Adaptación del manual Linux al setup **Windows** de OpenCode (config activa en `C:\Users\evo01\.config\opencode\`).

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 📁 Perfiles | 10/09/2026 · rev. 10/09/2026 | Antonio |

> Perfiles global / local, MCPs y proveedores en Windows

---

## 📑 Índice

1. [Descripción general](#descripción-general)
2. [Perfil global (`opencode.jsonc`)](#perfil-global)
3. [Perfil local (`opencode-local.json`)](#perfil-local)
4. [Comparativa de perfiles](#comparativa)
5. [Cambio entre perfiles](#cambio-entre-perfiles)
6. [Explicación detallada de cada sección](#explicación-de-secciones)

> ⚠️ **No aplica en Windows:** en Linux existía un perfil `opencode-cloud.json` separado. En Windows hay **TRES perfiles** (`opencode.jsonc` global/cloud, `opencode-local.json` local completo y `opencode-local-min.json` local mínimo) y el `opencode.jsonc` es el **perfil global activo**. Ver sección [Descripción general](#descripción-general).

---

## Descripción general

Existen **tres archivos** de configuración para OpenCode en Windows, todos en `C:\Users\evo01\.config\opencode\`:

| Archivo | Propósito |
|---------|-----------|
| `opencode.jsonc` | **Perfil GLOBAL por defecto** - Agente `cloud` por defecto, agente `local` deshabilitado, provider nvidia con whitelist de 8 modelos, **todos los MCPs** activos |
| `opencode-local.json` | Perfil **local completo** - Provider `lmstudio` (proxy `http://127.0.0.1:4001/v1`), modelo `qwen3.8-9b`, agente `local` por defecto, **todos los MCPs** |
| `opencode-local-min.json` | Perfil **local mínimo** - Igual pero con **solo MCPs esenciales** (`fetch`, `filesystem`, `memory`) |

Cada perfil se activa con **su propia función de PowerShell** vía la variable de entorno `OPENCODE_CONFIG` (la fijan `ocv`, `ocv-local` y `ocv-cloud` del perfil). **Nada se copia nunca sobre `opencode.jsonc`.**

| Función PowerShell | Config | Agente por defecto | Agente local | MCPs | LM Studio |
|--------------------|--------|--------------------|--------------|------|-----------|
| `ocv` | `opencode-local.json` | `local` (Qwen local) | ✅ activo (primario) | Todos (5) | ✅ Carga modelo |
| `ocv-local` | `opencode-local-min.json` | `local` (Qwen local) | ✅ activo (primario) | `fetch`, `filesystem`, `memory` | ✅ Carga modelo |
| `ocv-cloud` | `opencode.jsonc` (global) | `cloud` (OpenCode Go) | ❌ desactivado | Todos (5) | ❌ No carga modelo |

> 📌 **Diferencia clave con Linux:** en Linux el perfil por defecto (`opencode.json`) era distinto del cloud. En Windows **`opencode.jsonc` ES el perfil cloud/global**; el perfil local se divide en **completo** (`opencode-local.json`) y **mínimo** (`opencode-local-min.json`, equivalente funcional al `opencode-local.json` de Linux).

---

## Perfil global

### Archivo: `C:\Users\evo01\.config\opencode\opencode.jsonc`

Perfil global por defecto (para `ocv-cloud` o ejecutando `opencode` sin `OPENCODE_CONFIG`). Tiene **agente `cloud` por defecto**, el agente **local deshabilitado** (`agent.local.disable: true`) y **todos los MCPs activos**.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "small_model": "opencode-go/deepseek-flash",
  "instructions": [
    "C:/Users/evo01/.config/opencode/AGENTS.md"
  ],
  "default_agent": "cloud",
  "permission": {
    "edit": "ask",
    "bash": {
      "*": "ask",
      "sudo *": "deny",
      "pkexec *": "allow"
    }
  },
  "agent": {
    "build": {
      "prompt": "{file:./prompts/read-agents.txt}",
      "model": "opencode-go/deepseek-flash"
    },
    "plan": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "local": {
      "description": "Agente local desactivado en Windows (requiere LM Studio + proxy en localhost:4001)",
      "mode": "primary",
      "model": "opencode-go/deepseek-flash",
      "disable": true
    },
    "cloud": {
      "description": "Agente cloud - DeepSeek V4.1 Flash Off-Peak: pipeline diario de codigo, coste minimo",
      "mode": "primary",
      "model": "opencode-go/deepseek-flash",
      "permission": {
        "task": { "*": "allow" }
      }
    },
    "nvidia": {
      "description": "Agente NVIDIA - Muse Glimmer 30B de Meta: tool calling nativo, gratis via NIM (requiere API key nvidia en auth.json)",
      "mode": "all",
      "model": "nvidia/meta/muse-glimmer-30b",
      "temperature": 1,
      "top_p": 0.95
    },
    "multimodal": {
      "description": "Agente multimodal - Muse Glimmer 30B con soporte de imagen + texto (requiere API key nvidia)",
      "mode": "all",
      "model": "nvidia/meta/muse-glimmer-30b",
      "temperature": 0.8,
      "top_p": 0.9,
      "prompt": "Eres un asistente multimodal experto. Analiza imagenes, screenshots y documentos junto con el texto. Para contextos largos, resume, extrae key points y responde con referencias precisas."
    }
  },
  "provider": {
    "nvidia": {
      "whitelist": [
        "minimaxai/minimax-m3",
        "openai/gpt-oss-20b",
        "meta/llama-3.2-11b-vision-instruct",
        "meta/muse-glimmer-30b",
        "nvidia/nemotron-3-super-120b-a12b",
        "nvidia/nemotron-3-ultra-550b-a55b",
        "nvidia/nemotron-3.5-lightning-30b-a3b",
        "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning"
      ],
      "options": {
        "timeout": 600000,
        "chunkTimeout": 60000
      }
    }
  },
  "lsp": false,
  "mcp": {
    "context7": { "type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": true },
    "filesystem": { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "C:/Users/evo01"], "enabled": true },
    "memory": { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-memory"], "environment": { "MEMORY_FILE_PATH": "C:/Users/evo01/.config/opencode/data/memory/memory.jsonl" }, "enabled": true },
    "fetch": { "type": "local", "command": ["npx", "-y", "mcp-fetch-server"], "enabled": true },
    "sequential_thinking": { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"], "enabled": true }
  }
}
```

> 📌 **Diferencias con el perfil activo de Linux:** no hay clave `shell` (en Windows el shell de los agentes es PowerShell 5.1, sin zsh); `lsp` está desactivado (`false`) en lugar de los 11 LSPs de Linux; `instructions` usa la ruta absoluta `C:/Users/evo01/.config/opencode/AGENTS.md`.

---

## Perfil local

### Archivo: `C:\Users\evo01\.config\opencode\opencode-local.json`

Perfil local (para `ocv`). Usa **LM Studio** como provider con el modelo `qwen3.8-9b` (Qwen3.8-9B Q6_K) a través del **proxy local en `http://127.0.0.1:4001/v1`**, con agente **`local` por defecto**.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "lmstudio/qwen3.8-9b",
  "small_model": "lmstudio/qwen3.8-9b",
  "instructions": [
    "C:/Users/evo01/.config/opencode/AGENTS.md"
  ],
  "default_agent": "local",
  "permission": {
    "edit": "ask",
    "bash": {
      "*": "ask",
      "sudo *": "deny",
      "pkexec *": "allow"
    }
  },
  "provider": {
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LM Studio (local, proxy 4001)",
      "options": {
        "baseURL": "http://127.0.0.1:4001/v1"
      },
      "models": {
        "qwen3.8-9b": {
          "name": "Qwen3.8-9B Q6_K (local)",
          "reasoning": true,
          "tool_call": true,
          "temperature": true,
          "limit": {
            "context": 80000,
            "output": 32000
          }
        }
      }
    },
    "nvidia": {
      "whitelist": [
        "minimaxai/minimax-m3",
        "openai/gpt-oss-20b",
        "meta/llama-3.2-11b-vision-instruct",
        "meta/muse-glimmer-30b",
        "nvidia/nemotron-3-super-120b-a12b",
        "nvidia/nemotron-3-ultra-550b-a55b",
        "nvidia/nemotron-3.5-lightning-30b-a3b",
        "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning"
      ],
      "options": {
        "timeout": 600000,
        "chunkTimeout": 60000
      }
    }
  },
  "agent": {
    "build": {
      "prompt": "{file:./prompts/read-agents.txt}",
      "model": "lmstudio/qwen3.8-9b"
    },
    "plan": {
      "prompt": "{file:./prompts/read-agents.txt}",
      "model": "lmstudio/qwen3.8-9b"
    },
    "local": {
      "description": "Agente local - Qwen3.8-9B Q6_K en LM Studio via proxy (localhost:4001)",
      "mode": "primary",
      "model": "lmstudio/qwen3.8-9b",
      "disable": false
    },
    "cloud": {
      "description": "Agente cloud - DeepSeek V4.1 Flash Off-Peak: pipeline diario de codigo, coste minimo",
      "mode": "primary",
      "model": "opencode-go/deepseek-flash",
      "permission": {
        "task": { "*": "allow" }
      }
    },
    "nvidia": {
      "description": "Agente NVIDIA - Muse Glimmer 30B de Meta: tool calling nativo, gratis via NIM (requiere API key nvidia en auth.json)",
      "mode": "all",
      "model": "nvidia/meta/muse-glimmer-30b",
      "temperature": 1,
      "top_p": 0.95
    },
    "multimodal": {
      "description": "Agente multimodal - Muse Glimmer 30B con soporte de imagen + texto (requiere API key nvidia)",
      "mode": "all",
      "model": "nvidia/meta/muse-glimmer-30b",
      "temperature": 0.8,
      "top_p": 0.9,
      "prompt": "Eres un asistente multimodal experto. Analiza imagenes, screenshots y documentos junto con el texto. Para contextos largos, resume, extrae key points y responde con referencias precisas."
    }
  },
  "lsp": false,
  "mcp": {
    "context7": { "type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": true },
    "filesystem": { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "C:/Users/evo01"], "enabled": true },
    "memory": { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-memory"], "environment": { "MEMORY_FILE_PATH": "C:/Users/evo01/.config/opencode/data/memory/memory.jsonl" }, "enabled": true },
    "fetch": { "type": "local", "command": ["npx", "-y", "mcp-fetch-server"], "enabled": true },
    "sequential_thinking": { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"], "enabled": true }
  }
}
```

> 📌 **Diferencias con Linux:** en el perfil local Linux los MCPs `context7` y `sequential_thinking` estaban **desactivados** (`enabled: false`) por ser "esenciales". En Windows **todos los MCPs están activos** (5 de 5) tanto en global como en local. El modelo usa `qwen3.8-9b` (con `tool_call` y `reasoning: true`) y el contexto es de **80.000 tokens** (frente a 81.920 de Linux), con 32.000 de salida.

---

## Comparativa

| Aspecto | `opencode.jsonc` (global/cloud) | `opencode-local.json` (local) |
|---------|--------------------------------|-------------------------------|
| **Agentes** | `build`, `plan`, `local` (desactivado), `cloud`, `nvidia` (all), `multimodal` (all) | `build`, `plan`, `local`, `cloud`, `nvidia` (all), `multimodal` (all) |
| **Agente principal** | `cloud` (OpenCode Go) | `local` (Qwen 3.8 local) |
| **Agente local** | ❌ desactivado (`disable: true`) | ✅ activo (primario) |
| **Modelo local** | — | `qwen3.8-9b` (Qwen3.8-9B Q6_K, contexto 80.000) |
| **Modelo cloud** | ✅ OpenCode Go (deepseek-flash) | ✅ OpenCode Go (deepseek-flash) |
| **Agente NVIDIA** | ✅ Muse Glimmer 30B (mode `all`) | ✅ Muse Glimmer 30B (mode `all`) |
| **Agente multimodal** | ✅ Muse Glimmer 30B (mode `all`) | ✅ Muse Glimmer 30B (mode `all`) |
| **context7** | ✅ | ✅ |
| **filesystem** | ✅ | ✅ |
| **memory** | ✅ | ✅ |
| **fetch** | ✅ | ✅ |
| **sequential_thinking** | ✅ | ✅ |
| **LSPs** | ❌ (`lsp: false`) | ❌ (`lsp: false`) |
| **LM Studio (VRAM)** | ❌ No carga | ✅ Carga modelo |
| **Uso típico** | Todo en la nube (cloud + NVIDIA), sin ocupar VRAM | Tareas locales con LM Studio (privacidad, sin internet) |

### ¿Cuándo usar cada perfil?

| Perfil | Cuándo usarlo |
|--------|---------------|
| **`opencode.jsonc` (global/cloud)** | Uso general con todos los agentes en la nube (OpenCode Go + NVIDIA), sin cargar el modelo local en VRAM. |
| **Local (`opencode-local.json`)** | Cuando trabajes offline o quieras que el procesamiento sea local (privacidad). Usa LM Studio vía proxy (puerto 4001). |

---

## Cambio entre perfiles

### Lanzadores (funciones del perfil de PowerShell)

Cada perfil se activa con **su propia función de PowerShell** (definidas en `C:\Users\evo01\OneDrive\Documentos\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`). Usan la variable `OPENCODE_CONFIG` de OpenCode, que carga el archivo indicado **sin copiar nada sobre `opencode.jsonc`**.

```powershell
# Perfil local (agente 'local', carga LM Studio + proxy y abre OpenCode)
ocv

# Perfil global/cloud (sin cargar LM Studio, agente 'cloud' por defecto)
ocv-cloud

# Estado de LM Studio, modelo y proxy
ocv-status
```

### ¿Cómo funciona?

La función `ocv` del perfil de PowerShell arranca primero LM Studio (vía `start-lmstudio.ps1`) y luego exporta `OPENCODE_CONFIG` apuntando al perfil local:

```powershell
function ocv {
    & "$global:OpenCodeConfigDir\start-lmstudio.ps1"
    $prev = $env:OPENCODE_CONFIG
    $env:OPENCODE_CONFIG = "$global:OpenCodeConfigDir\opencode-local.json"
    try {
        if ($Rest) { opencode @Rest } else { opencode }
    }
    finally {
        if ($null -eq $prev) { Remove-Item Env:OPENCODE_CONFIG -ErrorAction SilentlyContinue }
        else { $env:OPENCODE_CONFIG = $prev }
    }
}
```

- `OPENCODE_CONFIG` carga el perfil indicado (OpenCode lo fusiona sobre la global).
- La función `ocv-cloud` **elimina** `OPENCODE_CONFIG` de la sesión, de modo que OpenCode usa la config global `opencode.jsonc` por defecto (con agente `cloud` y sin cargar LM Studio).
- `start-lmstudio.ps1` arranca servidor LM Studio (puerto 1234), carga el modelo `qwen3.8-9b` con contexto 80.000 en VRAM y levanta el proxy Python en el puerto 4001.

> ⚠️ **No aplica en Windows:** en Linux la carga automática del modelo se hacía con el script `start-opencode-server.sh` y `SKIP_LMSTUDIO=1` desactivaba la carga. En Windows no existe ese mecanismo: `ocv-cloud` sencillamente no llama a `start-lmstudio.ps1`, por lo que nunca arranca el modelo local.

> ⚠️ **Importante:** Los cambios de config requieren reiniciar OpenCode para que surtan efecto.

---

## Explicación de secciones

### `$schema`
Esquema de validación JSON. OpenCode lo usa para autocompletado y validación.

### `model` / `small_model`
En el perfil local, `model` y `small_model` apuntan a `lmstudio/qwen3.8-9b` (el modelo local). En el global, `small_model` apunta a la nube (`opencode-go/deepseek-flash`). `small_model` se usa para tareas ligeras (resúmenes rápidos, clasificaciones).

### `instructions`
Archivos con instrucciones que se pasan al **system prompt** del modelo al inicio de cada sesión. En Windows se usa la ruta absoluta `C:/Users/evo01/.config/opencode/AGENTS.md`.

### `default_agent`
Agente que se usa por defecto cuando no se especifica otro: `cloud` en global, `local` en el perfil local.

### `permission`
Control de permisos granular:

```jsonc
"permission": {
  "edit": "ask",         // Preguntar antes de editar archivos
  "bash": {
    "*": "ask",          // Preguntar para todo lo demás
    "sudo *": "deny",    // NUNCA ejecutar sudo
    "pkexec *": "allow"  // Permitir pkexec
  }
}
```

> ⚠️ **No aplica en Windows:** las reglas `sudo *` y `pkexec *` se conservan en el JSON por compatibilidad, pero en Windows **no hay sudo ni pkexec**; la elevación de privilegios se hace por **UAC** (ventana gráfica de confirmación de administrador).

### `agent`
Define agentes (personas/modos del asistente):

- **build:** Agente especial para tareas de construcción (lee AGENTS.md al inicio). En global usa DeepSeek V4 Flash; en local usa `lmstudio/qwen3.8-9b`
- **plan:** Agente especial para planificación (lee AGENTS.md al inicio)
- **local:** Agente local. En el perfil local usa el modelo Qwen3.8-9B Q6_K vía LM Studio (puerto 4001) y es **primario**; en el global está **desactivado** (`disable: true`)
- **cloud:** Agente principal del perfil global, usa **OpenCode Go** (`opencode-go/deepseek-flash`). Tiene `permission.task: {"*": "allow"}`, lo que le permite **delegar automáticamente** a los subagentes (nvidia, multimodal, general, explore, scout)
- **nvidia:** Agente con `mode: "all"`, usa **Muse Glimmer 30B** (`nvidia/meta/muse-glimmer-30b`). Mejor modelo del ranking para agentes de código (SWE-Bench 76, Terminal-Bench 51,7, 144,9 tok/s, tool calling nativo). Se puede usar con Tab como primario **y** DeepSeek puede delegarle código pesado como subagente
- **multimodal:** Agente con `mode: "all"`, usa Muse Glimmer 30B con prompt optimizado para imagen + texto y recuperación de contexto largo. Disponible como primario y como subagente delegado

Cada agente puede tener su propio modelo y prompt de sistema.

### `provider`
Proveedores de modelos. Dos proveedores configurados:

- **lmstudio** (solo en el perfil local):
  - **SDK:** `@ai-sdk/openai-compatible` (interfaz OpenAI para LM Studio)
  - **URL:** `http://127.0.0.1:4001/v1` (proxy local)
  - **Modelo:** `qwen3.8-9b`
  - **Límites:** 80.000 tokens de contexto, 32.000 de salida
  - **Tools:** Habilitadas (`tool_call: true`), con `reasoning: true`

- **nvidia** (en ambos perfiles, desde el **18/08/2026**):
  - **Modelo agente:** `nvidia/meta/muse-glimmer-30b` (Muse Glimmer 30B de Meta)
  - **Whitelist:** 8 modelos operativos (verificado el **05/09/2026** con HTTP 200 real + tool calling)
  - **API Key:** `nvapi-*` (en `auth.json` de OpenCode)
  - **Endpoint:** `https://integrate.api.nvidia.com/v1`

#### 🏆 Ranking y metodología de selección de modelos NVIDIA (05/09/2026)

> **Criterio principal:** un modelo solo es útil en OpenCode si soporta **tool calling** (llamada a herramientas: bash, edición, búsqueda...). Un modelo sin tools o que genere a menos de ~10 tok/s es inutilizable como agente. Se priorizó la velocidad sobre otras características: no sirve un modelo que tarda minutos en responder.

**Metodología (verificación en vivo contra `https://integrate.api.nvidia.com/v1`):**

1. **Catálogo:** se consultó `GET /v1/models` (81 modelos disponibles, sin paginación; `limit=1000` confirma el mismo total).
2. **HTTP 200 real:** se envió una petición `POST /chat/completions` real a cada candidato. Los modelos listados en el catálogo pero sin endpoint de chat desplegado devuelven **HTTP 404** (unos 30) → descartados.
3. **Velocidad:** generación real de ~180 tokens con `max_tokens` amplio (no limitado a 5) midiendo `tokens/segundo` reales. Los que no llegan a ~10 tok/s se descartan (inutilizables como agente).
4. **Tool calling:** petición con `tools: [get_current_time]` y `tool_choice: auto`. Se exige que la respuesta contenga `tool_calls` reales.
5. **Reintento de sobrecarga:** los que fallaron con timeout / 429 / 503 / 500 se reintentaron con más margen antes de decidir.

**Resultado del ranking (los 8 del whitelist, ordenados de mejor a peor):**

| # | Modelo | Velocidad | Tool calling | Veredicto |
|---|--------|-----------|--------------|-----------|
| 1 | `meta/muse-glimmer-30b` | 144,9 tok/s | ✅ | ⭐⭐⭐⭐⭐ *(agente nvidia desde 05/09/2026)* |
| 2 | `nvidia/nemotron-3.5-lightning-30b-a3b` | 119,6 tok/s | ✅ | ⭐⭐⭐⭐⭐ |
| 3 | `nvidia/nemotron-3-super-120b-a12b` | 93,4 tok/s | ✅ | ⭐⭐⭐⭐ |
| 4 | `nvidia/nemotron-3-ultra-550b-a55b` | 74,5 tok/s | ✅ | ⭐⭐⭐⭐ |
| 5 | `meta/llama-3.2-11b-vision-instruct` | 50,7 tok/s | ✅ | ⭐⭐⭐⭐ |
| 6 | `minimaxai/minimax-m3` | 45,2 tok/s | ✅ | ⭐⭐⭐⭐ |
| 7 | `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` | 40,3 tok/s | ✅ | ⭐⭐⭐⭐ |
| 8 | `openai/gpt-oss-20b` | 34,2 tok/s | ✅ | ⭐⭐⭐⭐ |

**Modelos nuevos del catálogo probados y descartados (05/09/2026):**

| Modelo | Motivo del descarte |
|--------|---------------------|
| `mistralai/mistral-nemotron` | 6 tok/s + sin tool calling |
| `moonshotai/kimi-k3` | 0,9–2,4 tok/s + sin tools |
| `google/gemma-4-31b-it` | 2,2 tok/s + timeout |
| `deepseek-ai/deepseek-v4-flash-0731` | 1 tok/s (inútil como agente) |
| `deepseek-ai/deepseek-v4-pro-0813` | timeout |
| `meta/llama-3.2-90b-vision-instruct` | timeout |
| `poolside/laguna-xs-2.1` | 0,1 tok/s |
| ~30 modelos más (01-ai, mistralai, ibm, google, etc.) | HTTP 404 (sin endpoint de chat) |

**Retirados del whitelist original (410 Gone, end of life):** `z-ai/glm-5.2`, `openai/gpt-oss-120b`, `stepfun-ai/step-3.7-flash`, `thinkingmachines/inkling`, `meta/llama-3.1-8b-instruct`, `meta/llama-3.1-70b-instruct`, `meta/llama-3.3-70b-instruct`, `nvidia/llama-3.3-nemotron-super-49b-v1` y `v1.5`, `nvidia/nemotron-3-nano-30b-a3b`, `nvidia/nemotron-mini-4b-instruct`, `nvidia/nemotron-nano-12b-v2-vl`, `nvidia/nvidia-nemotron-nano-9b-v2`, `nvidia/llama-3.1-nemotron-nano-vl-8b-v1`.

> 💡 **Conclusión:** el catálogo `models.dev` que integra OpenCode está desactualizado para NVIDIA (listaba modelos ya retirados). Por eso el `whitelist` manual es necesario: evita que aparezcan modelos muertos (410) en el selector `/models`.

> ⚠️ **No aplica en Windows:** la verificación automática del whitelist en Linux se hace con el script `check-nvidia-whitelist.sh` vía timer systemd `check-nvidia-whitelist.timer`. En Windows puede reproducirse con una **tarea programada** (Programador de tareas) que ejecute el equivalente `.ps1`; de momento el whitelist se mantiene manualmente en ambos perfiles.

### `lsp`

**No aplica en Windows.** En Linux había 11 servidores LSP configurados (python, c, cpp, rust, typescript, go, json, yaml, bash, zsh, markdown) para ayudar a la IA a analizar código. En Windows **`lsp` está desactivado (`lsp: false`)** en ambos perfiles: no se lanzan servidores de lenguaje. La IA se apoya en la lectura directa de archivos y en los LSPs propios del editor.

### `mcp`
Servidores MCP (Model Context Protocol). Cada uno proporciona **herramientas** que el modelo puede usar. En Windows hay **5 MCPs activos en ambos perfiles**:

| MCP | Tipo | Comando/URL | Qué hace |
|-----|------|-------------|----------|
| **context7** | Remote | `https://mcp.context7.com/mcp` | Documentación técnica actualizada |
| **filesystem** | Local | `@modelcontextprotocol/server-filesystem` | Leer/escribir archivos (raíz `C:/Users/evo01`) |
| **memory** | Local | `@modelcontextprotocol/server-memory` | Grafo de conocimiento persistente (`MEMORY_FILE_PATH`) |
| **fetch** | Local | `mcp-fetch-server` | Obtener contenido web |
| **sequential_thinking** | Local | `@modelcontextprotocol/server-sequential-thinking` | Razonamiento estructurado paso a paso |

### Dependencias npm

### Archivo: `C:\Users\evo01\.config\opencode\package.json`

```json
{
  "dependencies": {
    "@opencode-ai/plugin": "1.18.30"
  }
}
```

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `@opencode-ai/plugin` | 1.18.30 | SDK para desarrollar plugins de OpenCode |

> 📌 El `package.json` solo contiene el SDK de plugins de OpenCode. No incluye
> `@ai-sdk/*` ni el plugin de voz: los SDK de AI los resuelve el propio binario
> de OpenCode y el plugin TUI `opencode-throughput` se registra en `tui.json`
> (junto al keybind `session_rename` en F8).