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
  - ⚠️ **Nunca** debe haber archivos de configuración (`mimocode.json(c)`, `mimocode-local*.json(c)`,
    `mimocode-cloud*.json(c)`, `tui.json`, `cli.json`) en la **raíz** de `~/Config/mimocode/`.
    MiMoCode SOLO lee la config de sus rutas oficiales (`~/.config/mimocode/` y el perfil
    indicado por `MIMOCODE_CONFIG_DIR`), así que una copia en esa raíz es **inerte y confunde**.
    El respaldo de esos archivos vive en `sesion-mimocode/config/`. **El `sync-mimocode.sh` los
    BORRA automáticamente** de la raíz (bloque `rm -f` justo después del `rsync`) — mismo
    comportamiento que el `sync-opencode.sh` en OpenCode:
    ```bash
    rm -f "$BACKUP"/mimocode.json "$BACKUP"/mimocode.jsonc \
          "$BACKUP"/mimocode-local.json "$BACKUP"/mimocode-local.jsonc \
          "$BACKUP"/mimocode-cloud.json "$BACKUP"/mimocode-cloud.jsonc \
          "$BACKUP"/tui.json "$BACKUP"/cli.json 2>/dev/null || true
    ```
    ⚠️ **Ese borrado afecta SOLO a ficheros de configuración sueltos en la raíz: NUNCA toca
    `backups/` ni `credenciales/`.** Las claves de API **SÍ DEBEN ESTAR** en los tarballs de
    `~/Config/mimocode/backups/mimocode/` (es el backup de restauración y las necesita); donde
    **NUNCA** deben estar es en `~/Documentos/dotfiles/`.
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

### 🔐 Copia en dotfiles (SIN claves de API) — AUTOMÁTICA
`backup-mimocode.sh` (paso 8) la genera en cada backup volcando `~/Config/mimocode/` a
`~/Documentos/dotfiles/mimocode/` (repo git `anmarui74/dotfiles`), excluyendo cualquier
archivo con claves de API. Esa copia **NUNCA** debe contener ninguna clave de ningún tipo:
- ✅ **Las claves de API SÍ DEBEN estar en `~/Config/mimocode/`** (dentro de los tarballs de
  `backups/mimocode/`): es el backup de restauración y las necesita. **El único sitio donde NO
  deben estar NUNCA es `~/Documentos/dotfiles/`.** Esa es la frontera real, no "Config vs resto".
- 🧹 **El volcado usa `rsync --delete --delete-excluded` (el segundo flag es IMPRESCINDIBLE).**
  Con solo `--delete`, los ficheros que están en la lista de exclusión (`node_modules`,
  `*.bak*`, `.env`, `credenciales/`) **NO se purgan** del destino: al quedar fuera de la
  transferencia, `rsync` los ignora y los deja acumulándose. `--delete-excluded` sí los borra,
  así que `~/Documentos/dotfiles/mimocode/` queda siempre idéntico a `~/Config/mimocode/`.
  Sin él se detectaron **171 MB de `node_modules` huérfanos** el 22/09/2026 (el `.gitignore`
  los tapaba, pero ocupaban disco). ⚠️ Si se copia con otro método (`cp`, `tar`), hay que
  **vaciar la carpeta destino antes**.
- ⚠️ Los tarballs `backups/mimocode/*.tar.gz` **incluyen `credenciales/auth.json`**
  (claves `nvapi-*`/`sk-*`) → **NO** se copian a dotfiles.
- Excluir siempre: `backups/mimocode/` (tarballs), `.env`/`*.env`, `auth.json`,
  `credenciales/`, `node_modules/`, `*.bak*`.
- 🧴 **Saneado del instalador en dotfiles**: `setup-mimocode-completo.sh` **SÍ embebe
  `auth.json` con las claves reales** (paso 4, **a propósito**: así una instalación desde cero
  queda operativa con la misma configuración, igual que OpenCode hace con su `.env`). Por eso
  el `backup-mimocode.sh` (paso 8) **sanea la copia de dotfiles**, sustituyendo cada
  `"key": "..."` por `"key": "TU_CLAVE_AQUI"`.
  ⚠️ **NUNCA sanear el instalador canónico** (`~/Config/mimocode/sesion-mimocode/`): si no, una
  instalación desde cero no restauraría las credenciales.
