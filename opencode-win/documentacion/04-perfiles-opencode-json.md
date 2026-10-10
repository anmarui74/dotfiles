# 📋 Los Perfiles de OpenCode en Windows
Perfiles global, local y cloud, agentes, MCPs y proveedores en OpenCode V2

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo (V2 · 3 perfiles · LSP npx) | 10/09/2026 · rev. 10/10/2026 | Antonio |

> Config activa en `C:\Users\evo01\.config\opencode\`. Los perfiles usan la **sintaxis canónica V2** (`agents`, `providers`, `permissions`, `mcp.servers`) y se activan por lanzador.

---

## 📑 Índice

1. [Descripción general](#descripción-general)
2. [Perfil global (`opencode.jsonc`)](#perfil-global-opencodejsonc)
3. [Perfil local (`opencode-local.json`)](#perfil-local-opencode-localjson)
4. [Perfil cloud (`opencode-cloud.json`)](#perfil-cloud-opencode-cloudjson)
5. [Comparativa de perfiles](#comparativa-de-perfiles)
6. [Lanzadores (cambio entre perfiles)](#lanzadores-cambio-entre-perfiles)
7. [Agentes](#agentes)
8. [Proveedores](#proveedores)
9. [Ranking y metodología NVIDIA](#ranking-y-metodología-nvidia)
10. [MCPs](#mcps)
11. [Permisos](#permisos)
12. [LSP](#lsp)
13. [Dependencias npm](#dependencias-npm)

---

## Descripción general

OpenCode fusiona la configuración: primero el archivo indicado por `OPENCODE_CONFIG`. La **app de escritorio (V2)** lee siempre `opencode.jsonc`, que también está en **esquema V2**.

Hay **tres archivos** en `C:\Users\evo01\.config\opencode\`, todos en formato V2:

| Archivo | Propósito |
|---------|-----------|
| `opencode.jsonc` | **GLOBAL / base común** · agente `cloud` por defecto · agentes, proveedores, MCPs y `lsp` |
| `opencode-local.json` | **LOCAL** · agente `local` (Qwen 3.8 en LM Studio) · MCPs esenciales (`fetch`, `filesystem`, `memory`) y `lsp` |
| `opencode-cloud.json` | **CLOUD estricto** · agente `cloud` · bloquea los providers `lmstudio` y `local`, desactiva el agente local y mantiene `lsp` |

Cada perfil se activa con **su propia función de PowerShell** vía `OPENCODE_CONFIG`.

| Función | Config | Agente por defecto | LM Studio | MCPs | LSP |
|---------|--------|--------------------|-----------|------|-----|
| `ocv` | `opencode.jsonc` | `cloud` | ✅ Carga modelo | Todos (5) | ✅ |
| `ocv-local` | `opencode-local.json` | `local` (Qwen local) | ✅ Carga modelo | 3 esenciales | ✅ |
| `ocv-cloud` | `opencode-cloud.json` | `cloud` | ❌ No carga | Todos (5) | ✅ |

> 🔄 **Cambio del 03/10/2026:** la V1 de escritorio (winget) se sustituyó por la **app de escritorio V2** (NSIS desde `opencode.ai/download`, instalada en `%LOCALAPPDATA%\Programs\@opencodedesktop`). Al aceptar esquema V2, se unificaron los tres perfiles en V2 y se añadió `lsp` a todos (comando Python corregido a `basedpyright`).

---

## Perfil global

### Archivo: `C:\Users\evo01\.config\opencode\opencode.jsonc`

**Base común** de todos los perfiles. Define la `shell`, los agentes, los proveedores (nvidia + local), los MCPs y los permisos. Agente por defecto: `cloud`.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "powershell.exe",
  "model": "opencode-go/deepseek-v4.1-flash",
  "default_agent": "cloud",
  "permissions": [
    { "action": "edit", "resource": "*", "effect": "ask" },
    { "action": "shell", "resource": "*", "effect": "ask" },
    { "action": "shell", "resource": "sudo *", "effect": "deny" },
    { "action": "shell", "resource": "pkexec *", "effect": "allow" }
  ],
  "agents": {
    "title":    { "model": "local/qwen3.8-9b" },
    "build":    { "model": "opencode-go/deepseek-v4.1-flash", "system": "{file:./prompts/read-agents.txt}" },
    "plan":     { "model": "opencode-go/deepseek-v4.1-flash", "system": "{file:./prompts/read-agents.txt}" },
    "local":    { "description": "Agente local - Qwen 3.8 Q6_K optimizado (80k contexto)", "mode": "primary", "model": "local/qwen3.8-9b" },
    "cloud":    { "description": "Agente cloud predeterminado - DeepSeek V4.1 Flash vía OpenCode Go", "mode": "primary", "model": "opencode-go/deepseek-v4.1-flash",
                  "permissions": [ { "action": "subagent", "resource": "*", "effect": "allow" } ] },
    "nvidia":   { "description": "Agente NVIDIA - Nemotron 3 Ultra 550B (A55B)", "mode": "all", "model": "nvidia/nvidia/nemotron-3-ultra-550b-a55b" },
    "multimodal": { "description": "Agente multimodal - MiMo-V2.6-Flash (OpenCode Go)", "mode": "all", "model": "opencode-go/mimo-v2.6-flash",
                    "system": "Eres un asistente multimodal experto. Analiza imagenes, screenshots y documentos junto con el texto." }
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
      "settings": { "timeout": 600000, "chunkTimeout": 60000 },
      "body": { "temperature": 1, "top_p": 0.95 }
    },
    "local": {
      "name": "LM Studio (Qwen 3.8)",
      "env": [ "LMSTUDIO_API_KEY" ],
      "package": "@opencode/ai/providers/openai-compatible",
      "settings": { "baseURL": "http://localhost:4001/v1", "apiKey": "lm-studio" },
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
      "context7":            { "type": "remote", "url": "https://mcp.context7.com/mcp" },
      "filesystem":          { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "C:/Users/evo01"] },
      "memory":              { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-memory"],
                               "environment": { "MEMORY_FILE_PATH": "C:/Users/evo01/.config/opencode/data/memory/memory.jsonl" } },
      "fetch":               { "type": "local", "command": ["npx", "-y", "mcp-fetch-server"] },
      "sequential_thinking": { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"] }
    }
  },
  "lsp": {
    "python":     { "command": ["npx", "-y", "basedpyright", "--stdio"],              "extensions": [".py", ".pyw"] },
    "typescript": { "command": ["npx", "-y", "typescript-language-server", "--stdio"], "extensions": [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"] },
    "json":       { "command": ["npx", "-y", "vscode-json-languageserver", "--stdio"], "extensions": [".json", ".jsonc"] },
    "yaml":       { "command": ["npx", "-y", "yaml-language-server", "--stdio"],       "extensions": [".yaml", ".yml"] },
    "bash":       { "command": ["npx", "-y", "bash-language-server", "start"],         "extensions": [".sh", ".bash"] },
    "zsh":        { "command": ["npx", "-y", "bash-language-server", "start"],         "extensions": [".zsh", ".zshrc"] },
    "markdown":   { "command": ["npx", "-y", "vscode-markdown-language-server", "--stdio"], "extensions": [".md", ".markdown"] },
    "go":         { "command": ["npx", "-y", "gopls"],                                 "extensions": [".go"] },
    "rust":       { "command": ["npx", "-y", "rust-analyzer"],                         "extensions": [".rs"] },
    "c":          { "command": ["npx", "-y", "clangd"],                                "extensions": [".c", ".h"] },
    "cpp":        { "command": ["npx", "-y", "clangd"],                                "extensions": [".cpp", ".hpp", ".cc", ".cxx"] }
  }
}
```

