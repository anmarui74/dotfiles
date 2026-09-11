# 📜 AGENTS.md — Reglas de comportamiento de OpenCode

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 📜 Reglas del sistema | 26/07/2026 · rev. 09/08/2026 | Antonio |

> Instrucciones del sistema que OpenCode carga al inicio de cada sesión

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
- Qué NO debe hacer (sudo, comandos de detección)

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
   ├── Sincronización con Config/opencode (estructura ordenada)
   └── Atención a setup-opencode-completo.sh

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

### Estructura de `~/Config/opencode/` (desde 09/08/2026)

```
Config/opencode/
├── backups/opencode/          # Tarballs de backup de OpenCode (1/día, retención 30 días)
├── backups/                   # Backups del grafo de memoria (mcp-memory-backup-*.jsonl)
├── data/onlyoffice-ai/        # Integración IA de OnlyOffice
├── documentacion/             # Manuales de configuración en Markdown (respaldo)
├── sesion-opencode/           # Setup completo desde limpio + scripts sincronizados
└── raíz: AGENTS.md, backup-opencode.sh, bootstrap-ocv.sh, sync-opencode.sh
    + enlace simbólico setup-opencode-completo.sh → sesion-opencode/ (sin duplicar)
```

El AGENTS.md documenta esta estructura y exige mantener la raíz limpia.

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

Es un concepto importante. Cuando el TTS (edge-tts) lee el texto en voz alta, los emojis como ✈️ serían leídos como "avión" o "icono de avión". El **locucionero** es un filtro (implementado en el script `speak`) que elimina los emojis ANTES de pasar el texto a edge-tts, permitiendo que el asistente use emojis en pantalla sin que el TTS los lea.

#### Formato de fecha y hora

| Concepto | Estilo España | Ejemplo |
|----------|--------------|---------|
| Fecha | dd/mm/aaaa | 26/07/2026 |
| Hora | 24h | 14:30 |
| Decimales | coma | 3,14 |
| Moneda | símbolo € | 25 € |
| Temperatura | °C | 32 °C |
| Velocidad | km/h | 120 km/h |
| Distancia | km / m | 5 km |

### ☁️ Consultar el tiempo (líneas 21-27) — IMPORTANTE

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

### 💻 Consultar hardware (líneas 29-39) — IMPORTANTE

```
Cuando Antonio pregunte sobre su hardware, LEE el archivo:
~/.config/opencode/data/hardware/index.json

NO ejecutes comandos de detección (inxi, lspci, dmidecode, etc.)
```

Razón: Ejecutar comandos de hardware (inxi, lspci) es lento y consume recursos. El archivo `index.json` ya contiene **toda** la información del sistema, generada una sola vez. Contiene 26 secciones con datos de CPU, RAM, GPU, discos, monitores, audio, USB, sensores, red, etc.

Consulta rápida desde terminal:
```bash
source ~/.config/opencode/hardware-query.sh && hw_query <campo>
```

### 🔧 Uso de herramientas (líneas 49-57) — OBLIGATORIO

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

### 🛠️ Elevación de privilegios (líneas 58-62)

```
- NUNCA uses `sudo` para comandos que requieran contraseña
- Usa SIEMPRE `pkexec` en su lugar
- Ejemplo: `pkexec apt update` en vez de `sudo apt update`
```

Razón: `sudo` pide la contraseña por terminal, pero OpenCode se ejecuta en un entorno TUI donde no puede introducir la contraseña. `pkexec` abre una **ventana gráfica** donde Antonio puede escribir la contraseña cómodamente.

---

## Sección 2: PROCEDIMIENTOS TÉCNICOS

### Sincronización con Config/opencode (líneas 78-100) — OBLIGATORIO

Explica el **sistema de dos directorios**:

```
~/.config/opencode/     ← Activo (el que usa OpenCode)
~/Config/opencode/      ← Backup (para reinstalar desde limpio)
```

#### Flujo de trabajo al modificar algo:

```
1. Modificas en ~/.config/opencode/
2. COPIA el archivo a ~/Config/opencode/ (misma estructura)
3. Actualiza scripts de instalación si es necesario:
   - backup-opencode.sh  → empaqueta el backup
   - bootstrap-ocv.sh    → instalación desde limpio
   - restore.sh          → va dentro del tarball
4. Ejecuta: bash ~/Config/opencode/backup-opencode.sh
```

### Atención a setup-opencode-completo.sh (líneas 101-149) — IMPORTANTE

