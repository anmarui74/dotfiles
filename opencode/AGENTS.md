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

## 🌤️ Consultar el tiempo (IMPORTANTE)
Para preguntas sobre el tiempo, usa la herramienta bash con curl para consultar la API oficial de AEMET OpenData (predeterminada):

1. **Obtener URL temporal de datos** (primera llamada):
   ```bash
   curl -s -X GET "https://opendata.aemet.es/opendata/api/prediccion/especifica/municipio/horaria/{ID_MUNICIPIO}?api_key=$AEMET_API_KEY" -H "accept: application/json"
   ```
   - `AEMET_API_KEY` está en `.env` (cargar con `set -a; source /home/antonio/.config/opencode/.env; set +a`)
   - ID de Pechina: `04074` (solo el número, sin prefijo)
   - La respuesta devuelve `datos` (URL temporal válida ~5 min) y `metadatos`
2. **Descargar los datos reales** (segunda llamada, a la URL de `datos`):
   ```bash
   curl -s "{URL_DE_DATOS}" | iconv -f ISO-8859-15 -t UTF-8
   ```
   - Los datos vienen en JSON (ISO-8859-15): temperatura, estadoCielo, viento, probPrecipitacion, humedad, etc.
3. Para predicción diaria (7 días): cambiar `horaria` por `diaria` en la URL.

⚠️ Si AEMET no responde o da error, usa wttr.in como respaldo:
https://wttr.in/{ciudad}?format=j1&m&lang=es
Ejemplo: https://wttr.in/Pechina?format=j1&m&lang=es

## 💻 Consultar hardware del sistema (IMPORTANTE)
Cuando Antonio pregunte sobre su hardware (CPU, RAM, GPU, almacenamiento,
monitores, audio, USB, sensores, red, etc.), LEE el archivo:
```
~/.config/opencode/data/hardware/index.json
```
Ese JSON contiene TODA la información de su sistema. No ejecutes comandos de
detección (inxi, lspci, dmidecode, etc.) a menos que el usuario lo pida
explícitamente o que el JSON no tenga la respuesta.

Consulta rápida desde terminal: `source ~/.config/opencode/hardware-query.sh && hw_query <campo>`

Para REGENERAR el índice con los datos reales actuales del hardware:
```bash
python3 ~/.config/opencode/hardware-query.py scan
```
(Escanea lscpu, lspci, lsusb, nvidia-smi, sensors, lsblk, dmidecode, iw,
xrandr, free, /proc... y actualiza data/hardware/index.json. Usa pkexec
para dmidecode: saldrá una ventana pidiendo contraseña la primera vez.)

## 🔧 Uso de herramientas (OBLIGATORIO)
Cuando tengas que hacer una tarea que requiera una herramienta (leer archivos,
listar directorios, ejecutar comandos, etc.) USA LA HERRAMIENTA directamente.
NO describas lo que harías — hazlo.
NO digas "voy a leer" sin llamar a la herramienta.
NO generes texto explicando los pasos sin ejecutarlos.
SIMPLIFICA: si necesitas leer múltiples archivos, usa search_files con un
patrón, o llama a read_file para cada archivo individual.

## 🐚 Shell del sistema: ZSH (usuario) vs Bash (agentes) (IMPORTANTE)
- Antonio usa **ZSH** como shell predeterminada del sistema y de OpenCode
  (`"shell": "/usr/bin/zsh"` en los 3 perfiles JSON).
- Los agentes ejecutan los comandos de la herramienta bash con **Bash** por defecto.
- NO todos los comandos funcionan igual en ambas shells: expansiones, globs
  (`**`, `=`, `~` como path), alias y plugins de ZSH pueden fallar o comportarse
  distinto en Bash, y viceversa.