- Verificar antes de commitear/push (abortar si aparece algo). El patrón exige un **límite de
  palabra** antes de `sk-` y claves **largas**, para no dar falsos positivos con `task-<hash>`,
  `disk-encryption-keyvault` o los ejemplos documentales (`sk-1234567890abcdef`) que están en
  el grafo de memoria:
  ```bash
  cd ~/Documentos/dotfiles
  git grep -nIP --exclude='*.md' '(nvapi-|oc_sk_)[A-Za-z0-9_-]{15,}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{25,}|AEMET_API_KEY=[A-Za-z0-9]{15,}'
  ```
- ⚠️ El riesgo de claves está en **dos** sitios: los tarballs de `backups/` y el **instalador
  embebido** (que viaja dentro de `sesion-mimocode/`). Ambos se excluyen/sanean en el volcado
  a dotfiles.
- El `.gitignore` del repo debe incluir `mimocode/backups/mimocode/*.tar.gz`,
  `**/*.env`, `**/auth.json` y `**/credenciales/`.

## Atención al script setup-mimocode-completo.sh (IMPORTANTE)
El script `~/Config/mimocode/sesion-mimocode/setup-mimocode-completo.sh` es el INSTALADOR desde
cero, en paridad con el de OpenCode. Deja MiMoCode **igual que la instalación activa** partiendo
de un sistema limpio. **13 pasos:**

| Paso | Qué hace |
|------|----------|
| 0 | Dependencias base (node, npm, python3, curl, git) — las instala con `pacman` si faltan |
| 1 | Binario `mimo` — lo instala con el oficial (`https://mimo.xiaomi.com/install`) si no está |
| 2 | Estructura de directorios (`~/.config/mimocode`, `~/.local/share/mimocode`, `~/Config/mimocode/…`) |
| 3 | Restaura la configuración completa desde `sesion-mimocode/config/` |
| 4 | **Credenciales `auth.json` EMBEBIDAS** (ver abajo) |
| 5 | Lanzadores `start-mimo*.sh` (embebidos) |
| 6 | Funciones ZSH `mimo`/`mimo-local`/`mimo-cloud` + PATH |
| 7 | Timer systemd `mimocode-sync.timer` |
| 8 | `npm install` del plugin de voz |
| 9 | Estructura `~/Config/mimocode/` + `backup-mimocode.sh` + `check-setup-completo.sh` + symlink |
| 10 | Instala la infraestructura LM Studio **PROPIA** (`start-lmstudio.sh`, server, proxy) |
| 11 | Instala/verifica los servidores LSP |
| 12 | Verifica las dependencias de voz (`sox`, `whisper-cli`, `speak-kokoro-gpu`) |
| 13 | Verificación final (`check-setup-completo.sh`) + sincronización de la copia canónica |

**Qué está EMBEBIDO** (si se edita el original, hay que replicarlo en el instalador — el
`check-setup-completo.sh` lo detecta y aborta el backup):
- Los 3 lanzadores `start-mimo*.sh`, `mimocode-sync.service` y `.timer`
- `backup-mimocode.sh` y `check-setup-completo.sh`
- **La infraestructura LM Studio propia**: `start-lmstudio.sh`, `start-lmstudio-server.sh` y
  `lmstudio-proxy.py` (así MiMoCode es autónomo y no depende de OpenCode)
- 🔐 **`auth.json` con las claves reales** (paso 4): **a propósito**, para que una instalación
  desde cero quede operativa con la misma configuración (OpenCode hace lo mismo con su `.env`).
  La copia de dotfiles se sanea automáticamente en `backup-mimocode.sh` (paso 8).

✅ **Lo que NO se embebe a propósito: la configuración** (`mimocode.jsonc`, `profiles/`, `tui.json`,
`AGENTS.md`, plugin de voz). Se copia desde `sesion-mimocode/config/`, que el `sync-mimocode.sh`
mantiene idéntica a la activa. Duplicarla reintroduciría el desfase que ya nos mordió (2 lanzadores
un mes desfasados, detectado el 22/09/2026).

