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
  "small_model": "lmstudio/qwen/qwen3.5-9b",
  "instructions": ["AGENTS.md"],
  "default_agent": "local",
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
      "mode": "primary",
      "model": "lmstudio/qwen/qwen3.5-9b"
    },
    "cloud": {
      "description": "Agente para modelos cloud",
      "mode": "primary",
      "model": "anthropic/claude-sonnet-4-20250514"
    }
  },
  "provider": {
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Qwen 3.5",
      "model": "qwen/qwen3.5-9b",
      "options": {"baseURL": "http://localhost:4001/v1"},
      "models": {
        "qwen/qwen3.5-9b": {
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
    "sequential_thinking": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"], "enabled": true},
    "duckduckgo_search": {"type": "local", "command": ["duckduckgo-mcp-server"], "enabled": true}
  }
}
```

---

## Perfil local

### Archivo: `~/.config/opencode/opencode-local.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "small_model": "lmstudio/qwen/qwen3.5-9b",
  "instructions": ["AGENTS.md"],
  "default_agent": "local",
  "permission": {
    "edit": "ask",
    "bash": { "sudo *": "deny", "pkexec *": "allow", "*": "ask" }
  },
  "agent": {
    "local": {
      "description": "Agente local - Qwen 3.5 optimizado",
      "mode": "primary",
      "model": "lmstudio/qwen/qwen3.5-9b"
    }
  },
  "provider": {
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Qwen 3.5",
      "model": "qwen/qwen3.5-9b",
      "options": {"baseURL": "http://localhost:4001/v1"},
      "models": {
        "qwen/qwen3.5-9b": {
          "name": "Qwen 3.5 - Tool Calling Excellence",
          "tools": true,
          "limit": {"context": 81920, "output": 8192}
        }
      }
    }
  },
  "mcp": {
    "context7": {"enabled": false},
    "filesystem": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/antonio"], "enabled": true},
    "memory": {"enabled": false},
    "fetch": {"type": "local", "command": ["npx", "-y", "mcp-fetch-server"], "enabled": true},
    "sequential_thinking": {"enabled": false},
    "duckduckgo_search": {"enabled": false}
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
| **Agentes** | Solo `local` | `build`, `plan`, `local`, `cloud` |
| **Modelo local** | ✅ Qwen 3.5 | ✅ Qwen 3.5 |
| **Modelo cloud** | ❌ No | ✅ Claude Sonnet 4 |
| **context7** | ❌ | ✅ |
| **filesystem** | ✅ | ✅ |
| **memory** | ❌ | ✅ |
| **fetch** | ✅ | ✅ |
| **sequential_thinking** | ❌ | ✅ |
| **duckduckgo_search** | ❌ | ✅ |
| **Uso típico** | Tareas simples/sin internet | Tareas complejas/con internet |

### ¿Cuándo usar cada perfil?

| Perfil | Cuándo usarlo |
|--------|--------------|
| **Local** | Cuando trabajes offline, tareas que no requieran búsqueda web ni memoria persistente. Menos consumo de VRAM (solo filesystem + fetch). |
| **Cloud** | Cuando necesites toda la potencia: documentación (context7), búsqueda web (duckduckgo), memoria persistente, razonamiento estructurado (sequential_thinking). |

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
- **local:** Modo principal, usa el modelo local Qwen 3.5
- **cloud:** Modo cloud, usa Claude Sonnet 4 (requiere API key de Anthropic)

Cada agente puede tener su propio modelo y prompt de sistema.

### `provider`
Proveedores de modelos. Actualmente solo `lmstudio`, configurado como:

- **SDK:** `@ai-sdk/openai-compatible` (interfaz OpenAI para LM Studio)
- **URL:** `http://localhost:4001/v1` (proxy local)
- **Modelo:** `qwen/qwen3.5-9b`
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
| **duckduckgo_search** | Local | `duckduckgo-mcp-server` | Búsqueda web |

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
