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
Toda documentación Markdown (manuales en `~/.config/opencode/documentacion/` y su
respaldo en `~/Config/opencode/documentacion/`, README, notas) DEBE seguir el mismo
esquema que los manuales ya existentes
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

⚠️ **Si lo lanza el AGENTE** (no hereda la sesión gráfica), `pkexec` no alcanza
el agente polkit y falla en silencio: la RAM (DIMMs) y la placa base quedarían
incompletas. Antes de escanear, exporta el entorno de la sesión GNOME:
```bash
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
export XDG_RUNTIME_DIR="/run/user/1000"
python3 ~/.config/opencode/hardware-query.py scan
```
Así aparece la ventana de contraseña y `dmidecode` funciona. `meta.generated` y
`meta.source` se rellenan con la fecha real (dinámicos desde el 22/09/2026).

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

## 🆕 OpenCode V2 (2.0.x): cambios importantes (16/09/2026)
Antonio migró de OpenCode V1 (1.18.x) a **V2 (2.0.x)**. Cambios que afectan a esta config:
- **Config del cliente TUI:** `tui.json` (V1) → **`cli.json`** (V2, `~/.config/opencode/cli.json`).
  Ahí se registran los plugins del terminal y se desactivan los internos (`-opencode.sidebar.context` y `-opencode.sidebar.footer`).
- **⚠️ Cambio de tecla de agente:** el ciclo de agentes primarios ya NO está en `Tab` sino en
  **`Shift+Tab`** (`agent.cycle`; `agent.cycle.reverse` sin asignar). `Tab` pasó a ser
  `prompt.autocomplete.complete` (`dialog.worktree.generate` en diálogos). Fallback: `Ctrl+X` → `A`
  (`agent.list`). Verificado el 16/09/2026 en una TUI aislada (`/usr/bin/opencode --standalone`
  enviando `ESC[Z`): rotó de agente correctamente. En `cli.json` solo se sobrescribe
  `session.rename` → `f8`; `agent.cycle` NO se toca. El aviso `shift+tab agents` sale en la barra
  inferior de la TUI. El antiguo `tui.json` (V1) se retiró el 16/09/2026 (archivado en `~/Config/opencode/legacy/`): V2 no lo lee.
- **Plugins TUI:** los plugins V1 **no funcionan** en V2. Los nuevos van en
  `~/.config/opencode/plugins/<nombre>/tui.tsx` (auto-descubiertos) e importan `@opencode/plugin/tui`
  con `Plugin.define({ id, setup(context) })`. NO llevar `index.ts` de servidor en la carpeta salvo
  que se instale `@opencode/plugin` (si no, falla con "Cannot find package").
- **Barra lateral estilo MiMoCode:** `plugins/sidebar-mimo/tui.tsx`. Muestra arriba del todo
  **Context** (tokens, % usado, límite, **t/s** y coste), luego **Directorio de trabajo** e
  **Instrucciones**, y al final la **versión de OpenCode**. Usa `prepend: "sidebar.content"`.
  El footer nativo (`opencode.sidebar.footer`) se desactiva en `cli.json` para no repetir la ruta.
- **Voz:** `opencode-voice-modified/tui.js` (puente V2 sobre `lib/`), registrado en `cli.json`.
- **Sintaxis canónica V2 (19/09/2026):** los 3 perfiles usan las claves de la wiki V2
  (`providers`, `agents`, `permissions`, `mcp.servers`, `system`, `disabled`). V2 acepta además
  las claves V1 (`provider`, `agent`, `permission`, `mcp` plano, `prompt`…) y las migra
  automáticamente, pero ya no se usan. ⚠️ El schema público `opencode.ai/config.json` aún solo
  valida las claves V1, así que el editor puede marcarlas como desconocidas (desajuste de la beta).
  - **Ampliación canónica (21/09/2026):** se pasaron a sintaxis nativa V2 las dos últimas claves V1
    que quedaban: `small_model` → **`agents.title.model`** (agente oculto `title`) y
    `disabled_providers` → **`experimental.policies`** (`action: provider.use`, `effect: deny`).
    V2 ya las normalizaba en silencio, pero ahora son explícitas. Se añadió además **`model`** raíz
    (`opencode-go/deepseek-v4.1-flash` en base/cloud, `local/qwen3.8-9b` en local) para fijar el
    modelo por defecto de sesión, y **`session.tps: true`** en `cli.json`.
