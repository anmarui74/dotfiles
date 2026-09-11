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
Toda documentación Markdown (manuales en `~/Config/opencode/documentacion/` y
`~/Config/mimocode/documentacion/`, README, notas) DEBE seguir el mismo esquema
que los manuales ya existentes (ver `01-configuracion-ollama.md`,
`04-perfiles-opencode-json.md`, `README.md`). Usa EXACTAMENTE esta plantilla:

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

> 🔎 Ejemplo real: `~/Config/opencode/documentacion/README.md` (índice de documentación)
> y `~/Config/opencode/documentacion/01-configuracion-ollama.md` (plantilla de manual).

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
SIMPLIFICA: si necesitas leer múltiples archivos, usa la búsqueda con patrón,
o lee cada archivo individual.

## 🐚 Shell del sistema: ZSH (usuario) vs Bash (agentes) (IMPORTANTE)
- Antonio usa **ZSH** como shell del sistema.
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
- NUNCA uses `sudo` para comandos que requieran contraseña **cuando los ejecutes tú como agente**
- Usa SIEMPRE `pkexec` en su lugar: así saldrá una ventana gráfica pidiendo la contraseña
- Ejemplo: `pkexec apt update` en vez de `sudo apt update`
- **Diferencia clave:** `pkexec` es para las ejecuciones que realiza el agente, que no tiene terminal interactiva. Los scripts que Antonio ejecuta manualmente desde su terminal pueden y deben usar `sudo` para escalar privilegios de forma cómoda en consola. Es decir:
  - Agente → `pkexec`
  - Scripts/terminal de Antonio → `sudo` permitido

## 📖 Consultar documentación oficial ante problemas (OBLIGATORIO)
Cuando algo te esté dando problemas (herramientas que fallan, configuraciones que no
funcionan, errores desconocidos, etc.):
1. **Accede PRIMERO a la documentación/wiki oficial** de la herramienta afectada
2. Busca información en la web (issues, foros, stackoverflow)
3. NO te quedes dando vueltas probando a ciegas: si tras 2-3 intentos propios no
   lo resuelves, consulta fuentes externas
4. Para MiMoCode: https://mimo.xiaomi.com/mimocode (esquema https://mimo.xiaomi.com/mimocode/config.json)
5. Para OpenCode (infra compartida: LM Studio, proxy): https://opencode.ai/docs
6. Para LSPs concretos: consulta la wiki del servidor (ej. github del proyecto)
Anota siempre la solución encontrada en la memoria.

## 🔍 Verificar hechos antes de afirmar (OBLIGATORIO)
Antes de declarar que algo "falta", "está roto" o "es un problema crítico":
1. **COMPRUEBA con herramientas** (ls, read, test, búsqueda) que la ruta o
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

## Sincronización con Config/mimocode (OBLIGATORIO)
- `~/.config/mimocode/` es la configuración ACTIVA que usa MiMoCode
- `~/Config/mimocode/` es la copia de SEGURIDAD para instalaciones desde limpio
- Estructura `~/Config/mimocode/`:
  - `backups/mimocode/` → tarballs `mimocode-backup-*.tar.gz` (config + credenciales + instalador + restore.sh)
  - `documentacion/` → documentación de incidencias de MiMoCode
  - `sesion-mimocode/` → INSTALADOR desde cero (`setup-mimocode-completo.sh`) + `config/` (copia canónica de la config activa que restaura el instalador)
  - En la raíz solo viven: `AGENTS.md`, `backup-mimocode.sh`, `check-setup-completo.sh`
    y el enlace simbólico `setup-mimocode-completo.sh` → `sesion-mimocode/setup-mimocode-completo.sh`
- **Sincronización automática**: el timer systemd `mimocode-sync.timer` ejecuta
  `~/.config/mimocode/sync-mimocode.sh --quiet` cada 30 min y mantiene
  `sesion-mimocode/config/` idéntico a la config activa (rsync, sin node_modules ni `.bak`).
- Cada vez que modifiques, crees o elimines algo en `~/.config/mimocode/`:
  1. **Sincroniza la copia canónica**: `bash ~/.config/mimocode/sync-mimocode.sh`
  2. Si el cambio afecta a la instalación, actualiza `setup-mimocode-completo.sh`
  3. Regenera el tarball: `bash ~/Config/mimocode/backup-mimocode.sh`
     (el backup sincroniza y verifica automáticamente antes de empaquetar)