Este script es el **instalador completo embebido**. Contiene toda la configuración dentro de sí mismo (es un script autocontenido).

#### Reglas:

- Cada cambio en `~/.config/opencode/` debe reflejarse en `setup-opencode-completo.sh`
- Antes de un backup, hay que **revisar** que el script incluya TODOS los archivos actuales
- Copiar a: `~/Config/opencode/sesion-opencode/` (tanto raíz como `scripts/`)

---

## Sección 3: PERSISTENCIA DE DATOS Y RECUPERACIÓN

### Variables de entorno (líneas 152-157)

```bash
set -a; source /home/antonio/.config/opencode/.env; set +a
```

- Usa `set -a` para exportar automáticamente todas las variables
- El `.env` contiene credenciales y rutas sensibles

### Inicialización tras reinicio (líneas 158-171)

```bash
bash /home/antonio/.config/opencode/init-opencode.sh
```

Verifica:
1. **LM Studio** activo en puerto 1234
2. **Modelos** disponibles
3. **Grafo de memoria** persistente
4. **PWAs** en el Escritorio
5. **Variables de entorno** (.env)

### Backup del grafo de memoria (líneas 172-176)

```
Directorio: /home/antonio/Config/opencode/backups/
Formato:    mcp-memory-backup-{fecha}.jsonl
Retención:  30 días
```

El grafo de memoria es un archivo **JSONL** (una línea JSON por entidad) que contiene todas las entidades, observaciones y relaciones que el asistente ha aprendido.

### Recuperación del grafo (líneas 177-190)

Si el grafo se pierde o corrompe:

```bash
# 1. Localizar backup más reciente
ls -t /home/antonio/Config/opencode/backups/mcp-memory-backup-*.jsonl | head -1

# 2. Copiar el backup a la ruta activa del grafo (MEMORY_FILE_PATH)
cp /home/antonio/Config/opencode/backups/mcp-memory-backup-*.jsonl \
   /home/antonio/.config/opencode/data/memory/memory.jsonl
```

### Recordatorio MCP memory (líneas 191-201) — IMPORTANTE

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

### Timeline completo (líneas 202-216)