- Si un comando falla:
  1. Prueba primero con sintaxis portable (POSIX), sin depender de ZSH.
  2. Si necesitas características de ZSH, ejecuta explícitamente: `zsh -c '...'`.
  3. Si necesitas Bash puro: `bash -c '...'`.
  4. Verifica qué shell resuelve cada comando con `type` o `which`.

## 🗣️ Pronunciación de Antonio (entrada por voz) (IMPORTANTE)
- Antonio a veces usa entrada por voz y su pronunciación puede no ser perfecta,
  o el locucionero/TTS puede transcribir alguna palabra de forma incorrecta.
- Interpreta SIEMPRE según el **CONTEXTO** de la conversación antes que
  literalmente: si la palabra transcrita no encaja con lo que se está haciendo,
  es probable que sea un error de transcripción.
- Si una palabra resulta ambigua o no cuadra, **confirma con Antonio** antes de
  actuar en base a ella.
- NO fijes equivalencias rígidas de palabras mal transcritas: el contexto manda.

## 🛠️ Elevación de privilegios (sudo NO)
- NUNCA uses `sudo` para comandos que requieran contraseña
- Usa SIEMPRE `pkexec` en su lugar: así saldrá una ventana gráfica pidiendo la contraseña
- Ejemplo: `pkexec apt update` en vez de `sudo apt update`

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
1. **COMPRUEBA con herramientas** (ls, read, test, search_files) que la ruta o
   archivo realmente no existe. No lo des por hecho.
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

## Sincronización con Config/opencode (OBLIGATORIO)
- `~/.config/opencode/` es la configuración ACTIVA (la que usa OpenCode)
- `~/Config/opencode/` es la copia de SEGURIDAD para instalaciones desde limpio
- Estructura ordenada de `~/Config/opencode/`:
  - `backups/opencode/` → tarballs de backup de OpenCode (`opencode-backup-*.tar.gz`)
  - `backups/` (raíz) → backups del grafo de memoria (`mcp-memory-backup-*.jsonl`)
  - `data/` → datos auxiliares (p. ej. `onlyoffice-ai/`)
  - `documentacion/` → documentación en Markdown
  - `sesion-opencode/` → setup completo desde limpio + scripts sincronizados
  - `respaldo-config/` → snapshot antiguo de la configuración
  - `legacy/` → scripts y carpetas obsoletos
  - En la raíz solo viven: `AGENTS.md`, `backup-opencode.sh`, `bootstrap-ocv.sh`, `sync-opencode.sh`
    y el enlace simbólico `setup-opencode-completo.sh` → `sesion-opencode/setup-opencode-completo.sh`
- Cada vez que modifiques, crees o elimines algo en `~/.config/opencode/`:
  1. **Copia el archivo** a `~/Config/opencode/` (manteniendo la misma estructura)
  2. **Actualiza los scripts** de instalación si es necesario:
     - `~/Config/opencode/backup-opencode.sh` → script que empaqueta el backup
     - `~/Config/opencode/bootstrap-ocv.sh` → script de instalación desde limpio
     - `restore.sh` (va dentro del tarball, lo genera backup-opencode.sh)
  3. Si el cambio afecta al proceso de instalación/restauración, modifica los scripts para reflejarlo
- Ejecuta `bash ~/Config/opencode/backup-opencode.sh` para regenerar el tarball con restore.sh actualizado
- El tarball se genera en `~/Config/opencode/backups/opencode/`

## Atención al script setup-opencode-completo.sh (IMPORTANTE)
El script `~/Config/opencode/sesion-opencode/setup-opencode-completo.sh` es el
INSTALADOR COMPLETO desde cero. Contiene toda la configuración embebida. Por tanto:
- **ÚNICA copia en disco**: vive SOLO en `~/Config/opencode/sesion-opencode/`
  (carpeta de respaldo) y dentro del tarball del backup. NO debe existir en la raíz
  de `~/.config/opencode/` ni en ningún `scripts/`.
