# 📚 Documentación de Configuración de OpenCode (Windows)
Guía completa del sistema de voz, modelos y herramientas en Windows.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Índice de documentación | 24/09/2026 · rev. 10/10/2026 | Antonio |

> 📁 Índice de todos los manuales de configuración de OpenCode **en Windows**
> (`D:\Linux\Config\opencode-win\documentacion\`).
> Manuales del lado Linux: `D:\Linux\Config\opencode\documentacion\`.

---

## 📑 Índice
1. [Documentos disponibles](#documentos-disponibles)
2. [Perfiles de configuración](#perfiles-de-configuración)
3. [Mapa de conceptos](#mapa-de-conceptos)
4. [Arquitectura de red](#arquitectura-de-red)
5. [Atajos de teclado importantes](#atajos-de-teclado-importantes)
6. [Comandos rápidos](#comandos-rápidos)
7. [Notas importantes](#notas-importantes)

---

## Documentos disponibles

### Guías principales

| # | Documento | Descripción |
|---|-----------|-------------|
| 01 | [Configuración de Ollama + Proxy](01-configuracion-ollama.md) | 🦙 Proxy de Ollama _(EN DESUSO)_ · LiteLLM · bug #34892 |
| 02 | [Configuración de LM Studio + Proxy](02-configuracion-lmstudio.md) | 🖥️ Proxy de LM Studio (4001) · `ocv` · carga de modelo en Windows |
| 03 | [Configuración completa de Voz](03-configuracion-voz.md) | 🎤 STT/TTS **implementado en Windows (GPU)**: whisper.cpp CUDA + Kokoro GPU con **servidor persistente** · atajos |
| 04 | [Los perfiles de `opencode.json`](04-perfiles-opencode-json.md) | 📋 Perfiles V2 Windows (`opencode.jsonc` / `opencode-local.json` / `opencode-cloud.json`) · MCPs · agentes y proveedores |
| 05 | [Configuración adicional](05-configuracion-adicional.md) | ⚙️ Instalador · Programador de tareas · scripts `.ps1` · estructura |
| 06 | [AGENTS.md al detalle](06-agents-md.md) | 📜 Reglas de comportamiento de OpenCode |
| 07 | [Playbook de Recuperación](07-playbook-recuperacion.md) | 🛟 Restaurar OpenCode · grafo de memoria · reinstalación desde limpio |
| 08 | [Incidencia GPU — Xid 79](08-incidencia-gpu-xid79.md) | 💥 GPU caída del bus PCIe (22/09/2026) · cómo detectarla desde Windows |
| 09 | [Informe del sistema](09-informe-sistema.md) | 📝 Generar informe del equipo con PowerShell/CIM (`sysinfo.ps1`) |

### Notas, seguimientos y hardware

| Documento | Descripción |
|-----------|-------------|
| [hardware-info.md](hardware-info.md) | 📊 Información completa del hardware (Ryzen 9 7900 · RTX 4070 Ti SUPER) |
| [README-hardware.md](README-hardware.md) | 🖥️ Comandos rápidos de consulta de hardware (PowerShell) |
| [notas-opencode-go.md](notas-opencode-go.md) | ☁️ Modelos de OpenCode Go alojados en China (opt-in) |
| [seguimiento-issue-memory.md](seguimiento-issue-memory.md) | 🐛 Seguimiento del issue MCP memory (draft-07 vs 2020-12) |

---

## Perfiles de configuración

Todos en **esquema V2** (`permissions`, `agents`, `providers`, `mcp`, `lsp`):

| Archivo | Uso | LSP | MCP |
|---------|-----|-----|-----|
| `opencode.jsonc` | `ocv` + app de escritorio (global/base) | ✅ 11 | Todos (5) |
| `opencode-local.json` | `ocv-local` | ✅ 11 | Esenciales (3) |
| `opencode-cloud.json` | `ocv-cloud` | ✅ 11 | Todos (5) |

| Lanzador | Config | LM Studio |
|----------|--------|-----------|
| `ocv` | `opencode.jsonc` | ✅ Carga modelo |
| `ocv-local` | `opencode-local.json` | ✅ Carga modelo |
| `ocv-cloud` | `opencode-cloud.json` | ❌ No carga |
| `ocv-status` | — | Estado de componentes |

> 🖥️ **App de escritorio V2** (2.0.26): instalada desde `opencode.ai/download` (NSIS) en `%LOCALAPPDATA%\Programs\@opencodedesktop`.
> La V1 de `winget` fue desinstalada. El CLI V2 (`@opencode/cli`) está en **2.0.26**.
> Los LSP se lanzan con `npx -y` (Python vía `basedpyright`) y **no** aparecen en la barra lateral: corren en segundo plano.

---

## Mapa de conceptos

Flujo de **voz → texto → IA → respuesta** (STT/TTS **implementado en Windows con GPU**):

| Paso | Componente | Detalle |
|------|-----------|---------|
| 1️⃣ | 🎤 **Tú (Antonio)** | Hablas o escribes · micrófono por defecto: **TONOR TD510 Air Mic** |
| 2️⃣ | **STT** ✅ | `ffmpeg` (DirectShow) + **whisper.cpp build CUDA** (`voice\stt.ps1`) |
| 3️⃣ | **TUI de OpenCode** | Teclado + atajos de voz |
| 4️⃣ | **OpenCode** | Agentes: `cloud`/`build` **deepseek-v4.1-flash** + `local` Qwen 3.8 + `nvidia` Nemotron 3 Ultra + `multimodal` MiMo-V2.6-Flash · 5 MCP |
| 5️⃣ | **TTS** ✅ | **Kokoro v1.0 ONNX en GPU** con servidor persistente (4210) → `ffplay` (`voice\speak.ps1`, `voice\kokoro-server.py`) |

---

## Arquitectura de red

| Servicio | Endpoint | Uso |
|----------|----------|-----|
| **LM Studio** | `http://localhost:1234` | Modelo local `qwen3.8-9b` (80K contexto) |
| **Proxy OpenCode ↔ LM Studio** | `http://localhost:4001` | `lmstudio-proxy.py` — intermediario con métricas (tokens/s) |
| **Servidor TTS (Kokoro)** | `http://127.0.0.1:4210` | `kokoro-server.py` — TTS persistente (modelo cargado en GPU) |
| **OpenCode Go (cloud)** | `https://opencode.ai` | Agentes `cloud` + `build`: `deepseek-v4.1-flash` |
| **NVIDIA NIM (cloud)** | `https://integrate.api.nvidia.com/v1` | Agente `nvidia`: Nemotron 3 Ultra 550B (whitelist de 7 modelos) |
| **Ollama** _(en desuso)_ | `http://localhost:11434` | Solo Linux; en Windows se instalaría con `winget install Ollama.Ollama` |

**Secuencia de arranque (`ocv`):**

```text
ocv  (función del perfil de PowerShell)
  ├─ start-lmstudio.ps1 → lms server start + load qwen3.8-9b + proxy(4001)
  ├─ Start-TtsServerIfNeeded → kokoro-server.py (4210)
  └─ opencode  (con OPENCODE_CONFIG=opencode.jsonc)
```

---

## Atajos de teclado importantes

| Atajo | Acción |
|-------|--------|
| `Shift+Tab` | Ciclar agentes primarios (en V2; antes `Tab`) |
| `Ctrl+R` | 🎤 Grabar / transcribir (inserta el texto) |
| `Leader+R` | 🎤 Grabar + transcribir + enviar |
| `Leader+S` | 🔊 Leer la última respuesta |
| `Leader+V` | 🔊 Activar/desactivar TTS automático |
| `Ctrl+Q` | ⏹️ Parar la locución |
| `F8` | Renombrar sesión |

---

## Comandos rápidos (PowerShell)

```powershell
# Lanzar OpenCode (necesita una ventana NUEVA de PowerShell para cargar el perfil)
ocv            # LM Studio + modelo + proxy + TTS + OpenCode con opencode.jsonc (global)
ocv-local      # Igual, pero perfil LOCAL (solo fetch, filesystem, memory)
ocv-cloud      # OpenCode en modo CLOUD (sin LM Studio, providers locales bloqueados)
ocv-status     # Estado de LM Studio, modelo en VRAM, proxy y servidor TTS

# Servidor TTS persistente (Kokoro)
tts-server status   # estado (voz + providers)
tts-server stop     # parar y liberar VRAM
tts-server start    # arrancar manualmente

# Historial COMPLETO de peticiones (el TUI solo muestra las últimas ~6)
& "$env:USERPROFILE\.config\opencode\scripts\timeline-completo.ps1"              # Sesión actual
& "$env:USERPROFILE\.config\opencode\scripts\timeline-completo.ps1" -Sesiones    # Listar sesiones
& "$env:USERPROFILE\.config\opencode\scripts\timeline-completo.ps1" -Buscar "x"  # Buscar en todas

# Hardware
hw_query                                                        # Resumen (CPU, GPU, RAM, discos, red)
& "$env:USERPROFILE\.config\opencode\scripts\sysinfo.ps1" -OutFile "$env:USERPROFILE\informe-sistema-sysinfo.txt"

# Backup / sincronización / Obsidian
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\scripts\backup-opencode.ps1"
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\scripts\sync-opencode.ps1"
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\scripts\sync-obsidian.ps1"

# Instalación desde cero
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\instalar-opencode-win.ps1"
```

---

## Notas importantes

> 🕐 **Timeline:** la TUI solo muestra las últimas ~6 peticiones (PR #26861 sin
> mergear). `timeline-completo.ps1` lee todas desde `opencode.db` (SQLite vía Python).
>
> 💾 **Backup:** `backup-opencode.ps1` copia el grafo de memoria (`memory.jsonl`) con
> fecha, sincroniza la config activa con `D:\Linux\Config\opencode-win\`, vuelca una
> copia saneada (sin claves) a `D:\Linux\Documentos\dotfiles\opencode-win` y publica un
> espejo en `F:` (`F:\@home\antonio\Config\opencode-win`).
>
> 🗂️ **Obsidian:** `sync-obsidian.ps1` espeja estos manuales al vault
> (`…\MEGA\Obsidian\Obsidian\armarui74\OpenCode-win\`), con la misma estructura que en Linux.
>
> 🔊 **TTS:** el servidor Kokoro persistente (puerto 4210) reduce la locución de
> ~2,1 s a ~0,5-1,5 s. Se arranca solo al locutar o al abrir `ocv`/`ocv-local`/`ocv-cloud`.
> Se para con `tts-server stop` (libera VRAM).
>
> 🎙️ **Micrófono:** el predeterminado es el **TONOR TD510 Air Mic** (configurado con
> el módulo `AudioDeviceCmdlets`, `Set-AudioDevice`).

---

> 📁 `D:\Linux\Config\opencode-win\documentacion\` · 🚀 `instalar-opencode-win.ps1` · 🧠 `scripts\backup-opencode.ps1`