- **NVIDIA whitelist:** la clave `providers.nvidia.whitelist` está **IGNORADA** por V2 (no tiene
  equivalente V2). La aplica el plugin de servidor `plugins/nvidia-filter/index.ts`
  (`ctx.model.transform`), que lee la lista de `opencode.json`. `check-nvidia-whitelist.sh`
  sigue siendo la fuente de verdad de esa lista (lee/escribe `providers.nvidia.whitelist`).
- **LSP:** V2 **NO ejecuta servidores LSP** (sin diagnósticos ni indicador en la barra).
  Por eso el bloque `lsp` se **retiró** de `opencode.json` el 16/09/2026 (copia en
  `~/Config/opencode/legacy/lsp-block-v1.json`, por si V2 lo recupera). Para tipos/lint, por
  terminal: `basedpyright`, `tsc --noEmit`, `cargo clippy`, `shellcheck`, etc.
- **`instructions`** de `opencode.json` se acepta pero V2 **no carga sus entradas**; `AGENTS.md`
  se descubre automáticamente. Se **retiró** de `opencode.json` el 19/09/2026 por ser inerte.
- **Ollama:** retirado. Antonio usa **LM Studio** (ver `02-configuracion-lmstudio.md`).
- **Provider local (LM Studio) en V2:** el id `lmstudio` **no resuelve** (choca con el builtin).
  Se usa un provider propio `local` (paquete nativo `@opencode/ai/providers/openai-compatible`,
  `settings.baseURL` = proxy `http://localhost:4001/v1`) con el modelo explícito `qwen3.8-9b`.
  El agente `local` y el agente `title` (vía `agents.title.model`) usan **`local/qwen3.8-9b`**.
- **✅ NVIDIA en V2 (`prompt_cache_key`) — RESUELTO (17/09/2026):** el bug del runtime
  OpenAI-compatible de V2 (2.0.3) que inyectaba `prompt_cache_key` y la API de NVIDIA rechazaba
  (`Validation: Unsupported parameter(s)`) está **corregido en OpenCode 2.0.5**. Verificado
  end-to-end con `muse-glimmer-30b` y los 4 nemotron (super/ultra/lightning/nano-omni): todos
  responden, tanto en `--standalone` como en el servicio compartido. Por eso se retiró el
  vigilante `check-nvidia-prompt-cache.sh` + su timer y servicio systemd (17/09/2026).

---

