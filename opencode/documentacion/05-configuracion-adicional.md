# ⚙️ Configuración Adicional

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 🔧 Utilidades | 26/07/2026 | Antonio |

> Variables de entorno, sincronización, systemd y scripts

---

## 📑 Índice


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
MEMORY_FILE_PATH=/home/antonio/.config/opencode/data/memory/memory.jsonl
MEMORY_DATA_DIR=/home/antonio/.config/opencode/data/memory
MEMORY_BACKUP_ENABLED=true
MEMORY_BACKUP_PATH=/home/antonio/Config/opencode/backups/mcp-memory-backup-$(date '+%Y-%m-%d_%H%M').jsonl

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
| `OLLAMA_PROXY_PORT` | `4000` | Puerto del proxy de Ollama (en desuso) |
| `MCP_CONTEXT7_URL` | `https://mcp.context7.com/mcp` | Endpoint del servidor MCP de documentación |
| `CHROME_DEBUG_PROFILE` | `/tmp/chrome-debug-profile` | Perfil temporal de Chrome para depuración de PWAs |
| `REMOTE_DEBUGGING_PORT` | `9222` | Puerto de depuración remota de Chrome |
| `USER_AGENT` | `Mozilla/5.0 (compatible; OpenCode-Bot)` | User-Agent para peticiones web |
| `MAX_SEARCH_RESULTS` | `8` | Máximo de resultados de búsqueda |
| `TIMEOUT_SECONDS` | `120` | Timeout para peticiones web |
| `MEMORY_DATA_DIR` | `~/.config/opencode/data/memory` | Directorio del grafo de memoria persistente |
| `MEMORY_FILE_PATH` | `~/.config/opencode/data/memory/memory.jsonl` | **Ruta del archivo del grafo que usa el servidor MCP memory** (vía `environment` en los 3 perfiles) |
| `MEMORY_BACKUP_ENABLED` | `true` | Activa backups automáticos del grafo |
| `MEMORY_BACKUP_PATH` | `Config/opencode/backups/...` | Ruta de los backups del grafo |
| `LOG_FILE` | `data/init.log` | Archivo de log de inicialización |
| `LOG_RETENTION_DAYS` | `30` | Días de retención de logs y tarballs de backup |
| `AUDIT_ENABLED` | `true` | Auditoría de actividad |
| `ENABLE_METRICS` | `true` | Métricas de tokens/s (proxy LM Studio, activado 05/09/2026) |
| `METRICS_EXPORT_PATH` | `data/metrics.json` | Ruta de exportación de métricas del proxy |
| `HARDWARE_INDEX_PATH` | `data/hardware/index.json` | Ruta al índice de hardware |

### Cargar el .env

```bash
set -a; source /home/antonio/.config/opencode/.env; set +a
```

---

## `sync-opencode.sh`

### Archivo: `~/.config/opencode/sync-opencode.sh`

### ¿Qué hace?

1. **Sincroniza** archivos de `~/.config/opencode/` → `~/Config/opencode/sesion-opencode/`
2. Copia archivos individuales (JSON, scripts, md, `.env`) al directorio de sesión
3. Copia directorios: `commands/`, `prompts/`, `skills/`, `skills-disabled/`, `tui.json`, plugin de voz
4. **Regenera** el tarball de backup ejecutando `backup-opencode.sh`

> 📌 El backup completo se genera en `~/Config/opencode/backups/opencode/` con retención de 30 días y poda de 1 tarball por día.
>
> 🔑 Desde el **05/09/2026** el backup incluye además `auth.json` (credenciales de proveedores NVIDIA `nvapi-*` y OpenCode GO `sk-*`) en `credenciales/auth.json` dentro del tarball, y el `restore.sh` lo restaura a `~/.local/share/opencode/auth.json`. Sin él, los agentes en la nube no funcionan tras reinstalar.
>
> 💡 **Nota (10/08/2026):** el backup automático hace **exactamente lo mismo** que el manual: al final ejecuta el mismo `backup-opencode.sh`, que incluye la **verificación automática del setup** (`check-setup-completo.sh`). Si el setup estuviera incorrecto, el backup se aborta (y se registra en `data/sync.log`).

### ¿Cuándo se ejecuta?

- Automáticamente cada **30 minutos** vía systemd timer (cambió de 2 min a 30 min el 10/08/2026)
- También se puede ejecutar manualmente

### Lock file

