# 📚 Documentación de Configuración de OpenCode

> **Usuario:** Antonio 🧑‍💻  
> **Ubicación:** Pechina, Almería, España 📍  
> **Fecha:** 10/08/2026  
> **Modelo principal:** OpenCode Go (deepseek-v4-flash) ☁️ + Qwen 3.5 (9B) local 🤖  
> **LSPs:** 11 servidores configurados el 10/08/2026 (Python, C/C++, Rust, TS/JS, Go, JSON, YAML, Bash, Zsh, Markdown) 🛠️

---

## Documentos disponibles

| # | Documento | Descripción |
|---|-----------|-------------|
| 01 | [Configuración de Ollama + Proxy](01-configuracion-ollama.md) | 🦙 Proxy de Ollama (EN DESUSO), LiteLLM, modelos disponibles, bug #34892 |
| 02 | [Configuración de LM Studio + Proxy](02-configuracion-lmstudio.md) | 🖥️ Proxy de LM Studio, init-opencode, systemd, carga de modelo |
| 03 | [Configuración completa de Voz](03-configuracion-voz.md) | 🎤 STT (sox→whisper→LLM), TTS (edge-tts→paplay), plugin, speak |
| 04 | [Los tres perfiles de opencode.json](04-perfiles-opencode-json.md) | 📋 Perfiles local/cloud/activo, MCPs, proveedores, agentes |
| 05 | [Configuración adicional](05-configuracion-adicional.md) | ⚙️ .env, sync, systemd, scripts, estructura |
| 06 | [AGENTS.md al detalle](06-agents-md.md) | 📜 Explicación de las reglas de comportamiento |
| 07 | [OnlyOffice IA + OpenCode](../data/onlyoffice-ai/ONLYOFFICE-AI-OPENCODE.md) | 📝 Integración del plugin IA de OnlyOffice con el modelo local |

### Notas y seguimientos

| Archivo | Descripción |
|---------|-------------|
| [notas-opencode-go.md](notas-opencode-go.md) | ☁️ Modelos de OpenCode Go alojados en China (opt-in) |
| [seguimiento-issue-memory.md](seguimiento-issue-memory.md) | 🐛 Seguimiento del issue MCP memory (draft-07 vs 2020-12) |
| [README-hardware.md](README-hardware.md) | 🖥️ Comandos rápidos de consulta de hardware |
| [hardware-info.md](hardware-info.md) | 📊 Información completa del hardware |

### Proyectos Rust de Antonio (10/08/2026)

| Documento | Descripción |
|-----------|-------------|
| [README-arcman.md](../../../Documentos/dotfiles/utilidades%20rust/arcman/README-arcman.md) | 🦀 arcman (CLI): gestor de paquetes Arch en Rust, comandos, mejoras aplicadas |
| [README-arcman-gui.md](../../../Documentos/dotfiles/utilidades%20rust/arcman-gui/README-arcman-gui.md) | 🖥️ arcman-gui: versión gráfica (Iced), pantallas, fix GPU NVIDIA, compilación |

> 📌 Ambos proyectos también están respaldados en `~/Config/utilidades rust/` con sus README.

---

## Mapa de conceptos

```
                    ┌──────────────────────────────────┐
                    │          TÚ (Antonio)            │
                    │     🎤 Hablas / 📝 Escribes     │
                    └──────────┬──────────┬───────────┘
                               │          │
                    ┌──────────▼          ▼───────────┐
                    │  STT (sox+whisper)  │  TUI      │
                    │  ────────────────   │  (teclado)│
                    │  Audio → Texto     │           │
                    └──────────┬──────────┘───────────┘
                               │
                    ┌──────────▼───────────────────────┐
                    │        OPENCODE                  │
                    │  ┌──────────────────────────┐   │
                    │  │  Agente cloud (principal)│   │
                    │  │  deepseek-v4-flash       │   │
                    │  │  + Qwen 3.5 local (sub)  │   │
                    │  │  Tools: 5 MCP servers    │   │
                    │  │  Skills: 68 activos      │   │
                    │  └──────────┬───────────────┘   │
                    └─────────────┼───────────────────┘
                                  │
                    ┌─────────────▼───────────────────┐
                    │     SALIDA                      │
                    │  ┌──────────┐ ┌──────────────┐  │
                    │  │  TTS     │ │  Pantalla    │  │
                    │  │ edge-tts │ │  (texto)     │  │
                    │  │ → paplay │ │              │  │
                    │  │ 🔊 Audio │ │  📄 Texto    │  │
                    │  └──────────┘ └──────────────┘  │
                    └─────────────────────────────────┘
```

## Arquitectura de red

