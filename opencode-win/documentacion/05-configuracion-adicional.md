# ⚙️ Configuración Adicional (Windows)

Adaptación del manual Linux al setup **Windows** de OpenCode (config activa en `C:\Users\evo01\.config\opencode\`).

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Utilidades | 10/09/2026 · rev. 24/09/2026 | Antonio |

> AGENTS.md, variables de entorno, sincronización, Programador de tareas y scripts

---

## 📓 Índice

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

> 📍 **Nota Windows:** en el perfil local `opencode-local.json`, la variable `MEMORY_FILE_PATH` del MCP `memory` apunta a `C:/Users/evo01/.config/opencode/data/memory/memory.jsonl`. La ruta de respaldo del grafo vive en la copia de seguridad `D:\Linux\Config\opencode-win\data\memory\`.

> ⚠️ **No aplica en Windows:** en Linux se usaban `set -a; source .env; set +a` para cargar el `.env`. En Windows las variables del proxy (`PROXY_PORT`, `LMSTUDIO_UPSTREAM`, `ENABLE_METRICS`, `METRICS_EXPORT_PATH`) se leen directamente de las variables de entorno del sistema o usan sus valores por defecto dentro del propio `lmstudio-proxy.py`.

---

## `sync-opencode.ps1`

En Windows el script equivalente es `D:\Linux\Config\opencode-win\scripts\sync-opencode.ps1`, que sincroniza la config activa (`C:\Users\evo01\.config\opencode\`) con el respaldo (`D:\Linux\Config\opencode-win\`). Además, `scripts\backup-opencode.ps1` regenera la copia de seguridad y vuelca una copia saneada a `D:\Linux\Documentos\dotfiles\opencode-win`.

### ¿Qué hace el instalador en Windows?

El instalador `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1` despliega todo desde las subcarpetas `config\` y `perfil\`:

1. Copia los archivos de `config\` (`opencode.jsonc`, `opencode-local.json`, `opencode-cloud.json`, `cli.json`, `AGENTS.md`, `package.json`, `prompts\`, `lmstudio-proxy.py`, `start-lmstudio.ps1`, `voice\`, `opencode-voice-modified\`, `plugins\`, `scripts\`) a `C:\Users\evo01\.config\opencode\`
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

> 📍 La elevación de privilegios para crear tareas que requieran administrador se hace por **UAC**.

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

> 📍 Equivale a `nohup ... &` de Linux: en Windows los procesos en segundo plano se lanzan con `Start-Process -WindowStyle Hidden`.

### `lmstudio-proxy.py` (con métricas, 05/09/2026)

**Archivo:** `C:\Users\evo01\.config\opencode\lmstudio-proxy.py`

Proxy OpenCode ↔ LM Studio (puerto 4001), solo usa la librería estándar de Python (no requiere `pip install`). Además de reenviar las peticiones:
- **Registra métricas por request** en `data\metrics.json` (definido en `METRICS_EXPORT_PATH`): timestamp, modelo, tokens in/out, tiempo, TTFT y **tokens/s**.
- **Inyecta `stats.tokens_per_second`** en respuestas no-streaming (las streaming estiman tokens con chars/4 porque LM Studio no reporta usage en SSE).

Variables de entorno: `PROXY_HOST`, `PROXY_PORT`, `LMSTUDIO_UPSTREAM`, `METRICS_EXPORT_PATH`, `ENABLE_METRICS`.

### `lmstudio-metrics-server.py` (dashboard, 05/09/2026)

> ⚠️ **No implementado en Windows.** En Linux servía un dashboard web en `http://localhost:4200` con la última velocidad, la media, peticiones totales y el histórico del proxy. En Windows **no está desplegado**. Las métricas del proxy se registran en `data\metrics.json` y se pueden consultar por terminal o con la barra lateral MiMo (ver más abajo).

### Barra lateral MiMo (`antonio.sidebar-mimo`)

Plugin TUI propio (`plugins\antonio.sidebar-mimo\tui.tsx`, auto-descubierto por V2) que pinta la barra lateral de OpenCode. Muestra en el bloque **Context**: tokens usados, % del límite, límite del modelo, **t/s** y coste, además del directorio de trabajo y los ficheros de instrucciones. Funciona para **todos** los providers (local, NVIDIA, cloud).

> ⚠️ El antiguo plugin npm `opencode-throughput` ya **no está instalado**; su función la cubren la barra MiMo y el proxy (puerto 4001).

### `timeline-completo.ps1` (historial de sesiones)

Script `D:\Linux\Config\opencode-win\scripts\timeline-completo.ps1` (y función `timeline-completo` del perfil). Lee el historial **completo** de sesiones directamente de `C:\Users\evo01\.local\share\opencode\opencode.db` con el módulo `sqlite3` de Python.

```powershell
timeline-completo                 # historial de la sesión actual
timeline-completo <id_sesión>     # historial de una sesión concreta
timeline-completo -Sesiones       # lista las sesiones recientes
timeline-completo -Buscar "texto" # busca en todas las sesiones
```

> El timeline de la TUI (Ctrl+X G) sigue mostrando solo las últimas ~6 peticiones (límite hardcodeado; PR #26861 sin mergear).

### Servidor TTS persistente (`voice\tts-server.ps1`)

Gestión del servidor Kokoro (ver `03-configuracion-voz.md`):

```powershell
tts-server status    # estado del servidor (voz + providers)
tts-server start     # arrancar (carga el modelo en GPU)
tts-server stop      # parar (libera VRAM)
tts-server restart
```

### Hardware / checks

Scripts PowerShell desplegados en `scripts\`:

| Script | Función |
|--------|---------|
| `hardware-query.ps1` | Consulta de hardware (CPU, GPU, RAM, disco, red). Función `hw_query` del perfil |
| `check-nvidia-whitelist.ps1` | Verifica el whitelist NVIDIA (HTTP 200 + tool calling) |
| `check-setup-completo.ps1` | Verifica la coherencia del setup |
| `backup-opencode.ps1` | Genera la copia de seguridad (+ copia saneada a dotfiles) |
| `sync-opencode.ps1` | Sincroniza la config activa con el respaldo |
| `setup-voz.ps1` | Instala el stack de voz (STT + TTS) |
| `ocv-status.ps1` | Estado de los componentes |

---

## Prompts personalizados

### `C:\Users\evo01\.config\opencode\prompts\`

```
prompts\
└── read-agents.txt    # "Lee AGENTS.md al inicio de cada sesión"
```

Este prompt se asigna a los agentes `build` y `plan` en el perfil base (`opencode.jsonc`), que los perfiles local y cloud heredan.

> ⚠️ **No aplica en Windows:** el directorio `commands\` (comandos estructurados de metodología de desarrollo) no está desplegado en la config de Windows. Solo existe `prompts\read-agents.txt`.

---

## Estructura de directorios

### `C:\Users\evo01\.config\opencode\` (activo)

```
.config\opencode\
├── opencode.jsonc              # Perfil GLOBAL / base común (agente cloud)
├── opencode-local.json         # Perfil LOCAL (LM Studio + agente local, MCPs esenciales)
├── opencode-cloud.json         # Perfil CLOUD (bloquea providers locales)
├── cli.json                    # Config del CLI/TUI (V2): tema, plugins, keybinds
├── AGENTS.md                   # Instrucciones del sistema
├── README.md                   # Índice de la config
├── package.json                # Dependencias npm (@opencode-ai/plugin)
├── package-lock.json           # Lock de npm
│
├── start-lmstudio.ps1          # Arranca LM Studio + modelo + proxy (idempotente)
├── lmstudio-proxy.py           # Proxy LM Studio (puerto 4001) + métricas
│
├── voice\                      # Stack de voz (STT + TTS)
│   ├── stt.ps1                 #   STT CLI (ffmpeg + whisper)
│   ├── speak.ps1               #   Locución (Kokoro / edge / sapi)
│   ├── kokoro-tts.py           #   Síntesis Kokoro (modo frío)
│   ├── kokoro-server.py        #   Servidor TTS persistente (puerto 4210)
│   ├── tts-server.ps1          #   Gestión del servidor TTS
│   └── venv\                   #   venv de Python (Kokoro + onnxruntime-gpu)
│
├── opencode-voice-modified\    # Plugin de voz (index.js V1 + tui.js V2 + lib\)
├── plugins\                    # Plugins TUI auto-descubiertos (antonio.sidebar-mimo)
│
├── prompts\
│   └── read-agents.txt
│
├── scripts\                    # Scripts PowerShell (timeline, backup, checks…)
│
└── data\
    ├── memory\
    │   └── memory.jsonl        # Grafo de memoria persistente (MCP memory)
    └── metrics.json            # Métricas de tokens/s del proxy LM Studio
```

### `C:\Users\evo01\OneDrive\Documentos\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` (perfil)

Perfil de PowerShell con las funciones **`ocv`** (global), **`ocv-local`** (local), **`ocv-cloud`** (cloud estricto), **`ocv-status`**, **`tts-server`**, **`timeline-completo`** y **`hw_query`**. Es el equivalente Windows del `.zshrc` de Linux.

### `D:\Linux\Config\opencode-win\` (copia de seguridad / origen de instalación)

```
opencode-win\
├── AGENTS.md                        # Copia de respaldo de las reglas
├── README.md
├── instalar-opencode-win.ps1        # Instalador desde cero
│
├── config\                          # 🎯 Config activa a desplegar
│   ├── opencode.jsonc
│   ├── opencode-local.json
│   ├── opencode-cloud.json
│   ├── cli.json
│   ├── AGENTS.md
│   ├── README.md
│   ├── package.json
│   ├── start-lmstudio.ps1
│   ├── lmstudio-proxy.py
│   ├── voice\                       # Stack de voz (sin venv)
│   ├── opencode-voice-modified\     # Plugin de voz
│   ├── plugins\                     # Plugins TUI
│   ├── prompts\read-agents.txt
│   └── scripts\                     # Scripts .ps1
│
├── perfil\
│   └── Microsoft.PowerShell_profile.ps1   # Perfil con los lanzadores ocv
│
├── data\
│   ├── hardware\
│   └── memory\                    # Respaldo del grafo de memoria
│
├── scripts\                        # Utilidades PowerShell (backup, sync, checks…)
│
└── documentacion\                  # 📚 Documentación en Markdown (este manual)
```

> 📍 **Diferencia con Linux:** no hay tarballs (`opencode-backup-*.tar.gz`) ni `sesion-opencode/` con un setup embebido por heredocs. El instalador Windows es `instalar-opencode-win.ps1`, que despliega desde `config\` y `perfil\`; `scripts\backup-opencode.ps1` regenera la copia de seguridad.

### Política de retención de backups

`scripts\backup-opencode.ps1` regenera la copia de seguridad y vuelca la config **saneada** (sin `.env`, `auth.json`, `credenciales\` ni `backups\`) a `D:\Linux\Documentos\dotfiles\opencode-win` para poder versionarla en git.

> La poda automática de `LOG_RETENTION_DAYS` (30 días) era de Linux; en Windows, si se crea la tarea programada `OpenCode-Backup`, conviene que implemente su propia retención (p. ej. copia con fecha del grafo en `data\memory\`).
