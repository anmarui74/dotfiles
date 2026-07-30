# 📚 Documentación de Configuración de OpenCode

> **Usuario:** Antonio 🧑‍💻  
> **Ubicación:** Pechina, Almería, España 📍  
> **Fecha:** 26/07/2026  
> **Modelo activo:** Qwen 3.5 (9B) con 80K contexto 🤖

---

## Documentos disponibles

| # | Documento | Descripción |
|---|-----------|-------------|
| 01 | [Configuración de Ollama + Proxy](01-configuracion-ollama.md) | 🦙 Proxy de Ollama, LiteLLM, modelos disponibles, bug #34892 |
| 02 | [Configuración de LM Studio + Proxy](02-configuracion-lmstudio.md) | 🖥️ Proxy de LM Studio, init-opencode, systemd, carga de modelo |
| 03 | [Configuración completa de Voz](03-configuracion-voz.md) | 🎤 STT (sox→whisper→LLM), TTS (edge-tts→paplay), plugin, speak |
| 04 | [Los tres perfiles de opencode.json](04-perfiles-opencode-json.md) | 📋 Perfiles local/cloud/activo, MCPs, proveedores, agentes |
| 05 | [Configuración adicional](05-configuracion-adicional.md) | ⚙️ .env, sync, systemd, scripts, estructura |
| 06 | [AGENTS.md al detalle](06-agents-md.md) | 📜 Explicación línea por línea de las reglas de comportamiento |

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
                    │  │  Modelo: Qwen 3.5 (9B)   │   │
                    │  │  Contexto: 80K tokens    │   │
                    │  │  Tools: 6 MCP servers    │   │
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
     ├── Modelo: qwen/qwen3.5-9b (80K contexto)
     ├── lms server start (systemd)
     └── lms load / unload

Ollama API ────── http://localhost:11434 ──── Proxy (4000) ──── (en desuso)
     │
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

# Sincronizar configuración
bash ~/.config/opencode/sync-opencode.sh

# Regenerar backup completo
bash ~/Config/opencode/backup-opencode.sh

# Cargar variables de entorno
set -a; source ~/.config/opencode/.env; set +a
```

---

> 📁 **Ubicación de estos documentos:** `~/Config/opencode/documentacion/`  
> 🔄 **Se actualizan manualmente** cuando cambia la configuración.
