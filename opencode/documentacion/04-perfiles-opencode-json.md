# 📋 Los Tres Perfiles de `opencode.json`

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 📁 Perfiles | 26/07/2026 · rev. 22/09/2026 | Antonio |

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

### 🧬 Herencia: el perfil activo es la base (11/09/2026)

OpenCode **fusiona** todos los archivos de configuración (el global `opencode.json` y
luego el `OPENCODE_CONFIG` del perfil). Por eso `opencode.json` actúa como **base común**:

- `opencode.json` define TODO lo compartido: `shell`, `model`, `agents.title.model`,
  `permissions`, `providers` (NVIDIA + LM Studio, incluida la `whitelist`), `mcp.servers`,
  `agents` y las descripciones de los agentes. Usa la **sintaxis canónica de V2**.
- `opencode-local.json` y `opencode-cloud.json` contienen **solo lo que difiere** de la
  base; el resto se **hereda** automáticamente.

Ventaja: cambiar los `permissions` o la `whitelist` de NVIDIA solo requiere tocar
`opencode.json`. Antes estaban duplicados en los tres archivos (~330 líneas redundantes).

> ⚠️ Los perfiles **no son autónomos**: se lanzan siempre junto al global
> (`~/.config/opencode/opencode.json`). Si se copiara solo `opencode-local.json` a otro
> sistema sin el global, faltarían `permissions`, `providers`, etc.
>
> 📌 **Sintaxis V2 (19/09/2026):** los 3 perfiles usan las claves de la wiki V2
> (`providers`, `agents`, `permissions`, `mcp.servers`, `system`, `disabled`). V2 también
> acepta las claves V1 (`provider`, `agent`, `permission`, `mcp` plano…) y las migra
> automáticamente, pero ya no se usan. ⚠️ El schema público `opencode.ai/config.json` aún
> solo valida las claves V1: el editor puede marcar las V2 como desconocidas.

---

## Perfil activo

### Archivo: `~/.config/opencode/opencode.json`

