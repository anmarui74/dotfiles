# ⚙️ Configuración Adicional

> **Fecha:** 26/07/2026 | **Usuario:** Antonio

---

## Índice

1. [AGENTS.md (reglas de comportamiento)](#agentsmd)
2. [Archivo `.env` (variables de entorno)](#env)
3. [Script de sincronización](#sync-opencode-sh)
4. [Servicios systemd](#servicios-systemd)
5. [Scripts de utilidad](#scripts-de-utilidad)
6. [Prompts personalizados](#prompts-personalizados)
7. [Estructura de directorios](#estructura-de-directorios)

---

## AGENTS.md

### Archivo: `~/.config/opencode/AGENTS.md`

Es el archivo de **instrucciones del sistema** que OpenCode carga al inicio de cada sesión. Contiene **todas las reglas de comportamiento** que el modelo debe seguir.

### Secciones principales

#### 👤 Identidad del usuario

```
- Se llama Antonio
- Vive en Pechina (Almería, España)
```

#### 🌐 Reglas de idioma y formato

```
- Responde SIEMPRE en español
- Español de España (no latinoamericano)
- Fecha: dd/mm/aaaa
- Hora: formato 24h (14:30, no 2:30pm)
- Decimales: coma (3,14 no 3.14)
- Moneda: euros (€)
- Sistema métrico: km/h, °C, mm, km
```

#### 😊 Uso de emojis

```
- SÍ usamos emoji en pantalla (✈️ 🌤️ 😊)
- "Mi locucionero filtra estos iconos automáticamente antes del TTS"
```

El `locucionero` es un filtro que elimina los emojis del texto antes de pasarlo a edge-tts, para que no los lea en voz alta.

#### 🌤️ Consultar el tiempo

```
- Usar wttr.in con formato JSON
- URL: https://wttr.in/{ciudad}?format=j1&m&lang=es
- Si wttr.in no responde, NO reintentar
```

#### 💻 Consultar hardware

```
- Leer ~/.config/opencode/data/hardware/index.json
- NO ejecutar comandos de detección (inxi, lspci, dmidecode)
```

#### 🔧 Uso de herramientas

```
- USA LA HERRAMIENTA directamente
- NO describas lo que harías — hazlo
- NO digas "voy a leer" sin llamar a la herramienta
```

#### 🛠️ Elevación de privilegios

```
- NUNCA uses sudo (requiere contraseña)
- Usa SIEMPRE pkexec (interfaz gráfica)
```

#### 🔄 Sincronización con Config/opencode

```
- ~/.config/opencode/ es la configuración ACTIVA
- ~/Config/opencode/ es la copia de SEGURIDAD
- Al modificar algo: copiar a Config/opencode/
- Actualizar scripts de instalación si es necesario
- Ejecutar backup-opencode.sh para regenerar tarball
```

#### 💾 Persistencia y recuperación

```
- .env contiene variables sensibles (cargar con set -a; source .env; set +a)
- init-opencode.sh verifica todo tras reinicio
- Backups del grafo de memoria en Config/opencode/backups/
- Los backups se conservan 30 días
```

#### 🖥️ PWAs (Progressive Web Apps)

```
- Para abrir: buscar .desktop en /home/antonio/Escritorio
- Para cerrar: curl a localhost:9222 o pkill chrome
```

#### 📋 Checklist antes de responder

```
- ¿Respuesta en español?
- ¿Fecha/hora en formato España?
- ¿Decimales con coma?
- ¿He usado la herramienta directamente?
```

---

## `.env`

### Archivo: `~/.config/opencode/.env`

```bash
# ─── Ollama ───
OLLAMA_API_KEY=ollama
OLLAMA_PROXY_PORT=4000

# ─── Context7 (documentación) ───
MCP_CONTEXT7_URL=https://mcp.context7.com/mcp

# ─── Chrome Debug (PWAs) ───
CHROME_DEBUG_PROFILE=/tmp/chrome-debug-profile
REMOTE_DEBUGGING_PORT=9222

# ─── Web / Fetch ───
USER_AGENT="Mozilla/5.0 (compatible; OpenCode-Bot)"
MAX_SEARCH_RESULTS=8
TIMEOUT_SECONDS=120

# ─── Memoria persistente ───
MEMORY_DATA_DIR=/home/antonio/.config/opencode/data/memory
MEMORY_BACKUP_ENABLED=true
MEMORY_BACKUP_PATH=/home/antonio/Config/opencode/backups/mcp-memory-backup-$(date '+%Y-%m-%d_%H%M').json

# ─── Logging ───
LOG_FILE=/home/antonio/.config/opencode/data/init.log
LOG_RETENTION_DAYS=30
AUDIT_ENABLED=true

# ─── Hardware ───
HARDWARE_INDEX_PATH=/home/antonio/.config/opencode/data/hardware/index.json
```

### Explicación de cada variable

| Variable | Valor | Propósito |
|----------|-------|-----------|
| `OLLAMA_API_KEY` | `ollama` | API key para Ollama (no necesita autenticación real) |
| `OLLAMA_PROXY_PORT` | `4000` | Puerto del proxy de Ollama |
| `MCP_CONTEXT7_URL` | `https://mcp.context7.com/mcp` | Endpoint del servidor MCP de documentación |
| `CHROME_DEBUG_PROFILE` | `/tmp/chrome-debug-profile` | Perfil temporal de Chrome para depuración de PWAs |
| `REMOTE_DEBUGGING_PORT` | `9222` | Puerto de depuración remota de Chrome |
| `USER_AGENT` | `Mozilla/5.0 (compatible; OpenCode-Bot)` | User-Agent para peticiones web |
| `MAX_SEARCH_RESULTS` | `8` | Máximo de resultados de búsqueda |
| `TIMEOUT_SECONDS` | `120` | Timeout para peticiones web |
| `MEMORY_DATA_DIR` | `~/.config/opencode/data/memory` | Directorio del grafo de memoria persistente |
| `MEMORY_BACKUP_ENABLED` | `true` | Activa backups automáticos del grafo |
| `MEMORY_BACKUP_PATH` | `Config/opencode/backups/...` | Ruta de los backups del grafo |
| `LOG_FILE` | `data/init.log` | Archivo de log de inicialización |
| `LOG_RETENTION_DAYS` | `30` | Días de retención de logs |
| `AUDIT_ENABLED` | `true` | Auditoría de actividad |
| `HARDWARE_INDEX_PATH` | `data/hardware/index.json` | Ruta al índice de hardware |

### Cargar el .env

```bash
set -a; source /home/antonio/.config/opencode/.env; set +a
```

---

## `sync-opencode.sh`

### Archivo: `~/.config/opencode/sync-opencode.sh`

### ¿Qué hace?

1. **Sincroniza** archivos de `~/.config/opencode/` → `~/Config/opencode/`
2. Copia archivos individuales (excepto `__pycache__`, `node_modules`, `build`, ocultos)
3. Copia directorios completos: `commands/`, `prompts/`, `data/`, `skills/`
4. Sincroniza `setup-opencode-completo.sh` con su copia en `scripts/`
5. **Regenera** el tarball de backup si existe `backup-opencode.sh`

### ¿Cuándo se ejecuta?

- Automáticamente cada **2 minutos** vía systemd timer
- También se puede ejecutar manualmente

### Lock file

Usa `/tmp/opencode-sync.lock` para evitar ejecuciones simultáneas.

---

## Servicios systemd

### `init-opencode.service`

**Archivos:**
- `~/.config/systemd/user/init-opencode.service`
- `~/Config/opencode/systemd/init-opencode.service`

```ini
[Unit]
Description=OpenCode - arranca LM Studio, modelo 80K y proxy
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/home/antonio/.config/opencode/init-opencode.sh

[Install]
WantedBy=default.target
```

**Propósito:** Arranca LM Studio, carga el modelo con 80K de contexto e inicia el proxy al iniciar sesión.

### `opencode-sync.service`

**Archivo:** `~/.config/systemd/user/opencode-sync.service`

```ini
[Service]
Type=oneshot
ExecStart=/home/antonio/.config/opencode/sync-opencode.sh
```

### `opencode-sync.timer`

**Archivo:** `~/.config/systemd/user/opencode-sync.timer`

```ini
[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
Unit=opencode-sync.service
```

**Propósito:** Ejecuta la sincronización cada 2 minutos.

### Gestión de servicios

```bash
# Ver estado
systemctl --user status init-opencode.service
systemctl --user status opencode-sync.timer

# Activar
systemctl --user enable init-opencode.service
systemctl --user enable opencode-sync.timer

# Desactivar
systemctl --user disable opencode-sync.timer

# Ejecutar manualmente
systemctl --user start init-opencode.service
```

---

## Scripts de utilidad

### `hardware-query.sh`

**Archivo:** `~/.config/opencode/hardware-query.sh`

Consulta rápida de información del hardware:

```bash
source ~/.config/opencode/hardware-query.sh && hw_query <campo>
```

Lee del archivo JSON `data/hardware/index.json`.

### `web-search.sh`

**Archivo:** `~/.config/opencode/web-search.sh`

Servidor MCP de búsqueda DuckDuckGo (fallback HTML). Se usa cuando `duckduckgo-mcp-server` no está disponible.

### `check-fix.sh`

**Archivo:** `~/.config/opencode/check-fix.sh`

Verifica el estado del **issue #39164** de OpenCode (un bug que afecta al sistema).

### `setup-lmstudio-models.sh`

**Archivo:** `~/.config/opencode/setup-lmstudio-models.sh`

Verifica qué modelos están disponibles en LM Studio.

---

## Prompts personalizados

### `~/.config/opencode/prompts/`

```
prompts/
└── read-agents.txt    # "Lee AGENTS.md al inicio de cada sesión"
```

Este prompt se asigna a los agentes `build` y `plan` en `opencode.json`.

### `~/.config/opencode/commands/`

Directorio con **comandos estructurados** para flujos de trabajo:

```
commands/
├── common-ground.md                       # Suposiciones compartidas (309 líneas)
├── common-ground-references/
│   ├── assumption-classification.md
│   ├── reasoning-graph.md
│   └── file-management.md
├── discovery/
│   ├── create.md                          # Descubrimiento: crear
│   ├── synthesize.md                      # Descubrimiento: sintetizar
│   └── approve.md                         # Descubrimiento: aprobar
├── planning/
│   ├── epic-plan.md                       # Planificación de épica
│   └── impl-plan.md                       # Plan de implementación
├── execution/
│   ├── execute-ticket.md                  # Ejecutar ticket
│   └── complete-ticket.md                 # Completar ticket
└── retrospectives/
    ├── complete-sprint.md                 # Retrospectiva de sprint (752 líneas)
    └── complete-epic.md                   # Retrospectiva de épica
```

Estos comandos implementan una **metodología de desarrollo** completa con fases de descubrimiento, planificación, ejecución y retrospectivas.

---

## Estructura de directorios

### `~/.config/opencode/` (activo)

```
.config/opencode/
├── opencode.json              # Config principal (perfil activo)
├── opencode-local.json        # Perfil local
├── opencode-cloud.json        # Perfil cloud
├── opencode.jsonc             # Config shell
├── tui.json                   # Config TUI (plugin voz)
├── AGENTS.md                  # Instrucciones del sistema
├── .env                       # Variables de entorno
├── package.json               # Dependencias npm
├── package-lock.json          # Lock de npm
│
├── lmstudio-proxy.py          # Proxy LM Studio
├── init-opencode.sh           # Inicialización completa
├── start-opencode.sh          # Lanzador interactivo
├── start-lmstudio.sh          # Arranque rápido LM Studio
├── setup-lmstudio-models.sh   # Verificar modelos
├── switch-mcp-profile.sh      # Cambiar perfil MCP
├── sync-opencode.sh           # Sincronización
├── bootstrap-ocv.sh           # Instalador de voz
├── check-fix.sh               # Verificar issue #39164
├── web-search.sh              # MCP búsqueda web
├── hardware-query.sh          # Consulta hardware
│
├── settings.lmstudio.json     # Settings de LM Studio
├── litellm-config.yaml        # Config LiteLLM
│
├── opencode-voice-modified/   # Plugin de voz
│   ├── index.js
│   ├── package.json
│   ├── README.md
│   └── lib/
│       ├── stt.js
│       ├── tts.js
│       ├── llm-client.js
│       ├── session.js
│       └── logger.js
│
├── prompts/
│   └── read-agents.txt
│
├── commands/
│   ├── common-ground.md
│   ├── discovery/
│   ├── planning/
│   ├── execution/
│   └── retrospectives/
│
├── skills/                   # Skills de OpenCode (68 activos)
│   ├── angular-architect/
│   ├── python-pro/
│   ├── react-expert/
│   └── ... (68 skills)
│
├── skills-disabled/          # Skills desactivados (18)
│
└── data/
    ├── hardware/
    │   ├── index.json        # Información completa del sistema
    │   └── README.txt
    ├── memory/               # Grafo de memoria persistente
    ├── init.log              # Log de inicialización
    ├── sync.log              # Log de sincronización
    ├── available_models.txt  # Modelos disponibles
    ├── memory_status.txt     # Estado de la memoria
    └── issue_status.txt      # Estado del issue #39164
```

### `~/Config/opencode/` (backup)

Misma estructura que `.config/opencode/` más:

```
Config/opencode/
├── backup-opencode.sh        # Script de backup completo
├── restore.sh                # (dentro del tarball de backup)
├── ollama-proxy.py           # Proxy de Ollama (histórico)
├── .zshrc                    # Config ZSH con alias de OpenCode
├── optimizacion-26-07-2026.md
├── systemd/
│   ├── init-opencode.service
│   └── user/
│       ├── init-opencode.service
│       ├── opencode-sync.service
│       └── opencode-sync.timer
├── sesion-opencode/
│   ├── setup-opencode-completo.sh   # Instalador completo
│   ├── scripts/
│   │   └── setup-opencode-completo.sh
│   └── config/
│       └── opencode.json
├── instalar-voz-opencode-v2/
├── setup-voz.sh
└── backups/                  # Backups del grafo de memoria
    ├── mcp-memory-backup-*.json
    └── 20260726_1220/
        └── opencode.json
```
