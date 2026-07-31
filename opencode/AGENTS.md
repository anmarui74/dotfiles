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

## 🌤️ Consultar el tiempo (IMPORTANTE)
Para preguntas sobre el tiempo, usa la herramienta fetch_html (o fetch_json) para consultar:
https://wttr.in/{ciudad}?format=j1&m&lang=es
Ejemplo: https://wttr.in/Pechina?format=j1&m&lang=es

⚠️ Si wttr.in no responde o devuelve vacío, NO vuelvas a llamar a fetch.
Limítate a informar al usuario: "wttr.in no está disponible ahora, inténtalo más tarde."

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

## 🔧 Uso de herramientas (OBLIGATORIO)
Cuando tengas que hacer una tarea que requiera una herramienta (leer archivos,
listar directorios, ejecutar comandos, etc.) USA LA HERRAMIENTA directamente.
NO describas lo que harías — hazlo.
NO digas "voy a leer" sin llamar a la herramienta.
NO generes texto explicando los pasos sin ejecutarlos.
SIMPLIFICA: si necesitas leer múltiples archivos, usa search_files con un
patrón, o llama a read_file para cada archivo individual.

## 🛠️ Elevación de privilegios (sudo NO)
- NUNCA uses `sudo` para comandos que requieran contraseña
- Usa SIEMPRE `pkexec` en su lugar: así saldrá una ventana gráfica pidiendo la contraseña
- Ejemplo: `pkexec apt update` en vez de `sudo apt update`

---

# PROCEDIMIENTOS TÉCNICOS

## Sincronización con Config/opencode (OBLIGATORIO)
- `~/.config/opencode/` es la configuración ACTIVA (la que usa OpenCode)
- `~/Config/opencode/` es la copia de SEGURIDAD para instalaciones desde limpio
- Cada vez que modifiques, crees o elimines algo en `~/.config/opencode/`:
  1. **Copia el archivo** a `~/Config/opencode/` (manteniendo la misma estructura)
  2. **Actualiza los scripts** de instalación si es necesario:
     - `~/Config/opencode/backup-opencode.sh` → script que empaqueta el backup
     - `~/Config/opencode/bootstrap-ocv.sh` → script de instalación desde limpio
     - `restore.sh` (va dentro del tarball, lo genera backup-opencode.sh)
  3. Si el cambio afecta al proceso de instalación/restauración, modifica los scripts para reflejarlo
- Ejecuta `bash ~/Config/opencode/backup-opencode.sh` para regenerar el tarball con restore.sh actualizado

## Atención al script setup-opencode-completo.sh (IMPORTANTE)
El script `~/Config/opencode/sesion-opencode/setup-opencode-completo.sh` es el
INSTALADOR COMPLETO desde cero. Contiene toda la configuración embebida. Por tanto:
- **ÚNICA copia en disco**: vive SOLO en `~/Config/opencode/sesion-opencode/`
  (carpeta de respaldo) y dentro del tarball del backup. NO debe existir en la raíz
  de `~/.config/opencode/` ni en ningún `scripts/`.
- El `sync-opencode.sh` (timer systemd `opencode-sync.timer`, cada 2 minutos)
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
Con nombre `mcp-memory-backup-{fecha}.json`
Los backups se conservan 30 días (según LOG_RETENTION_DAYS en .env)

## Recuperación del grafo de memoria
Si el grafo se pierde o corrompe:
1. Localizar el backup más reciente:
   ```bash
   ls -t /home/antonio/Config/opencode/backups/mcp-memory-backup-*.json | head -1
   ```
2. El servidor MCP Memory debería restaurarlo automáticamente al iniciar desde `MEMORY_DATA_DIR`

## Directorios de datos
- `/home/antonio/.config/opencode/data/` - Datos de ejecución (logs, estado)
- `/home/antonio/.config/opencode/data/memory/` - Grafo de memoria persistente
- `/home/antonio/Config/opencode/backups/` - Copias de seguridad del grafo
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

## 📊 Tokens/s en respuestas locales
El proxy en puerto 4001 calcula y muestra tokens/segundo automáticamente
en cada respuesta. Se ve en el campo `stats.tokens_per_second` del JSON.

Para ver tokens/s en OpenCode TUI: la info aparece al final de cada mensaje
junto al nombre del modelo (ej: "Qwen 3.5 Q6_K · 13.5 tok/s").

Método rápido por terminal:
```bash
curl -s http://localhost:4001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"models-qwen3.5-9b","messages":[{"role":"user","content":"hola"}]}' | \
  python3 -c "import json,sys; d=json.load(sys.stdin); u=d['usage']; s=d.get('stats',{}); print(f\"Prompt: {u['prompt_tokens']} tok\\nGenerados: {u['completion_tokens']} tok\\nVelocidad: {s.get('tokens_per_second','N/A')} tok/s\")"
```

# CHECKLIST ANTES DE RESPONDER
- ¿Respuesta en español?
- ¿Fecha/hora en formato España?
- ¿Decimales con coma?
- Si pregunta por el tiempo: ¿he usado wttr.in?
- ¿He usado la herramienta directamente en vez de describir lo que haría?
