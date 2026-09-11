# ⚙️ Configuración Adicional (Windows)

Adaptación del manual Linux al setup **Windows** de OpenCode (config activa en `C:\Users\evo01\.config\opencode\`).

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 🔧 Utilidades | 10/09/2026 · rev. 10/09/2026 | Antonio |

> AGENTS.md, variables de entorno, sincronización, Programador de tareas y scripts

---

## 📑 Índice

1. [AGENTS.md (reglas de comportamiento)](#agentsmd)
2. [Archivo `.env` (variables de entorno)](#env)
3. [Script de sincronización](#sync-opencodeps1)
4. [Tareas programadas (en vez de systemd)](#tareas-programadas)
5. [Scripts de utilidad](#scripts-de-utilidad)
6. [Prompts personalizados](#prompts-personalizados)
7. [Estructura de directorios](#estructura-de-directorios)

---

## AGENTS.md

### Archivo: `C:\Users\evo01\.config\opencode\AGENTS.md`

Es el archivo de **instrucciones del sistema** que OpenCode carga al inicio de cada sesión (referenciado en la clave `instructions` de ambos perfiles JSON). Contiene **todas las reglas de comportamiento** que el modelo debe seguir.

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
- Leer C:\Users\evo01\.config\opencode\data\hardware\index.json
- NO ejecutar comandos de detección
```

> ⚠️ **No aplica en Windows:** los comandos de detección de Linux (inxi, lspci, dmidecode) no existen; en Windows se usarían `wmic`/`Get-CimInstance` si se regenera el índice. De momento solo se lee el JSON si existe.

#### 🔧 Uso de herramientas

```
- USA LA HERRAMIENTA directamente
- NO describas lo que harías — hazlo
- NO digas "voy a leer" sin llamar a la herramienta
```

#### 🛠️ Elevación de privilegios

```
- NUNCA uses sudo (requiere contraseña)
- Elevación por UAC (ventana gráfica de administrador)
```

> ⚠️ **No aplica en Windows:** no hay sudo ni pkexec. La elevación de privilegios se hace por **UAC**: el instalador `instalar-opencode-win.ps1` se auto-eleva a administrador con `Start-Process -Verb RunAs`.

#### 🔄 Sincronización con Config/opencode-win

```
- C:\Users\evo01\.config\opencode\ es la configuración ACTIVA
- D:\Linux\Config\opencode-win\ es la copia de SEGURIDAD / origen de instalación
- Al modificar algo: copiar a D:\Linux\Config\opencode-win\config\
- Actualizar scripts de instalación si es necesario
- Ejecutar backup para regenerar la copia de seguridad
```

#### 💾 Persistencia y recuperación

```
- Las variables de entorno se cargan a nivel de usuario (no con `set -a; source`)
- start-lmstudio.ps1 verifica todo tras reinicio
- Backups del grafo de memoria en D:\Linux\Config\opencode-win\data\memory\
- Los backups se conservan según política de retención
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

> ⚠️ **No aplica en Windows tal cual.** En Linux el archivo `.env` se cargaba con `set -a; source /home/antonio/.config/opencode/.env; set +a` y contenía variables sensibles. En Windows **no se usa `.env`**: las variables de entorno necesarias se definen **a nivel de usuario** (Panel de control → Variables de entorno, o `[Environment]::SetEnvironmentVariable(...,"User")`) o las fijan los scripts directamente.

### Variables relevantes para Windows

| Variable | Valor | Propósito |
|----------|-------|-----------|
| `MEMORY_FILE_PATH` | `C:\Users\evo01\.config\opencode\data\memory\memory.jsonl` | **Ruta del archivo del grafo que usa el servidor MCP memory** (vía `environment` en los 2 perfiles JSON) |
| `MEMORY_DATA_DIR` | `C:\Users\evo01\.config\opencode\data\memory` | Directorio del grafo de memoria persistente |
| `PROXY_PORT` | `4001` | Puerto del proxy de LM Studio (variable del propio `lmstudio-proxy.py`) |
| `LMSTUDIO_UPSTREAM` | `http://127.0.0.1:1234` | Upstream de LM Studio del proxy (variable del `lmstudio-proxy.py`) |
| `ENABLE_METRICS` | `true` | Activa métricas de tokens/s en el proxy (por defecto en `lmstudio-proxy.py`) |
| `METRICS_EXPORT_PATH` | `<dir>/data/metrics.json` | Ruta de exportación de métricas del proxy (por defecto, junto al script) |
| `HARDWARE_INDEX_PATH` | `C:\Users\evo01\.config\opencode\data\hardware\index.json` | Ruta al índice de hardware |

> 📌 **Nota Windows:** en el perfil local `opencode-local.json`, la variable `MEMORY_FILE_PATH` del MCP `memory` apunta a `C:/Users/evo01/.config/opencode/data/memory/memory.jsonl`. La ruta de respaldo del grafo vive en la copia de seguridad `D:\Linux\Config\opencode-win\data\memory\`.

> ⚠️ **No aplica en Windows:** en Linux se usaban `set -a; source .env; set +a` para cargar el `.env`. En Windows las variables del proxy (`PROXY_PORT`, `LMSTUDIO_UPSTREAM`, `ENABLE_METRICS`, `METRICS_EXPORT_PATH`) se leen directamente de las variables de entorno del sistema o usan sus valores por defecto dentro del propio `lmstudio-proxy.py`.

---

## `sync-opencode.ps1`

> ⚠️ **No aplica en Windows tal cual.** En Linux existía el script `sync-opencode.sh` que sincronizaba la config activa a `~/Config/opencode/sesion-opencode/` y regeneraba el tarball de backup. En Windows **no existe un sync automático implementado**: la copia de seguridad es la carpeta `D:\Linux\Config\opencode-win\` que actúa de origen de instalación y respaldo. El instalador `instalar-opencode-win.ps1` despliega desde esa carpeta.

### ¿Qué hace el instalador en Windows?

El instalador `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1` despliega todo desde las subcarpetas `config\` y `perfil\`:

1. Copia los archivos de `config\` (opencode.jsonc, opencode-local.json, tui.json, AGENTS.md, package.json, prompts, lmstudio-proxy.py, start-lmstudio.ps1) a `C:\Users\evo01\.config\opencode\`
2. Copia `perfil\Microsoft.PowerShell_profile.ps1` al perfil de PowerShell de usuario
3. Crea las tareas programadas (backup diario + whitelist NVIDIA) si se pasa `-WithTasks`

> ⚠️ **Consejo:** al hacer una copia de seguridad manual de la config, conviene pausar las tareas programadas del Programador de tareas para evitar que copien archivos a mitad de proceso (equivalente al `systemctl --user stop opencode-sync.timer` de Linux).

---

## Tareas programadas

### En vez de servicios systemd

En Linux la automatización se hacía con servicios y timers de **systemd** (`init-opencode.service`, `opencode-sync.timer`, `check-timeline-fix.timer`, `check-nvidia-whitelist.timer`). **En Windows no hay systemd**: el equivalente es el **Programador de tareas** (`Register-ScheduledTask` / `schtasks`).

### `init-opencode` (equivalente a `init-opencode.service`)

> ⚠️ **No aplica en Windows.** En Linux existía un servicio systemd `init-opencode.service` (DESHABILITADO) que arrancaba LM Studio + modelo + proxy al iniciar sesión. En Windows **no hay servicio de inicialización**: el stack se arranca automáticamente al ejecutar la función `ocv` del perfil de PowerShell (llama a `start-lmstudio.ps1`), igual que en Linux.

Para verificar componentes manualmente, usar la función `ocv-status`:

```powershell
ocv-status
```

Esto comprueba:
- Servidor LM Studio (puerto 1234)
- Modelo cargado en VRAM (`lms ps`)
- Proxy local (puerto 4001, endpoint `/health`)

### Backup programado (tarea `OpenCode-Backup`)

El instalador `instalar-opencode-win.ps1`, si se lanza con `-WithTasks`, crea una **tarea programada diaria** para el backup:

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\Users\evo01\.config\opencode\backup-opencode.ps1`""
$trigger = New-ScheduledTaskTrigger -Daily -At 20:00
Register-ScheduledTask -TaskName "OpenCode-Backup" -Action $action -Trigger $trigger -Force
```

> ⚠️ **Nota:** el script `backup-opencode.ps1` de referencia es **opcional** (solo se crea la tarea si el archivo existe). Es el equivalente Windows del `backup-opencode.sh` de Linux.

### Verificación automática del whitelist NVIDIA

> ⚠️ **No aplica en Windows todavía.** En Linux el whitelist NVIDIA se verificaba cada 15 días con el script `check-nvidia-whitelist.sh` vía timer systemd. En Windows **no está implementado**: el whitelist de 8 modelos se mantiene manualmente en los 2 perfiles (`opencode.jsonc` y `opencode-local.json`). Puede reproducirse creando una tarea programada en el Programador de tareas con el equivalente `.ps1`.

### Gestión de tareas programadas

```powershell
# Ver tareas
Get-ScheduledTask -TaskName "OpenCode-*"

# Ejecutar manualmente una tarea
Start-ScheduledTask -TaskName "OpenCode-Backup"

# Desactivar / reactivar
Disable-ScheduledTask -TaskName "OpenCode-Backup"
Enable-ScheduledTask  -TaskName "OpenCode-Backup"

# Eliminar
Unregister-ScheduledTask -TaskName "OpenCode-Backup" -Confirm:$false

# Crear una tarea manualmente con schtasks (alternativa)
schtasks /create /tn "OpenCode-Backup" /tr "powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\evo01\.config\opencode\backup-opencode.ps1" /sc daily /st 20:00
```

> 📌 La elevación de privilegios para crear tareas que requieran administrador se hace por **UAC**.

---

## Scripts de utilidad

### `start-lmstudio.ps1`

**Archivo:** `C:\Users\evo01\.config\opencode\start-lmstudio.ps1`

Equivalente Windows de `start-lmstudio.sh` de Linux. Es **idempotente**: si el servidor, el modelo o el proxy ya están activos, no los reinicia. Autodetecta las rutas de LM Studio (`lms.exe`) y de Python, por lo que es portable.

```powershell
# Parámetros por defecto
& "$env:USERPROFILE\.config\opencode\start-lmstudio.ps1"
# Modelo, contexto y puerto del proxy configurables
& "$env:USERPROFILE\.config\opencode\start-lmstudio.ps1" -Model qwen3.8-9b -ContextLength 80000 -ProxyPort 4001
```

Qué hace:
1. Comprueba si el servidor LM Studio responde (`lms server status`); si no, lo arranca.
2. Comprueba si el modelo `qwen3.8-9b` está en VRAM (`lms ps`); si no, lo carga con `lms load qwen3.8-9b --gpu max -c 80000 -y`.
3. Arranca el proxy `lmstudio-proxy.py` en el puerto 4001 con `Start-Process ... -WindowStyle Hidden`.

> 📌 Equivale a `nohup ... &` de Linux: en Windows los procesos en segundo plano se lanzan con `Start-Process -WindowStyle Hidden`.

### `lmstudio-proxy.py` (con métricas, 05/09/2026)

**Archivo:** `C:\Users\evo01\.config\opencode\lmstudio-proxy.py`

Proxy OpenCode ↔ LM Studio (puerto 4001), solo usa la librería estándar de Python (no requiere `pip install`). Además de reenviar las peticiones:
- **Registra métricas por request** en `data\metrics.json` (definido en `METRICS_EXPORT_PATH`): timestamp, modelo, tokens in/out, tiempo, TTFT y **tokens/s**.
- **Inyecta `stats.tokens_per_second`** en respuestas no-streaming (las streaming estiman tokens con chars/4 porque LM Studio no reporta usage en SSE).

Variables de entorno: `PROXY_HOST`, `PROXY_PORT`, `LMSTUDIO_UPSTREAM`, `METRICS_EXPORT_PATH`, `ENABLE_METRICS`.

### `lmstudio-metrics-server.py` (dashboard, 05/09/2026)

> ⚠️ **No aplica en Windows (no implementado).** En Linux existía `lmstudio-metrics-server.py` que servía un dashboard web en `http://localhost:4200` con la última velocidad, la media, peticiones totales y el histórico del proxy. **En Windows este archivo no está desplegado** en la config activa. Las métricas del proxy (token/s, TTFT, latencia) se siguen registrando en `data\metrics.json` y se pueden consultar con el plugin TUI `opencode-throughput`.

### Plugin TUI `opencode-throughput` (05/09/2026)

Plugin npm registrado en `tui.json` (junto al keybind `session_rename` en F8). Muestra en la barra
lateral de OpenCode el rendimiento de **cada solicitud y de cada modelo/provider**
(local, NVIDIA y cloud): TPS medio, TTFT, latencia, tokens ↑/↓ y coste, más una
lista "Recent" con cada petición.

### `timeline-completo` (historial de sesiones)

> ⚠️ **No aplica en Windows todavía.** En Linux existía el script `~/.local/bin/timeline-completo` que leía el historial completo de `opencode.db` (sqlite3). **En Windows no está desplegado**, y además **no hay sqlite3** como comando: habría que usar el módulo `sqlite3` de Python. El timeline de la TUI (Ctrl+X G) sigue mostrando solo las últimas ~6 peticiones (límite hardcodeado; PR #26861 sin mergear).

### Hardware / check-fix / check-timeline-fix

> ⚠️ **No aplica en Windows:** los scripts `hardware-query.sh`, `check-fix.sh`, `check-timeline-fix.sh`, `check-setup-completo.sh` y `setup-lmstudio-models.sh` son de Linux y **no están desplegados en Windows**.

---

## Prompts personalizados

### `C:\Users\evo01\.config\opencode\prompts\`

```
prompts\
└── read-agents.txt    # "Lee AGENTS.md al inicio de cada sesión"
```

Este prompt se asigna a los agentes `build` y `plan` en los 2 perfiles (`opencode.jsonc` y `opencode-local.json`).

> ⚠️ **No aplica en Windows:** el directorio `commands\` (comandos estructurados de metodología de desarrollo) no está desplegado en la config de Windows. Solo existe `prompts\read-agents.txt`.

---

## Estructura de directorios

### `C:\Users\evo01\.config\opencode\` (activo)

```
.config\opencode\
├── opencode.jsonc              # Perfil GLOBAL por defecto (agente cloud)
├── opencode-local.json         # Perfil local (LM Studio + agente local)
├── tui.json                    # Config TUI (keybind f8 + plugin opencode-throughput)
├── AGENTS.md                   # Instrucciones del sistema
├── package.json                # Dependencias npm (@opencode-ai/plugin 1.18.30)
├── package-lock.json           # Lock de npm
│
├── start-lmstudio.ps1          # Arranca LM Studio + modelo + proxy (idempotente)
├── lmstudio-proxy.py           # Proxy LM Studio (puerto 4001) + métricas
│
├── prompts\
│   └── read-agents.txt
│
└── data\
    ├── hardware\
    │   └── index.json          # Índice de hardware (si se genera)
    ├── memory\
    │   └── memory.jsonl        # Grafo de memoria persistente (MCP memory)
    └── metrics.json            # Métricas de tokens/s del proxy LM Studio
```

### `C:\Users\evo01\OneDrive\Documentos\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (perfil)

Perfil de PowerShell con las funciones **`ocv`** (local), **`ocv-cloud`** (global/cloud) y **`ocv-status`** (estado). Es el equivalente Windows del `.zshrc` de Linux.

### `D:\Linux\Config\opencode-win\` (copia de seguridad / origen de instalación)

```
opencode-win\
├── AGENTS.md                        # Copia de respaldo de las reglas
├── instalar-opencode-win.ps1        # Instalador desde cero (PASOS 1-9)
│
├── config\                          # 🎯 Config activa a desplegar
│   ├── opencode.jsonc
│   ├── opencode-local.json
│   ├── tui.json
│   ├── AGENTS.md
│   ├── package.json
│   ├── start-lmstudio.ps1
│   ├── lmstudio-proxy.py
│   └── prompts\read-agents.txt
│
├── perfil\
│   └── Microsoft.PowerShell_profile.ps1   # Perfil con los lanzadores ocv
│
├── data\
│   ├── hardware\
│   └── memory\                    # Respaldo del grafo de memoria
│
├── scripts\                        # (vacío por ahora; futuro sync/backup .ps1)
│
└── documentacion\                  # 📚 Documentación en Markdown (este manual)
```

> 📌 **Diferencia con Linux:** no hay tarballs (`opencode-backup-*.tar.gz`) ni `sesion-opencode/` con un setup embebido por heredocs. El instalador Windows es `instalar-opencode-win.ps1`, que despliega desde `config\` y `perfil\`. La copia de seguridad es la propia carpeta `opencode-win\`.

### Política de retención de backups

> ⚠️ **No aplica en Windows todavía.** En Linux había una política de retención automática de 30 días para tarballs y backups del grafo (`LOG_RETENTION_DAYS`), con poda diaria. En Windows **no hay un script `backup-opencode.ps1` implementado aún**: la copia de seguridad es la carpeta `D:\Linux\Config\opencode-win\`. Si se crea la tarea programada `OpenCode-Backup`, deberá implementar su propia política de retención (p. ej. guardar una copia con fecha del grafo en `data\memory\`).