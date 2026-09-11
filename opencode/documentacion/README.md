# 📚 Documentación de Configuración de OpenCode

**Guía completa del sistema de voz, modelos y herramientas**

| 🧑‍💻 Antonio | 📍 Pechina, Almería | ☁️ OpenCode Go + 🤖 Qwen 3.8 local |
|---|---|---|

---

## 🗂️ Documentos disponibles

### Guías principales

| # | Documento | Descripción |
|---|-----------|-------------|
| 01 | [Configuración de Ollama + Proxy](01-configuracion-ollama.md) | 🦙 Proxy de Ollama _(EN DESUSO)_ · LiteLLM · bug #34892 |
| 02 | [Configuración de LM Studio + Proxy](02-configuracion-lmstudio.md) | 🖥️ Proxy de LM Studio · init-opencode · systemd · carga de modelo |
| 03 | [Configuración completa de Voz](03-configuracion-voz.md) | 🎤 STT (sox→whisper→LLM) · TTS (Kokoro GPU→paplay) · plugin · scripts |
| 04 | [Los tres perfiles de `opencode.json`](04-perfiles-opencode-json.md) | 📋 Perfiles local/cloud/activo · MCPs · proveedores · agentes |
| 05 | [Configuración adicional](05-configuracion-adicional.md) | ⚙️ `.env` · sync · systemd · scripts · estructura |
| 06 | [AGENTS.md al detalle](06-agents-md.md) | 📜 Reglas de comportamiento de OpenCode |

### Notas, seguimientos y hardware

| Documento | Descripción |
|-----------|-------------|
| [hardware-info.md](hardware-info.md) | 📊 Información completa del hardware del equipo |
| [README-hardware.md](README-hardware.md) | 🖥️ Comandos rápidos de consulta de hardware |
| [notas-opencode-go.md](notas-opencode-go.md) | ☁️ Modelos de OpenCode Go alojados en China (opt-in) |
| [seguimiento-issue-memory.md](seguimiento-issue-memory.md) | 🐛 Seguimiento del issue MCP memory (draft-07 vs 2020-12) |

> 📝 Integración OnlyOffice IA: [ONLYOFFICE-AI-OPENCODE.md](../data/onlyoffice-ai/ONLYOFFICE-AI-OPENCODE.md)

---

## 🧭 Mapa de conceptos

Flujo de **voz → texto → IA → respuesta**:

| Paso | Componente | Detalle |
|------|-----------|---------|
| 1️⃣ | 🎤 **Tú (Antonio)** | Hablas o escribes |
| 2️⃣ | **STT** — `sox` + `whisper-cpp` | Audio capturado y transcrito en **GPU** |
| 3️⃣ | **TUI de OpenCode** | Teclado + comandos `/stt-*` |
| 4️⃣ | **OpenCode** | Agentes: `cloud`/`build` **deepseek-v4.1-flash** + `local` Qwen 3.8 + `nvidia` Nemotron 3 Ultra · 5 MCP · 50 skills |
| 5️⃣ | **TTS** — `Kokoro GPU` → `paplay` + **Pantalla** | 🔊 Audio por voz · 📄 Texto en pantalla |

---

## 🌐 Arquitectura de red

| Servicio | Endpoint | Uso |
|----------|----------|-----|
| **LM Studio** | `http://localhost:1234` | Modelo local `models-qwen3.8-9b` (80K contexto) |
| **Proxy OpenCode ↔ LM Studio** | `http://localhost:4001` | Intermediario con métricas (tokens/s) |
| **OpenCode Go (cloud)** | `https://opencode.ai` | Agentes `cloud` + `build`: `deepseek-v4.1-flash` |
| **NVIDIA NIM (cloud)** | `https://integrate.api.nvidia.com/v1` | Agente `nvidia`: Nemotron 3 Ultra 550B (1M contexto) |
| **Ollama** _(en desuso)_ | `http://localhost:11434` | Modelos `llama3.1`, `gemma4`, `deepseek-r1`, `qwen3.5` (LiteLLM) |

**Secuencia de arranque:**

```text
start-opencode-server.sh
  └─ start-lmstudio.sh → lms server start + load modelo + proxy(4001)
       └─ exec /usr/bin/opencode
```

---

