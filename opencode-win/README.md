# 🏠 Índice de la configuración de OpenCode (Windows)

Configuración activa de OpenCode en Windows: agentes, perfiles, proveedores, MCPs y lanzadores.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 24/09/2026 | Antonio |

> 📁 Esta carpeta es la **configuración activa** que usa OpenCode: `C:\Users\evo01\.config\opencode\`.
> El **backup** + **instalador** están en `D:\Linux\Config\opencode-win\` y la **documentación completa** en `D:\Linux\Config\opencode-win\documentacion\`.

---

## 📑 Índice

1. [¿Qué hay en esta carpeta?](#qué-hay-en-esta-carpeta)
2. [Lanzadores y comandos](#lanzadores-y-comandos)
3. [Arquitectura](#arquitectura)
4. [Perfiles de configuración](#perfiles-de-configuración)
5. [Proveedores y agentes](#proveedores-y-agentes)
6. [MCPs (servidores de contexto)](#mcps-servidores-de-contexto)
7. [Barra lateral y LSP](#barra-lateral-y-lsp)
8. [Documentación](#documentación)
9. [Backup e instalación](#backup-e-instalación)
10. [Notas](#notas)

---

## ¿Qué hay en esta carpeta?

| Archivo / carpeta | Para qué sirve |
|-------------------|----------------|
| `opencode.jsonc` | 🅰️ Perfil **global / base común** (agente `cloud` por defecto). Define agentes, proveedores y MCPs |
| `opencode-local.json` | 🖥️ Perfil **local** (LM Studio vía proxy 4001, agente `local`, solo MCPs `fetch`, `filesystem`, `memory`) |
| `opencode-cloud.json` | ☁️ Perfil **cloud estricto** (bloquea providers locales, desactiva el agente local) |
| `cli.json` | 🎛️ **Config del cliente V2**: tema, keybind `F8`, plugin de voz + barra lateral MiMo, y desactivación de los bloques nativos `sidebar.context`/`sidebar.footer` |
| `tui.json` | 🧩 Config V1 residual (migrada automáticamente a `cli.json`). Solo conserva `plugin_enabled` para el sidebar nativo |
| `plugins\antonio.sidebar-mimo\tui.tsx` | 📊 Plugin TUI de la **barra lateral MiMo** (Context, Directorio de trabajo, Instrucciones, versión). Auto-descubierto por V2 |
| `AGENTS.md` | 📜 Reglas de comportamiento de OpenCode (el archivo que el agente lee como instrucciones) |
| `lmstudio-proxy.py` | 🔀 Proxy OpenAI-compatible en el **puerto 4001** → LM Studio (1234). Mide tokens/s |
| `start-lmstudio.ps1` | 🚀 Arranque portable e idempotente: servidor + modelo + proxy |
| `package.json` | 📦 Dependencia `@opencode-ai/plugin` (para plugins/TUI) |
| `prompts\read-agents.txt` | 🧩 Prompt que usan los agentes `build` y `plan` |
| `scripts\` | 🛠️ Utilidades portadas: `timeline-completo`, `hardware-query`, `check-nvidia-whitelist`, `sync-opencode`, `backup-opencode`, `setup-voz` |
| `voice\` | 🎤 Voz: `stt.ps1` (whisper.cpp **CUDA**), `speak.ps1` (TTS), `kokoro-tts.py` (Kokoro GPU modo frío), `kokoro-server.py` (**servidor TTS persistente**, puerto 4210), `tts-server.ps1` (gestión) |
| `opencode-voice-modified\` | 🗣️ Plugin de voz de OpenCode (portado a Windows), registrado en `cli.json` |
| `lsp` (en los perfiles) | ⚠️ `"lsp": {}` — **OpenCode V2 no ejecuta LSP**. El campo se acepta y se conserva, pero no arranca servidores de lenguaje |
| `data\memory\memory.jsonl` | 🧠 Grafo de memoria persistente del MCP `memory` (`MEMORY_FILE_PATH`) |
| `data\metrics.json` | 📊 Métricas del proxy local (últimas 500 peticiones + media de tokens/s) |
| `AGENTS.md` · `README.md` | 📚 Reglas e índice (este documento) |

---

## Lanzadores y comandos

Los lanzadores son **funciones del perfil de PowerShell**
(`C:\Users\evo01\OneDrive\Documentos\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`).
Se cargan al abrir una ventana de PowerShell.

| Comando | Qué hace |
|---------|----------|
| `ocv` | Arranca **LM Studio + modelo + proxy + servidor TTS** y abre OpenCode con `opencode.jsonc` (global/base, todos los MCPs) |
| `ocv-local` | Igual pero con el perfil **local** (`opencode-local.json`): solo MCPs **fetch, filesystem, memory** |
| `ocv-cloud` | Abre OpenCode con `opencode-cloud.json` (modo **cloud**, providers locales bloqueados, sin LM Studio) |
| `ocv-status` | Muestra el estado de LM Studio (1234), modelo en VRAM, proxy (4001) y servidor TTS (4210) |
| `tts-server` | Gestiona el servidor TTS persistente (`status`/`start`/`stop`/`restart`) |
| `timeline-completo` | Historial **completo** de peticiones (el TUI solo muestra las últimas ~6) |
| `hw_query` | Consulta de hardware (CPU, GPU, RAM, disco, red) |

```powershell
ocv                 # arranque global (todos los MCPs)
ocv-local           # arranque local (fetch, filesystem, memory)
ocv-cloud           # modo cloud (providers locales bloqueados)
ocv-status          # estado del stack
tts-server status   # estado del servidor TTS
timeline-completo -Sesiones     # lista tus sesiones
hw_query gpu                    # consulta la GPU
```

---

## Arquitectura

```text
                       ┌─────────────────────────────┐
   ocv  ──────────────►│  start-lmstudio.ps1         │
   (perfil PS)         │   ├─ lms server start (1234)│
                       │   ├─ lms load qwen3.8-9b    │
                       │   └─ lmstudio-proxy.py (4001)│
                       └─────────────────────────────┘
                                    │
                       ┌────────────▼────────────────┐
   ocv / ocv-local /   │  Start-TtsServerIfNeeded    │
   ocv-cloud ─────────►│   └─ kokoro-server.py (4210)│
                       └─────────────────────────────┘
                                    │
   OpenCode ──► http://localhost:4001/v1 ──► http://localhost:1234/v1 ──► Qwen3.8-9B
        │
        ├──► OpenCode Go (cloud)  ·  deepseek-v4.1-flash
        └──► NVIDIA NIM (cloud)   ·  Nemotron 3 Super / MiMo V2.5