Usa `/tmp/opencode-sync.lock` para evitar ejecuciones simultáneas.

> ⚠️ **Consejo:** al hacer un backup manual, conviene parar el timer primero para evitar que el sync (cada 30 min) interfiera copiando archivos durante el proceso:
> ```bash
> systemctl --user stop opencode-sync.timer
> bash ~/Config/opencode/backup-opencode.sh
> systemctl --user start opencode-sync.timer
> ```

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

> ⚠️ **Estado actual: DESHABILITADO.** La carga del modelo ocurre automáticamente al abrir `opencode` u `ocv` (vía `start-opencode-server.sh`), no al iniciar sesión. No es necesario habilitarlo.

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
OnBootSec=5min
OnUnitActiveSec=30min
Unit=opencode-sync.service
```

**Propósito:** Ejecuta la sincronización cada 30 minutos (cambiado de 2 min a 30 min el 10/08/2026).

### `check-opencode-fix.timer`

**Archivos:**
- `~/.config/systemd/user/check-opencode-fix.service`
- `~/.config/systemd/user/check-opencode-fix.timer`

```ini
# check-opencode-fix.service
[Unit]
Description=Check OpenCode issue #39164 status

[Service]
Type=oneshot
ExecStart=/home/antonio/.config/opencode/check-fix.sh

# check-opencode-fix.timer
[Timer]
OnCalendar=*-*-* 10:00:00
OnUnitActiveSec=3d
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
```

**Propósito:** Ejecuta `check-fix.sh` cada 3 días para comprobar si el **issue #39164** de OpenCode (bug de tools locales) se ha cerrado. Si está cerrado, muestra una notificación de escritorio.

### `check-timeline-fix.timer`

**Archivos:**
- `~/.config/systemd/user/check-timeline-fix.service`
- `~/.config/systemd/user/check-timeline-fix.timer`

Mismo patrón: cada 3 días ejecuta `check-timeline-fix.sh` para vigilar el PR #26861 (fix del timeline TUI).

### Gestión de servicios

```bash
# Ver estado
systemctl --user status init-opencode.service
systemctl --user status opencode-sync.timer
systemctl --user status check-opencode-fix.timer
systemctl --user status check-timeline-fix.timer

# Activar
systemctl --user enable init-opencode.service
systemctl --user enable opencode-sync.timer

# Desactivar
systemctl --user disable opencode-sync.timer

# Ejecutar manualmente
systemctl --user start init-opencode.service
systemctl --user start check-opencode-fix.service
```

---

## Scripts de utilidad

### `hardware-query.sh` + `hardware-query.py`

**Archivos:** `~/.config/opencode/hardware-query.sh` (wrapper) y `~/.config/opencode/hardware-query.py` (motor Python)

Consulta rápida de información del hardware:

```bash
source ~/.config/opencode/hardware-query.sh && hw_query <campo>
```

Campos: `status`, `cpu`, `gpu`, `ram`, `motherboard`, `wifi`, `bluetooth`, `all` (o cualquier clave del índice).

El `.sh` es un wrapper fino que delega en `hardware-query.py` (motor Python robusto con `argparse`-free, JSON manejado con `json.dumps`, sin quoting frágil). Lee del archivo JSON `data/hardware/index.json`.

> **Nota (16/08/2026):** `web-search.sh` fue **eliminado** — no estaba registrado como MCP en ningún perfil y la búsqueda web la cubren el MCP `fetch` y la herramienta integrada de OpenCode.

### `check-fix.sh`

**Archivo:** `~/.config/opencode/check-fix.sh`

Verifica el estado del **issue #39164** de OpenCode (un bug que afecta al sistema).

### `check-timeline-fix.sh` (10/08/2026)

**Archivo:** `~/.config/opencode/check-timeline-fix.sh`

Vigila el **PR #26861** de OpenCode (fix del timeline TUI). Se ejecuta automáticamente cada 3 días vía el timer systemd `check-timeline-fix.timer` y registra el resultado en `data/timeline-fix.log`. Si el PR se mergea, avisa para retirar el script `timeline-completo`.

### `check-setup-completo.sh` (10/08/2026)

**Archivo:** `~/.config/opencode/check-setup-completo.sh`

**Verificación OBLIGATORIA del setup antes de cada backup.** Comprueba automáticamente que `setup-opencode-completo.sh` está correcto y completo:

- `bash -n` (sintaxis)
- `shellcheck` (sin errores reales; SC2016 en heredocs = OK)
- **22 heredocs embebidos** comparados uno a uno contra los archivos activos
  (incluye `timeline-completo` y `speak` de `~/.local/bin/`)
- Estructura completa de pasos (1-19 + sub-pasos)
- Comandos necesarios presentes en el sistema

Está **integrado en `backup-opencode.sh`** (sección 0): se ejecuta SIEMPRE al hacer un backup (manual o automático) y **si el setup no está correcto, el backup se ABORTA**. No depende de la memoria del asistente — es automático.

### `setup-lmstudio-models.sh`

**Archivo:** `~/.config/opencode/setup-lmstudio-models.sh`

Verifica qué modelos están disponibles en LM Studio.

### `lmstudio-proxy.py` (con métricas, 05/09/2026)

**Archivo:** `~/.config/opencode/lmstudio-proxy.py`

Proxy OpenCode ↔ LM Studio (puerto 4001). Además de reenviar las peticiones:
- **Registra métricas por request** en `data/metrics.json` (definido en `METRICS_EXPORT_PATH` del `.env`, activado con `ENABLE_METRICS=true`): timestamp, modelo, tokens in/out, tiempo y **tokens/s**.
- **Inyecta `stats.tokens_per_second`** en respuestas no-streaming (las streaming estiman tokens con chars/4 porque LM Studio no reporta usage en SSE).

### `lmstudio-metrics-server.py` (dashboard, 05/09/2026)

**Archivo:** `~/.config/opencode/lmstudio-metrics-server.py`

Servidor web local (puerto 4200) con dashboard de métricas:
- `http://localhost:4200/` → página HTML (última velocidad, media, peticiones, histórico).
- `http://localhost:4200/api/metrics` → JSON crudo de `metrics.json`.