- **Acceso directo**: en la raíz de `~/Config/opencode/` hay un ENLACE SIMBÓLICO
  `setup-opencode-completo.sh` → `sesion-opencode/` para tenerlo a mano SIN duplicarlo.
- El `sync-opencode.sh` (timer systemd `opencode-sync.timer`, cada 30 minutos)
  sincroniza el resto de archivos desde `~/.config/opencode/`, pero NO crea copias
  del setup: ese se edita directamente en `~/Config/opencode/sesion-opencode/`.
- El `backup-opencode.sh` lo incluye automáticamente en el tarball desde
  `~/Config/opencode/sesion-opencode/`.
- Cuando Antonio pida un backup, DEBES:
  1. Revisar `setup-opencode-completo.sh` por completo
  2. Comprobar que incluye TODOS los archivos actuales de `~/.config/opencode/`
     (JSON, scripts, AGENTS.md, .env, etc.) con su contenido real
  3. Si falta algo o está desactualizado, actualizarlo ANTES del backup en
     `~/Config/opencode/sesion-opencode/setup-opencode-completo.sh`
     (única copia en disco)
  4. Ejecutar `bash ~/Config/opencode/backup-opencode.sh` para regenerar el tarball
  5. Verificar que el tarball contiene el setup actualizado y que no hay copias
     del setup en `~/.config/opencode/` (ni en la raíz ni en `sesion-opencode/scripts/`)

  ### ✅ CHECKLIST OBLIGATORIO del punto 1 (revisar el setup POR COMPLETO):
  - [ ] `bash -n` del setup (sintaxis)
  - [ ] `shellcheck` del setup (sin warnings/errors reales; SC2016 en heredocs = OK)
  - [ ] TODOS los heredocs embebidos == archivos activos, comparando UNO A UNO
        (opencode.json, opencode-local.json, opencode-cloud.json, tui.json,
        AGENTS.md, .env, y TODOS los scripts: sync, init, start-*,
        hardware-query, check-fix, check-timeline-fix, hardware-query.py,
        lmstudio-proxy.py, backup-opencode, bootstrap-ocv, timeline-completo)
        — no solo los JSON
  - [ ] Comandos usados existen en el sistema (pkexec, pacman, pipx, npm, etc.)
  - [ ] Estructura completa (pasos 1-19, sin saltos ni duplicados)

  ### ⚡ VERIFICACIÓN AUTOMÁTICA (NO DEPENDE DE MI MEMORIA):
  El script `~/.config/opencode/check-setup-completo.sh` hace TODO el checklist
  automáticamente (sintaxis, shellcheck, heredocs uno a uno, estructura, comandos).
  Está INTEGRADO en `backup-opencode.sh`: se ejecuta SIEMPRE al hacer un backup y
  si el setup no está correcto, el backup se ABORTA. NO es opcional ni manual.
  Si Antonio pide un backup, simplemente ejecuta `bash ~/Config/opencode/backup-opencode.sh`
  — la verificación ocurre sola. Si algo falla, el script dirá exactamente qué corregir.
- El `backup-opencode.sh` ya lo incluye automáticamente desde `~/Config/opencode/sesion-opencode/`
- Al RESTAURAR desde un tarball, el `restore.sh` coloca el setup en
  `~/Config/opencode/sesion-opencode/`, no en la raíz de `~/.config/opencode/`

---

# PERSISTENCIA DE DATOS Y RECUPERACIÓN

## Variables de entorno
El archivo `.env` contiene la configuración sensible. Para cargarlo:
```bash
set -a; source /home/antonio/.config/opencode/.env; set +a
```

## Inicialización (tras reinicio del sistema)
El servicio systemd `init-opencode.service` está DESHABILITADO.
Al abrir `opencode` u `ocv` se carga LM Studio + modelo + proxy automáticamente.
Para verificar componentes manualmente:
```bash
bash /home/antonio/.config/opencode/init-opencode.sh
```
Esto comprueba:
- Servidor LM Studio (puerto 1234)
- Modelos disponibles en LM Studio
- Persistencia del grafo de memoria
- PWAs en el Escritorio
- Variables de entorno (.env)