```

| Servicio | Endpoint | Uso |
|----------|----------|-----|
| LM Studio | `http://localhost:1234` | Modelo local `qwen3.8-9b` (80K contexto) |
| Proxy local | `http://localhost:4001` | Métricas tokens/s (`lmstudio-proxy.py`) |
| Servidor TTS | `http://127.0.0.1:4210` | Kokoro persistente (`kokoro-server.py`) |
| OpenCode Go | `https://opencode.ai` | Agentes `cloud` y `build` (`deepseek-v4.1-flash`) |
| NVIDIA NIM | `https://integrate.api.nvidia.com/v1` | Agente `nvidia` (whitelist de 8 modelos) |

---

## Perfiles de configuración

En Windows hay **tres** perfiles, y se seleccionan con la variable de entorno `OPENCODE_CONFIG`:

| Perfil | Archivo | MCPs | Proveedor local | Agente por defecto | Lanzador |
|--------|---------|------|-----------------|--------------------|----------|
| **Global / base** | `opencode.jsonc` | Todos (5) | `local` (proxy 4001) | `cloud` | `ocv` / `opencode` |
| **Local** | `opencode-local.json` | `fetch`, `filesystem`, `memory` | `local` (proxy 4001) | `local` | `ocv-local` |
| **Cloud estricto** | `opencode-cloud.json` | Todos (5) | (bloqueado) | `cloud` | `ocv-cloud` |

> `opencode.jsonc` es la **base común** (agentes, proveedores, MCPs); `opencode-local.json` y
> `opencode-cloud.json` contienen **solo lo que difiere**. Estructura **idéntica a la de Linux**
> (un perfil por lanzador).

---

## Proveedores y agentes

| Proveedor | Tipo | Modelo destacado |
|-----------|------|------------------|
| `local` | Local (proxy 4001) | `qwen3.8-9b` (Q6_K, 80K, tool calling + razonamiento) |
| `opencode-go` | Cloud | `deepseek-v4.1-flash` · `mimo-v2.5` (multimodal) |
| `nvidia` | Cloud (NIM) | `nemotron-3-super-120b-a12b`, `muse-glimmer-30b` (whitelist de 8) |

| Agente | Modo | Modelo |
|--------|------|--------|
| `title` | oculto | `local/qwen3.8-9b` |
| `local` | primary | `local/qwen3.8-9b` |
| `cloud` | primary | `opencode-go/deepseek-v4.1-flash` |
| `build` | primary | `opencode-go/deepseek-v4.1-flash` |
| `plan` | primary | `opencode-go/deepseek-v4.1-flash` |
| `nvidia` | all | `nvidia/nvidia/nemotron-3-super-120b-a12b` |
| `multimodal` | all | `opencode-go/mimo-v2.5` |

---

## MCPs (servidores de contexto)

| MCP | Tipo | Función |
|-----|------|---------|
| `context7` | remote | Documentación actualizada de librerías |
| `filesystem` | local (`npx`) | Acceso a archivos (`C:/Users/evo01`) |
| `memory` | local (`npx`) | Grafo de conocimiento en `data\memory\memory.jsonl` |
| `fetch` | local (`npx`) | Descarga de contenido web |
| `sequential_thinking` | local (`npx`) | Razonamiento en pasos |

> ⚠️ Recordatorio del MCP `memory`: cada observación necesita el campo `entityName` junto a `contents`.