✅ **MiMoCode es AUTÓNOMO**: desde el 22/09/2026 instala su **propia** infraestructura LM Studio
(`~/.config/mimocode/start-lmstudio.sh`, `start-lmstudio-server.sh` y `lmstudio-proxy.py`), con las
rutas ya adaptadas a mimocode. **NO depende de que OpenCode esté instalado.** El único requisito
externo es el binario de **LM Studio** (`~/.lmstudio/bin/lms`) con el modelo `qwen3.8-9b`; sin él,
los perfiles locales arrancan igual con `SKIP_LMSTUDIO=1`.

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
- Que los **11 heredocs embebidos** en el instalador coinciden con los ficheros activos: los 3
  lanzadores, `mimocode-sync.service`, `.timer`, `backup-mimocode.sh`, `check-setup-completo.sh`,
  `auth.json` y la infraestructura LM Studio (`start-lmstudio.sh`, `start-lmstudio-server.sh`,
  `lmstudio-proxy.py`) — añadido el 22/09/2026, porque antes solo se comprobaba que los
  lanzadores *existieran*, no que su contenido fuese el correcto
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
- `mimo` → perfil global (`~/.config/mimocode/mimocode.jsonc`), agente `nvidia`, carga LM Studio
- `mimo-local` → `profiles/local`, agente `local`, carga LM Studio
- `mimo-cloud` → `profiles/cloud`, agente `cloud`, NO carga LM Studio
- **NO hay funciones `mimo-voz*`** (retiradas el 16/09/2026): el plugin de voz vive en `tui.json`
  (fichero único, sin variante por perfil), así que se carga en los 3 lanzamientos y basta con
  `/voice` en la TUI. Ver `~/Config/mimocode/documentacion/03-configuracion-voz-mimo.md`.
- **Los lanzadores se ejecutan en la ventana ACTUAL — NO abren ventana nueva** (rev. 16/09/2026, tras
  revertir un intento previo que sí la abría). **⛔ `~/.config/kitty/kitty.conf` está VETADO.**
  ⚠️ **El fondo translúcido de la TUI NO se arregla por configuración: es un BUG OFICIAL de MiMoCode**
  (issue **#1146**, abierto; PR de arreglo **#1382** sin fusionar; afecta también a la última versión,
  0.1.14). Causa: `theme.tsx:484-486` → `renderer.setBackgroundColor(values().background)` publica como
  fondo por defecto del terminal **el mismo color que pinta**, y el terminal le aplica su
  `background_opacity`. `thinkingOpacity` sólo afecta al **texto** del pensamiento: no lo arregla.
  Diagnóstico completo y comentario publicado: `~/Config/mimocode/documentacion/bug-fondo-translucido-mimocode.md`.
- Los perfiles se activan con `MIMOCODE_CONFIG_DIR` (merge sobre el global). **Nada se copia** sobre el config global.
- **Merge profundo verificado:** los perfiles heredan del global todo lo que no redefinan. Para inspeccionar
  la config efectiva de un perfil: `MIMOCODE_CONFIG_DIR=<dir> mimo debug config` (incluye `mcp_origins.<mcp>.source`,
  que indica de qué archivo procede cada entrada).
- **Cada perfil declara sus bloques `lsp` y `mcp` COMPLETOS a propósito** (son autodescriptivos: el archivo se
  entiende por sí solo, sin depender de otro). Comportamiento por perfil (verificado 11/09/2026):
  - `mimocode.jsonc` (global): los **5 MCP activos**. Modelo barato (grupo `lite`) → `opencode-go/deepseek-v4.1-flash`.
  - `profiles/local`: solo `filesystem`, `memory` y `fetch` (`context7` y `sequential_thinking` con `enabled: false`)
    + modelo local. Es lo que se ve en la TUI: 3 MCP "Connected".
  - `profiles/cloud`: los **5 MCP activos** pero `disabled_providers: ["lmstudio"]` → NO carga el modelo local.
  ⚠️ Al añadir o cambiar un LSP o un MCP hay que replicarlo a mano en los 3 archivos: **la duplicación es intencional**.
  Verificación rápida de coherencia (debe dar `lsp 11` en los tres, y MCP 5 · 3 · 5):
  ```bash
  for p in "" profiles/local profiles/cloud; do
    echo "== ${p:-GLOBAL}"
    MIMOCODE_CONFIG_DIR="$HOME/.config/mimocode/$p" mimo debug config 2>/dev/null \
      | python3 -c "import json,sys;c=json.load(sys.stdin);print(' lsp',len(c.get('lsp',{})),'| mcp',sorted(k for k,v in c.get('mcp',{}).items() if v.get('enabled')))"
  done
  ```
  ⚠️ Las claves `tui.json` (`keybinds`, `plugin`) NO se resuelven por perfil: `MIMOCODE_CONFIG_DIR` solo
  busca `mimocode.json(c)`. Un `tui.json` por perfil sería ignorado (verificado en la doc oficial, 11/09/2026).
- Los `.jsonc` admiten comentarios `//` (verificado: MiMoCode los parsea sin error).
- **Telemetría**: los lanzadores exportan `MIMOCODE_ENABLE_ANALYSIS=false` por privacidad
  (sobreescribible con `MIMOCODE_ENABLE_ANALYSIS=true`).
