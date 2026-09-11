# 📜 AGENTS.md — Reglas de comportamiento de OpenCode (Windows)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 📜 Reglas del sistema | 10/09/2026 · rev. 10/09/2026 | Antonio |

> Instrucciones del sistema que OpenCode carga al inicio de cada sesión.
> Esta versión documenta el **equivalente en Windows** (PowerShell 5.1) del
> setup original de Linux.

> ⚠️ **Nota Windows:** el sistema operativo es **Windows 10/11** y el shell es
> **Windows PowerShell 5.1** (NO existe `pwsh`). No hay `zsh` ni `bash` nativos
> (salvo Git Bash). Los comandos y rutas de este manual usan PowerShell.

---

## 📑 Índice


1. [¿Qué es AGENTS.md?](#qué-es-agentsmd)
2. [Estructura general del archivo](#estructura-general)
3. [Sección 1: REGLAS OBLIGATORIAS](#sección-1-reglas-obligatorias)
4. [Sección 2: PROCEDIMIENTOS TÉCNICOS](#sección-2-procedimientos-técnicos)
5. [Sección 3: PERSISTENCIA DE DATOS Y RECUPERACIÓN](#sección-3-persistencia-de-datos-y-recuperación)
6. [Sección 4: AVANZADO](#sección-4-avanzado)
7. [Sección 5: CHECKLIST](#sección-5-checklist)
8. [Cómo interpretar las reglas](#cómo-interpretar-las-reglas)

---

## ¿Qué es AGENTS.md?

`AGENTS.md` es el archivo que se pasa como **instrucciones del sistema** a OpenCode. Se carga al inicio de cada sesión y actúa como la **constitución** que el asistente debe seguir.

En Windows vive en:

```
C:\Users\evo01\.config\opencode\AGENTS.md
```

### ¿Cómo se carga?

En `opencode.json`:
```json
"instructions": ["AGENTS.md"]
```

Esto le dice a OpenCode: "al empezar cada sesión, lee AGENTS.md e intégralo en tu prompt de sistema".

### ¿Por qué es importante?

Define **TODO** el comportamiento del asistente:
- Cómo debe comunicarse (idioma, formato, emojis)
- Qué procedimientos seguir (sincronización, backups)
- Cómo responder a preguntas específicas (tiempo, hardware)
- Qué NO debe hacer (comandos de detección, elevación de privilegios)

---

## Estructura general

El archivo se organiza en **5 secciones** claramente delimitadas:

```
1. REGLAS OBLIGATORIAS (APLICAR SIEMPRE)    → Líneas 1-75
   ├── Usuario
   ├── Idioma
   ├── Formato
   ├── Consultar el tiempo
   ├── Consultar hardware
   ├── Uso de herramientas
   ├── Elevación de privilegios
   └── Consultar documentación oficial

2. PROCEDIMIENTOS TÉCNICOS                   → Líneas 76-149
   ├── Sincronización con la copia de seguridad (estructura ordenada)
   └── Atención al instalador

3. PERSISTENCIA DE DATOS Y RECUPERACIÓN      → Líneas 150-233
   ├── Variables de entorno
   ├── Inicialización
   ├── Backup del grafo de memoria
   ├── Recuperación del grafo
   ├── Recordatorio MCP memory (entityName)
   ├── Timeline completo (timeline-completo)
   ├── Vigilancia del fix del timeline
   └── Directorios de datos

4. AVANZADO                                  → Líneas 234-301
   ├── PWAs - Abrir/Cerrar
   ├── Chrome debug
   ├── Carga automática al abrir opencode/ocv
   ├── Perfiles por lanzador
   ├── Iniciar LM Studio manualmente
   ├── Liberar VRAM
   └── Tokens/s en respuestas locales

5. CHECKLIST ANTES DE RESPONDER              → Líneas 302-307
```

### Estructura de `D:\Linux\Config\opencode-win\`

```
Config\opencode-win\
├── backups\opencode\          # Backups de OpenCode (retención 30 días)
├── data\memory\               # Backups del grafo de memoria (mcp-memory-backup-*.jsonl)
├── data\onlyoffice-ai\        # Integración IA de OnlyOffice
├── documentacion\             # Documentación en Markdown
├── instalar-opencode-win.ps1  # Instalador completo desde limpio
└── raíz: AGENTS.md, scripts .ps1 de sincronización y backup
```

El AGENTS.md documenta esta estructura y exige mantener la raíz limpia.

> ⚠️ **Nota Windows:** en Linux la copia de seguridad era `~/Config/opencode/`
> con scripts `.sh` y un tarball `opencode-backup-*.tar.gz`. En Windows la copia
> vive en `D:\Linux\Config\opencode-win\` y el instalador es un script
> **PowerShell** (`instalar-opencode-win.ps1`).

---

## Sección 1: REGLAS OBLIGATORIAS

### Usuario (líneas 3-5)

```
- Se llama Antonio
- Vive en Pechina (Almería, España)
```

Razón: El asistente debe saber a quién se dirige. Antonio es de Pechina, un pueblo de Almería. Esto permite personalizar respuestas (ej. el tiempo en su ubicación).

### Idioma (líneas 7-10)

```
- Responde SIEMPRE en español
- NUNCA cambies al inglés (salvo petición expresa de traducción)
- Español de España (no latinoamericano)
```

Razón: OpenCode a veces cambia al inglés espontáneamente. Esta regla **fuerza** el español peninsular. Diferencias clave:
- Vosotros vs. ustedes
- "Ordenador" vs. "computadora"
- "Coche" vs. "carro"
- "Vale" vs. "ok"

### Formato (líneas 12-19)

```
- SÍ usamos emoji en pantalla (✈️ 🌤️ 😊)
- Mi locucionero filtra estos iconos automáticamente antes del TTS
- Fecha: dd/mm/aaaa
- Hora: formato 24h (14:30, no 2:30pm)
- Decimales: coma (3,14 no 3.14)
- Moneda: euros (€)
- Sistema métrico: km/h, °C, mm, km
```

#### El "locucionero"

Es un concepto importante. Cuando el TTS lee el texto en voz alta, los emojis como ✈️ serían leídos como "avión" o "icono de avión". El **locucionero** es un filtro que elimina los emojis ANTES de pasar el texto al TTS, permitiendo que el asistente use emojis en pantalla sin que la voz los lea.

> ⚠️ **No aplica en Windows:** el locucionero original (script `speak` con
> `edge-tts`) es una utilidad de Linux. En Windows, si se usa TTS, el filtro de
> emojis debe implementarse aparte; no forma parte del setup actual.

#### Formato de fecha y hora

| Concepto | Estilo España | Ejemplo |
|----------|--------------|---------|
| Fecha | dd/mm/aaaa | 10/09/2026 |
| Hora | 24h | 14:30 |
| Decimales | coma | 3,14 |
| Moneda | símbolo € | 25 € |
| Temperatura | °C | 32 °C |
| Velocidad | km/h | 120 km/h |
| Distancia | km / m | 5 km |

#### Formato de manuales y README (líneas 22-71) — añadido 07/09/2026

El AGENTS.md incluye una sección **`📄 Formato de manuales y README (OBLIGATORIO)`** que
estandariza cómo se escriben TODOS los documentos Markdown de configuración
(manuales en `D:\Linux\Config\opencode-win\documentacion\`, README, notas).

Plantilla de estructura:

```markdown
# <emoji> <Título del documento>
<descripción breve en una línea>

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| <✅/⚠️/🔴 + estado> | <dd/mm/aaaa> · rev. <dd/mm/aaaa> | Antonio |

> <cita de contexto (opcional)>

---

## 📑 Índice
1. [Sección 1](#sección-1)
...

---

## <Sección 1>
<contenido con TABLAS Markdown nativas>
```

Reglas clave:
1. Título `# <emoji> <Nombre>` + una línea de descripción
2. Cabecera de estado SIEMPRE con la tabla `| ⚙️ Estado | 📅 Fecha | 👤 Usuario |` y badges (✅ activo / ⚠️ en desuso / 🔴 roto)
3. Índice `## 📑 Índice` con enlaces ancla
4. Separadores `---` entre secciones
5. Tablas Markdown nativas (NUNCA cajas Unicode `┌──┐ ═══ ║` ni bloques ASCII)
6. Emojis en títulos y contenido
7. Bloques de código con ` ``` ` para comandos
8. Pie con rutas clave (`> 📁 ...`)
9. Árboles de directorio solo dentro de bloques de código

> 🔎 Ejemplos reales: `README.md` y `01-configuracion-ollama.md` en `D:\Linux\Config\opencode-win\documentacion\`

### ☁️ Consultar el tiempo (líneas 72-90) — IMPORTANTE

```
Para preguntas sobre el tiempo, usa la herramienta fetch_html (o fetch_json):
https://wttr.in/{ciudad}?format=j1&m&lang=es

⚠️ Si wttr.in no responde, NO vuelvas a llamar a fetch.
Limítate a informar: "wttr.in no está disponible ahora, inténtalo más tarde."
```

Razón: wttr.in es un servicio gratuito y fiable. La URL usa:
- `j1` → Formato JSON detallado
- `m` → Unidades métricas (°C, km/h)
- `lang=es` → Respuestas en español

La advertencia de **no reintentar** evita bucles infinitos de peticiones cuando el servicio está caído.

### 💻 Consultar hardware (líneas 93-111) — IMPORTANTE

```
Cuando Antonio pregunte sobre su hardware, LEE el archivo:
C:\Users\evo01\.config\opencode\data\hardware\index.json

NO ejecutes comandos de detección (inxi, lspci, dmidecode, etc.)
```

Razón: Ejecutar comandos de hardware es lento y consume recursos. El archivo `index.json` ya contiene **toda** la información del sistema, generada una sola vez. Contiene múltiples secciones con datos de CPU, RAM, GPU, discos, monitores, audio, USB, sensores, red, etc.

> ⚠️ **No aplica en Windows:** el helper `hardware-query.sh` (`source ... &&
> hw_query <campo>`) es un script **Bash** de Linux y no está disponible en
> PowerShell. En Windows lee directamente el JSON con `Get-Content` o
> `ConvertFrom-Json`:

```powershell
Get-Content "C:\Users\evo01\.config\opencode\data\hardware\index.json" -Raw | ConvertFrom-Json
```

### 🔧 Uso de herramientas (líneas 113-121) — OBLIGATORIO

```
Cuando tengas que hacer una tarea que requiera una herramienta, USA LA HERRAMIENTA directamente.
NO describas lo que harías — hazlo.
NO digas "voy a leer" sin llamar a la herramienta.
```

Razón: Esta es la regla más importante para la **eficiencia**. OpenCode tiende a describir lo que va a hacer en vez de hacerlo directamente. Esto obliga a **actuar** en vez de **narrar**.

Ejemplo de lo que NO debe hacer:
> "Voy a leer el archivo de configuración para ver qué modelos tienes..."

Ejemplo de lo que SÍ debe hacer:
> *(llama directamente a la herramienta Read)*

### 🛠️ Elevación de privilegios (líneas 145-151)

```
- NUNCA uses sudo para comandos que requieran contraseña
- Usa SIEMPRE la elevación UAC en su lugar
- Ejemplo: lanzar PowerShell "Ejecutar como administrador" antes del comando
```

> ⚠️ **Nota Windows:** no existen `sudo` ni `pkexec`. En Windows la elevación se
> hace mediante **UAC** ("Ejecutar como administrador"). Cuando el agente necesite
> privilegios, debe lanzar el proceso con `Start-Process -Verb RunAs` (aparecerá
> la ventana de UAC para que Antonio acepte).

```powershell
Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File C:\ruta\script.ps1"
```

Razón: en Linux `sudo` pedía la contraseña por terminal (imposible en la TUI) y `pkexec` abría una ventana gráfica. En Windows el equivalente es UAC.

---

## Sección 2: PROCEDIMIENTOS TÉCNICOS

### Sincronización con la copia de seguridad (líneas 181-207) — OBLIGATORIO

Explica el **sistema de dos directorios**:

```
C:\Users\evo01\.config\opencode\   ← Activo (el que usa OpenCode)
D:\Linux\Config\opencode-win\      ← Copia de seguridad (para reinstalar desde limpio)
```

#### Flujo de trabajo al modificar algo:

```
1. Modificas en C:\Users\evo01\.config\opencode\
2. COPIA el archivo a D:\Linux\Config\opencode-win\ (misma estructura)
3. Actualiza los scripts de instalación/sincronización si es necesario
4. Ejecuta el backup/sincronización correspondiente
```

> ⚠️ **No aplica en Windows:** el flujo original usaba `backup-opencode.sh`,
> `bootstrap-ocv.sh` y `restore.sh` (Bash + tarball `.tar.gz`). En Windows el
> instalador es `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1` y la
> sincronización/empaquetado se hace con cmdlets de PowerShell
> (`Copy-Item`, `Compress-Archive`).

### Atención al instalador (líneas 208-259) — IMPORTANTE

El instalador `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1` es el **instalador completo** del setup en Windows.

#### Reglas:

- Cada cambio en `C:\Users\evo01\.config\opencode\` debe reflejarse en el instalador
- Antes de un backup, hay que **revisar** que el instalador incluya TODOS los archivos actuales
- El instalador coloca la configuración en `C:\Users\evo01\.config\opencode\`

> ⚠️ **No aplica en Windows:** el `setup-opencode-completo.sh` con heredocs
> embebidos es específico de Linux. En Windows se usa el instalador `.ps1`.

---

## Sección 3: PERSISTENCIA DE DATOS Y RECUPERACIÓN

### Variables de entorno (líneas 260-265)

El `.env` contiene credenciales y rutas sensibles. En Windows se puede cargar en
la sesión actual con `$env:VAR` o definirse como variables de entorno de usuario.

```powershell
# Cargar el .env en la sesión actual (equivalente a "set -a; source .env; set +a")
Get-Content "C:\Users\evo01\.config\opencode\.env" | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
    Set-Item -Path "Env:$($matches[1].Trim())" -Value $matches[2].Trim()
  }
}

# Consultar una variable
$env:MEMORY_FILE_PATH
```

> ⚠️ **Nota Windows:** no existe `set -a; source .env; set +a`. Usa variables de
> entorno de usuario (panel de sistema o `[Environment]::SetEnvironmentVariable`)
> o cárgalas en la sesión como se muestra arriba.

### Inicialización tras reinicio (líneas 266-279)

```powershell
ocv-status
```

Verifica:
1. **LM Studio** activo en puerto 1234
2. **Modelos** disponibles
3. **Grafo de memoria** persistente
4. **PWAs** (si aplica)
5. **Variables de entorno** (.env)

> ⚠️ **No aplica en Windows:** el script `init-opencode.sh` es de Linux. En
> Windows el arranque/chequeo se hace con las funciones del perfil de PowerShell
> (`ocv` arranca LM Studio + proxy + OpenCode; `ocv-status` muestra el estado).

### Backup del grafo de memoria (líneas 280-296)

```
Directorio: D:\Linux\Config\opencode-win\data\memory\
Formato:    mcp-memory-backup-{fecha}.jsonl
Retención:  30 días
```

El grafo de memoria es un archivo **JSONL** (una línea JSON por entidad) que contiene todas las entidades, observaciones y relaciones que el asistente ha aprendido.

El grafo se respalda copiando el archivo activo a la carpeta de backups:
1. **Copia con fecha** en `D:\Linux\Config\opencode-win\data\memory\mcp-memory-backup-{fecha}.jsonl`
2. **Retención** de 30 días

El grafo activo vive en `C:\Users\evo01\.config\opencode\data\memory\memory.jsonl`.

> ⚠️ **Nota Windows:** no hay `systemd` ni tarballs automáticos. La copia
> periódica se programa con el **Programador de tareas** de Windows, que ejecuta
> un script PowerShell de backup.

### Recuperación del grafo (líneas 298-314)

Si el grafo se pierde o corrompe:

```powershell
# 1. Localizar el backup más reciente
Get-ChildItem "D:\Linux\Config\opencode-win\data\memory\mcp-memory-backup-*.jsonl" |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1

# 2. Copiar el backup a la ruta activa del grafo (MEMORY_FILE_PATH)
Copy-Item "D:\Linux\Config\opencode-win\data\memory\mcp-memory-backup-XXXX.jsonl" `
  "C:\Users\evo01\.config\opencode\data\memory\memory.jsonl" -Force
```

Alternativa: reinstalar/restaurar con `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1`, que coloca `data\memory\memory.jsonl` en la ruta activa.

### Recordatorio MCP memory (líneas 310-320) — IMPORTANTE

Al usar `memory_add_observations` o `memory_delete_observations`, **CADA observación**
del array DEBE incluir el campo `entityName` junto a `contents`. Si falta `entityName`,
el MCP devuelve error `-32602` (Input validation error). Formato correcto:

```json
{"observations": [
  {"entityName": "Nombre de la entidad", "contents": ["observación 1", "observación 2"]}
]}
```

> 📌 Este recordatorio se añadió el **10/08/2026** porque el asistente repetía el error
> de omitir `entityName` al usar las herramientas de memoria. Mismo formato para
> `memory_create_relations` (cada relación necesita `from`, `to`, `relationType`).

### Timeline completo (líneas 321-335)

La TUI de OpenCode (Ctrl+X G) solo muestra las últimas ~6 peticiones (límite hardcodeado;
el PR #26861 que lo arregla sigue abierto, sin mergear).

> ⚠️ **No aplica en Windows:** el script `timeline-completo` es una utilidad **Bash**
> de Linux y no está instalado en Windows. Como no hay `sqlite3` en el PATH, usa el
> **módulo `sqlite3` de Python** contra la base de datos de sesiones:

```powershell
python -c "import sqlite3; c=sqlite3.connect(r'C:\Users\evo01\.local\share\opencode\opencode.db'); print(c.execute('SELECT name FROM sqlite_master WHERE type=\"table\"').fetchall())"
```

### Vigilancia del fix del timeline (líneas 336-343)

El PR #26861 de OpenCode corrige el límite del timeline. Si se mergea, avisa para retirar `timeline-completo`.

> ⚠️ **No aplica en Windows:** el script `check-timeline-fix.sh` y su timer
> `systemd` son de Linux. En Windows, si se desea, se programa una comprobación
> equivalente con el **Programador de tareas**.

### Directorios de datos (líneas 344-354)

| Directorio | Contenido |
|------------|-----------|
| `C:\Users\evo01\.config\opencode\data\` | Logs, estado |
| `C:\Users\evo01\.config\opencode\data\memory\` | Grafo de memoria persistente |
| `D:\Linux\Config\opencode-win\data\memory\` | Copias de seguridad del grafo |
| `C:\Users\evo01\.config\opencode\.env` | Variables de entorno seguras |

---

## Sección 4: AVANZADO

Esta sección está pensada principalmente para cuando se usa **DeepSeek** u otros modelos que puedan necesitar instrucciones más detalladas para tareas específicas.

### PWAs - Abrir (líneas 355-359)

> ⚠️ **No aplica en Windows:** las PWAs del setup de Linux se lanzaban desde
> archivos `.desktop` (`chrome-<app-id>-Profile_2.desktop`) en el Escritorio. En
> Windows Chrome instala las PWAs como accesos directos `.lnk`, no `.desktop`.

### PWAs - Cerrar (líneas 360-363)

> ⚠️ **No aplica en Windows:** el cierre por puerto de depuración se mantiene
> conceptualmente, pero el comando `pkill` es de Linux. En Windows se cierran con
> `Stop-Process`:

```powershell
# Cerrar una PWA específica vía DevTools Protocol
Invoke-RestMethod -Uri "http://localhost:9222/json/close/<ID>"

# Cerrar todo Chrome con depuración remota
Get-Process chrome | Where-Object { $_.CommandLine -like "*remote-debugging-port*" } | Stop-Process
```

### Chrome debug (líneas 364-366)

```powershell
Start-Process "C:\Program Files\Google\Chrome\Application\chrome.exe" `
  -ArgumentList "--user-data-dir=$env:TEMP\chrome-debug-profile",
                "--profile-directory=DebugProfile",
                "--remote-debugging-port=9222",
                "--remote-allow-origins=*",
                "about:blank"
```

Lanza Chrome en modo depuración con un perfil temporal, necesario para controlar PWAs remotamente.

> ⚠️ **Nota Windows:** no hay `nohup` ni `/tmp`; se usa `Start-Process` y la
> variable `$env:TEMP`.

### Carga automática al abrir opencode/ocv (líneas 367-382)

Al ejecutar `ocv`, el lanzador carga automáticamente:

1. **Servidor LM Studio** (puerto 1234)
2. **Modelo Qwen3.8-9B Q6_K** con 80 000 de contexto
3. **Proxy** en puerto 4001 con métricas de tokens/s

La carga ocurre solo al abrir `ocv`/`opencode` (no hay servicio que cargue el modelo al iniciar sesión).

> 📌 **Perfil cloud:** `ocv-cloud` NO carga el modelo local en VRAM.

> ⚠️ **No aplica en Windows:** el lanzador `start-opencode-server.sh` es de Linux.
> En Windows el arranque lo hace la función **`ocv`** del perfil de PowerShell
> (`C:\Users\evo01\OneDrive\Documentos\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`).

### Perfiles por lanzador (líneas 383-398)

Cada comando del perfil de PowerShell cumple una función distinta:

| Comando | Archivo de config | MCPs | LM Studio (VRAM) |
|---------|-------------------|------|------------------|
| `ocv` | `opencode-local.json` | Todos (5) | ✅ Carga modelo |
| `ocv-local` | `opencode-local-min.json` | `fetch`, `filesystem`, `memory` | ✅ Carga modelo |
| `ocv-cloud` | `opencode.jsonc` (global) | Todos (5) | ❌ NO carga modelo |
| `ocv-status` | — | — | Muestra el estado del sistema |

En cloud: agente local desactivado (`agent.local.disable`), `small_model` apunta a la nube (`opencode-go/deepseek-flash`) y el provider LM Studio está bloqueado (`disabled_providers`).

> ⚠️ **Nota Windows:** las funciones disponibles son `ocv` (local completo), `ocv-local`
> (local mínimo: solo `fetch`, `filesystem`, `memory`), `ocv-cloud` (cloud) y `ocv-status`.

### Iniciar LM Studio manualmente (líneas 431-436)

```powershell
# Recomendado: la función ocv arranca LM Studio + proxy + OpenCode local
ocv

# Control manual del servidor LM Studio
& "C:\Users\evo01\.lmstudio\bin\lms.exe" server start
```

> ⚠️ **No aplica en Windows:** los scripts `start-lmstudio.sh` y
> `start-lmstudio-server.sh` son de Linux.

### Liberar VRAM (líneas 437-442)

Si el modelo se satura, usar:

```powershell
& "C:\Users\evo01\.lmstudio\bin\lms.exe" unload --all
```

### Tokens/s (todas las fuentes, sección 4)

#### En la TUI — plugin `opencode-throughput` (05/09/2026)

Registrado en `tui.json` junto al plugin de voz. En la barra lateral muestra el
rendimiento de cada solicitud y de cada modelo/provider (local, NVIDIA y cloud):
TPS medio, TTFT, latencia, tokens ↑/↓ y coste, más la lista "Recent". Funciona
para TODOS los providers porque engancha los eventos de mensaje de OpenCode.

#### Proxy local (puerto 4001)

El proxy `lmstudio-proxy.py` (versión con métricas, 05/09/2026) reenvía a LM
Studio y además:
- Registra métricas por request en `data\metrics.json` (`METRICS_EXPORT_PATH`).
- Inyecta `stats.tokens_per_second` en respuestas no-streaming.

#### Dashboard web (puerto 4200)

`lmstudio-metrics-server.py` sirve en `http://localhost:4200` el histórico de
velocidad, tokens y peticiones del proxy local. Datos crudos en `/api/metrics`.

Método rápido por terminal:

```powershell
$r = Invoke-RestMethod -Uri "http://localhost:4001/v1/chat/completions" -Method Post `
  -ContentType "application/json" `
  -Body '{"model":"qwen3.8-9b","messages":[{"role":"user","content":"hola"}]}'
"Prompt: $($r.usage.prompt_tokens) tok"
"Generados: $($r.usage.completion_tokens) tok"
"Velocidad: $($r.stats.tokens_per_second) tok/s"
```

> ⚠️ **Nota Windows:** `python3` no existe; el intérprete es
> `C:\Python314\python.exe` (invocable como `python`).

---

## Sección 5: CHECKLIST

### Líneas 302-307

```
CHECKLIST ANTES DE RESPONDER:
- ¿Respuesta en español?
- ¿Fecha/hora en formato España?
- ¿Decimales con coma?
- Si pregunta por el tiempo: ¿he usado wttr.in?
- ¿He usado la herramienta directamente en vez de describir lo que haría?
```

Es una **auto-verificación** que el asistente debe repasar mentalmente antes de enviar cada respuesta. Cubre los 5 puntos más críticos que tienden a fallar:

| Pregunta | Por qué es importante |
|----------|----------------------|
| ¿Español? | OpenCode a veces cambia solo al inglés |
| ¿Formato España? | Fechas y horas incorrectas si no se forza el formato |
| ¿Decimales con coma? | Por defecto los modelos usan punto |
| ¿Tiempo con wttr.in? | Es la herramienta específica para el clima |
| ¿Herramienta directa? | La regla de ORO: actuar, no narrar |

---

## Cómo interpretar las reglas

### Prioridad

1. **OBLIGATORIO / APLICAR SIEMPRE** → Reglas inquebrantables
2. **IMPORTANTE** → Deben cumplirse siempre que apliquen
3. **Sin marcador** → Directrices generales

### Modificaciones futuras

Si quieres modificar AGENTS.md en Windows:

1. Edita `C:\Users\evo01\.config\opencode\AGENTS.md`
2. **Copia** a `D:\Linux\Config\opencode-win\AGENTS.md` (sincronización)
3. **Actualiza** el instalador `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1` para que incluya los cambios
4. **Regenera** la copia de seguridad con `Copy-Item` / `Compress-Archive`

> ⚠️ **No aplica en Windows:** el paso original "regenerar backup con
> `bash ~/Config/opencode/backup-opencode.sh`" es de Linux.

### Notas sobre el "locucionero"

El término aparece en la línea 14:
> "Mi locucionero filtra estos iconos automáticamente antes del TTS, sin necesidad de configuración extra"

Es una **nota para Antonio** (no para el asistente). Le indica que puede usar emojis con libertad porque el sistema de voz los filtra automáticamente.

> ⚠️ **No aplica en Windows:** el "locucionero" es el script `speak`
> (`~/.local/bin/speak`, Bash + `edge-tts`) del setup de Linux; no existe en
> Windows.

---

> 📁 Activo: `C:\Users\evo01\.config\opencode\AGENTS.md` ·
> Copia: `D:\Linux\Config\opencode-win\AGENTS.md` ·
> Manual: `D:\Linux\Config\opencode-win\documentacion\06-agents-md.md`