Iniciar:
```bash
python3 ~/.config/opencode/lmstudio-metrics-server.py 4200
```

### Plugin TUI `opencode-throughput` (05/09/2026)

Plugin npm registrado en `tui.json` (junto al plugin de voz). Muestra en la barra
lateral de OpenCode el rendimiento de **cada solicitud y de cada modelo/provider**
(local, NVIDIA y cloud): TPS medio, TTFT, latencia, tokens ↑/↓ y coste, más una
lista "Recent" con cada petición. Se instala vía npm en `~/.cache/opencode/node_modules/`.

---

## Timeline completo (`timeline-completo`, 10/08/2026)

El timeline de la TUI de OpenCode (Ctrl+X G) solo muestra las últimas ~6 peticiones (límite hardcodeado; el PR #26861 sigue abierto). El script **`~/.local/bin/timeline-completo`** lee el historial completo directamente de `opencode.db` (sqlite3):

```bash
timeline-completo                # Historial completo de la sesión actual
timeline-completo <id_sesión>    # Historial de una sesión concreta
timeline-completo --sesiones     # Lista las sesiones recientes con título
timeline-completo --buscar "txt" # Busca peticiones en TODAS las sesiones
```

Todas las peticiones de Antonio están guardadas en `~/.local/share/opencode/opencode.db` aunque la TUI no las muestre.

---

## Servidores LSP (10/08/2026)

OpenCode tiene **11 servidores LSP** configurados en la sección `lsp` de los tres perfiles (`opencode.json`, `opencode-local.json`, `opencode-cloud.json`). Ayudan a la IA a analizar código: localizar funciones, detectar errores y entender la estructura del proyecto.

### Instalados vía npm (`~/.npm-global/bin/`)

| Servidor | Paquete | Para |
|----------|---------|------|
| `typescript-language-server` | `typescript-language-server` | TS/JS |
| `vscode-json-language-server` | `vscode-langservers-extracted` | JSON (y de regalo CSS, HTML, ESLint, Markdown) |
| `yaml-language-server` | `yaml-language-server` | YAML |
| `bash-language-server` | `bash-language-server` | Bash y Zsh (forzado) |
| `marksman` | `pacman -S marksman` (binario autónomo) | Markdown |

### Instalados por otros medios

| Servidor | Cómo | Para |
|----------|------|------|
| `basedpyright-langserver` | `pipx install basedpyright` | Python |
| `clangd` | `pacman -S clang` | C/C++ |
| `rust-analyzer` | `rustup component add rust-analyzer` | Rust |
| `gopls` | `go install golang.org/x/tools/gopls@latest` | Go |

### Herramientas auxiliares

| Herramienta | Cómo | Función |
|-------------|------|---------|
| `shellcheck` | `pacman -S shellcheck` | Linting de scripts bash |
| `shfmt` | `pacman -S shfmt` | Formateo de scripts bash |

> 📌 **Nota zsh:** no existe LSP zsh dedicado (parser tree-sitter-zsh abandonado). Se fuerza `bash-language-server` en `.zsh`/`.zshrc`: navegación y símbolos sí, diagnósticos no.
>
> 📌 **Nota instalación:** el `setup-opencode-completo.sh` (PASO 4b) instala todos los servidores LSP automáticamente en instalaciones desde cero.

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
 ├── start-opencode-server.sh    # Lanzador OpenCode/OCV (carga LM Studio salvo SKIP_LMSTUDIO)
 ├── sync-opencode.sh           # Sincronización
 ├── bootstrap-ocv.sh           # Instalador de voz
├── check-fix.sh               # Verificar issue #39164
 ├── check-timeline-fix.sh      # Vigilar PR #26861 (fix timeline)
 ├── check-setup-completo.sh    # Verificar setup antes de cada backup
  ├── hardware-query.sh          # Consulta hardware (wrapper)
  ├── hardware-query.py          # Consulta hardware (motor Python)
  ├── lmstudio-proxy.py          # Proxy LM Studio + métricas (metrics.json)
  ├── lmstudio-metrics-server.py # Dashboard web de métricas (puerto 4200)
│
├── tui.json                    # Config TUI (plugins: voz + opencode-throughput)
│
├── settings.lmstudio.json     # Settings de LM Studio
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
├── skills/                   # Skills de OpenCode (50 activos)
│   ├── angular-architect/
│   ├── python-pro/
│   ├── react-expert/
│   └── ... (50 skills)
│
├── skills-disabled/          # Skills desactivados (18)
│
└── data/
    ├── hardware/
    │   ├── index.json        # Información completa del sistema
    │   └── README.txt
    ├── memory/               # Grafo de memoria persistente
    ├── metrics.json          # Métricas de tokens/s del proxy LM Studio
    ├── init.log              # Log de inicialización
    ├── sync.log              # Log de sincronización
    ├── available_models.txt  # Modelos disponibles
    ├── memory_status.txt     # Estado de la memoria
    └── issue_status.txt      # Estado del issue #39164
```

### `~/Config/opencode/` (backup)

Estructura **ordenada** de respaldo (reorganizada el 09/08/2026):

```
Config/opencode/
├── AGENTS.md                  # Copia de respaldo de las reglas
├── backup-opencode.sh         # Script de backup (genera tarball + retención + poda)
├── sync-opencode.sh           # Copia de respaldo del sincronizador
├── bootstrap-ocv.sh           # Instalador de voz desde limpio
├── setup-opencode-completo.sh # 🔗 ENLACE SIMBÓLICO → sesion-opencode/ (instalador completo, sin duplicar)
│
├── backups/                   # 🎯 CARPETA DE BACKUPS
│   ├── opencode/              # Tarballs opencode-backup-*.tar.gz (1/día, 30 días)
│   └── mcp-memory-backup-*.json  # Backups del grafo de memoria
│
├── data/
│   ├── onlyoffice-ai/         # Integración IA de OnlyOffice (script + snapshot + doc)
│   ├── hardware/              # Índice de hardware
│   └── ...                    # Logs y estado
│
├── documentacion/             # 📚 Documentación en Markdown (este README y docs 01-06)
├── sesion-opencode/           # Setup completo + scripts sincronizados cada 30 min
│   ├── setup-opencode-completo.sh   # Instalador completo (con PASO 19: OnlyOffice)
│   ├── AGENTS.md
│   ├── backup-opencode.sh
│   └── ...                    # Resto de scripts/config sincronizados
│
└── (legacy/ y respaldo-config/ fueron eliminados el 09/08/2026 por obsoletos)
```

### Política de retención de backups

| Regla | Detalle |
|-------|---------|
| **Retención** | Tarballs con más de 30 días (`LOG_RETENTION_DAYS`) se borran automáticamente |
| **Poda diaria** | Solo se conserva el **primer** tarball de cada día |
| **Total esperado** | ~30 tarballs (~50 MB) en estado estable |
| **Carpeta** | `~/Config/opencode/backups/opencode/` |