Perfil por defecto (para `ocv` / `opencode`). Tiene **todos los agentes activos** (local, cloud y NVIDIA) y **todos los MCPs activos**.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "/usr/bin/zsh",
  "model": "opencode-go/deepseek-v4.1-flash",
  "default_agent": "cloud",
  "permissions": [
    { "action": "edit", "resource": "*", "effect": "ask" },
    { "action": "shell", "resource": "*", "effect": "ask" },
    { "action": "shell", "resource": "sudo *", "effect": "deny" },
    { "action": "shell", "resource": "pkexec *", "effect": "allow" }
  ],
  "agents": {
    "title": {
      "model": "local/qwen3.8-9b"
    },
    "build": {
      "model": "opencode-go/deepseek-v4.1-flash",
      "system": "{file:./prompts/read-agents.txt}"
    },
    "plan": {
      "model": "opencode-go/deepseek-v4.1-flash",
      "system": "{file:./prompts/read-agents.txt}"
    },
    "local": {
      "description": "Agente local - Qwen 3.8 Q6_K optimizado (80k contexto)",
      "mode": "primary",
      "model": "local/qwen3.8-9b"
    },
    "cloud": {
      "description": "Agente cloud predeterminado - DeepSeek V4.1 Flash vía OpenCode Go: pipeline diario de código y agentic coding",
      "mode": "primary",
      "model": "opencode-go/deepseek-v4.1-flash",
      "permissions": [
        { "action": "subagent", "resource": "*", "effect": "allow" }
      ]
    },
    "nvidia": {
      "description": "Agente NVIDIA - NVIDIA Nemotron 3 Super 120B (A12B): ~74 tok/s medida, tool calling nativo, gratis vía NIM. Predeterminado del agente nvidia desde el 17/09/2026 (antes Muse Glimmer 30B). Usable como primario (Shift+Tab) y como subagente delegado por DeepSeek",
      "mode": "all",
      "model": "nvidia/nvidia/nemotron-3-super-120b-a12b"
    },
    "multimodal": {
      "description": "Agente multimodal - MiMo V2.5 (Xiaomi, 311B MoE, 1M contexto, omnimodal). Usable como primario (Shift+Tab) y como subagente delegado",
      "mode": "all",
      "model": "opencode-go/mimo-v2.5",
      "system": "Eres un asistente multimodal experto. Analiza imágenes, screenshots y documentos junto con el texto. Para contextos largos, resume, extrae key points y responde con referencias precisas."
    }
  },
  "providers": {
    "nvidia": {
      "whitelist": [
        "meta/muse-glimmer-30b",
        "meta/llama-3.2-11b-vision-instruct",
        "openai/gpt-oss-20b",
        "nvidia/nemotron-3-ultra-550b-a55b",
        "nvidia/nemotron-3-super-120b-a12b",
        "nvidia/nemotron-3.5-lightning-30b-a3b",
        "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning"
      ],
      "settings": {
        "timeout": 600000,
        "chunkTimeout": 60000
      },
      "body": {
        "temperature": 1,
        "top_p": 0.95
      }
    },
    "local": {
      "name": "LM Studio (Qwen 3.8)",
      "env": ["LMSTUDIO_API_KEY"],
      "package": "@opencode/ai/providers/openai-compatible",
      "settings": {
        "baseURL": "http://localhost:4001/v1",
        "apiKey": "lm-studio"
      },
      "models": {
        "qwen3.8-9b": {
          "name": "Qwen 3.8 - Tool Calling Excellence",
          "capabilities": { "tools": true, "input": ["text"], "output": ["text"] },
          "limit": { "context": 81920, "output": 8192 }
        }
      }
    }
  },
  "mcp": {
    "servers": {
      "context7": {
        "type": "remote",
        "url": "https://mcp.context7.com/mcp"
      },
      "filesystem": {
        "type": "local",
        "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/antonio"]
      },
      "memory": {
        "type": "local",
        "command": ["npx", "-y", "@modelcontextprotocol/server-memory"],
        "environment": {"MEMORY_FILE_PATH": "/home/antonio/.config/opencode/data/memory/memory.jsonl"}
      },
      "fetch": {
        "type": "local",
        "command": ["node", "/home/antonio/.config/opencode/mcp-fetch-fix.js"]
      },
      "sequential_thinking": {
        "type": "local",
        "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"]
      }
    }
  }
}
```

---

## Perfil local

### Archivo: `~/.config/opencode/opencode-local.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "local",
  "model": "local/qwen3.8-9b",
  "mcp": {
    "servers": {
      "context7": {
        "type": "remote",
        "url": "https://mcp.context7.com/mcp",
        "disabled": true
      },
      "sequential_thinking": {
        "type": "local",
        "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"],
        "disabled": true
      }
    }
  }
}
```

> 📌 Para desactivar un servidor MCP en V2 hay que **repetir su definición completa** con
> `"disabled": true` (un override parcial `{"disabled": true}` se descarta al fusionar).

---

## Perfil cloud

### Archivo: `~/.config/opencode/opencode-cloud.json`

Perfil para `ocv-cloud` / `opencode-cloud`. Tiene **todos los MCPs activos** y el agente
local **desactivado** (`agents.local.disabled: true`). Como el modelo local no se va a
usar, el agente oculto `title` apunta a la nube (`agents.title.model` =
`opencode-go/deepseek-v4.1-flash`) y el lanzador no carga el modelo en VRAM (`SKIP_LMSTUDIO=1`).

Solo contiene lo que **difiere** de `opencode.json` (el resto se hereda):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "cloud",
  "experimental": {
    "policies": [
      { "action": "provider.use", "resource": "lmstudio", "effect": "deny" },
      { "action": "provider.use", "resource": "local", "effect": "deny" }
    ]
  },
  "agents": {
    "title": {
      "model": "opencode-go/deepseek-v4.1-flash"
    },
    "local": {
      "description": "Agente local desactivado en perfil cloud",
      "disabled": true
    }
  }
}
```

Diferencias respecto a `opencode.json` (por defecto):
- `experimental.policies`: bloquea el provider LM Studio builtin (`lmstudio`) **y** el provider
  propio `local` (el proxy del puerto 4001) con `action: provider.use` → `effect: deny`
  (sustituye al antiguo `disabled_providers`, canonizado el 21/09/2026)
- `agents.title.model`: el agente oculto `title` apunta a la nube (en `opencode.json` usa `local/qwen3.8-9b`)
- Agente `local`: `disabled: true` (en `opencode.json` es el agente activo)

---

## Comparativa