---

## Perfil local

### Archivo: `C:\Users\evo01\.config\opencode\opencode-local.json`

Perfil para `ocv` / `ocv-local`. Solo contiene **lo que difiere** de la base: el agente por defecto, el modelo y los MCPs esenciales.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "powershell.exe",
  "default_agent": "local",
  "model": "local/qwen3.8-9b",
  "mcp": {
    "servers": {
      "context7":            { "type": "remote", "url": "https://mcp.context7.com/mcp", "disabled": true },
      "sequential_thinking": { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"], "disabled": true },
      "filesystem":          { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "C:/Users/evo01"] },
      "memory":              { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-memory"],
                               "environment": { "MEMORY_FILE_PATH": "C:/Users/evo01/.config/opencode/data/memory/memory.jsonl" } },
      "fetch":               { "type": "local", "command": ["npx", "-y", "mcp-fetch-server"] }
    }
  },
  "lsp": {
    "python":     { "command": ["npx", "-y", "basedpyright", "--stdio"],              "extensions": [".py", ".pyw"] },
    "typescript": { "command": ["npx", "-y", "typescript-language-server", "--stdio"], "extensions": [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"] },
    "json":       { "command": ["npx", "-y", "vscode-json-languageserver", "--stdio"], "extensions": [".json", ".jsonc"] },
    "yaml":       { "command": ["npx", "-y", "yaml-language-server", "--stdio"],       "extensions": [".yaml", ".yml"] },
    "bash":       { "command": ["npx", "-y", "bash-language-server", "start"],         "extensions": [".sh", ".bash"] },
    "zsh":        { "command": ["npx", "-y", "bash-language-server", "start"],         "extensions": [".zsh", ".zshrc"] },
    "markdown":   { "command": ["npx", "-y", "vscode-markdown-language-server", "--stdio"], "extensions": [".md", ".markdown"] },
    "go":         { "command": ["npx", "-y", "gopls"],                                 "extensions": [".go"] },
    "rust":       { "command": ["npx", "-y", "rust-analyzer"],                         "extensions": [".rs"] },
    "c":          { "command": ["npx", "-y", "clangd"],                                "extensions": [".c", ".h"] },
    "cpp":        { "command": ["npx", "-y", "clangd"],                                "extensions": [".cpp", ".hpp", ".cc", ".cxx"] }
  }
}
```

Los agentes, proveedores y permisos se **heredan** de la base (`opencode.jsonc`).

---

## Perfil cloud

### Archivo: `C:\Users\evo01\.config\opencode\opencode-cloud.json`

Perfil para `ocv-cloud`. Bloquea los providers locales y desactiva el agente local, forzando todo a la nube.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "powershell.exe",
  "default_agent": "cloud",
  "experimental": {
    "policies": [
      { "action": "provider.use", "resource": "lmstudio", "effect": "deny" },
      { "action": "provider.use", "resource": "local",    "effect": "deny" }
    ]
  },
  "agents": {
    "title": { "model": "opencode-go/deepseek-v4.1-flash" },
    "local": { "description": "Agente local desactivado en perfil cloud", "disabled": true }
  },
  "lsp": {
    "python":     { "command": ["npx", "-y", "basedpyright", "--stdio"],              "extensions": [".py", ".pyw"] },
    "typescript": { "command": ["npx", "-y", "typescript-language-server", "--stdio"], "extensions": [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"] },
    "json":       { "command": ["npx", "-y", "vscode-json-languageserver", "--stdio"], "extensions": [".json", ".jsonc"] },
    "yaml":       { "command": ["npx", "-y", "yaml-language-server", "--stdio"],       "extensions": [".yaml", ".yml"] },
    "bash":       { "command": ["npx", "-y", "bash-language-server", "start"],         "extensions": [".sh", ".bash"] },
    "zsh":        { "command": ["npx", "-y", "bash-language-server", "start"],         "extensions": [".zsh", ".zshrc"] },
    "markdown":   { "command": ["npx", "-y", "vscode-markdown-language-server", "--stdio"], "extensions": [".md", ".markdown"] },
    "go":         { "command": ["npx", "-y", "gopls"],                                 "extensions": [".go"] },
    "rust":       { "command": ["npx", "-y", "rust-analyzer"],                         "extensions": [".rs"] },
    "c":          { "command": ["npx", "-y", "clangd"],                                "extensions": [".c", ".h"] },
    "cpp":        { "command": ["npx", "-y", "clangd"],                                "extensions": [".cpp", ".hpp", ".cc", ".cxx"] }
  }
}
```

El resto (agentes, proveedores, MCPs) se hereda de la base.

---

## Comparativa de perfiles

| Aspecto | `opencode.jsonc` (global) | `opencode-local.json` (local) | `opencode-cloud.json` (cloud) |
|---------|---------------------------|-------------------------------|-------------------------------|
| **Agente por defecto** | `cloud` | `local` | `cloud` |
| **Modelo raíz** | `opencode-go/deepseek-v4.1-flash` | `local/qwen3.8-9b` | (heredado) |
| **Agente local** | ✅ disponible | ✅ activo (primario) | ❌ desactivado |
| **Providers locales** | ✅ permitidos | ✅ permitidos | ❌ bloqueados (`experimental.policies`) |
| **context7** | ✅ | ❌ deshabilitado | ✅ (heredado) |
| **sequential_thinking** | ✅ | ❌ deshabilitado | ✅ (heredado) |
| **filesystem / memory / fetch** | ✅ | ✅ | ✅ (heredado) |
| **LM Studio (VRAM)** | ❌ No carga | ✅ Carga modelo | ❌ No carga |

### ¿Cuándo usar cada perfil?

| Perfil | Cuándo usarlo |
|--------|---------------|
| **`ocv`** (global) | Uso general con todos los agentes y MCPs; base común. |
| **`ocv-local`** (local) | Trabajo offline/privado con LM Studio y MCPs esenciales (menos ruido de herramientas). |
| **`ocv-cloud`** (cloud) | Todo en la nube, sin arrancar LM Studio ni permitir providers locales. |

---

## Lanzadores (cambio entre perfiles)

Definidos en `C:\Users\evo01\OneDrive\Documentos\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`. Usan `OPENCODE_CONFIG` para cargar el perfil **sin copiar nada**.

```powershell
# LOCAL: arranca LM Studio + proxy + servidor TTS y abre OpenCode con opencode-local.json
ocv-local

# GLOBAL: arranca LM Studio + proxy + servidor TTS y abre con opencode.jsonc
ocv

# CLOUD: sin LM Studio; abre con opencode-cloud.json (providers locales bloqueados)
ocv-cloud

# Estado de LM Studio, modelo, proxy y servidor TTS
ocv-status
```

Patrón de las funciones:

```powershell
function ocv {
    & "$global:OpenCodeConfigDir\start-lmstudio.ps1"   # solo en ocv / ocv-local
    Start-TtsServerIfNeeded                             # servidor Kokoro persistente
    $prev = $env:OPENCODE_CONFIG
    $env:OPENCODE_CONFIG = "$global:OpenCodeConfigDir\opencode.jsonc"
    try { if ($Rest) { opencode @Rest } else { opencode } }
    finally {
        if ($null -eq $prev) { Remove-Item Env:OPENCODE_CONFIG -ErrorAction SilentlyContinue }
        else { $env:OPENCODE_CONFIG = $prev }
    }
}
```

- `ocv` y `ocv-local` arrancan **LM Studio** (puerto 1234) + el modelo `qwen3.8-9b` (contexto 80.000) + el **proxy** (puerto 4001).
- `ocv-cloud` **no** llama a `start-lmstudio.ps1`, así que nunca arranca el modelo local.
- Los tres llaman a `Start-TtsServerIfNeeded` (servidor TTS Kokoro, ver `03-configuracion-voz.md`).

> ⚠️ Los cambios de config requieren **reiniciar OpenCode** para surtir efecto.

> ⚠️ **No aplica en Windows:** en Linux la carga del modelo se controlaba con `start-opencode-server.sh` y `SKIP_LMSTUDIO=1`; en Windows simplemente se llama o no a `start-lmstudio.ps1`.

---

## Agentes

| Agente | Modelo | Modo | Descripción |
|--------|--------|------|-------------|
| `title` | `local/qwen3.8-9b` | oculto | Genera títulos de sesión |
| `build` | `opencode-go/deepseek-v4.1-flash` | primary | Construcción de código; lee `prompts/read-agents.txt` |
| `plan` | `opencode-go/deepseek-v4.1-flash` | primary | Planificación; lee `prompts/read-agents.txt` |
| `local` | `local/qwen3.8-9b` | primary | Qwen 3.8 Q6_K en LM Studio (proxy 4001) |
| `cloud` | `opencode-go/deepseek-v4.1-flash` | primary | Predeterminado; delegación a subagentes permitida |
| `nvidia` | `nvidia/nvidia/nemotron-3-ultra-550b-a55b` | all | NVIDIA Nemotron 3 Ultra 550B (A55B), tool calling nativo vía NIM |
| `multimodal` | `opencode-go/mimo-v2.6-flash` | all | MiMo-V2.6-Flash (OpenCode Go), omnimodal |

- `mode: "all"` → usable como **primario** (ciclo de agente) y como **subagente** delegado.
- Se cambia de agente primario con **Shift+Tab** (V2); `Ctrl+X` → `A` abre la lista.
- El `system` de `build`/`plan` apunta a `prompts/read-agents.txt`.

> 💡 **Nota V2:** el `model` de un agente primario no cambia el modelo de la sesión al
> seleccionarlo (la sesión guarda el suyo); sí se aplica cuando se usa como subagente.

---

## Proveedores

- **nvidia** — `https://integrate.api.nvidia.com/v1` · API key `nvapi-*` en `auth.json`. Whitelist manual de 7 modelos (ver más abajo).
- **local** — LM Studio a través del proxy `http://localhost:4001/v1` · paquete `@opencode/ai/providers/openai-compatible` · modelo `qwen3.8-9b`.

> 💡 En V2 el id `lmstudio` no resuelve (choca con el builtin); se usa un provider propio llamado `local`.

---

## Ranking y metodología NVIDIA

> **Criterio principal:** un modelo solo es útil en OpenCode si soporta **tool calling** y genera a una velocidad razonable. Se priorizó la velocidad.

**Metodología (verificación en vivo contra `https://integrate.api.nvidia.com/v1`):**

1. **Catálogo:** `GET /v1/models` — el catálogo `models.dev` de OpenCode está **desactualizado** para NVIDIA (lista modelos retirados).
2. **HTTP 200 real:** `POST /chat/completions` a cada candidato. Los listados sin endpoint de chat desplegado devuelven **404** → descartar.
3. **Velocidad:** generación real de ~180 tokens (no limitar a 5), exigir **≥ ~10 tok/s**.
4. **Tool calling (obligatorio):** petición con `tools: [get_current_time]` + `tool_choice: auto`; exigir `tool_calls` reales.
5. **Reintentos:** los 429/500/503/timeout se reintentan con más margen antes de decidir.

**Whitelist actual (7 modelos):**

| # | Modelo |
|---|--------|
| 1 | `meta/muse-glimmer-30b` |
| 2 | `meta/llama-3.2-11b-vision-instruct` |
| 3 | `openai/gpt-oss-20b` |
| 4 | `nvidia/nemotron-3-ultra-550b-a55b` |
| 5 | `nvidia/nemotron-3-super-120b-a12b` |
| 6 | `nvidia/nemotron-3.5-lightning-30b-a3b` |
| 7 | `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` |

> 🔴 Retirado del whitelist: `minimaxai/minimax-m3` (**HTTP 410 Gone**, end of life el 09/09/2026; verificado el 10/10/2026).

> 🔎 El detalle del ranking (velocidades, descartados, retirados 410) está en la sección homónima del manual de Linux y en el grafo de memoria (entidad «Proveedor NVIDIA en OpenCode»).

> ⚠️ En Windows la verificación automática del whitelist se haría con una **tarea programada** que ejecute `scripts\check-nvidia-whitelist.ps1`; de momento se mantiene a mano.

---

## MCPs

Configurados bajo `mcp.servers` (sintaxis V2). En Windows hay **5 MCPs**:

| MCP | Tipo | Comando / URL | Qué hace |
|-----|------|---------------|----------|
| **context7** | Remote | `https://mcp.context7.com/mcp` | Documentación técnica actualizada |
| **filesystem** | Local | `@modelcontextprotocol/server-filesystem` | Leer/escribir archivos (raíz `C:/Users/evo01`) |
| **memory** | Local | `@modelcontextprotocol/server-memory` | Grafo de conocimiento persistente (`MEMORY_FILE_PATH`) |
| **fetch** | Local | `mcp-fetch-server` | Obtener contenido web |
| **sequential_thinking** | Local | `@modelcontextprotocol/server-sequential-thinking` | Razonamiento estructurado paso a paso |

- **Global y cloud:** los 5 activos.
- **Local:** `filesystem`, `memory` y `fetch` activos; `context7` y `sequential_thinking` deshabilitados (`disabled: true`).

---

## Permisos

```jsonc
"permissions": [
  { "action": "edit",  "resource": "*",         "effect": "ask" },
  { "action": "shell", "resource": "*",         "effect": "ask" },
  { "action": "shell", "resource": "sudo *",    "effect": "deny" },
  { "action": "shell", "resource": "pkexec *",  "effect": "allow" }
]
```

> ⚠️ **No aplica en Windows:** `sudo` y `pkexec` no existen; se conservan por compatibilidad con el setup de Linux. La elevación en Windows se hace por **UAC** (`Start-Process -Verb RunAs` o «Ejecutar como administrador»).

---

## LSP

> ✅ **OpenCode V2 2.0.26 sí ejecuta servidores LSP** a través del bloque `lsp` de la configuración.

Los tres perfiles (`opencode.jsonc`, `opencode-local.json`, `opencode-cloud.json`) declaran **11 servidores LSP** lanzados con `npx -y` (bajo demanda, sin instalación global):

| Servidor | Comando | Extensiones |
|----------|---------|-------------|
| `python` | `npx -y basedpyright --stdio` | `.py`, `.pyw` |
| `typescript` | `npx -y typescript-language-server --stdio` | `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs` |
| `json` | `npx -y vscode-json-languageserver --stdio` | `.json`, `.jsonc` |
| `yaml` | `npx -y yaml-language-server --stdio` | `.yaml`, `.yml` |
| `bash` | `npx -y bash-language-server start` | `.sh`, `.bash` |
| `zsh` | `npx -y bash-language-server start` | `.zsh`, `.zshrc` |
| `markdown` | `npx -y vscode-markdown-language-server --stdio` | `.md`, `.markdown` |
| `go` | `npx -y gopls` | `.go` |
| `rust` | `npx -y rust-analyzer` | `.rs` |
| `c` | `npx -y clangd` | `.c`, `.h` |
| `cpp` | `npx -y clangd` | `.cpp`, `.hpp`, `.cc`, `.cxx` |

> ⚠️ El servidor Python es **`basedpyright`** (paquete npm real). El nombre `@basedpyright/language-server` **no existe** y devuelve error 404 en npm.

> 🧪 Verificados: `basedpyright 1.40.1` y `typescript-language-server 6.0.0` arrancan correctamente.
> Los LSP corren en segundo plano y **no aparecen** en la barra lateral MiMo; se activan al abrir archivos de la extensión correspondiente.

---

## Dependencias npm

### Archivo: `C:\Users\evo01\.config\opencode\package.json`

```json
{
  "dependencies": {
    "@opencode-ai/plugin": "^1.18.32"
  }
}
```

| Paquete | Versión | Propósito |
|---------|---------|-----------|
| `@opencode-ai/plugin` | `^1.18.32` | SDK para desarrollar plugins de OpenCode |

> 📍 Solo contiene el SDK de plugins. Los SDK de AI los resuelve el binario de OpenCode y los plugins TUI/CLI se registran en `cli.json` (V2).

---

> 📁 `C:\Users\evo01\.config\opencode\opencode.jsonc` · `opencode-local.json` · `opencode-cloud.json` · `D:\Linux\Config\opencode-win\documentacion\04-perfiles-opencode-json.md`
