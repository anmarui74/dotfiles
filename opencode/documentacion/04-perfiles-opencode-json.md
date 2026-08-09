# 📋 Los Tres Perfiles de `opencode.json`

> **Fecha:** 26/07/2026 | **Usuario:** Antonio

---

## Índice

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

Existen **tres archivos** de configuración principal para OpenCode, más un archivo complementario:

| Archivo | Propósito |
|---------|-----------|
| `opencode.json` | **Activo** - Configuración en uso actualmente |
| `opencode-local.json` | Perfil **local** - Solo MCPs esenciales |
| `opencode-cloud.json` | Perfil **cloud** - Todos los MCPs activos |
| `opencode.jsonc` | Configuración de shell |

Los tres archivos están en `~/.config/opencode/`. Para cambiar entre local y cloud se usa el script `switch-mcp-profile.sh`.

---

## Perfil activo

### Archivo: `~/.config/opencode/opencode.json`

Actualmente es el mismo que `opencode-cloud.json` (todos los MCPs activos).

```json
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "/usr/bin/zsh",
  "small_model": "lmstudio/models-qwen3.5-9b",
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
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "plan": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "local": {
      "description": "Agente local - Qwen 3.5",
      "mode": "subagent",
      "model": "lmstudio/models-qwen3.5-9b"
    },
    "cloud": {
      "description": "Agente cloud para modelos en la nube (Claude, Gemini, OpenCode Go)",
      "mode": "primary",
      "model": "opencode-go/deepseek-v4-flash"
    }
  },
  "provider": {
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Qwen 3.5 Q6_K",
      "model": "models-qwen3.5-9b",
      "options": {"baseURL": "http://localhost:4001/v1"},
      "models": {
        "models-qwen3.5-9b": {
          "name": "Qwen 3.5 - Tool Calling Excellence",
          "tools": true,
          "limit": {"context": 81920, "output": 8192}
        }
      }
    }
  },
  "mcp": {
    "context7": {"type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": true},
    "filesystem": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/antonio"], "enabled": true},
    "memory": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-memory"], "enabled": true},
    "fetch": {"type": "local", "command": ["npx", "-y", "mcp-fetch-server"], "enabled": true},
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
  "small_model": "lmstudio/models-qwen3.5-9b",
  "instructions": ["AGENTS.md"],
  "default_agent": "local",
  "permission": {
    "edit": "ask",
    "bash": { "sudo *": "deny", "pkexec *": "allow", "*": "ask" }
  },
  "agent": {
    "build": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "plan": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "local": {
      "description": "Agente local - Qwen 3.5 Q6_K optimizado (80k contexto)",
      "mode": "primary",
      "model": "lmstudio/models-qwen3.5-9b"
    }
  },
  "provider": {
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Qwen 3.5 Q6_K",
      "model": "models-qwen3.5-9b",
      "options": {"baseURL": "http://localhost:4001/v1"},
      "models": {
        "models-qwen3.5-9b": {
          "name": "Qwen 3.5 - Tool Calling Excellence",
          "tools": true,
          "limit": {"context": 81920, "output": 8192}
        }
      }
    }
  },
  "mcp": {
    "context7": {"type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": false},
    "filesystem": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/antonio"], "enabled": true},
    "memory": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-memory"], "enabled": true},
    "fetch": {"type": "local", "command": ["npx", "-y", "mcp-fetch-server"], "enabled": true},
    "sequential_thinking": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"], "enabled": false}
  }
}
```

---

## Perfil cloud

### Archivo: `~/.config/opencode/opencode-cloud.json`

