# 📚 Documentación de Configuración de OpenCode (Windows)

**Guía completa del sistema de voz, modelos y herramientas en Windows**

| 🧑‍💻 Antonio | 📍 Pechina, Almería | ☁️ OpenCode Go + 🤖 Qwen 3.8 local (Windows) |
|---|---|---|

---

## 🗂️ Documentos disponibles

### Guías principales

| # | Documento | Descripción |
|---|-----------|-------------|
| 01 | [Configuración de Ollama + Proxy](01-configuracion-ollama.md) | 🦙 Proxy de Ollama _(EN DESUSO)_ · LiteLLM · bug #34892 |
| 02 | [Configuración de LM Studio + Proxy](02-configuracion-lmstudio.md) | 🖥️ Proxy de LM Studio (4001) · `ocv` · carga de modelo en Windows |
| 03 | [Configuración completa de Voz](03-configuracion-voz.md) | 🎤 STT/TTS **implementado en Windows (GPU)**: whisper.cpp CUDA + Kokoro GPU · atajos `Ctrl+R`, `Leader+R`, `Leader+S`, `Leader+V`, `Ctrl+Q` |
| 04 | [Los perfiles de `opencode.json`](04-perfiles-opencode-json.md) | 📋 Perfiles Windows (`opencode.jsonc` / `opencode-local.json`) · MCPs · proveedores · agentes |
| 05 | [Configuración adicional](05-configuracion-adicional.md) | ⚙️ Instalador · Programador de tareas · scripts `.ps1` · estructura |
| 06 | [AGENTS.md al detalle](06-agents-md.md) | 📜 Reglas de comportamiento de OpenCode |

### Notas, seguimientos y hardware

| Documento | Descripción |
|-----------|-------------|
| [hardware-info.md](hardware-info.md) | 📊 Información completa del hardware (Ryzen 9 7900 · RTX 4070 Ti SUPER) |
| [README-hardware.md](README-hardware.md) | 🖥️ Comandos rápidos de consulta de hardware (PowerShell) |
| [notas-opencode-go.md](notas-opencode-go.md) | ☁️ Modelos de OpenCode Go alojados en China (opt-in) |
| [seguimiento-issue-memory.md](seguimiento-issue-memory.md) | 🐛 Seguimiento del issue MCP memory (draft-07 vs 2020-12) |

---

## 🧭 Mapa de conceptos

Flujo de **voz → texto → IA → respuesta** (STT/TTS **implementado en Windows con GPU**):

| Paso | Componente | Detalle |
|------|-----------|---------|
| 1️⃣ | 🎤 **Tú (Antonio)** | Hablas o escribes · micrófono por defecto: **TONOR TD510 Air Mic** |
| 2️⃣ | **STT** ✅ | `ffmpeg` (DirectShow) + **whisper.cpp build CUDA** (`stt.ps1`) |
| 3️⃣ | **TUI de OpenCode** | Teclado + atajos de voz |
| 4️⃣ | **OpenCode** | Agentes: `cloud`/`build` **deepseek-flash** + `local` Qwen 3.8 + `nvidia` Nemotron 3 · 5 MCP |
| 5️⃣ | **TTS** ✅ | **Kokoro v1.0 ONNX en GPU** → ffplay (`speak.ps1`, `kokoro-tts.py`) |

---

## 🌐 Arquitectura de red

| Servicio | Endpoint | Uso |
|----------|----------|-----|
| **LM Studio** | `http://localhost:1234` | Modelo local `qwen3.8-9b` (80K contexto) |
| **Proxy OpenCode ↔ LM Studio** | `http://localhost:4001` | `lmstudio-proxy.py` — intermediario con métricas (tokens/s) |
| **OpenCode Go (cloud)** | `https://opencode.ai` | Agentes `cloud` + `build`: `deepseek-flash` |
| **NVIDIA NIM (cloud)** | `https://integrate.api.nvidia.com/v1` | Agente `nvidia`: Nemotron 3 Ultra 550B |
| **Ollama** _(en desuso)_ | `http://localhost:11434` | Solo Linux; en Windows se instalaría con `winget install Ollama.Ollama` |

**Secuencia de arranque (`ocv`):**

```text
ocv  (función del perfil de PowerShell)
  └─ start-lmstudio.ps1 → lms server start + load qwen3.8-9b + proxy(4001)
       └─ opencode  (con OPENCODE_CONFIG=opencode-local.json)
```

---

## ⌨️ Atajos de teclado

| Atajo | Acción |
|-------|--------|
| `F8` | Renombrar sesión |
| `Ctrl+R` | 🎤 Grabar / transcribir (inserta el texto) |
| `Leader+R` | 🎤 Grabar + transcribir + enviar |
| `Leader+S` | 🔊 Leer la última respuesta |
| `Leader+V` | 🔊 Activar/desactivar TTS automático |
| `Ctrl+Q` | ⏹️ Parar la locución |

---

## ⚡ Comandos rápidos (PowerShell)

```powershell
# Lanzar OpenCode (necesita una ventana NUEVA de PowerShell para cargar el perfil)
ocv            # LM Studio + modelo + proxy + OpenCode local (TODOS los MCPs)
ocv-local      # Igual, pero perfil local minimo (solo fetch, filesystem, memory)
ocv-cloud      # OpenCode en modo cloud (sin LM Studio)
ocv-status     # Estado de LM Studio, modelo en VRAM y proxy

# Historial COMPLETO de peticiones (el TUI solo muestra las últimas ~6)
& "$env:USERPROFILE\.config\opencode\scripts\timeline-completo.ps1"              # Sesión actual
& "$env:USERPROFILE\.config\opencode\scripts\timeline-completo.ps1" -Sesiones    # Listar sesiones
& "$env:USERPROFILE\.config\opencode\scripts\timeline-completo.ps1" -Buscar "x"  # Buscar en todas

# Consultar hardware
& "$env:USERPROFILE\.config\opencode\scripts\hardware-query.ps1"        # Todo
& "$env:USERPROFILE\.config\opencode\scripts\hardware-query.ps1" gpu    # Solo GPU

# Backup / sincronización
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\scripts\backup-opencode.ps1"
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\scripts\sync-opencode.ps1"

# Instalación desde cero
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\instalar-opencode-win.ps1"
```

---

## 📌 Notas importantes

> 🕐 **Timeline:** la TUI solo muestra las últimas ~6 peticiones (PR #26861 sin
> mergear). `timeline-completo.ps1` lee todas desde `opencode.db` (SQLite vía Python).
>
> 💾 **Backup:** `backup-opencode.ps1` copia el grafo de memoria (`memory.jsonl`) con
> fecha y sincroniza la config activa con `D:\Linux\Config\opencode-win\`.
> Retención de 30 días.
>
> 🎙️ **Micrófono:** el predeterminado es el **TONOR TD510 Air Mic** (configurado con
> el módulo `AudioDeviceCmdlets`, `Set-AudioDevice`).

---

> 📁 `D:\Linux\Config\opencode-win\documentacion\` · 🚀 `instalar-opencode-win.ps1` · 🧠 `scripts\backup-opencode.ps1`