---

## Barra lateral y LSP

### 📊 Barra lateral (plugin MiMo)

La barra lateral se replica de Linux con el plugin **`antonio.sidebar-mimo`**
(`plugins\antonio.sidebar-mimo\tui.tsx`), auto-descubierto por OpenCode V2. Muestra:

| Bloque | Contenido |
|--------|-----------|
| **Context** | Tokens usados, % del límite, límite del modelo, t/s y coste |
| **Directorio de trabajo** | Ruta del proyecto activo |
| **Instrucciones** | Ficheros de instrucciones (`AGENTS.md`) |
| **Footer** | Versión de OpenCode (al final de la barra) |

En `cli.json` se **desactivan** los bloques nativos `opencode.sidebar.context` y
`opencode.sidebar.footer` para no duplicarlos:

```json
"plugins": [
  { "package": "C:/Users/evo01/.config/opencode/opencode-voice-modified", "options": { ... } },
  "-opencode.sidebar.context",
  "-opencode.sidebar.footer"
]
```

> ⚠️ **Corrección (24/09/2026):** antes había **dos** registros del sidebar (uno en
> `tui.json` apuntando a `opencode-sidebar-mimo\index.tsx` y otro auto-descubierto), lo
> que duplicaba los bloques y rompía el aspecto respecto a Linux. Se dejó solo el
> auto-descubierto y se saneó `tui.json`.

### ⚠️ LSP en OpenCode V2

> 🔴 **OpenCode V2 NO ejecuta servidores LSP.** Según la documentación oficial de V2
> (*«V2 accepts and preserves `lsp` configuration, but it does not run language servers,
> expose LSP tools, or produce LSP diagnostics»*), el bloque `lsp` se acepta y conserva,
> pero **no arranca ningún language server**.
>
> Por eso en los tres perfiles se deja `"lsp": {}` (neutral): no hace nada en V2, pero
> queda listo si en el futuro V2 los soporta. Los antiguos comandos `npx`
> (`gopls`, `rust-analyzer`, `clangd`, `vscode-markdown-language-server`, etc.) eran de
> **V1** y además estaban rotos (paquetes inexistentes en npm, `basedpyright` sin
> comillas → **JSON inválido**), así que se han retirado.
>
> **Alternativa para diagnóstico en V2:** ejecutar lint/typecheck/compilador por CLI
> (p. ej. `pylint`, `tsc --noEmit`, `cargo check`) e indicarlo en `AGENTS.md`.

---

## Documentación

Toda la documentación está en **`D:\Linux\Config\opencode-win\documentacion\`**:

| Documento | Tema |
|-----------|------|
| [README.md](../documentacion/README.md) | 📚 Índice general de manuales |
| 01 · 02 · 03 | Ollama (en desuso) · **LM Studio + proxy** · **Voz (✅ implementada, GPU)** |
| 04 · 05 · 06 | Perfiles · Configuración adicional · AGENTS.md al detalle |
| 07 | Playbook de recuperación |
| hardware · notas | Hardware · OpenCode Go · issue MCP memory |

---

## Backup e instalación

| Acción | Comando |
|--------|---------|
| 🔄 Sincronizar config → backup | `powershell -File "D:\Linux\Config\opencode-win\scripts\sync-opencode.ps1"` |
| 💾 Backup grafo + config | `powershell -File "D:\Linux\Config\opencode-win\scripts\backup-opencode.ps1"` |
| 🚀 Instalar desde cero | `powershell -File "D:\Linux\Config\opencode-win\instalar-opencode-win.ps1"` |

El instalador instala Node.js, Python, LM Studio, OpenCode, despliega esta configuración,
el perfil, el proxy y el modelo, y verifica todo (probado: 9/9 OK).

---

## Notas

> 🎤 **Voz (STT/TTS):** implementada en Windows con **GPU** — STT `whisper.cpp` CUDA (`voice\stt.ps1`, ~0,8 s/audio) y TTS **Kokoro GPU** con **servidor persistente** (`voice\kokoro-server.py` en 4210, `speak.ps1`, `tts-server.ps1`; ~0,5-1,5 s/locución). Atajos: `Ctrl+R` (grabar), `Leader+R` (grabar+enviar), `Leader+S` (leer respuesta), `Leader+V` (TTS on/off), `Ctrl+Q` (parar).
>
> 🎙️ **Micrófono:** el predeterminado es el **TONOR TD510 Air Mic**.
>
> 🕐 **Timeline:** la TUI solo muestra ~6 peticiones (PR #26861 sin mergear); usa `timeline-completo`.
>
> 🔐 **Política de ejecución:** `RemoteSigned` (CurrentUser) para poder cargar el perfil.
>
> 🖥️ **Hardware:** AMD Ryzen 9 7900 · NVIDIA RTX 4070 Ti SUPER (16 GB) · 63,1 GB RAM.

---

> 📁 Config activa: `C:\Users\evo01\.config\opencode\` · 💾 Backup: `D:\Linux\Config\opencode-win\`