La TUI de OpenCode (Ctrl+X G) solo muestra las últimas ~6 peticiones (límite hardcodeado;
el PR #26861 que lo arregla sigue abierto, sin mergear). Para ver el historial completo:

```bash
~/.local/bin/timeline-completo                # Sesión actual
~/.local/bin/timeline-completo <id_sesión>    # Sesión concreta
~/.local/bin/timeline-completo --sesiones     # Listar sesiones
~/.local/bin/timeline-completo --buscar "txt" # Buscar en todas
```

Lee directamente de `~/.local/share/opencode/opencode.db` (sqlite3). Todas las peticiones
de Antonio están guardadas ahí aunque la TUI no las muestre.

### Vigilancia del fix del timeline (líneas 217-224)

El script `~/.config/opencode/check-timeline-fix.sh` comprueba si el PR #26861 se ha mergeado.
Se ejecuta cada 3 días vía el timer systemd `check-timeline-fix.timer` y registra en
`~/.config/opencode/data/timeline-fix.log`. Si se mergea, avisa para retirar `timeline-completo`.

### Directorios de datos (líneas 225-233)

| Directorio | Contenido |
|------------|-----------|
| `~/.config/opencode/data/` | Logs, estado |
| `~/.config/opencode/data/memory/` | Grafo de memoria persistente |
| `~/Config/opencode/backups/` | Copias de seguridad del grafo |
| `~/.config/opencode/.env` | Variables de entorno seguras |

---

## Sección 4: AVANZADO

Esta sección está pensada principalmente para cuando se usa **DeepSeek** u otros modelos que puedan necesitar instrucciones más detalladas para tareas específicas.

### PWAs - Abrir (líneas 236-240)

```
1. Leer /home/antonio/Escritorio
2. Buscar archivo chrome-<app-id>-Profile_2.desktop
3. Ejecutar línea Exec= del archivo
```

Las PWAs (Progressive Web Apps) se instalan como accesos directos en el Escritorio con nombres como `chrome-<app-id>-Profile_2.desktop`. La línea `Exec=` contiene el comando completo para lanzarlas.

### PWAs - Cerrar (líneas 241-244)

```bash
# Cerrar una PWA específica
curl -s http://localhost:9222/json/close/<ID>

# Cerrar todo Chrome
pkill -f "chrome.*remote-debugging-port"
```

Usa el puerto de depuración remota (9222) para comunicarse con Chrome.

### Chrome debug (líneas 245-247)

```bash
nohup /opt/google/chrome/google-chrome \
  --user-data-dir="/tmp/chrome-debug-profile" \
  "--profile-directory=DebugProfile" \
  --remote-debugging-port=9222 \
  "--remote-allow-origins=*" \
  about:blank > /dev/null 2>&1 &
```

Lanza Chrome en modo depuración con un perfil temporal, necesario para controlar PWAs remotamente.

### Carga automática al abrir opencode/ocv (líneas 248-258)

Al ejecutar `opencode` u `ocv`, el lanzador `start-opencode-server.sh` carga automáticamente:

1. **Servidor LM Studio** (puerto 1234)
2. **Modelo Qwen3.5-9B Q6_K** con 80K de contexto
3. **Proxy** en puerto 4001 con métricas de tokens/s

El servicio systemd `init-opencode.service` está **DESHABILITADO** (no carga el modelo al iniciar sesión). La carga ocurre solo al abrir `opencode`/`ocv`.

> 📌 **Perfil cloud:** `ocv-cloud`/`opencode-cloud` exporta `SKIP_LMSTUDIO=1`, por lo que `start-opencode-server.sh` NO carga el modelo local en VRAM.

### Perfiles por lanzador (líneas 259-274)

Cada comando usa **SU archivo de config** vía `OPENCODE_CONFIG`. Nada se copia nunca sobre `opencode.json`:

| Comando | Archivo de config | LM Studio (VRAM) |
|---------|-------------------|------------------|
| `ocv`, `opencode` | `opencode.json` | ✅ Carga modelo (todos los agentes y MCPs) |
| `ocv-local`, `opencode-local` | `opencode-local.json` | ✅ Carga modelo (MCPs esenciales) |
| `ocv-cloud`, `opencode-cloud` | `opencode-cloud.json` | ❌ NO carga modelo (`SKIP_LMSTUDIO=1`) |

En cloud: agente local desactivado (`agent.local.disable`), `small_model` apunta a la nube (`opencode-go/deepseek-v4.1-flash`) y el provider LM Studio está bloqueado (`disabled_providers`). El antiguo `switch-mcp-profile.sh` está **ELIMINADO** desde el 18/08/2026.

### Iniciar LM Studio manualmente (líneas 275-279)

```bash
bash /home/antonio/.config/opencode/start-lmstudio.sh      # servidor + modelo + proxy
bash /home/antonio/.config/opencode/start-lmstudio-server.sh  # solo servidor + proxy
```

### Liberar VRAM (líneas 281-285)

Si el modelo se satura, usar:

```bash
/home/antonio/.lmstudio/bin/lms unload --all
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
- Registra métricas por request en `data/metrics.json` (`METRICS_EXPORT_PATH`).
- Inyecta `stats.tokens_per_second` en respuestas no-streaming.

#### Dashboard web (puerto 4200)

`lmstudio-metrics-server.py` sirve en `http://localhost:4200` el histórico de
velocidad, tokens y peticiones del proxy local. Datos crudos en `/api/metrics`.

Método rápido por terminal:

```bash
curl -s http://localhost:4001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"models-qwen3.5-9b","messages":[{"role":"user","content":"hola"}]}' | \
  python3 -c "import json,sys; d=json.load(sys.stdin); u=d['usage']; s=d.get('stats',{}); print(f\"Prompt: {u['prompt_tokens']} tok\\nGenerados: {u['completion_tokens']} tok\\nVelocidad: {s.get('tokens_per_second','N/A')} tok/s\")"
```

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

Si quieres modificar AGENTS.md:

1. Edita `~/.config/opencode/AGENTS.md`
2. **Copia** a `~/Config/opencode/AGENTS.md` (sincronización)
3. **Actualiza** `setup-opencode-completo.sh` para que incluya los cambios
4. **Regenera** backup: `bash ~/Config/opencode/backup-opencode.sh`

### Notas sobre el "locucionero"

El término aparece en la línea 14:
> "Mi locucionero filtra estos iconos automáticamente antes del TTS, sin necesidad de configuración extra"

Es una **nota para Antonio** (no para el asistente). Le indica que puede usar emojis con libertad porque el sistema de voz los filtra automáticamente. El "locucionero" es el script `speak` (~/.local/bin/speak), que limpia los emojis y caracteres especiales del texto antes de pasarlo a edge-tts.