| Aspecto | `opencode.json` (defecto) | Local | Cloud |
|---------|---------------------------|-------|-------|
| **Agentes** | `build`, `plan`, `local`, `cloud`, `nvidia` (all), `multimodal` (all) | `build`, `plan`, `local`, `cloud`, `nvidia` (all), `multimodal` (all) | `build`, `plan`, `cloud`, `nvidia` (all), `multimodal` (all) |
| **Agente principal** | `cloud` (OpenCode Go) | `local` (Qwen 3.8 local) | `cloud` (OpenCode Go) |
| **Agente local** | ✅ activo (primario) | ✅ activo (primario) | ❌ desactivado |
| **Modelo cloud** | ✅ OpenCode Go (deepseek-v4.1-flash) | ✅ OpenCode Go (deepseek-v4.1-flash) | ✅ OpenCode Go (deepseek-v4.1-flash) |
| **Agente NVIDIA** | ✅ primario/subagente Nemotron 3 Super 120B | ✅ primario/subagente Nemotron 3 Super 120B | ✅ primario/subagente Nemotron 3 Super 120B |
| **Agente multimodal** | ✅ primario/subagente MiMo V2.5 (`opencode-go/mimo-v2.5`) | ✅ primario/subagente (heredado de global) | ✅ primario/subagente (heredado de global) |
| **context7** | ✅ | ❌ | ✅ |
| **filesystem** | ✅ | ✅ | ✅ |
| **memory** | ✅ | ✅ | ✅ |
| **fetch** | ✅ | ✅ | ✅ |
| **sequential_thinking** | ✅ | ❌ | ✅ |
| **LSPs** | ❌ (V2 no los ejecuta; bloque `lsp` retirado) | — | — |
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

### `model` (raíz)
Modelo por defecto de la sesión: `opencode-go/deepseek-v4.1-flash` en base/cloud y `local/qwen3.8-9b` en local. Se añadió el **21/09/2026** para fijarlo explícitamente.

### `agents.title.model` (antes `small_model`)
Modelo del agente oculto `title`, usado para tareas **ligeras** (título de sesión, resúmenes rápidos, clasificaciones): `local/qwen3.8-9b` en `opencode.json` y en local; `opencode-go/deepseek-v4.1-flash` en cloud. Sustituye a la clave V1 `small_model` (canonizado el 21/09/2026).

### `instructions` — ❌ retirado
V2 acepta el campo `instructions` pero **no carga sus entradas**; `AGENTS.md` se descubre
automáticamente. Se retiró de `opencode.json` el **19/09/2026** por ser inerte.

### `default_agent`
Agente que se usa por defecto cuando no se especifica otro.

### `permissions` (sintaxis V2; antes `permission`)
Lista **ordenada** de reglas `{action, resource, effect}`. Gana la **última** que coincida:

```json
"permissions": [
  { "action": "edit",   "resource": "*",        "effect": "ask" },
  { "action": "shell",  "resource": "*",        "effect": "ask" },
  { "action": "shell",  "resource": "sudo *",   "effect": "deny" },
  { "action": "shell",  "resource": "pkexec *", "effect": "allow" }
]
```

- `action`: `edit`, `shell` (antes `bash`), `read`, `subagent` (antes `task`), `skill`, etc.
- `resource`: comando, ruta o ID sobre el que se actúa.
- `effect`: `allow`, `ask` o `deny`.

> 📌 Esta sección vive solo en `opencode.json` (global); `opencode-local.json` y
> `opencode-cloud.json` la **heredan** por fusión.

### `agents` (sintaxis V2; antes `agent`)
Define agentes (personas/modos del asistente):