- El tarball se genera en `~/Config/mimocode/backups/mimocode/` e incluye:
  `config.tar.gz` (config activa), `setup.tar.gz` (instalador), `credenciales/auth.json`
  (claves de `~/.local/share/mimocode/auth.json`), `scripts/` (backup + check) y `restore.sh`
- Retención: 30 días (los tarballs antiguos se eliminan solos)

## Atención al script setup-mimocode-completo.sh (IMPORTANTE)
El script `~/Config/mimocode/sesion-mimocode/setup-mimocode-completo.sh` es el INSTALADOR desde cero:
- Copia `sesion-mimocode/config/` → `~/.config/mimocode/`, crea los lanzadores `start-mimo*.sh`
  en `~/.local/bin`, añade las funciones ZSH (`mimo`, `mimo-local`, ...) si no existen
  y activa el timer `mimocode-sync.timer`
- ÚNICA copia en disco en `~/Config/mimocode/sesion-mimocode/` y dentro del tarball
  (NO debe existir en `~/.config/mimocode/`)
- Acceso directo vía enlace simbólico `~/Config/mimocode/setup-mimocode-completo.sh`
- Cuando Antonio pida un backup de MiMoCode, simplemente ejecuta
  `bash ~/Config/mimocode/backup-mimocode.sh`: sincroniza la copia canónica, verifica
  el setup y empaqueta. Si la verificación falla, el backup se ABORTA.
- Para RESTAURAR: descomprimir el tarball y ejecutar `bash restore.sh`; para instalar
  desde cero: `bash ~/Config/mimocode/setup-mimocode-completo.sh`

## ⚡ Verificación del setup
El script `~/Config/mimocode/check-setup-completo.sh` comprueba:
- Que existe la copia canónica y el instalador (sintaxis `bash -n`)
- Que la copia canónica == config activa
- Que existen los lanzadores `start-mimo*.sh` y las funciones ZSH
Se ejecuta automáticamente desde `backup-mimocode.sh` (aborta el backup si falla).
Ejecución manual: `bash ~/Config/mimocode/check-setup-completo.sh`

---

# PERSISTENCIA DE DATOS Y RECUPERACIÓN

## Variables de entorno
El archivo `.env` contiene la configuración sensible. Para cargarlo:
```bash
set -a; source /home/antonio/.config/opencode/.env; set +a
```

## Lanzadores y perfiles (MiMoCode)
- `mimo` / `mimo-voz` → perfil global (`~/.config/mimocode/mimocode.jsonc`), agente `nvidia`, carga LM Studio
- `mimo-local` / `mimo-voz-local` → `profiles/local`, agente `local`, carga LM Studio
- `mimo-cloud` / `mimo-voz-cloud` → `profiles/cloud`, agente `cloud`, NO carga LM Studio
- Los perfiles se activan con `MIMOCODE_CONFIG_DIR` (merge sobre el global). **Nada se copia** sobre el config global.
- **Telemetría**: los lanzadores exportan `MIMOCODE_ENABLE_ANALYSIS=false` por privacidad
  (sobreescribible con `MIMOCODE_ENABLE_ANALYSIS=true`).
- Al abrir `mimo` o `mimo-local` se carga LM Studio + modelo Qwen3.8-9B + proxy
  reutilizando `~/.config/opencode/start-lmstudio.sh`. No hay servicio systemd de arranque.

## Grafo de memoria
- El grafo MCP vive en `~/.config/mimocode/data/memory/memory.jsonl` (ruta vía `MEMORY_FILE_PATH`).
- Se incluye en `config.tar.gz` dentro de cada `mimocode-backup-*.tar.gz`.
- Recuperación: restaurar con `restore.sh` o copiar `data/memory/memory.jsonl` desde un backup.
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

## Directorios de datos
- `/home/antonio/.config/mimocode/data/` - Datos de ejecución (logs, estado)
- `/home/antonio/.config/mimocode/data/memory/` - Grafo de memoria (`memory.jsonl`)
- `/home/antonio/.config/mimocode/data/sync.log` - Log del timer de sincronización
- `/home/antonio/Config/mimocode/backups/mimocode/` - Tarballs de backup de MiMoCode
- `/home/antonio/.local/share/mimocode/auth.json` - Credenciales de proveedores
- `/home/antonio/.config/opencode/` - Recursos compartidos (LM Studio, proxy, `.env`, hardware)

