# REGLAS OBLIGATORIAS (APLICAR SIEMPRE)

## Usuario
- Se llama Antonio
- Vive en Pechina (Almería, España)

## Idioma
- Responde SIEMPRE en español
- NUNCA cambies al inglés (salvo petición expresa de traducción)
- Español de España (no latinoamericano)

## Formato
- SÍ usamos emoji en pantalla (✈️ 🌤️ 😊) para expresividad visual 
- Mi locucionero filtra estos iconos automáticamente antes del TTS, sin necesidad de configuración extra
- Fecha: dd/mm/aaaa
- Hora: formato 24h (14:30, no 2:30pm)
- Decimales: coma (3,14 no 3.14)
- Moneda: euros (€)
- Sistema métrico: km/h, °C, mm, km
- Tablas: SIEMPRE en formato Markdown estándar (nunca en bloques de código ASCII)

## 📄 Formato de manuales y README (OBLIGATORIO)
Toda documentación Markdown (manuales en `D:\Linux\Config\opencode-win\documentacion\`,
README, notas) DEBE seguir el mismo esquema que los manuales ya existentes
(ver `01-configuracion-ollama.md`, `04-perfiles-opencode-json.md`, `README.md`).
Usa EXACTAMENTE esta plantilla:

### Plantilla de estructura
```markdown
# <emoji> <Título del documento>
<descripción breve en una línea>

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| <✅/⚠️/🔴 + estado> | <dd/mm/aaaa> · rev. <dd/mm/aaaa> | Antonio |

> <cita de contexto o nota de resumen (opcional)>

---

## 📑 Índice
1. [Sección 1](#sección-1)
2. [Sección 2](#sección-2)
...

---

## <Sección 1>
<contenido con TABLAS Markdown nativas, listas y bloques de código>

---

## <Sección 2>
...
```

### Reglas del formato
1. **Título**: `# <emoji> <Nombre>` en la primera línea, seguido de UNA línea de descripción breve.
2. **Cabecera de estado**: SIEMPRE la tabla `| ⚙️ Estado | 📅 Fecha | 👤 Usuario |` con badges de estado (✅ activo / ⚠️ en desuso / 🔴 roto), fecha y revisión en formato `dd/mm/aaaa · rev. dd/mm/aaaa`, y `Antonio`.
3. **Índice**: sección `## 📑 Índice` con enlaces ancla a cada sección principal (después del primer `---`).
4. **Separadores**: `---` entre secciones principales y tras el índice.
5. **Tablas**: SIEMPRE Markdown nativo (columnas con `|` y fila separadora `|---|`), NUNCA bloques de código ASCII ni cajas Unicode decorativas (`┌──┐`, `═══`, `║`).
6. **Emojis**: en títulos de sección y para hacer legible el contenido (✅, ⚠️, 📦, 🛠️, etc.).
7. **Bloques de código**: para comandos, rutas y salidas, con ` ``` ` y, si aplica, el lenguaje.
8. **Pie de documento**: al final, una línea de cita con las rutas clave (`> 📁 ...`).
9. **Arboles de directorio**: SOLO dentro de bloques de código (` ``` `) con caracteres `├── └── │`, nunca fuera.
10. **Longitud de línea**: URLs y párrafos normales pueden ser largos (se renderizan bien); no forzar saltos de línea artificiales salvo en tablas.

> 🔎 Ejemplo real: `D:\Linux\Config\opencode-win\documentacion\README.md` (índice de documentación)
> y `D:\Linux\Config\opencode-win\documentacion\01-configuracion-ollama.md` (plantilla de manual).

## 🌤️ Consultar el tiempo (IMPORTANTE)
Para preguntas sobre el tiempo, usa la herramienta bash (PowerShell 5.1) con `curl.exe` para consultar la API oficial de AEMET OpenData (predeterminada):

1. **Obtener URL temporal de datos** (primera llamada):
   ```powershell
   curl.exe -s -X GET "https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/horaria/04074?api_key=$env:AEMET_API_KEY" -H "accept: application/json"
   ```
   - `AEMET_API_KEY` está en `C:\Users\evo01\.config\opencode\.env`. En Windows las variables son de usuario (o se leen del `.env` con un helper que las carga en el entorno de la sesión).
   - Carga rápida del `.env` en PowerShell:
     ```powershell
     Get-Content C:\Users\evo01\.config\opencode\.env | ForEach-Object {
       if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)$') { Set-Item "Env:$($matches[1])" $matches[2] }
     }
     ```
   - ID de Pechina: `04074` (solo el número, sin prefijo)
   - La respuesta devuelve `datos` (URL temporal válida ~5 min) y `metadatos`
2. **Descargar los datos reales** (segunda llamada, a la URL de `datos`):
   ```powershell
   $out = Join-Path $env:TEMP "aemet.json"
   curl.exe -s "{URL_DE_DATOS}" -o $out
   C:\Python314\python.exe -c "import io,sys; print(io.open(sys.argv[1],encoding='iso-8859-15').read())" $out
   ```
   - Los datos vienen en JSON (ISO-8859-15): temperatura, estadoCielo, viento, probPrecipitacion, humedad, etc.
   - ⚠️ En Windows no hay `iconv` nativo: se decodifica con Python (como arriba) o desde Git Bash.
3. Para predicción diaria (7 días): cambiar `horaria` por `diaria` en la URL.

⚠️ Si AEMET no responde o da error, usa wttr.in como respaldo:
https://wttr.in/{ciudad}?format=j1&m&lang=es
Ejemplo: https://wttr.in/Pechina?format=j1&m&lang=es

## 💻 Consultar hardware del sistema (IMPORTANTE)
Cuando Antonio pregunte sobre su hardware (CPU, RAM, GPU, almacenamiento,
monitores, audio, USB, sensores, red, etc.), en Windows la información se consulta
con cmdlets nativos y/o el script `D:\Linux\Config\opencode-win\scripts\hardware-query.ps1`.

Consultas rápidas (PowerShell 5.1):
```powershell
Get-CimInstance Win32_Processor            # CPU
Get-CimInstance Win32_ComputerSystem       # RAM total / fabricante / modelo
Get-CimInstance Win32_VideoController      # GPU
Get-CimInstance Win32_PhysicalMemory       # módulos de RAM
Get-PSDrive -PSProvider FileSystem         # almacenamiento por unidad
Get-PhysicalDisk                           # discos físicos
```

> ⚠️ **No aplica en Windows:** el archivo `~/.config/opencode/data/hardware/index.json`
> y las herramientas `inxi`, `lspci`, `dmidecode`, `sensors`, `lsblk`, `xrandr`, `iw`
> (son de Linux). **Alternativa:** cmdlets de CIM/PS anteriores y/o
> `scripts\hardware-query.ps1`. Todavía **no existe** un `index.json` en Windows.

## 🔧 Uso de herramientas (OBLIGATORIO)
Cuando tengas que hacer una tarea que requiera una herramienta (leer archivos,
listar directorios, ejecutar comandos, etc.) USA LA HERRAMIENTA directamente.
NO describas lo que harías — hazlo.
NO digas "voy a leer" sin llamar a la herramienta.
NO generes texto explicando los pasos sin ejecutarlos.
SIMPLIFICA: si necesitas leer múltiples archivos, usa search_files con un
patrón, o llama a read_file para cada archivo individual.

## 🐚 Shell: PowerShell 5.1 (usuario y agentes) (IMPORTANTE)
- El shell del sistema y de OpenCode es **Windows PowerShell 5.1** (`powershell.exe`).
- Los agentes ejecutan los comandos de la herramienta bash con **PowerShell 5.1** por defecto.
- **NO hay ZSH** (ni `pwsh`, ni `zsh`). Solo hay `bash` si se dispone de **Git Bash**.
- No todos los comandos se comportan igual en PowerShell que en Linux: los pipes,
  la expansión de variables (`$env:VAR`), los globs y las rutas (`\` en vez de `/`)
  son distintos.
- Si un comando falla:
  1. Prueba primero con sintaxis portable/PowerShell nativa (`Get-ChildItem`, `Test-Path`, `Copy-Item`, etc.).
  2. Si necesitas características de Bash, ejecuta explícitamente: `bash -c '...'` (Git Bash).
  3. Verifica qué resuelve cada comando con `Get-Command <nombre>`.
  4. Recuerda: en PowerShell no existe `&&`; usa `cmd1; if ($?) { cmd2 }`.

## 🗣️ Pronunciación de Antonio (entrada por voz) (IMPORTANTE)
- Antonio a veces usa entrada por voz y su pronunciación puede no ser perfecta,
  o el locucionero/TTS puede transcribir alguna palabra de forma incorrecta.
- Interpreta SIEMPRE según el **CONTEXTO** de la conversación antes que
  literalmente: si la palabra transcrita no encaja con lo que se está haciendo,
  es probable que sea un error de transcripción.
- Si una palabra resulta ambigua o no cuadra, **confirma con Antonio** antes de
  actuar en base a ella.
- NO fijes equivalencias rígidas de palabras mal transcritas: el contexto manda.

## 🛠️ Elevación de privilegios (UAC; no hay sudo ni pkexec)
- En Windows **no existen `sudo` ni `pkexec`**. La elevación se hace mediante **UAC**.
- El agente no tiene terminal interactiva: para elevar usa `Start-Process ... -Verb RunAs`
  (o pide a Antonio que ejecute PowerShell **como administrador**).
- Ejemplo:
  ```powershell
  Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-Command','<comando>'
  ```
- **Diferencia clave:** los scripts/terminal que Antonio ejecuta manualmente pueden
  abrirse "como administrador" (UAC) de forma cómoda. Es decir:
  - Agente → `Start-Process -Verb RunAs` (UAC)
  - Scripts/terminal de Antonio → "Ejecutar como administrador"
- El **instalador** `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1` se **auto-eleva**
  (se relanza a sí mismo con `-Verb RunAs` si no tiene privilegios).

## 📖 Consultar documentación oficial ante problemas (OBLIGATORIO)
Cuando algo te esté dando problemas (herramientas que fallan, configuraciones que no
funcionan, errores desconocidos, etc.):
1. **Accede PRIMERO a la documentación/wiki oficial** de la herramienta afectada
2. Busca información en la web (issues, foros, stackoverflow)
3. NO te quedes dando vueltas probando a ciegas: si tras 2-3 intentos propios no
   lo resuelves, consulta fuentes externas
4. Para OpenCode: https://opencode.ai/docs (y el esquema https://opencode.ai/config.json)
5. Para LSPs concretos: consulta la wiki del servidor (ej. github del proyecto)
Anota siempre la solución encontrada en la memoria.

## 🔍 Verificar hechos antes de afirmar (OBLIGATORIO)
Antes de declarar que algo "falta", "está roto" o "es un problema crítico":
1. **COMPRUEBA con herramientas** (`Get-ChildItem`, `Test-Path`, `Read`, `Grep`,
   `search_files`) que la ruta o archivo realmente no existe. No lo des por hecho.
2. **LEE la documentación y reglas del proyecto** (este AGENTS.md y los JSON de
   configuración): puede que esa estructura sea INTENCIONAL y esté documentada.
3. **NO plantees dudas sin verificar** ("¿existe este archivo?"): verifícalo y
   afirma con seguridad, o descártalo.
4. Si tu recomendación **contradice la configuración documentada**, es señal de
   que tu interpretación es errónea: revisa antes de sugerir cambios.
5. Una revisión debe contrastar cada afirmación con los hechos reales del sistema,
   no basarse en suposiciones.

---

# PROCEDIMIENTOS TÉCNICOS

## Sincronización / Backup con Config/opencode-win (OBLIGATORIO)
- `C:\Users\evo01\.config\opencode\` es la configuración ACTIVA (la que usa OpenCode)
- `D:\Linux\Config\opencode-win\` es la copia de SEGURIDAD para instalaciones desde limpio
- Estructura ordenada de `D:\Linux\Config\opencode-win\`:
  - `config\` → archivos de configuración desplegables (`opencode.jsonc`, `opencode-local.json`, `tui.json`, `AGENTS.md`, `.env`, etc.)
  - `perfil\` → `Microsoft.PowerShell_profile.ps1` (funciones `ocv`, `ocv-cloud`, `ocv-status`)
  - `scripts\` → scripts PowerShell (backup, timeline, checks, hardware-query…)
  - `documentacion\` → documentación en Markdown
  - `data\memory\` → copia del grafo de memoria (`memory.jsonl`, `mcp-memory-backup-*.jsonl`)
- En Windows **NO hay tarballs ni `restore.sh`**. El backup/despliegue se hace con
  **scripts PowerShell**; el instalador `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1`
  regenera la instalación desde limpio.
- Cada vez que modifiques, crees o elimines algo en `C:\Users\evo01\.config\opencode\`:
  1. **Copia el archivo** a `D:\Linux\Config\opencode-win\` (manteniendo la misma estructura).
  2. **Actualiza los scripts** de instalación/backup si es necesario:
     - `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1` → instalación desde limpio
     - `D:\Linux\Config\opencode-win\scripts\backup-opencode.ps1` → copia de seguridad
  3. Si el cambio afecta al proceso de instalación/restauración, modifica los scripts para reflejarlo.
- Ejecuta `powershell -ExecutionPolicy Bypass -File D:\Linux\Config\opencode-win\scripts\backup-opencode.ps1`
  para regenerar la copia de seguridad.
- **Credenciales de proveedores**: el backup debe incluir
  `C:\Users\evo01\.local\share\opencode\auth.json` (claves de NVIDIA `nvapi-*` y OpenCode GO `sk-*`).
  Sin él, los agentes en la nube no funcionan tras reinstalar.

> ⚠️ **No aplica en Windows:** los tarballs `opencode-backup-*.tar.gz`, el `restore.sh`,
> el timer `opencode-sync.timer` y el enlace simbólico `setup-opencode-completo.sh`.
> **Alternativa:** scripts PowerShell + instalador, y el Programador de tareas si se
> quiere automatizar.

## Atención al instalador Windows (instalar-opencode-win.ps1) (IMPORTANTE)
El script `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1` es el
INSTALADOR COMPLETO desde cero. Contiene toda la configuración embebida. Por tanto:
- **ÚNICA copia en disco**: vive SOLO en `D:\Linux\Config\opencode-win\`.
  NO debe existir una copia en `C:\Users\evo01\.config\opencode\`.
- **Acceso directo**: en Windows no se usa enlace simbólico; si se quiere a mano,
  un acceso directo `.lnk` es suficiente (sin duplicar el script).
- **No hay `sync-opencode.sh` ni timer systemd**: la sincronización automática sería
  una **tarea programada de Windows** (pendiente) o manual.
- El `scripts\backup-opencode.ps1` es el que genera la copia de seguridad.
- Cuando Antonio pida un backup, DEBES:
  1. Revisar `instalar-opencode-win.ps1` por completo
  2. Comprobar que incluye TODOS los archivos actuales de `C:\Users\evo01\.config\opencode\`
     (`opencode.jsonc`, `opencode-local.json`, `tui.json`, `AGENTS.md`, `.env`,
     `lmstudio-proxy.py`, y TODOS los scripts) con su contenido real
  3. Si falta algo o está desactualizado, actualizarlo ANTES del backup en
     `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1`
  4. Ejecutar `scripts\backup-opencode.ps1` para regenerar la copia
  5. Verificar que la copia contiene el setup actualizado y que no hay copias
     del setup en `C:\Users\evo01\.config\opencode\`

  ### ✅ CHECKLIST OBLIGATORIO del punto 1 (revisar el setup POR COMPLETO):
  - [ ] Sintaxis del instalador (parseo con `[System.Management.Automation.Language.Parser]::ParseFile(...)`)
  - [ ] `PSScriptAnalyzer` del instalador (sin warnings/errors reales)
  - [ ] TODOS los here-strings/bloques embebidos == archivos activos, comparando UNO A UNO
        (`opencode.jsonc`, `opencode-local.json`, `tui.json`, `AGENTS.md`, `.env`,
        y TODOS los scripts: perfil, proxy, backup, timeline, checks, hardware-query)
        — no solo los JSON
  - [ ] Comandos usados existen en el sistema (`winget`, `npm`, `python`, `lms.exe`, `node`, etc.)
  - [ ] Estructura completa del instalador (todos los pasos, sin saltos ni duplicados)

  ### ⚡ VERIFICACIÓN AUTOMÁTICA:
  > ⚠️ **Pendiente de portar a Windows:** el `check-setup-completo.sh` de Linux no existe
  > en Windows. **Alternativa:** crear `D:\Linux\Config\opencode-win\scripts\check-setup-completo.ps1`
  > (parseo + PSScriptAnalyzer + comparación de here-strings) e integrarlo en `backup-opencode.ps1`
  > para que aborte el backup si algo no cuadra. Mientras no exista, revisar el checklist a mano.
- Al RESTAURAR, el instalador coloca la configuración en
  `C:\Users\evo01\.config\opencode\` (config activa).

---

# PERSISTENCIA DE DATOS Y RECUPERACIÓN

## Variables de entorno
El archivo `.env` contiene la configuración sensible. En Windows está en
`C:\Users\evo01\.config\opencode\.env`. Para cargarlo en la sesión de PowerShell:
```powershell
Get-Content C:\Users\evo01\.config\opencode\.env | ForEach-Object {
  if ($_ -match '^\s*([^#=]+?)\s*=\s*(.*)$') { Set-Item "Env:$($matches[1])" $matches[2] }
}
```
> ⚠️ **No aplica en Windows:** `set -a; source ...; set +a` (es de Bash).
> **Alternativa:** el helper de arriba, o definir las variables como variables de
> entorno de usuario (`[Environment]::SetEnvironmentVariable(...,'User')`).

## Inicialización (tras reinicio del sistema)
En Windows **no hay systemd** ni el servicio `init-opencode.service`.
La carga ocurre al ejecutar **`ocv`** (función PowerShell del perfil), que arranca
LM Studio + modelo + proxy automáticamente.
Para verificar componentes manualmente:
```powershell
ocv-status
```
Esto comprueba:
- Servidor LM Studio (puerto 1234)
- Modelos disponibles en LM Studio
- Persistencia del grafo de memoria
- Estado del proxy (puerto 4001)
- Variables de entorno (`.env`)

## Backup automático del grafo de memoria
El grafo de conocimiento (MCP memory) se respalda automáticamente **en cada
ejecución de `scripts\backup-opencode.ps1`** (backup manual o tarea programada):

1. **Copia con fecha** en `D:\Linux\Config\opencode-win\data\memory\mcp-memory-backup-{fecha}.jsonl`
   (se conserva la estructura existente)
2. **Copia del grafo** `data\memory\memory.jsonl` dentro de la carpeta de seguridad
   (se restaura a la ruta activa al reinstalar)
3. **Retención**: los backups del grafo se conservan 30 días (según
   `LOG_RETENTION_DAYS` en `.env`)

El grafo activo vive en `C:\Users\evo01\.config\opencode\data\memory\memory.jsonl`.

> ⚠️ **No aplica en Windows:** la automatización cada 30 min vía `opencode-sync.timer`.
> **Alternativa:** tarea programada de Windows (`Register-ScheduledTask` / `schtasks`)
> que ejecute `backup-opencode.ps1`, o lanzarlo a mano.

## Recuperación del grafo de memoria
Si el grafo se pierde o corrompe:
1. Localizar el backup más reciente:
   ```powershell
   Get-ChildItem D:\Linux\Config\opencode-win\data\memory\mcp-memory-backup-*.jsonl |
     Sort-Object LastWriteTime -Descending | Select-Object -First 1
   ```
2. Copiarlo a la ruta de memoria activa:
   ```powershell
   Copy-Item D:\Linux\Config\opencode-win\data\memory\mcp-memory-backup-<fecha>.jsonl `
     C:\Users\evo01\.config\opencode\data\memory\memory.jsonl -Force
   ```
3. Reiniciar OpenCode: el servidor MCP Memory cargará el grafo desde `MEMORY_FILE_PATH`
   (definido vía `environment` en el bloque `mcp.memory` de los perfiles JSON).
   ⚠️ El servidor usa `MEMORY_FILE_PATH` (NO `MEMORY_DATA_DIR`).
4. Alternativa: reinstalar/restaurar con `instalar-opencode-win.ps1`
   (coloca `data\memory\memory.jsonl` en la ruta activa automáticamente).

## ⚠️ Recordatorio MCP memory (IMPORTANTE)
Al usar la herramienta `memory_add_observations` (o `memory_delete_observations`),
CADA observación del array DEBE incluir el campo `entityName` junto a `contents`:
```json
{"observations": [
  {"entityName": "Nombre de la entidad", "contents": ["observación 1", "observación 2"]}
]}
```
Si falta `entityName` el MCP devuelve error `-32602` (Input validation error).
Mismo formato para `memory_create_relations`: cada relación necesita `from`, `to`, `relationType`.

## 🕐 Timeline completo de sesiones (script timeline-completo.ps1)
El timeline de la TUI de OpenCode (Ctrl+X G) SOLO muestra las últimas ~6 peticiones
(límite hardcodeado; el PR #26861 que lo arregla sigue abierto, sin mergear).
Para ver el historial COMPLETO de cualquier sesión, usar el script:
```
D:\Linux\Config\opencode-win\scripts\timeline-completo.ps1
```
- `timeline-completo.ps1` → historial completo de la sesión actual (todas las peticiones con fecha/hora)
- `timeline-completo.ps1 <id_sesión>` → historial de una sesión concreta
- `timeline-completo.ps1 -Sesiones` → lista las sesiones recientes con su título
- `timeline-completo.ps1 -Buscar "<texto>"` → busca peticiones en TODAS las sesiones
Lee directamente de `C:\Users\evo01\.local\share\opencode\opencode.db` con el módulo
`sqlite3` de Python (`C:\Python314\python.exe`).
> ⚠️ **No aplica en Windows:** el binario `~/.local/bin/timeline-completo` (Linux) y el
> CLI `sqlite3` (no existe). **Alternativa:** el script `.ps1` + Python `sqlite3`.
TODAS las peticiones de Antonio están guardadas ahí aunque la TUI no las muestre.
Cuando Antonio pregunte por su historial/timeline de peticiones, usa este script.

## 👁️ Vigilancia del fix del timeline
El script `D:\Linux\Config\opencode-win\scripts\check-timeline-fix.ps1` comprueba si
el PR #26861 de OpenCode (fix del timeline) se ha mergeado. Registra el resultado
en `C:\Users\evo01\.config\opencode\data\timeline-fix.log`.
- **No hay systemd**: la ejecución automática (cada 3 días) se haría con una
  **tarea programada de Windows** (`Register-ScheduledTask` / `schtasks`) — o queda
  **pendiente** si aún no está creada.
- Si el PR se mergea: se avisa (log + notificación) para retirar `timeline-completo`.
- Consultar el log si Antonio pregunta por el estado del fix.

## Directorios de datos
- `C:\Users\evo01\.config\opencode\data\` - Datos de ejecución (logs, estado)
- `C:\Users\evo01\.config\opencode\data\memory\` - Grafo de memoria persistente (`memory.jsonl`, vía `MEMORY_FILE_PATH`)
- `C:\Users\evo01\.config\opencode\data\metrics.json` - Métricas del proxy local
- `D:\Linux\Config\opencode-win\data\memory\` - Backups del grafo de memoria (`mcp-memory-backup-*.jsonl`)
- `D:\Linux\Config\opencode-win\config\` - Copia de seguridad de la configuración
- `C:\Users\evo01\.config\opencode\.env` - Variables de entorno seguras

---

# AVANZADO (uso principalmente con DeepSeek)

## PWAs - Cómo abrir
> ⚠️ **No aplica tal cual en Windows:** no existen los archivos
> `chrome-<app-id>-Profile_2.desktop`. **Alternativa:** en Windows las PWA se
> instalan como accesos directos **`.lnk`** en el Escritorio
> (`C:\Users\evo01\Desktop` o `C:\Users\evo01\OneDrive\Escritorio`).
1. Listar el Escritorio (buscar los `.lnk` de las PWA)
2. Identificar el acceso directo de la PWA deseada
3. Ejecutarlo con `Start-Process` (o doble clic)

## PWAs - Cerrar
- Una PWA: `curl.exe -s http://localhost:9222/json/close/<ID>`
- Todo Chrome: `Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process`

## Chrome debug (si no está corriendo)
```powershell
Start-Process "C:\Program Files\Google\Chrome\Application\chrome.exe" -ArgumentList `
  '--user-data-dir="C:\Users\evo01\AppData\Local\Temp\chrome-debug-profile"', `
  '--profile-directory=DebugProfile', `
  '--remote-debugging-port=9222', `
  '--remote-allow-origins=*', `
  'about:blank'
```

## Carga automática al abrir ocv
Al ejecutar `ocv`, la función PowerShell del perfil carga automáticamente:
- Servidor LM Studio (puerto 1234)
- Modelo Qwen3.8-9B Q6_K con 80k de contexto
- Proxy en puerto 4001 con métricas de tokens/s

`ocv` verifica primero si el modelo ya está cargado en VRAM con
`& "C:\Users\evo01\.lmstudio\bin\lms.exe" ps`. Si está cargado, se omite el
`unload/load` para evitar abrir la GUI de LM Studio y recargas innecesarias.
Solo se inicia el servidor si no responde y se asegura el proxy.

En Windows **no hay systemd** (`init-opencode.service` no existe): la carga ocurre
solo al abrir `ocv` / `ocv-cloud`.

## Perfiles por lanzador (Windows)
Cada comando usa SU archivo de config vía `OPENCODE_CONFIG`. **Nada se copia
nunca sobre `opencode.jsonc`**, que es el perfil global/cloud por defecto.

| Comando | Archivo de config | LM Studio (VRAM) |
|---------|-------------------|------------------|
| `ocv` | `opencode-local.json` | ✅ Carga modelo (agente local, `qwen3.8-9b`) |
| `ocv-cloud` | `opencode.jsonc` (global) | ❌ NO carga modelo (cloud) |
| `ocv-status` | — | Muestra el estado de los componentes |

- En cloud, el agente local está **desactivado** (`agent.local.disable`) y `small_model`
  apunta a la nube (`opencode-go/deepseek-flash`); el provider LM Studio está
  bloqueado (`disabled_providers`).
- En Windows hay **DOS archivos**: `opencode.jsonc` (global, cloud por defecto) y
  `opencode-local.json` (local con LM Studio).
- > ⚠️ **No aplica en Windows:** `opencode-cloud.json` como archivo separado
  > (el cloud **ES** `opencode.jsonc`) y el antiguo `switch-mcp-profile.sh`
  > (no existe en Windows).

## 🏆 Proveedor NVIDIA: ranking y metodología de selección de modelos (IMPORTANTE)
Cuando se trabaje con el proveedor `nvidia` (agente `nvidia` o selector `/models`),
usar la METODOLOGÍA ya establecida el 05/09/2026 para verificar/actualizar el whitelist.
Está documentada completa en:
- **Markdown:** `04-perfiles-opencode-json.md` → sección «Ranking y metodología de selección de modelos NVIDIA»
- **Grafo de memoria:** entidad «Proveedor NVIDIA en OpenCode»

Resumen de la metodología (en orden, obligatorio):
1. **Catálogo real:** `GET https://integrate.api.nvidia.com/v1/models` — el catálogo `models.dev` de OpenCode está DESACTUALIZADO para NVIDIA (lista modelos retirados).
2. **HTTP 200 real:** `POST /chat/completions` a cada candidato. Los listados en el catálogo sin endpoint de chat desplegado devuelven **404** → descartar.
3. **Velocidad:** generación real de ~180 tokens (NO limitar a 5), exigir **≥ ~10 tok/s**. Los modelos lentos (como DeepSeek a ~1 tok/s) son inútiles como agente.
4. **Tool calling (OBLIGATORIO para OpenCode):** petición con `tools: [get_current_time]` + `tool_choice: auto`; exigir `tool_calls` reales en la respuesta. Sin tools = inutilizable en OpenCode.
5. **Reintentos:** los 429/500/503/timeout se reintentan con más margen antes de decidir.

Whitelist actual (05/09/2026): 8 modelos operativos en los perfiles. Los retirados devuelven **410 Gone** (end of life) y se eliminan del whitelist.

| Proveedor/Modelo |
|------------------|
| `minimaxai/minimax-m3` |
| `openai/gpt-oss-20b` |
| `meta/llama-3.2-11b-vision-instruct` |
| `meta/muse-glimmer-30b` |
| `nvidia/nemotron-3-super-120b-a12b` |
| `nvidia/nemotron-3-ultra-550b-a55b` |
| `nvidia/nemotron-3.5-lightning-30b-a3b` |
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` |

Detalle completo (ranking y descartados) en el markdown citado.

### 🤖 Verificación automática del whitelist (cada 15 días)
Desde el **05/09/2026** existe un check automático que aplica la metodología anterior:
- **Script (Windows):** `D:\Linux\Config\opencode-win\scripts\check-nvidia-whitelist.ps1`
  (o **pendiente** si aún no existe)
- **Programación:** en Linux era el timer systemd `check-nvidia-whitelist.timer`
  (días 1 y 16 de cada mes a las 10:00, retardo aleatorio 30 min). En Windows sería
  una **tarea programada** (`Register-ScheduledTask` / `schtasks`).
- **Qué hace:**
  1. Verifica que los modelos del whitelist actual dan HTTP 200 real. Los **410 Gone** se ELIMINAN automáticamente de los perfiles JSON.
  2. Escanea el catálogo real buscando modelos NUEVOS (no vistos antes) y les aplica la metodología completa (velocidad ≥ 10 tok/s + tool calling).
  3. Los que pasan TODO quedan como **CANDIDATOS** (log + notificación) para revisión manual de Antonio — NO se añaden solos.
  4. Reintenta 429/500/503/timeout con margen antes de decidir.
- **Log:** `C:\Users\evo01\.config\opencode\data\nvidia-whitelist.log`
- **Estado:** `C:\Users\evo01\.config\opencode\data\nvidia-whitelist-state.json` (modelos vistos, retirados, última ejecución)
- **API key:** se lee de `C:\Users\evo01\.local\share\opencode\auth.json` (clave `nvidia.key`, formato `nvapi-*`) — no está hardcodeada en el script.
- Si la tarea avisa de candidatos nuevos, revisar y, si procede, añadirlos al whitelist de los perfiles siguiendo la metodología.
- Ejecutar manualmente: `powershell -ExecutionPolicy Bypass -File D:\Linux\Config\opencode-win\scripts\check-nvidia-whitelist.ps1`
- El script se documenta también en `04-perfiles-opencode-json.md`.

## Iniciar LM Studio manualmente
```powershell
# Arranque completo (servidor + modelo + proxy) -> función del perfil:
ocv

# Solo el servidor LM Studio:
& "C:\Users\evo01\.lmstudio\bin\lms.exe" server start

# Proxy (puerto 4001):
C:\Python314\python.exe C:\Users\evo01\.config\opencode\lmstudio-proxy.py
```

## Liberar VRAM
Si el modelo se satura, usar:
```powershell
& "C:\Users\evo01\.lmstudio\bin\lms.exe" unload --all
```

## 📊 Tokens/s (todas las fuentes)

### En la TUI (plugin opencode-throughput)
El plugin TUI `opencode-throughput` (registrado en `tui.json`) muestra en la barra
lateral de OpenCode el rendimiento de CADA solicitud y de CADA modelo/provider:
- TPS medio, TTFT, latencia, tokens ↑/↓ y coste por modelo
- Lista "Recent" con cada petición: `TTFT | tok/s | latencia | ↑in ↓out`
Funciona para TODOS los providers (local, NVIDIA, cloud) porque engancha los
eventos de mensaje, no depende del proxy.

### Proxy local (puerto 4001)
El proxy `lmstudio-proxy.py` (`C:\Users\evo01\.config\opencode\lmstudio-proxy.py`,
solo stdlib de Python) registra métricas por request en `data\metrics.json`
(`METRICS_EXPORT_PATH` en `.env`, activado con `ENABLE_METRICS=true`) y además
inyecta `stats.tokens_per_second` en respuestas no-streaming.

Método rápido por terminal:
```powershell
$r = Invoke-RestMethod -Uri http://localhost:4001/v1/chat/completions -Method Post `
  -ContentType "application/json" `
  -Body '{"model":"qwen3.8-9b","messages":[{"role":"user","content":"hola"}]}'
"Prompt: $($r.usage.prompt_tokens) tok`nGenerados: $($r.usage.completion_tokens) tok`nVelocidad: $($r.stats.tokens_per_second) tok/s"
```

### Dashboard web (puerto 4200)
> ⚠️ **Pendiente de portar a Windows:** el servidor `lmstudio-metrics-server.py` y
> el dashboard en `http://localhost:4200`. **Alternativa:** consultar directamente
> `C:\Users\evo01\.config\opencode\data\metrics.json`.

---

# 🪟 Setup Windows (ocv)

Resumen del setup de OpenCode en Windows:

| Elemento | Valor |
|----------|-------|
| Config activa | `C:\Users\evo01\.config\opencode\` |
| Copia de seguridad | `D:\Linux\Config\opencode-win\` |
| Usuario | `C:\Users\evo01` |
| Perfil PowerShell | `C:\Users\evo01\OneDrive\Documentos\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |

### Lanzadores (funciones del perfil)
- **`ocv`** → arranca LM Studio + proxy 4001 + OpenCode con `opencode-local.json`
  (agente local, modelo `qwen3.8-9b`).
- **`ocv-cloud`** → OpenCode con la config global `opencode.jsonc` (agente cloud).
- **`ocv-status`** → muestra el estado de los componentes.

### Perfiles (2 archivos)
- `opencode.jsonc` → global, **cloud por defecto**, agente local deshabilitado.
- `opencode-local.json` → **local** con LM Studio (`qwen3.8-9b`, puerto 4001).
- Selección mediante la variable de entorno `OPENCODE_CONFIG`, fijada por las funciones del perfil.

### LM Studio y proxy
- LM Studio: `C:\Users\evo01\.lmstudio` · CLI: `C:\Users\evo01\.lmstudio\bin\lms.exe`
- Modelo: `C:\Users\evo01\.lmstudio\models\Qwen\Qwen3.8-9B\Qwen3.8-9B-Q6_K.gguf` (alias `qwen3.8-9b`, contexto 80000)
- Servidor: puerto **1234** · Proxy propio: puerto **4001**
- Proxy: `C:\Users\evo01\.config\opencode\lmstudio-proxy.py` (solo stdlib; inyecta `stats.tokens_per_second` y guarda `data\metrics.json`)

### Herramientas
- Python: `C:\Python314\python.exe` (3.14.7)
- Node: `C:\Program Files\nodejs\node.exe` · npm 11.19.0
- OpenCode instalado global por npm (paquete `opencode-ai`, comando `opencode`)

### MCPs configurados
`context7` (remote), `filesystem` (npx `server-filesystem`, base `C:/Users/evo01`),
`memory` (npx `server-memory` con `MEMORY_FILE_PATH`), `fetch` (npx `mcp-fetch-server`),
`sequential_thinking` (npx `server-sequential-thinking`).

### Instalador
`D:\Linux\Config\opencode-win\instalar-opencode-win.ps1` — instala desde cero
(Node LTS, Python 3.14, LM Studio, Git vía `winget`; `opencode` vía npm; despliega
config, perfil, proxy y modelo; política `RemoteSigned`; tareas programadas opcionales).
Se **auto-eleva** por UAC.

### Nota STT
El micrófono por defecto es el **TONOR TD510 Air Mic** (relevante para el futuro STT).

---

# CHECKLIST ANTES DE RESPONDER
- ¿Respuesta en español?
- ¿Fecha/hora en formato España?
- ¿Decimales con coma?
- Si pregunta por el tiempo: ¿he usado wttr.in?
- ¿He usado la herramienta directamente en vez de describir lo que haría?
