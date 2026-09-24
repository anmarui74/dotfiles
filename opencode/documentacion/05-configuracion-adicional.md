# ⚙️ Configuración Adicional

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 🔧 Utilidades | 26/07/2026 · rev. 22/09/2026 | Antonio |

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
- Usar la API oficial de AEMET OpenData (predeterminada) con curl
- ID de Pechina: 04074 · api_key en $AEMET_API_KEY (.env)
- Respaldo si AEMET falla: https://wttr.in/{ciudad}?format=j1&m&lang=es
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
- El AGENTE nunca usa sudo (no tiene terminal interactiva): usa SIEMPRE pkexec (ventana gráfica)
- Los scripts que Antonio ejecuta en SU terminal SÍ pueden usar sudo
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
# ─── Context7 (documentación) ───
MCP_CONTEXT7_URL=https://mcp.context7.com/mcp

# ─── Chrome Debug (PWAs) ───
CHROME_DEBUG_PROFILE=/tmp/chrome-debug-profile
REMOTE_DEBUGGING_PORT=9222

# ─── Web / Fetch ───
USER_AGENT="Mozilla/5.0 (compatible; OpenCode-Bot)"
MAX_SEARCH_RESULTS=8
TIMEOUT_SECONDS=120
USER_PREFER_MARKDOWN_TABLES=true

# ─── Memoria persistente ───
MEMORY_FILE_PATH=/home/antonio/.config/opencode/data/memory/memory.jsonl
MEMORY_DATA_DIR=/home/antonio/.config/opencode/data/memory
MEMORY_BACKUP_ENABLED=true
MEMORY_BACKUP_PATH=/home/antonio/Config/opencode/backups/mcp-memory-backup-$(date '+%Y-%m-%d_%H%M').jsonl

# ─── Logging / métricas ───
LOG_FILE=/home/antonio/.config/opencode/data/init.log
LOG_RETENTION_DAYS=30
AUDIT_ENABLED=true
ENABLE_METRICS=true
METRICS_EXPORT_PATH=/home/antonio/.config/opencode/data/metrics.json

# ─── Hardware ───
HARDWARE_INDEX_PATH=/home/antonio/.config/opencode/data/hardware/index.json

# ─── AEMET (tiempo) ───
AEMET_API_KEY=********   # clave real en el .env activo (no se documenta)
```

> 📌 Las antiguas variables `OLLAMA_API_KEY` y `OLLAMA_PROXY_PORT` se **retiraron** del `.env`
> al abandonar Ollama (sustituido por LM Studio).

### Explicación de cada variable

| Variable | Valor | Propósito |
|----------|-------|-----------|
| `MCP_CONTEXT7_URL` | `https://mcp.context7.com/mcp` | Endpoint del servidor MCP de documentación |
| `CHROME_DEBUG_PROFILE` | `/tmp/chrome-debug-profile` | Perfil temporal de Chrome para depuración de PWAs |
| `REMOTE_DEBUGGING_PORT` | `9222` | Puerto de depuración remota de Chrome |
| `USER_AGENT` | `Mozilla/5.0 (compatible; OpenCode-Bot)` | User-Agent para peticiones web |
| `MAX_SEARCH_RESULTS` | `8` | Máximo de resultados de búsqueda |
| `TIMEOUT_SECONDS` | `120` | Timeout para peticiones web |
| `USER_PREFER_MARKDOWN_TABLES` | `true` | Fuerza tablas Markdown nativas en las respuestas |
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
| `AEMET_API_KEY` | (clave privada) | API key de AEMET OpenData para el tiempo (ID Pechina `04074`) |

### Cargar el .env

```bash
set -a; source /home/antonio/.config/opencode/.env; set +a
```

---

## `sync-opencode.sh`

### Archivo: `~/.config/opencode/sync-opencode.sh`

### ¿Qué hace?