- Al abrir `mimo` o `mimo-local` se carga LM Studio + modelo Qwen3.8-9B + proxy usando la copia
  **PROPIA** de MiMoCode (`~/.config/mimocode/start-lmstudio.sh`). No hay servicio systemd de arranque.

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
- `/home/antonio/.config/opencode/` - Recursos de OpenCode (`.env`, hardware). ⚠️ MiMoCode ya NO depende de aquí para LM Studio (copia propia desde 22/09/2026)

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

Whitelist actual: 7 modelos operativos en los 3 perfiles (rev. 11/09/2026; se retiró `minimaxai/minimax-m3`, EOL el 09/09/2026). Los retirados devuelven **410 Gone** y se eliminan.

### 🔄 Protocolo para que el whitelist de MiMoCode NO quede desfasado (IMPORTANTE)
⚠️ El check automático vive en **OpenCode** (`~/.config/opencode/check-nvidia-whitelist.sh` +
`check-nvidia-whitelist.timer`, días **1 y 16** de cada mes) y actualiza **solo** los perfiles de
OpenCode. Los 3 perfiles de **MiMoCode NO se actualizan solos**: hay que corregirlos a mano.

**Tras cada pase del timer de OpenCode (o al menos una vez al mes), hacer esto:**

1. Ver qué retiró el check automático (log + estado del propio OpenCode):
   ```bash
   tail -40 ~/.config/opencode/data/nvidia-whitelist.log
   python3 -c "import json;print(json.load(open('/home/antonio/.config/opencode/data/nvidia-whitelist-state.json')).get('retirados',{}))"
   ```
2. Quitar cada retirado de los **3** archivos de MiMoCode, en `provider.nvidia.whitelist`
   **y** en `provider.nvidia.models` (las dos listas):
   `mimocode.jsonc`, `profiles/local/mimocode.jsonc` y `profiles/cloud/mimocode.jsonc`.
3. Verificar que los 3 quedan iguales, sin el retirado y bien cargados:
   ```bash
   for p in "" profiles/local profiles/cloud; do
     MIMOCODE_CONFIG_DIR="$HOME/.config/mimocode/$p" mimo debug config 2>/dev/null \
       | python3 -c "import json,sys;w=json.load(sys.stdin)['provider']['nvidia']['whitelist'];print(len(w),w)"
   done
   ```
4. Cerrar el ciclo:
   ```bash
   bash ~/.config/mimocode/sync-mimocode.sh && bash ~/Config/mimocode/backup-mimocode.sh
   ```

**Comprobar si un modelo concreto sigue vivo** (sustituir `MODELO`):
```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST "https://integrate.api.nvidia.com/v1/chat/completions" \
  -H "Authorization: Bearer $(python3 -c "import json;print(json.load(open('$HOME/.local/share/mimocode/auth.json'))['nvidia']['key'])")" \
  -H "Content-Type: application/json" \
  -d '{"model":"MODELO","messages":[{"role":"user","content":"ok"}],"max_tokens":5}'
```
`200` = vivo · `404` = sin endpoint de chat (descartar) · `410` = **retirado → eliminar del whitelist**.

## Iniciar LM Studio manualmente
```bash
bash /home/antonio/.config/mimocode/start-lmstudio.sh      # servidor + modelo + proxy (propio de MiMoCode)
bash /home/antonio/.config/mimocode/start-lmstudio-server.sh  # solo servidor + proxy
```
> 🔗 Los equivalentes de OpenCode viven en `~/.config/opencode/` y son **independientes**: MiMoCode ya no los usa.
> 📦 **Modelos** — GGUF en cuantización **Q6_K** (~7,5 GB cada uno), descargados de Hugging Face.
> El instalador los baja solo si faltan (`lms get <repo>@Q6_K --yes`):

| En LM Studio | Repo de Hugging Face |
|---|---|
| `qwen3.8-9b` (principal) | `empero-ai/Qwen3.8-9B-Distill-GGUF` |
| `qwen3.5-9b` | `unsloth/Qwen3.5-9B-GGUF` |

## Liberar VRAM
Si el modelo se satura, usar:
```bash
/home/antonio/.lmstudio/bin/lms unload --all
```

## 📊 Tokens/s

### Proxy local (puerto 4001)
El proxy **propio** `~/.config/mimocode/lmstudio-proxy.py` registra métricas por request en
`~/.config/mimocode/data/metrics.json` (por defecto: `CONFIG_DIR/data/metrics.json`; se puede
sobreescribir con `METRICS_EXPORT_PATH` en un `.env` en ese mismo directorio) y además inyecta
`stats.tokens_per_second` en respuestas no-streaming. **No necesita `.env` ni claves de API.**

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