## Backup automático del grafo de memoria
El grafo de conocimiento se respalda automáticamente en:
`/home/antonio/Config/opencode/backups/`
Con nombre `mcp-memory-backup-{fecha}.jsonl`
Los backups se conservan 30 días (según LOG_RETENTION_DAYS en .env)
## Recuperación del grafo de memoria
Si el grafo se pierde o corrompe:
1. Localizar el backup más reciente:
   ```bash
   ls -t /home/antonio/Config/opencode/backups/mcp-memory-backup-*.jsonl | head -1
   ```
2. Copiarlo a la ruta de memoria activa:
   ```bash
   cp /home/antonio/Config/opencode/backups/mcp-memory-backup-*.jsonl /home/antonio/.config/opencode/data/memory/memory.jsonl
   ```
3. Reiniciar OpenCode: el servidor MCP Memory cargará el grafo desde `MEMORY_FILE_PATH`
   (definido vía `environment` en el bloque `mcp.memory` de los 3 perfiles JSON).
   ⚠️ El servidor usa `MEMORY_FILE_PATH` (NO `MEMORY_DATA_DIR`).

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

## 🕐 Timeline completo de sesiones (script timeline-completo)
El timeline de la TUI de OpenCode (Ctrl+X G) SOLO muestra las últimas ~6 peticiones
(límite hardcodeado; el PR #26861 que lo arregla sigue abierto, sin mergear).
Para ver el historial COMPLETO de cualquier sesión, usar el script:
```
~/.local/bin/timeline-completo
```
- `timeline-completo` → historial completo de la sesión actual (todas las peticiones con fecha/hora)
- `timeline-completo <id_sesión>` → historial de una sesión concreta
- `timeline-completo --sesiones` → lista las sesiones recientes con su título
- `timeline-completo --buscar "<texto>"` → busca peticiones en TODAS las sesiones
Lee directamente de `~/.local/share/opencode/opencode.db` (sqlite3).
TODAS las peticiones de Antonio están guardadas ahí aunque la TUI no las muestre.
Cuando Antonio pregunte por su historial/timeline de peticiones, usa este script.

## 👁️ Vigilancia del fix del timeline (timer systemd)
El script `~/.config/opencode/check-timeline-fix.sh` comprueba si el PR #26861
de OpenCode (fix del timeline) se ha mergeado. Se ejecuta automáticamente cada
3 días vía el timer systemd `check-timeline-fix.timer` y registra el resultado
en `~/.config/opencode/data/timeline-fix.log`.
- Si el PR se mergea: se avisa (log + notificación) para retirar timeline-completo.
- Consultar el log si Antonio pregunta por el estado del fix.

## Directorios de datos
- `/home/antonio/.config/opencode/data/` - Datos de ejecución (logs, estado)
- `/home/antonio/.config/opencode/data/memory/` - Grafo de memoria persistente (`memory.jsonl`, vía `MEMORY_FILE_PATH`)
- `/home/antonio/Config/opencode/backups/` - Backups del grafo de memoria (`mcp-memory-backup-*.jsonl`)
- `/home/antonio/Config/opencode/backups/opencode/` - Tarballs de backup de OpenCode
- `/home/antonio/.config/opencode/.env` - Variables de entorno seguras

---

# AVANZADO (uso principalmente con DeepSeek)

## PWAs - Cómo abrir
1. Leer /home/antonio/Escritorio
2. Buscar archivo chrome-<app-id>-Profile_2.desktop
3. Ejecutar línea Exec= del archivo

## PWAs - Cerrar
- Una PWA: curl -s http://localhost:9222/json/close/<ID>
- Todo Chrome: pkill -f "chrome.*remote-debugging-port"

## Chrome debug (si no está corriendo)
nohup /opt/google/chrome/google-chrome --user-data-dir="/tmp/chrome-debug-profile" "--profile-directory=DebugProfile" --remote-debugging-port=9222 "--remote-allow-origins=*" about:blank > /dev/null 2>&1 &

## Carga automática al abrir opencode/ocv
Al ejecutar `opencode` u `ocv`, el lanzador
`start-opencode-server.sh` carga automáticamente:
- Servidor LM Studio (puerto 1234)
- Modelo Qwen3.5-9B Q6_K con 80k de contexto
- Proxy en puerto 4001 con métricas de tokens/s

El servicio systemd `init-opencode.service` está DESHABILITADO
(no carga el modelo al iniciar sesión). La carga ocurre solo
al abrir opencode/ocv.

## Perfiles por lanzador (sin copias)
Cada comando usa SU archivo de config vía `OPENCODE_CONFIG`. **Nada se copia
nunca sobre `opencode.json`**, que es solo el perfil por defecto.

| Comando | Archivo de config | LM Studio (VRAM) |
|---------|-------------------|------------------|
| `ocv`, `opencode` | `opencode.json` | ✅ Carga modelo (todos los agentes y MCPs activos) |
| `ocv-local`, `opencode-local` | `opencode-local.json` | ✅ Carga modelo (todos los agentes, MCPs esenciales) |
| `ocv-cloud`, `opencode-cloud` | `opencode-cloud.json` | ❌ NO carga modelo (`SKIP_LMSTUDIO=1`) |

- En cloud, el agente local está **desactivado** (`agent.local.disable`) y `small_model`
  apunta a la nube (`opencode-go/deepseek-v4-flash`); el provider LM Studio está
  bloqueado (`disabled_providers`).
- El antiguo `switch-mcp-profile.sh` (copiaba local/cloud sobre `opencode.json`)
  está ELIMINADO desde el 18/08/2026.

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

Whitelist actual (05/09/2026): 8 modelos operativos en los 3 perfiles. Los retirados devuelven **410 Gone** (end of life) y se eliminan del whitelist. Detalle completo (ranking y descartados) en el markdown citado.

## Iniciar LM Studio manualmente
```bash
bash /home/antonio/.config/opencode/start-lmstudio.sh      # servidor + modelo + proxy
bash /home/antonio/.config/opencode/start-lmstudio-server.sh  # solo servidor + proxy
```

## Liberar VRAM
Si el modelo se satura, usar:
```bash
/home/antonio/.lmstudio/bin/lms unload --all
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
El proxy `lmstudio-proxy.py` registra métricas por request en `metrics.json`
(`METRICS_EXPORT_PATH` en `.env`, activado con `ENABLE_METRICS=true`) y además
inyecta `stats.tokens_per_second` en respuestas no-streaming.

Método rápido por terminal:
```bash
curl -s http://localhost:4001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"models-qwen3.5-9b","messages":[{"role":"user","content":"hola"}]}' | \
  python3 -c "import json,sys; d=json.load(sys.stdin); u=d['usage']; s=d.get('stats',{}); print(f\"Prompt: {u['prompt_tokens']} tok\\nGenerados: {u['completion_tokens']} tok\\nVelocidad: {s.get('tokens_per_second','N/A')} tok/s\")"
```

### Dashboard web (puerto 4200)
El servidor `lmstudio-metrics-server.py` sirve en `http://localhost:4200` un
dashboard con la última velocidad, la media, peticiones totales y el histórico
de peticiones del proxy local. Datos crudos en `/api/metrics`.
Iniciar: `python3 ~/.config/opencode/lmstudio-metrics-server.py 4200`

# CHECKLIST ANTES DE RESPONDER
- ¿Respuesta en español?
- ¿Fecha/hora en formato España?
- ¿Decimales con coma?
- Si pregunta por el tiempo: ¿he usado wttr.in?
- ¿He usado la herramienta directamente en vez de describir lo que haría?