1. **Sincroniza** la configuración de `~/.config/opencode/` → `~/Config/opencode/sesion-opencode/`
2. Copia archivos individuales (JSON, scripts, `.env`) al directorio de sesión
3. Copia directorios: `commands/`, `prompts/`, `skills/`, `skills-disabled/`, `plugins/`, plugin de voz (más `cli.json`)
4. Sincroniza los **manuales** de `~/.config/opencode/documentacion/` → `~/Config/opencode/documentacion/` y `AGENTS.md` a la raíz de `~/Config/opencode/` (regla: los manuales viven SOLO en las carpetas `documentacion/` de la config activa y del backup; `sesion-opencode/` es solo configuración/scripts)
5. **Regenera** el tarball de backup ejecutando `backup-opencode.sh`

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

**Archivo activo:** `~/.config/systemd/user/init-opencode.service` (embebido en `setup-opencode-completo.sh`, heredoc `INITSEOF`; no hay copia suelta en `~/Config/opencode/`)

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

### `check-nvidia-whitelist.timer`

**Archivos:**
- `~/.config/systemd/user/check-nvidia-whitelist.service`
- `~/.config/systemd/user/check-nvidia-whitelist.timer`

Mismo patrón: los **días 1 y 16 de cada mes** a las 10:00 (con retardo aleatorio de 30 min) ejecuta `check-nvidia-whitelist.sh` para verificar/actualizar el whitelist de modelos NVIDIA.

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

**Regenerar el índice (`scan`):**

```bash
python3 ~/.config/opencode/hardware-query.py scan
```

Recolecta 14 secciones (OS, CPU, RAM, placa base, GPU NVIDIA/AMD, monitores, almacenamiento, red, sensores, USB, audio, kernel/boot) y reescribe `data/hardware/index.json`. `meta.generated` y `meta.source` llevan la **fecha real** (dinámicos desde el 22/09/2026; antes `source` estaba fijado a `16/08/2026` por error).

> ⚠️ **`pkexec` y sesión gráfica:** el escaneo usa `dmidecode` vía `pkexec` (ventana de contraseña). Si lo lanza el **agente**, el proceso no hereda la sesión gráfica y `pkexec` falla en silencio, dejando **RAM (DIMMs) y placa base incompletas**. Hay que exportar antes el entorno de GNOME:
> ```bash
> export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
> export XDG_RUNTIME_DIR="/run/user/1000"
> python3 ~/.config/opencode/hardware-query.py scan
> ```

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
- **41 heredocs embebidos** comparados uno a uno contra los archivos activos
  (incluye `timeline-completo` y `speak` de `~/.local/bin/`, los plugins de
  `plugins/`, los 4 servicios/timers systemd y los manuales de hardware
  `documentacion/hardware-info.md` y `documentacion/README-hardware.md`)
- Estructura completa de pasos (1-19 + sub-pasos `4b`, `14b`, `15b`)
- Comandos necesarios presentes en el sistema

Está **integrado en `backup-opencode.sh`** (sección 0): se ejecuta SIEMPRE al hacer un backup (manual o automático) y **si el setup no está correcto, el backup se ABORTA**. No depende de la memoria del asistente — es automático.

### `check-nvidia-whitelist.sh` (05/09/2026)

**Archivo:** `~/.config/opencode/check-nvidia-whitelist.sh` · **Timer:** `check-nvidia-whitelist.timer` (días 1 y 16, 10:00 + retardo aleatorio 30 min)

Verifica el whitelist del proveedor NVIDIA aplicando la metodología completa:

1. Comprueba que los modelos del whitelist dan **HTTP 200 real**; los **410 Gone** se eliminan automáticamente de los 3 perfiles JSON.
2. Escanea el catálogo real buscando modelos **nuevos** y les aplica velocidad (≥ 10 tok/s) + tool calling.
3. Los que pasan todo quedan como **candidatos** (log + notificación) para revisión manual — no se añaden solos.
4. Reintenta 429/500/503/timeout con margen antes de decidir.

- **Log:** `data/nvidia-whitelist.log` · **Estado:** `data/nvidia-whitelist-state.json`
- **API key:** se lee de `~/.local/share/opencode/auth.json` (clave `nvidia.key`), no está hardcodeada.
- Ejecutar manualmente: `bash ~/.config/opencode/check-nvidia-whitelist.sh`

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