- **build:** Agente especial para tareas de construcción (lee AGENTS.md al inicio). Desde el **18/08/2026** usa **DeepSeek V4 Flash** como modelo explícito
- **plan:** Agente especial para planificación (lee AGENTS.md al inicio)
- **local:** Agente local, usa el modelo Qwen 3.8 Q6_K vía LM Studio (puerto 4001). Es **primario** en el perfil activo y en el perfil local; **desactivado** (`disabled: true`) en el perfil cloud
- **cloud:** Agente principal del perfil activo, usa **OpenCode Go** (`opencode-go/deepseek-v4.1-flash`). Desde el **09/09/2026** tiene la regla `{ "action": "subagent", "resource": "*", "effect": "allow" }`, lo que le permite **delegar automáticamente** a los subagentes (nvidia, multimodal, general, explore)
- **nvidia:** `mode: all` (primario y subagente), usa por defecto **NVIDIA Nemotron 3 Super 120B (A12B)** (`nvidia/nvidia/nemotron-3-super-120b-a12b`) desde el **17/09/2026** (antes Muse Glimmer 30B). ~74 tok/s medidas, tool calling nativo. DeepSeek lo invoca automáticamente para código pesado
- **multimodal:** `mode: all` (solo en `opencode.json`; heredado por fusión en local y cloud), usa **MiMo V2.5** (`opencode-go/mimo-v2.5`, Xiaomi, 311B MoE, 1M contexto, omnimodal) con prompt optimizado para imagen + texto y recuperación de contexto largo. (Antes usaba `opencode-go/deepseek-v4.1-flash#multimodal`.)

Campos por agente: `system` para el prompt (antes `prompt`), `model`
(`provider/model`, con `#variante` opcional), `permissions` (antes `permission`) y
`mode` (`primary` / `subagent` / `all`).

### `providers` (sintaxis V2; antes `provider`)
Proveedores de modelos. Configurados:

- **local** (LM Studio, provider propio):
  - **Paquete:** `@opencode/ai/providers/openai-compatible`
  - **URL:** `http://localhost:4001/v1` (proxy local)
  - **Modelo:** `qwen3.8-9b`
  - **Límites:** 81.920 tokens de contexto, 8.192 de salida
  - **Tools:** Habilitadas

- **nvidia** (cloud, desde el **18/08/2026**):
  - **Modelo agente:** `nvidia/nvidia/nemotron-3-super-120b-a12b` (NVIDIA Nemotron 3 Super 120B A12B; antes Muse Glimmer 30B)
  - **Whitelist:** 7 modelos operativos (rev. **11/09/2026**: se retiró `minimaxai/minimax-m3`, verificado con HTTP 410 Gone, fin de vida el 09/09/2026). Vive en `providers.nvidia.whitelist`: V2 **ignora** esta clave (no tiene equivalente V2) y la aplica el plugin `nvidia-filter`.
  - **Parámetros:** `providers.nvidia.body` = `{temperature: 1, top_p: 0.95}`. ⚠️ V2 **descarta** `temperature`/`top_p` a nivel de agente; hay que ponerlos en el provider, el modelo o una variante.
  - **API Key:** `nvapi-*` (en `auth.json` de OpenCode)
  - **Endpoint:** `https://integrate.api.nvidia.com/v1`
  - ⚠️ **Nota 18/08/2026:** `z-ai/glm-5.2` estaba saturado (HTTP 429) por rate limit de NVIDIA. **Retirado el 05/09/2026** (HTTP 410 Gone, fin de vida el 21/08/2026)
  - **Verificación 05/09/2026:** de los 22 modelos del whitelist original, 14 fueron retirados (HTTP 410 Gone, end of life entre el 21/08 y el 03/09/2026) y se eliminaron. Se probaron los modelos nuevos del catálogo NVIDIA (81 totales) midiendo velocidad real y tool calling: todos descartados (lentos <6 tok/s, sin tool calling o sin endpoint de chat HTTP 404). La lista quedó en **7 modelos** tras retirar `minimaxai/minimax-m3` el 11/09/2026 (antes 8).

#### 🏆 Ranking y metodología de selección de modelos NVIDIA (05/09/2026)

> **Criterio principal:** un modelo solo es útil en OpenCode si soporta **tool calling** (llamada a herramientas: bash, edición, búsqueda...). Un modelo sin tools o que genere a menos de ~10 tok/s es inutilizable como agente. Se priorizó la velocidad sobre otras características: no sirve un modelo que tarda minutos en responder.

**Metodología (verificación en vivo contra `https://integrate.api.nvidia.com/v1`):**

1. **Catálogo:** se consultó `GET /v1/models` (81 modelos disponibles, sin paginación; `limit=1000` confirma el mismo total).
2. **HTTP 200 real:** se envió una petición `POST /chat/completions` real a cada candidato. Los modelos listados en el catálogo pero sin endpoint de chat desplegado devuelven **HTTP 404** (unos 30) → descartados.
3. **Velocidad:** generación real de ~180 tokens con `max_tokens` amplio (no limitado a 5) midiendo `tokens/segundo` reales. Los que no llegan a ~10 tok/s se descartan (inutilizables como agente).
4. **Tool calling:** petición con `tools: [get_current_time]` y `tool_choice: auto`. Se exige que la respuesta contenga `tool_calls` reales.
5. **Reintento de sobrecarga:** los que fallaron con timeout / 429 / 503 / 500 se reintentaron con más margen antes de decidir.

