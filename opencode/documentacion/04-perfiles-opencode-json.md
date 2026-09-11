# 📋 Los Tres Perfiles de `opencode.json`

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 📁 Perfiles | 26/07/2026 · act. 09/09/2026 | Antonio |

> Perfiles local / cloud / activo, MCPs y proveedores

---

## 📑 Índice


1. [Descripción general](#descripción-general)
2. [Perfil activo (`opencode.json`)](#perfil-activo)
3. [Perfil local (`opencode-local.json`)](#perfil-local)
4. [Perfil cloud (`opencode-cloud.json`)](#perfil-cloud)
5. [Comparativa de perfiles](#comparativa)
6. [Archivo `opencode.jsonc`](#archivo-opencodejsonc)
7. [Cambio entre perfiles](#cambio-entre-perfiles)
8. [Explicación detallada de cada sección](#explicación-de-secciones)

---

## Descripción general

Existen **tres archivos** de configuración para OpenCode, más un archivo complementario:

| Archivo | Propósito |
|---------|-----------|
| `opencode.json` | **Perfil por defecto** - Todos los MCPs y agentes activos |
| `opencode-local.json` | Perfil **local** - Solo MCPs esenciales |
| `opencode-cloud.json` | Perfil **cloud** - Todos los MCPs, sin agente local |
| ~~`opencode.jsonc`~~ | ~~Configuración de shell~~ (obsoleto, ver sección 6) |

Los tres archivos están en `~/.config/opencode/`. Cada perfil se activa con **su propio lanzador** vía `OPENCODE_CONFIG`. **Nada se copia nunca sobre `opencode.json`** (el antiguo `switch-mcp-profile.sh`, que sobrescribía `opencode.json`, está ELIMINADO desde el 18/08/2026).

| Lanzador | Config | Agente local | MCPs | LM Studio |
|----------|--------|--------------|------|-----------|
| `ocv` / `opencode` | `opencode.json` | ✅ activo (primario) | Todos | ✅ Carga modelo |
| `ocv-local` / `opencode-local` | `opencode-local.json` | ✅ activo (primario) | Esenciales | ✅ Carga modelo |
| `ocv-cloud` / `opencode-cloud` | `opencode-cloud.json` | ❌ desactivado | Todos | ❌ No carga modelo (`SKIP_LMSTUDIO=1`) |

---

## Perfil activo

### Archivo: `~/.config/opencode/opencode.json`

Perfil por defecto (para `ocv` / `opencode`). Tiene **todos los agentes activos** (local, cloud y NVIDIA) y **todos los MCPs activos**.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "/usr/bin/zsh",
  "small_model": "lmstudio/qwen3.8-9b",
  "instructions": ["AGENTS.md"],
  "default_agent": "cloud",
  "permission": {
    "edit": "ask",
    "bash": {
      "sudo *": "deny",
      "pkexec *": "allow",
      "*": "ask"
    }
  },
  "agent": {
    "build": {
      "prompt": "{file:./prompts/read-agents.txt}",
      "model": "opencode-go/deepseek-v4.1-flash"
    },
    "plan": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "local": {
      "description": "Agente local - Qwen 3.8 Q6_K optimizado (80k contexto)",
      "mode": "primary",
      "model": "lmstudio/qwen3.8-9b"
    },
    "cloud": {
      "description": "Agente cloud para modelos en la nube (Claude, Gemini, OpenCode Go)",
      "mode": "primary",
      "model": "opencode-go/deepseek-v4.1-flash"
    },
    "nvidia": {
      "description": "Agente NVIDIA - Muse Glimmer 30B de Meta (mejor agente de código del ranking, 144,9 tok/s, tool calling nativo)",
      "mode": "all",
      "model": "nvidia/meta/muse-glimmer-30b",
      "temperature": 1,
      "top_p": 0.95
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
    },
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Qwen 3.8 Q6_K",
      "options": {"baseURL": "http://localhost:4001/v1"},
      "models": {
        "qwen3.8-9b": {
          "name": "Qwen 3.8 - Tool Calling Excellence",
          "tool_call": true,
          "limit": {"context": 81920, "output": 8192}
        }
      }
    }
  },
  "lsp": {
    "python": {
      "command": ["/home/antonio/.local/bin/basedpyright-langserver", "--stdio"],
      "extensions": [".py", ".pyw"]
    },
    "c": {
      "command": ["/usr/bin/clangd"],
      "extensions": [".c", ".h"]
    },
    "cpp": {
      "command": ["/usr/bin/clangd"],
      "extensions": [".cpp", ".hpp", ".cc", ".cxx"]
    },
    "rust": {
      "command": ["/home/antonio/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rust-analyzer"],
      "extensions": [".rs"]
    },
    "typescript": {
      "command": ["/home/antonio/.npm-global/bin/typescript-language-server", "--stdio"],
      "extensions": [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"]
    },
    "go": {
      "command": ["/home/antonio/go/bin/gopls"],
      "extensions": [".go"]
    },
    "json": {
      "command": ["/home/antonio/.npm-global/bin/vscode-json-language-server", "--stdio"],
      "extensions": [".json", ".jsonc"]
    },
    "yaml": {
      "command": ["/home/antonio/.npm-global/bin/yaml-language-server", "--stdio"],
      "extensions": [".yaml", ".yml"]
    },
    "bash": {
      "command": ["/home/antonio/.npm-global/bin/bash-language-server", "start"],
      "extensions": [".sh", ".bash"]
    },
    "zsh": {
      "command": ["/home/antonio/.npm-global/bin/bash-language-server", "start"],
      "extensions": [".zsh", ".zshrc"]
    },
    "markdown": {
      "command": ["/usr/bin/marksman"],
      "extensions": [".md", ".markdown"]
    }
  },
  "mcp": {
    "context7": {"type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": true},
    "filesystem": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/antonio"], "enabled": true},
    "memory": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-memory"], "environment": {"MEMORY_FILE_PATH": "/home/antonio/.config/opencode/data/memory/memory.jsonl"}, "enabled": true},
    "fetch": {"type": "local", "command": ["node", "/home/antonio/.config/opencode/mcp-fetch-fix.js"], "enabled": true},
    "sequential_thinking": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"], "enabled": true}
  }
}
```

---

## Perfil local

### Archivo: `~/.config/opencode/opencode-local.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "/usr/bin/zsh",
  "small_model": "lmstudio/qwen3.8-9b",
  "instructions": ["AGENTS.md"],
  "default_agent": "local",
  "permission": {
    "edit": "ask",
    "bash": { "sudo *": "deny", "pkexec *": "allow", "*": "ask" }
  },
  "agent": {
    "build": {
      "prompt": "{file:./prompts/read-agents.txt}",
      "model": "opencode-go/deepseek-v4.1-flash"
    },
    "plan": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "local": {
      "description": "Agente local - Qwen 3.8 Q6_K optimizado (80k contexto)",
      "mode": "primary",
      "model": "lmstudio/qwen3.8-9b"
    },
    "cloud": {
      "description": "Agente cloud para modelos en la nube (Claude, Gemini, OpenCode Go)",
      "mode": "primary",
      "model": "opencode-go/deepseek-v4.1-flash"
    },
    "nvidia": {
      "description": "Agente NVIDIA - Muse Glimmer 30B de Meta (mejor agente de código del ranking, 144,9 tok/s, tool calling nativo)",
      "mode": "all",
      "model": "nvidia/meta/muse-glimmer-30b",
      "temperature": 1,
      "top_p": 0.95
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
    },
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Qwen 3.8 Q6_K",
      "options": {"baseURL": "http://localhost:4001/v1"},
      "models": {
        "qwen3.8-9b": {
          "name": "Qwen 3.8 - Tool Calling Excellence",
          "tool_call": true,
          "limit": {"context": 81920, "output": 8192}
        }
      }
    }
  },
  "lsp": {
    "python": {
      "command": ["/home/antonio/.local/bin/basedpyright-langserver", "--stdio"],
      "extensions": [".py", ".pyw"]
    },
    "c": {
      "command": ["/usr/bin/clangd"],
      "extensions": [".c", ".h"]
    },
    "cpp": {
      "command": ["/usr/bin/clangd"],
      "extensions": [".cpp", ".hpp", ".cc", ".cxx"]
    },
    "rust": {
      "command": ["/home/antonio/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rust-analyzer"],
      "extensions": [".rs"]
    },
    "typescript": {
      "command": ["/home/antonio/.npm-global/bin/typescript-language-server", "--stdio"],
      "extensions": [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"]
    },
    "go": {
      "command": ["/home/antonio/go/bin/gopls"],
      "extensions": [".go"]
    },
    "json": {
      "command": ["/home/antonio/.npm-global/bin/vscode-json-language-server", "--stdio"],
      "extensions": [".json", ".jsonc"]
    },
    "yaml": {
      "command": ["/home/antonio/.npm-global/bin/yaml-language-server", "--stdio"],
      "extensions": [".yaml", ".yml"]
    },
    "bash": {
      "command": ["/home/antonio/.npm-global/bin/bash-language-server", "start"],
      "extensions": [".sh", ".bash"]
    },
    "zsh": {
      "command": ["/home/antonio/.npm-global/bin/bash-language-server", "start"],
      "extensions": [".zsh", ".zshrc"]
    },
    "markdown": {
      "command": ["/usr/bin/marksman"],
      "extensions": [".md", ".markdown"]
    }
  },
  "mcp": {
    "context7": {"type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": false},
    "filesystem": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/antonio"], "enabled": true},
    "memory": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-memory"], "environment": {"MEMORY_FILE_PATH": "/home/antonio/.config/opencode/data/memory/memory.jsonl"}, "enabled": true},
    "fetch": {"type": "local", "command": ["node", "/home/antonio/.config/opencode/mcp-fetch-fix.js"], "enabled": true},
    "sequential_thinking": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"], "enabled": false}
  }
}
```

---

## Perfil cloud

### Archivo: `~/.config/opencode/opencode-cloud.json`

Perfil para `ocv-cloud` / `opencode-cloud`. Tiene **todos los MCPs activos** y el agente
local **desactivado** (`agent.local.disable: true`). Como el modelo local no se va a
usar, `small_model` apunta a la nube (`opencode-go/deepseek-v4.1-flash`) y el lanzador
no carga el modelo en VRAM (`SKIP_LMSTUDIO=1`).

La diferencia con `opencode.json` (por defecto) es:
- `small_model`: nube en lugar de LM Studio local
- Agente `local`: `disable: true` (en `opencode.json` es el agente activo)

---

## Comparativa

| Aspecto | `opencode.json` (defecto) | Local | Cloud |
|---------|---------------------------|-------|-------|
| **Agentes** | `build`, `plan`, `local`, `cloud`, `nvidia` (sub), `multimodal` (sub) | `build`, `plan`, `local`, `cloud`, `nvidia` (sub), `multimodal` (sub) | `build`, `plan`, `cloud`, `nvidia` (sub), `multimodal` (sub) |
| **Agente principal** | `cloud` (OpenCode Go) | `local` (Qwen 3.8 local) | `cloud` (OpenCode Go) |
| **Agente local** | ✅ activo (primario) | ✅ activo (primario) | ❌ desactivado |
| **Modelo cloud** | ✅ OpenCode Go (deepseek-v4.1-flash) | ✅ OpenCode Go (deepseek-v4.1-flash) | ✅ OpenCode Go (deepseek-v4.1-flash) |
| **Agente NVIDIA** | ✅ subagente Muse Glimmer 30B | ✅ subagente Muse Glimmer 30B | ✅ subagente Muse Glimmer 30B |
| **Agente multimodal** | ✅ subagente Muse Glimmer 30B | ✅ subagente (heredado de global) | ✅ subagente (heredado de global) |
| **context7** | ✅ | ❌ | ✅ |
| **filesystem** | ✅ | ✅ | ✅ |
| **memory** | ✅ | ✅ | ✅ |
| **fetch** | ✅ | ✅ | ✅ |
| **sequential_thinking** | ✅ | ❌ | ✅ |
| **LSPs** | ✅ (los 11) | ✅ (los 11) | ✅ (los 11) |
| **LM Studio (VRAM)** | ✅ Carga modelo | ✅ Carga modelo | ❌ No carga |
| **Uso típico** | Uso general con todo activo | Tareas locales sin internet | Todo en la nube, sin ocupar VRAM |

### ¿Cuándo usar cada perfil?

| Perfil | Cuándo usarlo |
|--------|--------------|
| **`opencode.json` (defecto)** | Uso general: todos los agentes y MCPs disponibles, con el modelo local cargado para cuando lo necesites. |
| **Local** | Cuando trabajes offline o quieras que todo el procesamiento sea local (privacidad). Menos MCPs activos (context7 y sequential_thinking desactivados). |
| **Cloud** | Cuando necesites toda la potencia (documentación, razonamiento estructurado y modelos en la nube) sin ocupar VRAM con el modelo local. |

---

## Archivo `opencode.jsonc` (OBSOLETO desde 10/08/2026)

### Archivo: `~/.config/opencode/opencode.jsonc`

> ⚠️ **Ya no se usa.** El shell se define directamente en los **tres perfiles** (`opencode.json`, `opencode-local.json`, `opencode-cloud.json`) con `"shell": "/usr/bin/zsh"`. El `opencode.jsonc` quedó como resto de una versión anterior y se eliminó del backup el 10/08/2026.

Define el **shell** que usa OpenCode para ejecutar comandos bash. En este caso, `/usr/bin/zsh` (Z shell).

---

## Cambio entre perfiles

### Lanzadores (desde el 18/08/2026)

Cada perfil se activa con **su propio lanzador** (definidos en `~/.zshrc`). Usan la
variable `OPENCODE_CONFIG` de OpenCode, que carga el archivo indicado **sin copiar
nada sobre `opencode.json`**.

```bash
# Perfil por defecto
ocv                        # o: opencode

# Perfil local (MCPs esenciales, carga modelo en VRAM)
ocv-local                  # o: opencode-local

# Perfil cloud (todos los MCPs, sin modelo local en VRAM)
ocv-cloud                  # o: opencode-cloud
```

### ¿Cómo funciona?

El lanzador exporta `OPENCODE_CONFIG` apuntando al archivo del perfil:

```zsh
function ocv-cloud() {
    script -q -f -c "OPENCODE_CONFIG=$HOME/.config/opencode/opencode-cloud.json \
        SKIP_LMSTUDIO=1 REAL_OPENCODE=/usr/bin/opencode \
        /home/antonio/.local/bin/opencode $*" /dev/null 2>&1
}
```

- `OPENCODE_CONFIG` carga el perfil indicado (OpenCode lo fusiona sobre la global).
- `SKIP_LMSTUDIO=1` hace que `start-opencode-server.sh` **no cargue el modelo local** en VRAM.
- El antiguo `switch-mcp-profile.sh` (que copiaba local/cloud sobre `opencode.json`) está **ELIMINADO**.

> ⚠️ **Importante:** Los cambios de config requieren reiniciar OpenCode para que surtan efecto.

---

## Explicación de secciones

### `$schema`
Esquema de validación JSON. OpenCode lo usa para autocompletado y validación.

### `small_model`
Modelo usado para tareas **ligeras** (resúmenes rápidos, clasificaciones). Actualmente apunta al mismo que el modelo principal.

### `instructions`
Archivos markdown con instrucciones que se pasan al **system prompt** del modelo al inicio de cada sesión. `AGENTS.md` contiene todas las reglas de comportamiento.

### `default_agent`
Agente que se usa por defecto cuando no se especifica otro.

### `permission`
Control de permisos granular:

```json
"permission": {
  "edit": "ask",         // Preguntar antes de editar archivos
  "bash": {
    "sudo *": "deny",    // NUNCA ejecutar sudo (se usará pkexec)
    "pkexec *": "allow", // Permitir pkexec (interfaz gráfica)
    "*": "ask"           // Preguntar para todo lo demás
  }
}
```

### `agent`
Define agentes (personas/modos del asistente):

- **build:** Agente especial para tareas de construcción (lee AGENTS.md al inicio). Desde el **18/08/2026** usa **DeepSeek V4 Flash** como modelo explícito
- **plan:** Agente especial para planificación (lee AGENTS.md al inicio)
- **local:** Agente local, usa el modelo Qwen 3.8 Q6_K vía LM Studio (puerto 4001). Es **primario** en el perfil activo y en el perfil local; **desactivado** (`disable: true`) en el perfil cloud
- **cloud:** Agente principal del perfil activo, usa **OpenCode Go** (`opencode-go/deepseek-v4.1-flash`). Desde el **09/09/2026** tiene `permission.task: {"*": "allow"}`, lo que le permite **delegar automáticamente** a los subagentes (nvidia, multimodal, general, explore, scout)
- **nvidia:** **Subagente** desde el **09/09/2026** (antes primario), usa **Muse Glimmer 30B** (`nvidia/meta/muse-glimmer-30b`). Mejor modelo del ranking para agentes de código (SWE-Bench 76, Terminal-Bench 51,7, 144,9 tok/s, tool calling nativo). DeepSeek lo invoca automáticamente para código pesado
- **multimodal:** **Subagente** (solo en `opencode.json`; heredado por fusión en local y cloud), usa Muse Glimmer 30B con prompt optimizado para imagen + texto y recuperación de contexto largo. Desde el **09/09/2026** ya no es primario

Cada agente puede tener su propio modelo y prompt de sistema.

### `provider`
Proveedores de modelos. Dos proveedores configurados:

- **lmstudio** (local):
  - **SDK:** `@ai-sdk/openai-compatible` (interfaz OpenAI para LM Studio)
  - **URL:** `http://localhost:4001/v1` (proxy local)
  - **Modelo:** `qwen3.8-9b`
  - **Límites:** 81.920 tokens de contexto, 8.192 de salida
  - **Tools:** Habilitadas

- **nvidia** (cloud, desde el **18/08/2026**):
  - **Modelo agente:** `nvidia/meta/muse-glimmer-30b` (Muse Glimmer 30B de Meta)
  - **Whitelist:** 8 modelos operativos (verificado el **05/09/2026** con HTTP 200 real + tool calling)
  - **API Key:** `nvapi-*` (en `auth.json` de OpenCode)
  - **Endpoint:** `https://integrate.api.nvidia.com/v1`
  - ⚠️ **Nota 18/08/2026:** `z-ai/glm-5.2` estaba saturado (HTTP 429) por rate limit de NVIDIA. **Retirado el 05/09/2026** (HTTP 410 Gone, fin de vida el 21/08/2026)
  - **Verificación 05/09/2026:** de los 22 modelos del whitelist original, 14 fueron retirados (HTTP 410 Gone, end of life entre el 21/08 y el 03/09/2026) y se eliminaron. Se probaron los modelos nuevos del catálogo NVIDIA (81 totales) midiendo velocidad real y tool calling: todos descartados (lentos <6 tok/s, sin tool calling o sin endpoint de chat HTTP 404). La lista final de 8 es la única utilizable en OpenCode.

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

### `lsp`
Servidores de lenguaje (Language Server Protocol) que OpenCode lanza localmente para **ayudar a la IA** a analizar el código: localizar definiciones y referencias, detectar errores al editar y entender la estructura del proyecto. Configurados el **10/08/2026** en los tres perfiles:

| Lenguaje | Servidor | Ruta | Extensiones |
|----------|----------|------|-------------|
| Python | basedpyright | `~/.local/bin/basedpyright-langserver` | `.py`, `.pyw` |
| C | clangd | `/usr/bin/clangd` | `.c`, `.h` |
| C++ | clangd | `/usr/bin/clangd` | `.cpp`, `.hpp`, `.cc`, `.cxx` |
| Rust | rust-analyzer | `~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rust-analyzer` | `.rs` |
| TypeScript/JS | typescript-language-server | `~/.npm-global/bin/typescript-language-server` | `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs` |
| Go | gopls | `~/go/bin/gopls` | `.go` |
| JSON | vscode-json-language-server | `~/.npm-global/bin/vscode-json-language-server` | `.json`, `.jsonc` |
| YAML | yaml-language-server | `~/.npm-global/bin/yaml-language-server` | `.yaml`, `.yml` |
| Bash | bash-language-server | `~/.npm-global/bin/bash-language-server` | `.sh`, `.bash` |
| Zsh | bash-language-server (forzado) | `~/.npm-global/bin/bash-language-server` | `.zsh`, `.zshrc` |
| Markdown | marksman | `/usr/bin/marksman` | `.md`, `.markdown` |

> 📌 **Nota zsh:** no existe un LSP dedicado para zsh (el parser tree-sitter-zsh está abandonado). Se fuerza `bash-language-server` en archivos `.zsh`/`.zshrc`: funciona para navegación, símbolos y renombrado (~90%), pero **sin diagnósticos** de shellcheck (que solo aplica a bash puro).

> 💡 **Nota:** Los LSPs son independientes del modelo LLM (local o cloud). En el editor de Antonio (Neovim/VSCode) ya hay LSPs propios; los de OpenCode son una ayuda extra para que la IA trabaje con más precisión. No son imprescindibles: la IA puede revisar código leyendo los archivos sin ellos. Los servidores JSON y YAML se añadieron el 10/08/2026 para gestionar mejor los archivos de configuración (opencode.json, tui.json, etc.).

### `mcp`
Servidores MCP (Model Context Protocol). Cada uno proporciona **herramientas** que el modelo puede usar:

| MCP | Tipo | Comando/URL | Qué hace |
|-----|------|-------------|----------|
| **context7** | Remote | `https://mcp.context7.com/mcp` | Documentación técnica actualizada |
| **filesystem** | Local | `@modelcontextprotocol/server-filesystem` | Leer/escribir archivos |
| **memory** | Local | `@modelcontextprotocol/server-memory` | Grafo de conocimiento persistente |
| **fetch** | Local | `mcp-fetch-fix.js` (proxy de `mcp-fetch-server`) | Obtener contenido web (HTML, Markdown, texto, JSON, YouTube) |
| **sequential_thinking** | Local | `@modelcontextprotocol/server-sequential-thinking` | Razonamiento estructurado paso a paso |

> 🩹 **Fix MCP fetch (11/09/2026):** el servidor `mcp-fetch-server` (zcaceres/fetch v1.1.2) declara la capability `resources` sin implementarla y responde `-32601` (Method not found), lo que OpenCode registra como *"failed to get resources"*. Para conservar las 6 tools y eliminar el warning se usa el proxy `~/.config/opencode/mcp-fetch-fix.js`, que arranca `npx -y mcp-fetch-server` y quita la clave `resources` del mensaje `initialize`. El maintainer del servidor lo considera "expected behavior" (issue #26), así que no se corrige upstream.

### Dependencias npm

### Archivo: `~/.config/opencode/package.json`

```json
{
  "dependencies": {
    "@opencode-ai/plugin": "1.18.18"
  }
}
```

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `@opencode-ai/plugin` | 1.18.18 | SDK para desarrollar plugins de OpenCode |

> 📌 El `package.json` solo contiene el SDK de plugins de OpenCode. No incluye
> `@ai-sdk/*` ni `@renjfk/opencode-voice`: esos se gestionan por otras vías
> (el plugin de voz `opencode-voice-modified` es una copia local, no se instala
> desde npm, y los SDK de AI los resuelve el propio binario de OpenCode).