---

# AVANZADO

## PWAs - Cómo abrir
1. Leer /home/antonio/Escritorio
2. Buscar archivo chrome-<app-id>-Profile_2.desktop
3. Ejecutar línea Exec= del archivo

## PWAs - Cerrar
- Una PWA: curl -s http://localhost:9222/json/close/<ID>
- Todo Chrome: pkill -f "chrome.*remote-debugging-port"

## Chrome debug (si no está corriendo)
nohup /opt/google/chrome/google-chrome --user-data-dir="/tmp/chrome-debug-profile" "--profile-directory=DebugProfile" --remote-debugging-port=9222 "--remote-allow-origins=*" about:blank > /dev/null 2>&1 &

## 🏆 Proveedor NVIDIA: ranking y metodología de selección de modelos (IMPORTANTE)
Cuando se trabaje con el proveedor `nvidia` (agente `nvidia` o selector `/models`),
usar la METODOLOGÍA establecida el 05/09/2026 para verificar/actualizar el whitelist.
Documentada completa en `04-perfiles-mimocode-json.md` y en el grafo de memoria.

Resumen de la metodología (en orden, obligatorio):
1. **Catálogo real:** `GET https://integrate.api.nvidia.com/v1/models` — el catálogo `models.dev` está DESACTUALIZADO para NVIDIA (lista modelos retirados).
2. **HTTP 200 real:** `POST /chat/completions` a cada candidato. Los listados sin endpoint de chat desplegado devuelven **404** → descartar.
3. **Velocidad:** generación real de ~180 tokens, exigir **≥ ~10 tok/s**. Los modelos lentos son inútiles como agente.
4. **Tool calling (OBLIGATORIO):** petición con `tools: [get_current_time]` + `tool_choice: auto`; exigir `tool_calls` reales. Sin tools = inutilizable.
5. **Reintentos:** los 429/500/503/timeout se reintentan con más margen antes de decidir.

Whitelist actual: 8 modelos operativos en los 3 perfiles. Los retirados devuelven **410 Gone** y se eliminan.
- La verificación automática (`check-nvidia-whitelist.sh` + timer) pertenece a **OpenCode** y
  actualiza los perfiles de OpenCode, NO los de MiMoCode. Tras un check automático, revisar
  si hay cambios y aplicarlos manualmente al whitelist de los 3 perfiles de MiMoCode.

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

## 📊 Tokens/s

### Proxy local (puerto 4001)
El proxy `~/.config/opencode/lmstudio-proxy.py` (compartido) registra métricas por request
en `metrics.json` (`METRICS_EXPORT_PATH` en `.env`, activado con `ENABLE_METRICS=true`) y
además inyecta `stats.tokens_per_second` en respuestas no-streaming.

Método rápido por terminal:
```bash
curl -s http://localhost:4001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"models-qwen3.8-9b","messages":[{"role":"user","content":"hola"}]}' | \
  python3 -c "import json,sys; d=json.load(sys.stdin); u=d['usage']; s=d.get('stats',{}); print(f\"Prompt: {u['prompt_tokens']} tok\\nGenerados: {u['completion_tokens']} tok\\nVelocidad: {s.get('tokens_per_second','N/A')} tok/s\")"
```

### Dashboard web (puerto 4200)
El servidor `lmstudio-metrics-server.py` sirve en `http://localhost:4200` un
dashboard con la última velocidad, la media, peticiones totales y el histórico
de peticiones del proxy local. Datos crudos en `/api/metrics`.
Iniciar: `python3 ~/.config/opencode/lmstudio-metrics-server.py 4200`

> 📁 `~/.config/mimocode/` - Configuración activa de MiMoCode · `~/Config/mimocode/` - Copia de seguridad e instalador

# CHECKLIST ANTES DE RESPONDER
- ¿Respuesta en español?
- ¿Fecha/hora en formato España?
- ¿Decimales con coma?
- Si pregunta por el tiempo: ¿he usado AEMET/wttr.in?
- ¿He usado la herramienta directamente en vez de describir lo que haría?