### Plugin TUI `opencode-sidebar-mimo` (V2, 16/09/2026)

Plugin TUI propio (no npm) **auto-descubierto** en
`~/.config/opencode/plugins/sidebar-mimo/tui.tsx` (formato V2: `Plugin.define({ id, setup })`
importando `@opencode/plugin/tui`). Reproduce la barra lateral de **MiMoCode** en OpenCode:
bloque **Context** (tokens, % usado, límite del modelo, t/s y coste),
**Directorio de trabajo** e **Instrucciones** (AGENTS.md), y la **versión** al final.

En `cli.json` (config TUI de V2) se desactivan los bloques nativos para no duplicar:
`-opencode.sidebar.context` (Context propio) y `-opencode.sidebar.footer` (la ruta ya
aparece en «Directorio de trabajo»).

> ⚠️ En V2 la config TUI es `~/.config/opencode/cli.json`; el antiguo `tui.json` (V1) se
> retiró el 16/09/2026 (archivado en `~/Config/opencode/legacy/`).
> ⚠️ El antiguo plugin npm `opencode-throughput` se **eliminó** el 11/09/2026: su bloque
> «Throughput / Recent» ya no es necesario porque el t/s aparece en el bloque Context.

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

## Servidores LSP — ❌ retirados en V2 (histórico V1, 10/08/2026)