## ⌨️ Atajos de teclado importantes

| Atajo | Acción |
|-------|--------|
| `Ctrl+R` | Grabar / transcribir voz (STT) |
| `Leader+R` | Grabar, transcribir y enviar |
| `Leader+V` | Activar / desactivar TTS automático |
| `Leader+S` | Leer la última respuesta |
| `Escape` | Detener reproducción TTS |
| `F8` | Renombrar sesión |

---

## 🧩 Skills de OpenCode

### ✨ 50 skills activos

| Categoría | Skills |
|-----------|--------|
| **Frontend** | `angular-architect`, `nextjs-developer`, `react-expert`, `vue-expert`, `vue-expert-js`, `fullstack-guardian` |
| **Backend** | `nestjs-expert`, `fastapi-expert`, `django-expert`, `java-architect`, `golang-pro`, `rust-engineer`, `cpp-pro`, `php-pro`, `python-pro` |
| **Datos** | `pandas-pro`, `postgres-pro`, `sql-pro`, `database-optimizer` |
| **IA / LLM** | `prompt-engineer`, `pydantic`, `rag-architect`, `spec-miner` |
| **Infraestructura** | `cloud-architect`, `terraform-engineer`, `kubernetes-specialist`, `devops-engineer`, `sre-engineer`, `monitoring-expert` |
| **Calidad** | `code-reviewer`, `security-reviewer`, `secure-code-guardian`, `test-master`, `debugging-wizard`, `the-fool` |
| **APIs** | `api-designer`, `graphql-architect`, `websocket-engineer`, `atlassian-mcp`, `mcp-developer`, `opencode-marketplace` |
| **Otros** | `cli-developer`, `architecture-designer`, `code-documenter`, `feature-forge`, `legacy-modernizer`, `microservices-architect`, `playwright-expert`, `typescript-pro`, `javascript-pro` |

### 🚫 18 skills desactivados

`chaos-engineer`, `csharp-developer`, `dotnet-core-expert`, `embedded-systems`, `fine-tuning-expert`, `flutter-expert`, `game-developer`, `kotlin-specialist`, `laravel-specialist`, `ml-pipeline`, `rails-expert`, `react-native-expert`, `salesforce-developer`, `shopify-expert`, `spark-engineer`, `spring-boot-engineer`, `swift-expert`, `wordpress-pro`

---

## ⚡ Comandos rápidos

```bash
# Inicializar todo (LM Studio + proxy)
bash ~/.config/opencode/init-opencode.sh

# Lanzar OpenCode
bash ~/.config/opencode/start-opencode.sh      # o directamente: ocv

# Perfiles por lanzador (cada uno usa SU config, sin copiar nada)
ocv / opencode                                   # opencode.json (todos los agentes activos)
ocv-local / opencode-local                       # opencode-local.json (MCPs esenciales)
ocv-cloud / opencode-cloud                       # opencode-cloud.json (sin modelo local en VRAM)

# Sincronizar configuración (timer automático cada 30 min)
bash ~/.config/opencode/sync-opencode.sh

# Regenerar backup (verifica el setup; si falla, aborta)
bash ~/Config/opencode/backup-opencode.sh

# Historial COMPLETO de peticiones (el TUI solo muestra las últimas ~6)
timeline-completo                    # Sesión actual
timeline-completo --sesiones         # Listar sesiones
timeline-completo --buscar "texto"   # Buscar en todas

# Cargar variables de entorno
set -a; source ~/.config/opencode/.env; set +a
```

---

## 📌 Notas importantes

> 🕐 **Timeline:** la TUI solo muestra las últimas ~6 peticiones (PR #26861 sin
> mergear). `timeline-completo` lee todas desde `opencode.db`. Un timer systemd
> (`check-timeline-fix.timer`, cada 3 días) vigila el PR.
>
> 💾 **Backup:** el automático (`opencode-sync.timer`, cada 30 min) hace exactamente
> lo mismo que el manual: ejecuta `backup-opencode.sh`, que verifica el setup
> (`check-setup-completo.sh`) antes de generar el tarball.

---

> 📁 `~/Config/opencode/documentacion/` · 🎯 `~/Config/opencode/backups/opencode/` · 🧠 `mcp-memory-backup-*.jsonl`
