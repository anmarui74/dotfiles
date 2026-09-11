# 🏠 Índice de la configuración de OpenCode (Windows)

Configuración activa de OpenCode en Windows: agentes, perfiles, proveedores, MCPs y lanzadores.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

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
7. [Documentación](#documentación)
8. [Backup e instalación](#backup-e-instalación)
9. [Notas](#notas)

---

## ¿Qué hay en esta carpeta?

| Archivo / carpeta | Para qué sirve |
|-------------------|----------------|
| `opencode.jsonc` | 🅰️ Perfil **global** (cloud por defecto). Agente `cloud` + proveedor `nvidia` |
| `opencode-local.json` | 🖥️ Perfil **local completo** (LM Studio vía proxy 4001, agente `local`, todos los MCPs) |
| `opencode-local-min.json` | 🧩 Perfil **local mínimo** (LM Studio, solo MCPs `fetch`, `filesystem`, `memory`) |
| `tui.json` | 🎛️ Ajustes de la interfaz: keybind `F8` (renombrar sesión) + plugin `opencode-throughput` |
| `AGENTS.md` | 📜 Reglas de comportamiento de OpenCode (el archivo que el agente lee como instrucciones) |
| `lmstudio-proxy.py` | 🔀 Proxy OpenAI-compatible en el **puerto 4001** → LM Studio (1234). Mide tokens/s |
| `start-lmstudio.ps1` | 🚀 Arranque portable e idempotente: servidor + modelo + proxy |
| `package.json` | 📦 Dependencia `@opencode-ai/plugin` (para plugins/TUI) |
| `prompts\read-agents.txt` | 🧩 Prompt que usan los agentes `build` y `plan` |
| `scripts\` | 🛠️ Utilidades portadas: `timeline-completo`, `hardware-query`, `check-nvidia-whitelist`, `sync-opencode`, `backup-opencode`, `setup-voz` |
| `voice\` | 🎤 Voz: `stt.ps1` (whisper.cpp **CUDA**), `speak.ps1` (TTS), `kokoro-tts.py` (**Kokoro GPU**) |
| `opencode-voice-modified\` | 🗣️ Plugin de voz de OpenCode (portado a Windows), registrado en `tui.json` |
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
| `ocv` | Arranca **LM Studio + modelo + proxy** y abre OpenCode en modo **local completo** (`opencode-local.json`, todos los MCPs) |
| `ocv-local` | Igual pero con el perfil **local mínimo** (`opencode-local-min.json`): solo MCPs **fetch, filesystem, memory** |
| `ocv-cloud` | Abre OpenCode en modo **cloud** (sin LM Studio), con la config global (todos los MCPs) |
| `ocv-status` | Muestra el estado de LM Studio (1234), modelo en VRAM y proxy (4001) |
| `timeline-completo` | Historial **completo** de peticiones (el TUI solo muestra las últimas ~6) |
| `hw_query` | Consulta de hardware (CPU, GPU, RAM, disco, red) |

```powershell
ocv                 # arranque local completo (todos los MCPs)
ocv-local           # arranque local mínimo (fetch, filesystem, memory)
ocv-cloud           # modo cloud (todos los MCPs)
ocv-status          # estado del stack
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
   OpenCode ──► http://localhost:4001/v1 ──► http://localhost:1234/v1 ──► Qwen3.8-9B
        │
        ├──► OpenCode Go (cloud)  ·  deepseek-flash
        └──► NVIDIA NIM (cloud)   ·  Nemotron 3 / Muse Glimmer 30B
```

| Servicio | Endpoint | Uso |
|----------|----------|-----|
| LM Studio | `http://localhost:1234` | Modelo local `qwen3.8-9b` (80K contexto) |
| Proxy local | `http://localhost:4001` | Métricas tokens/s (`lmstudio-proxy.py`) |
| OpenCode Go | `https://opencode.ai` | Agentes `cloud` y `build` (`deepseek-flash`) |
| NVIDIA NIM | `https://integrate.api.nvidia.com/v1` | Agente `nvidia` (whitelist de 8 modelos) |

---

## Perfiles de configuración

En Windows hay **tres** perfiles, y se seleccionan con la variable de entorno `OPENCODE_CONFIG`:

| Perfil | Archivo | MCPs | Proveedor local | Agente por defecto | Lanzador |
|--------|---------|------|-----------------|--------------------|----------|
| **Local completo** | `opencode-local.json` | Todos (5) | `lmstudio` (proxy 4001) | `local` | `ocv` |
| **Local mínimo** | `opencode-local-min.json` | `fetch`, `filesystem`, `memory` | `lmstudio` (proxy 4001) | `local` | `ocv-local` |
| **Global / cloud** | `opencode.jsonc` | Todos (5) | (desactivado) | `cloud` | `ocv-cloud` / `opencode` |

> ⚠️ En Linux había tres perfiles (`opencode.json` / `opencode-local.json` / `opencode-cloud.json`).
> En Windows el **cloud ES el global** (`opencode.jsonc`), y el perfil **mínimo** se llama
> `opencode-local-min.json` (equivalente funcional al `opencode-local.json` de Linux).

---

## Proveedores y agentes

| Proveedor | Tipo | Modelo destacado |
|-----------|------|------------------|
| `lmstudio` | Local (proxy 4001) | `qwen3.8-9b` (Q6_K, 80K, tool calling + razonamiento) |
| `opencode-go` | Cloud | `deepseek-flash` |
| `nvidia` | Cloud (NIM) | `meta/muse-glimmer-30b`, Nemotron 3 Ultra 550B (whitelist de 8) |

| Agente | Modo | Modelo |
|--------|------|--------|
| `local` | primary | `lmstudio/qwen3.8-9b` |
| `cloud` | primary | `opencode-go/deepseek-flash` |
| `build` | primary | `deepseek-flash` (local: `qwen3.8-9b`) |
| `plan` | primary | `qwen3.8-9b` |
| `nvidia` | all | `nvidia/meta/muse-glimmer-30b` |
| `multimodal` | all | `nvidia/meta/muse-glimmer-30b` |

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

> 🎤 **Voz (STT/TTS):** implementada en Windows con **GPU** — STT `whisper.cpp` CUDA (`voice\stt.ps1`), TTS **Kokoro GPU** (`voice\speak.ps1` + `kokoro-tts.py`). Atajos: `Ctrl+R` (grabar), `Leader+R` (grabar+enviar), `Leader+S` (leer respuesta), `Leader+V` (TTS on/off), `Ctrl+Q` (parar).
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