```
LM Studio API ──── http://localhost:1234 ──── Proxy (4001) ──── OpenCode
     │                                                   
     ├── Modelo: models-qwen3.5-9b (80K contexto)
     ├── lms server start (a través de start-opencode.sh)
     └── lms load / unload

OpenCode Go (cloud) ──── agente principal (deepseek-v4-flash)
     │
     └── https://opencode.ai (suscripción Go)

Ollama API ────── http://localhost:11434 ──── Proxy (4000) ──── (en desuso)
     ├── Modelos: llama3.1, gemma4, deepseek-r1, qwen3.5
     └── LiteLLM como capa de abstracción
```

## Atajos de teclado importantes

| Atajo | Acción |
|-------|--------|
| `Ctrl+R` | Grabar/transcribir voz (STT) |
| `Leader+R` | Grabar, transcribir y enviar |
| `Leader+V` | Activar/desactivar TTS automático |
| `Leader+S` | Leer última respuesta |
| `Escape` | Detener reproducción TTS |
| `F8` | Renombrar sesión |

---

## Skills de OpenCode

### 68 skills activos

`angular-architect`, `api-designer`, `architecture-designer`, `atlassian-mcp`, `cli-developer`, `cloud-architect`, `code-documenter`, `code-reviewer`, `cpp-pro`, `database-optimizer`, `debugging-wizard`, `devops-engineer`, `django-expert`, `fastapi-expert`, `feature-forge`, `fullstack-guardian`, `golang-pro`, `graphql-architect`, `java-architect`, `javascript-pro`, `kubernetes-specialist`, `legacy-modernizer`, `mcp-developer`, `microservices-architect`, `monitoring-expert`, `nestjs-expert`, `nextjs-developer`, `opencode-marketplace`, `pandas-pro`, `php-pro`, `playwright-expert`, `postgres-pro`, `prompt-engineer`, `pydantic`, `python-pro`, `rag-architect`, `react-expert`, `rust-engineer`, `secure-code-guardian`, `security-reviewer`, `spec-miner`, `sql-pro`, `sre-engineer`, `terraform-engineer`, `test-master`, `the-fool`, `typescript-pro`, `vue-expert-js`, `vue-expert`, `websocket-engineer`, `customize-opencode`, etc.

### 18 skills desactivados

`chaos-engineer`, `csharp-developer`, `dotnet-core-expert`, `embedded-systems`, `fine-tuning-expert`, `flutter-expert`, `game-developer`, `kotlin-specialist`, `laravel-specialist`, `ml-pipeline`, `rails-expert`, `react-native-expert`, `salesforce-developer`, `shopify-expert`, `spark-engineer`, `spring-boot-engineer`, `swift-expert`, `wordpress-pro`

---

## Comandos rápidos

```bash
# Inicializar todo (LM Studio + proxy)
bash ~/.config/opencode/init-opencode.sh

# Lanzar OpenCode
bash ~/.config/opencode/start-opencode.sh
# o directamente: ocv

# Cambiar perfil MCP
bash ~/.config/opencode/switch-mcp-profile.sh local   # Solo esencial
bash ~/.config/opencode/switch-mcp-profile.sh cloud   # Todo activo

# Sincronizar configuración (el timer la hace cada 30 min automáticamente)
bash ~/.config/opencode/sync-opencode.sh

# Regenerar backup completo (verifica el setup automáticamente; si falla, aborta)
bash ~/Config/opencode/backup-opencode.sh

# Ver historial COMPLETO de peticiones (el timeline TUI solo muestra las últimas ~6)
timeline-completo                    # Sesión actual
timeline-completo --sesiones         # Listar sesiones
timeline-completo --buscar "texto"   # Buscar en todas las sesiones

# Cargar variables de entorno
set -a; source ~/.config/opencode/.env; set +a
```

> 🕐 **Nota timeline:** la TUI de OpenCode solo muestra las últimas ~6 peticiones (PR #26861 sin mergear). El script `timeline-completo` lee todas desde `opencode.db`. Un timer systemd (`check-timeline-fix.timer`, cada 3 días) vigila el PR para avisar cuando se arregle.
>
> 💾 **Nota backup:** el backup automático (`opencode-sync.timer`, cada 30 min) hace **exactamente lo mismo** que el manual: ejecuta `backup-opencode.sh`, que verifica el setup (`check-setup-completo.sh`) antes de generar el tarball. Si el setup estuviera incorrecto, el backup se aborta.

---

> 📁 **Ubicación de estos documentos:** `~/Config/opencode/documentacion/`  
> 🎯 **Backups de OpenCode:** `~/Config/opencode/backups/opencode/`  
> 🧠 **Grafo de memoria:** `~/Config/opencode/backups/` (mcp-memory-backup-*.json)  
> 🔄 **Se actualizan manualmente** cuando cambia la configuración.