**Resultado del ranking (los 7 del whitelist, ordenados de mejor a peor):**

| # | Modelo | Velocidad | Tool calling | Veredicto |
|---|--------|-----------|--------------|-----------|
| 1 | `meta/muse-glimmer-30b` | 144,9 tok/s | ✅ | ⭐⭐⭐⭐⭐ *(agente nvidia del 05/09 al 17/09/2026)* |
| 2 | `nvidia/nemotron-3.5-lightning-30b-a3b` | 119,6 tok/s | ✅ | ⭐⭐⭐⭐⭐ |
| 3 | `nvidia/nemotron-3-super-120b-a12b` | 93,4 tok/s | ✅ | ⭐⭐⭐⭐ *(agente nvidia desde 17/09/2026)* |
| 4 | `nvidia/nemotron-3-ultra-550b-a55b` | 74,5 tok/s | ✅ | ⭐⭐⭐⭐ |
| 5 | `meta/llama-3.2-11b-vision-instruct` | 50,7 tok/s | ✅ | ⭐⭐⭐⭐ |
| 6 | `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` | 40,3 tok/s | ✅ | ⭐⭐⭐⭐ |
| 7 | `openai/gpt-oss-20b` | 34,2 tok/s | ✅ | ⭐⭐⭐⭐ |

> ⚠️ **Actualización 11/09/2026:** `minimaxai/minimax-m3` (45,2 tok/s, puesto 6) fue **retirado** por NVIDIA — HTTP 410 Gone, fin de vida el 09/09/2026 — y eliminado del whitelist. Quedan **7 modelos**. El mismo retirado se eliminó también de los 3 perfiles de MiMoCode, que mantienen esta misma lista.

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

### `lsp` — ❌ retirado (V2)

**V2 no ejecuta servidores de lenguaje** (ni diagnósticos ni herramientas LSP). Por eso el bloque
`lsp` se **retiró** de `opencode.json` el **16/09/2026**; queda copia en
`~/Config/opencode/legacy/lsp-block-v1.json` por si una V2 futura lo recupera.

Para tipos/lint en V2 se usan comandos de terminal: `basedpyright`, `tsc --noEmit`, `cargo clippy`,
`go vet ./...`, `shellcheck`, `yamllint`, `jq empty`…

> 📚 **Histórico (V1):** V1 sí lanzaba 11 servidores LSP (basedpyright, clangd, rust-analyzer,
> typescript-language-server, gopls, vscode-json-language-server, yaml-language-server,
> bash-language-server, marksman) definidos en `opencode.json` y heredados por local/cloud.

### `mcp.servers` (sintaxis V2; antes `mcp` plano)
Servidores MCP (Model Context Protocol), bajo `mcp.servers`. Cada uno proporciona **herramientas** que el modelo puede usar:

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

El `package.json` activo está **vacío** (solo `{}`): el binario de OpenCode ya
resuelve sus propias dependencias y los plugins locales no necesitan paquetes npm
en la config activa.

```json
{}
```

`package-lock.json` es un **resto heredado** de cuando se instalaba el SDK
`@opencode-ai/plugin` (última versión anotada, `1.18.8`). Actualmente no se usa y
**ambos archivos se excluyen del backup** (`backup-opencode.sh` aplica
`--exclude=package.json` y `--exclude=package-lock.json`).

| Archivo | Estado | Propósito |
|---------|--------|-----------|
| `package.json` | `{}` (vacío) | Sin dependencias npm en la config activa |
| `package-lock.json` | Resto heredado (`@opencode-ai/plugin` 1.18.8) | Lock antiguo, no se usa ni se respalda |

> 📌 El `package.json` no incluye `@ai-sdk/*` ni `@renjfk/opencode-voice`: los SDK de AI
> los resuelve el propio binario de OpenCode, y el plugin de voz
> `opencode-voice-modified` es una copia local (no se instala desde npm).