Es idéntico al activo (`opencode.json`). Ver [sección del perfil activo](#perfil-activo).

---

## Comparativa

| Aspecto | Local | Cloud |
|---------|-------|-------|
| **Agentes** | `build`, `plan`, `local` | `build`, `plan`, `local`, `cloud` |
| **Agente principal** | `local` (Qwen 3.5 local) | `cloud` (OpenCode Go: deepseek-v4-flash) |
| **Modelo local** | ✅ Qwen 3.5 Q6_K | ✅ Qwen 3.5 Q6_K (subagente) |
| **Modelo cloud** | ❌ No | ✅ OpenCode Go (deepseek-v4-flash) |
| **context7** | ❌ | ✅ |
| **filesystem** | ✅ | ✅ |
| **memory** | ✅ | ✅ |
| **fetch** | ✅ | ✅ |
| **sequential_thinking** | ❌ | ✅ |
| **Uso típico** | Tareas locales sin internet | Tareas complejas con todo activo |

### ¿Cuándo usar cada perfil?

| Perfil | Cuándo usarlo |
|--------|--------------|
| **Local** | Cuando trabajes offline o quieras que todo el procesamiento sea local (privacidad). Menos MCPs activos (context7 y sequential_thinking desactivados). |
| **Cloud** | Cuando necesites toda la potencia: documentación (context7), razonamiento estructurado (sequential_thinking) y modelos en la nube (OpenCode Go). |

---

## Archivo `opencode.jsonc`

### Archivo: `~/.config/opencode/opencode.jsonc`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "/usr/bin/zsh"
}
```

Define el **shell** que usa OpenCode para ejecutar comandos bash. En este caso, `/usr/bin/zsh` (Z shell).

---

## Cambio entre perfiles

### Script: `~/.config/opencode/switch-mcp-profile.sh`

```bash
# Cambiar a perfil local
bash ~/.config/opencode/switch-mcp-profile.sh local

# Cambiar a perfil cloud
bash ~/.config/opencode/switch-mcp-profile.sh cloud
```

### ¿Cómo funciona?

Simplemente copia el archivo correspondiente sobre `opencode.json`:

```bash
cp "$CONFIG_DIR/opencode-$PROFILE.json" "$CONFIG_DIR/opencode.json"
```

> ⚠️ **Importante:** Hay que reiniciar OpenCode para que los cambios surtan efecto.

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

- **build:** Agente especial para tareas de construcción (lee AGENTS.md al inicio)
- **plan:** Agente especial para planificación (lee AGENTS.md al inicio)
- **local:** Agente local, usa el modelo Qwen 3.5 Q6_K vía LM Studio (puerto 4001). En el perfil activo es **subagente**
- **cloud:** Agente principal del perfil activo, usa **OpenCode Go** (`opencode-go/deepseek-v4-flash`)

Cada agente puede tener su propio modelo y prompt de sistema.

### `provider`
Proveedores de modelos. Actualmente solo `lmstudio`, configurado como:

- **SDK:** `@ai-sdk/openai-compatible` (interfaz OpenAI para LM Studio)
- **URL:** `http://localhost:4001/v1` (proxy local)
- **Modelo:** `models-qwen3.5-9b`
- **Límites:** 81.920 tokens de contexto, 8.192 de salida
- **Tools:** Habilitadas

### `mcp`
Servidores MCP (Model Context Protocol). Cada uno proporciona **herramientas** que el modelo puede usar:

| MCP | Tipo | Comando/URL | Qué hace |
|-----|------|-------------|----------|
| **context7** | Remote | `https://mcp.context7.com/mcp` | Documentación técnica actualizada |
| **filesystem** | Local | `@modelcontextprotocol/server-filesystem` | Leer/escribir archivos |
| **memory** | Local | `@modelcontextprotocol/server-memory` | Grafo de conocimiento persistente |
| **fetch** | Local | `mcp-fetch-server` | Obtener contenido web |
| **sequential_thinking** | Local | `@modelcontextprotocol/server-sequential-thinking` | Razonamiento estructurado paso a paso |

### Dependencias npm

### Archivo: `~/.config/opencode/package.json`

```json
{
  "dependencies": {
    "@ai-sdk/openai": "^4.0.11",
    "@ai-sdk/openai-compatible": "^3.0.7",
    "@opencode-ai/plugin": "1.17.13",
    "@renjfk/opencode-voice": "^0.6.0"
  }
}
```

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `@ai-sdk/openai` | ^4.0.11 | SDK de AI para OpenAI |
| `@ai-sdk/openai-compatible` | ^3.0.7 | SDK para APIs compatibles con OpenAI (LM Studio) |
| `@opencode-ai/plugin` | 1.17.13 | SDK para desarrollar plugins de OpenCode |
| `@renjfk/opencode-voice` | ^0.6.0 | Plugin de voz (declarado pero no instalado desde npm - se usa copia local modificada) |