## Sincronización con Config/opencode (OBLIGATORIO)
- `~/.config/opencode/` es la configuración ACTIVA (la que usa OpenCode)
- `~/Config/opencode/` es la copia de SEGURIDAD para instalaciones desde limpio
- Estructura ordenada de `~/Config/opencode/`:
  - `backups/opencode/` → tarballs de backup de OpenCode (`opencode-backup-*.tar.gz`)
  - `backups/` (raíz) → backups del grafo de memoria (`mcp-memory-backup-*.jsonl`)
  - `data/` → datos auxiliares (p. ej. `onlyoffice-ai/`)
  - `documentacion/` → manuales de configuración en Markdown (respaldo)
  - `sesion-opencode/` → setup completo desde limpio + **respaldo canónico** de los
    archivos de configuración (`opencode.json`, `opencode-local.json`, `opencode-cloud.json`,
    `cli.json`, `plugins/`, scripts, `AGENTS.md`, `.env`, etc.)
  - `respaldo-config/` → snapshot antiguo de la configuración
  - `legacy/` → scripts y carpetas obsoletos
  - En la raíz solo viven: `AGENTS.md`, `backup-opencode.sh`, `bootstrap-ocv.sh`, `sync-opencode.sh`
    y el enlace simbólico `setup-opencode-completo.sh` → `sesion-opencode/setup-opencode-completo.sh`
  - ⚠️ **Nunca** debe haber archivos de configuración (`opencode*.json`, `cli.json`) en la
    **raíz** de `~/Config/opencode/`. Según la wiki de OpenCode
    (https://opencode.ai/docs/config/#locations), OpenCode SOLO lee la config de sus rutas
    oficiales: global `~/.config/opencode/opencode.json`, perfil `OPENCODE_CONFIG` y
    directorios `.opencode/` de proyecto. Una copia en esa raíz es **inerte y confunde**.
    El respaldo de esos archivos vive en `sesion-opencode/`. El `sync-opencode.sh` borra
    automáticamente cualquier resto de ese tipo en la raíz.
    ⚠️ **Ese borrado afecta SOLO a ficheros de configuración sueltos en la raíz: NUNCA toca
    `backups/` ni `credenciales/`.** Las claves de API **SÍ DEBEN ESTAR** en los tarballs de
    `~/Config/opencode/backups/opencode/` (es el backup de restauración y las necesita); donde
    **NUNCA** deben estar es en `~/Documentos/dotfiles/`.
  - ⚠️ **Manuales (`*.md`)**: viven SOLO en `~/.config/opencode/documentacion/` (activos)
    y en `~/Config/opencode/documentacion/` (respaldo). NUNCA en la raíz de `.config/opencode/`
    (salvo `AGENTS.md`) ni en `sesion-opencode/`. `AGENTS.md` es configuración (no manual) →
    vive en la raíz de `~/.config/opencode/` y de `~/Config/opencode/`.
    El `sync-opencode.sh` aplica esta regla automáticamente.
- Cada vez que modifiques, crees o elimines algo en `~/.config/opencode/`:
  1. **Copia el archivo** a `~/Config/opencode/sesion-opencode/` (respaldo canónico).
     NUNCA a la raíz de `~/Config/opencode/` si es un archivo de configuración.
     El `sync-opencode.sh` lo hace automáticamente.
  2. **Actualiza los scripts** de instalación si es necesario:
     - `~/Config/opencode/backup-opencode.sh` → script que empaqueta el backup
     - `~/Config/opencode/bootstrap-ocv.sh` → script de instalación desde limpio
     - `restore.sh` (va dentro del tarball, lo genera backup-opencode.sh)
  3. Si el cambio afecta al proceso de instalación/restauración, modifica los scripts para reflejarlo
- Ejecuta `bash ~/Config/opencode/backup-opencode.sh` para regenerar el tarball con restore.sh actualizado
- El tarball se genera en `~/Config/opencode/backups/opencode/`
- **Credenciales de proveedores**: el backup incluye automáticamente
  `~/.local/share/opencode/auth.json` (claves de NVIDIA `nvapi-*` y OpenCode GO `sk-*`)
  en `credenciales/auth.json` dentro del tarball. El `restore.sh` lo restaura a su
  ubicación original. Sin él, los agentes en la nube no funcionan tras reinstalar.
  - ✅ **Las claves de API SÍ DEBEN ESTAR en `~/Config/opencode/`** (dentro de los tarballs de
    `backups/opencode/`): es el backup de restauración y las necesita. **El único sitio donde NO
    deben estar NUNCA es `~/Documentos/dotfiles/`.** Esa es la frontera real, no "Config vs resto".
  - 🔒 **Permisos `600`/`700` (22/09/2026)**: el tarball se crea con `umask 077` + `chmod 600` y su
    directorio con `chmod 700`, porque dentro va `credenciales/auth.json` en claro. Antes quedaban
    en `644`/`755` → **legibles por cualquier usuario del sistema**. Si se crean tarballs por otra
    vía, aplicar el `chmod` a mano.
- 🔐 **Copia en dotfiles (SIN claves de API) — AUTOMÁTICA**: `backup-opencode.sh` (paso 7)
  la genera en cada backup volcando `~/Config/opencode/` a `~/Documentos/dotfiles/opencode/`
  (repo git `anmarui74/dotfiles`), excluyendo cualquier archivo con claves de API.
  Esa copia **NUNCA** debe contener ninguna clave de ningún tipo. Reglas que aplica:
  1. **Excluir siempre** (no copiar ni commitear): `.env` y cualquier `*.env`, `auth.json`,
     el directorio `credenciales/` y los tarballs `*.tar.gz` (contienen `.env` +
     `credenciales/auth.json` en claro). Se excluye **todo** el directorio `backups/`
     (desde el 22/09/2026: los tarballs y las copias fechadas del grafo se quedan solo en
     local). También se excluyen `node_modules/`, `__pycache__/`, `models/`, `build/`,
     `data/*.log` y `*.bak*`.
     ✅ **El grafo de memoria (`data/memory/`) SÍ se copia** (decisión de Antonio, 22/09/2026):
     es conocimiento acumulado y debe viajar con la configuración. No contiene claves.
  2. **Verificar antes de commitear/push** (abortar si aparece cualquier clave):
     ```bash
     cd ~/Documentos/dotfiles
     git grep -nIP '(nvapi-|oc_sk_)[A-Za-z0-9_-]{15,}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{25,}|AEMET_API_KEY=[A-Za-z0-9]{15,}' -- ':(exclude)*.md'
     ```
     Si devuelve algo, NO hacer commit/push y eliminar el fichero.
  3. El `.gitignore` del repo debe incluir:
     ```
     **/*.env
     **/auth.json
     **/credenciales/
     **/backups/**/*.tar.gz
     **/mcp-memory-backup-*.jsonl
     ```
  4. Si hay que versionar la configuración, versionar SOLO plantillas saneadas
     (`.env.example`, `auth.json.example`) sin valores reales.
  5. El backup hace el volcado con `rsync --delete --delete-excluded` y estos excludes, borra
     cualquier `*.tar.gz`/`.env`/`auth.json`/`credenciales/` residual y **verifica** que no queda
     ninguna clave (avisa si la detecta). ⚠️ **`--delete-excluded` es imprescindible**: con solo
     `--delete`, lo que está en la lista de exclusión NO se purga del destino y se va acumulando
     (mismo fallo detectado en MiMoCode el 22/09/2026: 171 MB de `node_modules` huérfanos).
  6. **Instalador desde cero**: `setup-opencode-completo.sh` **embebe el `.env`** (con la
     `AEMET_API_KEY` real), así que la copia que se suba a dotfiles debe ir **saneada**:
     ```bash
     sed -E 's/^(AEMET_API_KEY=).*/\1TU_CLAVE_AQUI/' \
       ~/Config/opencode/sesion-opencode/setup-opencode-completo.sh \
       > ~/Documentos/dotfiles/opencode/sesion-opencode/setup-opencode-completo.sh
     ```
     ⚠️ **NO** sanear el setup canónico (`~/Config/opencode/sesion-opencode/`): el
     `check-setup-completo.sh` compara su heredoc `.env` con el `.env` activo y fallaría.
     Solo se sanea la **copia de dotfiles**. Verificar con el paso 2 antes de commitear.

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
        (opencode.json, opencode-local.json, opencode-cloud.json, cli.json,
        AGENTS.md, .env, y TODOS los scripts: sync, init, start-*,
        hardware-query, check-fix, check-timeline-fix, check-nvidia-whitelist,
        hardware-query.py, lmstudio-proxy.py, backup-opencode, bootstrap-ocv,
        timeline-completo)
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
El grafo de conocimiento (MCP memory) se respalda automáticamente **en cada
ejecución de `backup-opencode.sh`** (tanto el backup manual como el automático
vía `opencode-sync.timer`, cada 30 min):

1. **Copia ESTABLE** en `~/Config/opencode/data/memory/memory.jsonl` → es la que viaja a
   `~/Documentos/dotfiles/opencode/data/memory/` en **UNA sola copia** (igual que MiMoCode
   con `config/data/memory/`). El grafo **nunca** se excluye de dotfiles.
2. **Copia con fecha** en `~/Config/opencode/backups/mcp-memory-backup-{fecha}.jsonl`
   (histórico **LOCAL** de rotación; **excluida** del volcado a dotfiles porque generaba
   **179 ficheros duplicados** en el repo — corregido el 22/09/2026)
3. **Copia en el tarball** de OpenCode: `data/memory/memory.jsonl` dentro del
   `opencode-backup-*.tar.gz` (se restaura con el `restore.sh` a la ruta activa)
4. **Retención**: los backups del grafo se conservan 30 días (según
   `LOG_RETENTION_DAYS` en `.env`), igual que los tarballs

El grafo activo vive en `~/.config/opencode/data/memory/memory.jsonl`.

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
4. Alternativa: restaurar desde un tarball de OpenCode con el `restore.sh`
   (restaura `data/memory/memory.jsonl` a la ruta activa automáticamente).

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

## 🐞 Vigilancia del issue #39164 (timer systemd)
El script `~/.config/opencode/check-fix.sh` comprueba si el issue #39164 de
OpenCode (bug de tools locales) se ha cerrado. Se ejecuta automáticamente cada
3 días vía el timer systemd `check-opencode-fix.timer` y guarda el estado en
`~/.config/opencode/data/issue_status.txt`.
- Si el issue se cierra: se avisa (log + notificación) para retirar check-fix.sh.
- Detalle completo en `documentacion/05-configuracion-adicional.md`.

## ⌨️ Tecla `l` tragada en la TUI V2 — RESUELTO (16/09/2026)
**La causa NO era un bug de OpenCode, era local:** el plugin `opencode-voice-modified/tui.js`
tenía `normalizeBind()` convirtiendo `<leader>r` en `leader+r`. El parser de V2 lee `leader+r`
como una secuencia LITERAL de teclas que empieza por `l`, así que la `l` quedaba como prefijo
pendiente y se tragaba su primera pulsación en TODA la TUI (no solo en el compositor).
**Arreglo aplicado:** `normalizeBind()` devuelve el bind sin transformar, porque V2 usa el
mismo formato que V1 (`<leader>r`, con ángulos). Verificado el 16/09/2026 en la TUI real:
4 pulsaciones → 4 `l` (antes 2).
- **Diagnóstico reproducible:** en una ventana de Kitty aislada, `OTUI_STDIN_LOG` demostró que
  Kitty envía `l` como byte `6c` y que OpenCode lo recibe; con `a`/`b`/`n`/`p`/`c` no falla;
  sin plugins no falla; con solo el plugin de voz (original) vuelve a fallar; con la copia
  corregida funciona. `l x` → "x" (mal) vs "lx" (bien).
- El issue upstream [#49244](https://github.com/anomalyco/opencode/issues/49244) se abrió con
  un diagnóstico erróneo (por eso decía "sin plugins que usen `l`"); se comentó y se CERRÓ el
  16/09/2026. El vigilante `check-key-l-issue.sh` + `check-key-l-issue.timer` se RETIRARON el
  mismo día.

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
- Modelo Qwen3.8-9B Q6_K con 80k de contexto
- Proxy en puerto 4001 con métricas de tokens/s

`start-lmstudio.sh` verifica primero si el modelo ya está cargado en VRAM con
`lms ps`. Si está cargado, se omite el `unload/load` para evitar abrir la GUI de
LM Studio y recargas innecesarias. Solo se inicia el servidor si no responde y se
asegura el proxy.

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

- 🧬 **Herencia (11/09/2026):** OpenCode **fusiona** las configs (global `opencode.json`
  primero, luego el `OPENCODE_CONFIG` del perfil). Por eso `opencode.json` es la **base
  común** con todo lo compartido (`shell`, `agents.title.model`, `permissions`, `providers` +
  whitelist NVIDIA, `mcp.servers`, `agents` y descripciones), y `opencode-local.json` /
  `opencode-cloud.json` contienen **solo lo que difiere** de esa base.
  El resto se **hereda**. Cambiar los `permissions` o la whitelist solo requiere
  tocar `opencode.json`. Detalle en `documentacion/04-perfiles-opencode-json.md`.
- En cloud, el agente local está **desactivado** (`agents.local.disabled`) y el agente `title`
  apunta a la nube (`agents.title.model` = `opencode-go/deepseek-v4.1-flash`); los providers
  **LM Studio** (`lmstudio`) y el local (`local`) están bloqueados con `experimental.policies`
  (`action: provider.use` → `effect: deny`).
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

Whitelist actual (rev. 11/09/2026): 7 modelos operativos en los 3 perfiles (se retiró `minimaxai/minimax-m3`, EOL el 09/09/2026). Los retirados devuelven **410 Gone** (end of life) y se eliminan del whitelist. Detalle completo (ranking y descartados) en el markdown citado.

**Modelos de los agentes:** `cloud` (predeterminado), `build`, `plan` y `multimodal` usan el predefinido de OpenCode Go (`opencode-go/deepseek-v4.1-flash`, admite texto + imagen); `local` usa `local/qwen3.8-9b`; `nvidia` usa `nvidia/nvidia/nemotron-3-ultra-550b-a55b` (NVIDIA Nemotron 3 Ultra 550B A55B, modelo mayor de la familia Nemotron 3, tool calling nativo; hasta el 24/09/2026 usaba Nemotron 3 Super 120B A12B).

> ⚠️ **Nota V2:** el `model` de un agente **primario** no cambia el modelo de la sesión al seleccionar el agente (la sesión guarda el suyo). Sí se aplica cuando el agente se usa como **subagente** (verificado con `nvidia`).

### 🤖 Verificación automática del whitelist (cada 15 días)
Desde el **05/09/2026** existe un check automático que aplica la metodología anterior:
- **Script:** `~/.config/opencode/check-nvidia-whitelist.sh`
- **Timer systemd:** `check-nvidia-whitelist.timer` (días 1 y 16 de cada mes a las 10:00, retardo aleatorio 30 min)
- **Qué hace:**
  1. Verifica que los modelos del whitelist actual dan HTTP 200 real. Los **410 Gone** se ELIMINAN automáticamente de los 3 perfiles JSON.
  2. Escanea el catálogo real buscando modelos NUEVOS (no vistos antes) y les aplica la metodología completa (velocidad ≥ 10 tok/s + tool calling).
  3. Los que pasan TODO quedan como **CANDIDATOS** (log + notificación) para revisión manual de Antonio — NO se añaden solos.
  4. Reintenta 429/500/503/timeout con margen antes de decidir.
- **Log:** `~/.config/opencode/data/nvidia-whitelist.log`
- **Estado:** `~/.config/opencode/data/nvidia-whitelist-state.json` (modelos vistos, retirados, última ejecución)
- **API key:** se lee de `~/.local/share/opencode/auth.json` (clave `nvidia.key`, formato `nvapi-*`) — no está hardcodeada en el script.
- Si el timer avisa de candidatos nuevos, revisar y, si procede, añadirlos al whitelist de los 3 perfiles siguiendo la metodología.
- Ejecutar manualmente: `bash ~/.config/opencode/check-nvidia-whitelist.sh`
- El script se documenta también en `04-perfiles-opencode-json.md`.

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

### En la TUI (barra lateral de OpenCode)
La barra lateral (Ctrl+X → B) muestra arriba del todo el bloque **Context** (plugin propio
`plugins/sidebar-mimo/tui.tsx`, V2, rev. 16/09/2026) con el nº de tokens, el % usado, el
límite del modelo, los **tokens/s** de la última respuesta y el coste acumulado; debajo,
**Directorio de trabajo** e **Instrucciones**, y al final la **versión de OpenCode**.
Funciona para TODOS los providers (local, NVIDIA, cloud).
(El antiguo plugin npm `opencode-throughput` se eliminó el 11/09/2026.)

### Proxy local (puerto 4001)
El proxy `lmstudio-proxy.py` registra métricas por request en `metrics.json`
(`METRICS_EXPORT_PATH` en `.env`, activado con `ENABLE_METRICS=true`) y además
inyecta `stats.tokens_per_second` en respuestas no-streaming.

Método rápido por terminal:
```bash
curl -s http://localhost:4001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3.8-9b","messages":[{"role":"user","content":"hola"}]}' | \
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