**V2 no ejecuta servidores LSP** (sin diagnósticos ni herramientas). El bloque `lsp` se **retiró** de `opencode.json` el 16/09/2026 (copia en `~/Config/opencode/legacy/lsp-block-v1.json`). Los binarios siguen instalados y son útiles **por terminal** (`basedpyright`, `tsc --noEmit`, `cargo clippy`, `shellcheck`…). Lo de abajo es **referencia histórica (V1)**.

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
> 📌 **Nota instalación:** el `setup-opencode-completo.sh` (PASO 4b) instala igualmente los binarios de esos servidores; en V2 no se usan como LSP, pero sirven como herramientas de terminal/lint.

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
├── common-ground.md                       # Suposiciones compartidas
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
    ├── complete-sprint.md                 # Retrospectiva de sprint
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
├── cli.json                   # Config TUI V2 (plugins: voz + sidebar-mimo)
├── AGENTS.md                  # Instrucciones del sistema
├── .env                       # Variables de entorno
├── package.json               # Vacío ({}): el binario resuelve sus deps
├── package-lock.json          # Lock heredado (no se usa; excluido del backup)
│
├── mcp-fetch-fix.js           # Proxy del MCP fetch (quita la capability resources)
├── init-opencode.sh           # Inicialización completa
├── start-opencode.sh          # Lanzador interactivo
├── start-lmstudio.sh          # Arranque rápido LM Studio
├── setup-lmstudio-models.sh   # Verificar modelos
├── start-opencode-server.sh    # Lanzador OpenCode/OCV (carga LM Studio salvo SKIP_LMSTUDIO)
├── sync-opencode.sh           # Sincronización
├── bootstrap-ocv.sh           # Instalador completo desde limpio
├── check-fix.sh               # Verificar issue #39164
├── check-timeline-fix.sh      # Vigilar PR #26861 (fix timeline)
├── check-nvidia-whitelist.sh  # Verificar/actualizar whitelist NVIDIA
├── check-setup-completo.sh    # Verificar setup antes de cada backup
├── hardware-query.sh          # Consulta hardware (wrapper)
├── hardware-query.py          # Consulta hardware (motor Python)
├── lmstudio-proxy.py          # Proxy LM Studio + métricas (metrics.json)
├── lmstudio-metrics-server.py # Dashboard web de métricas (puerto 4200)
│
├── settings.lmstudio.json     # Settings de LM Studio
│
├── opencode-voice-modified/   # Plugin de voz
│   ├── index.js               # Punto de entrada (V1)
│   ├── tui.js                 # Puente V2 (Plugin.define)
│   ├── package.json
│   ├── README.md
│   └── lib/
│       ├── stt.js
│       ├── tts.js
│       ├── llm-client.js
│       ├── session.js
│       └── logger.js
│
├── plugins/
│   ├── sidebar-mimo/tui.tsx   # Barra lateral estilo MiMoCode
│   └── nvidia-filter/index.ts # Filtro de modelos NVIDIA (whitelist)
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
    ├── issue_status.txt      # Estado del issue #39164
    ├── timeline-fix.log      # Estado del PR #26861
    ├── setup-check.log       # Log de verificación del setup
    ├── nvidia-whitelist.log  # Log del check NVIDIA
    └── nvidia-whitelist-state.json  # Estado del check NVIDIA
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
│   └── mcp-memory-backup-*.jsonl  # Backups del grafo de memoria (histórico local)
│
├── data/
│   ├── onlyoffice-ai/         # Integración IA de OnlyOffice (script + snapshot + doc)
│   ├── dropbox/               # Config oficial + CLI de Dropbox
│   ├── memory/                # Grafo de memoria (copia estable → dotfiles)
│   └── ...                    # Logs y estado
│
├── documentacion/             # 📚 Manuales en Markdown (01-08 + README + hardware-info, etc.)
├── sesion-opencode/           # Setup completo + scripts/config sincronizados cada 30 min
│   ├── setup-opencode-completo.sh   # Instalador completo (con PASO 19: OnlyOffice)
│   ├── backup-opencode.sh
│   └── ...                    # Resto de scripts/config sincronizados (sin manuales)
│
├── legacy/                    # Obsoletos (tui.json V1, lsp-block-v1.json, logs retirados)
└── (respaldo-config/ fue eliminado el 09/08/2026 por obsoleto)
```

### Política de retención de backups

| Regla | Detalle |
|-------|---------|
| **Retención** | Tarballs con más de 30 días (`LOG_RETENTION_DAYS`) se borran automáticamente |
| **Poda diaria** | Solo se conserva el **primer** tarball de cada día |
| **Total esperado** | ~30 tarballs (~50 MB) en estado estable |
| **Carpeta** | `~/Config/opencode/backups/opencode/` |

### 🔐 Claves de API y copia en dotfiles (rev. 22/09/2026)

| Regla | Detalle |
|-------|---------|
| **Dónde SÍ van las claves** | En `~/Config/opencode/`: dentro de los tarballs (`credenciales/auth.json`) y **embebidas en el instalador** |
| **Dónde NUNCA** | En `~/Documentos/dotfiles/` |
| **Permisos** | El tarball se crea con `umask 077` + `chmod 600`; su directorio, con `chmod 700`. Antes quedaban en `644`/`755` (legibles por cualquier usuario) |
| **Volcado a dotfiles** | `rsync -a --delete --delete-excluded` — el segundo flag es **imprescindible**: con solo `--delete`, lo que está excluido **no se purga** del destino |
| **Grafo de memoria** | **No se excluye** de dotfiles, pero va en **UNA sola copia** (`data/memory/memory.jsonl`). Las copias fechadas `mcp-memory-backup-*.jsonl` se quedan solo en local (eran **179** versionadas) |
| **`backups/` excluido** | Se excluye **todo** el directorio `backups/` del volcado (tarballs y copias fechadas del grafo se quedan solo en local). Desde el 22/09/2026; antes solo se excluía `backups/opencode/` y se colaban restos como `.lmstudio/` |
| **Saneado del instalador** | En dotfiles sale con las claves como `TU_CLAVE_AQUI`. **Nunca** sanear el canónico de `sesion-opencode/` |

Verificar antes de commitear:

```bash
cd ~/Documentos/dotfiles
git grep -nIP '(nvapi-|oc_sk_)[A-Za-z0-9_-]{15,}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{25,}|AEMET_API_KEY=[A-Za-z0-9]{15,}' -- ':(exclude)*.md'
```
