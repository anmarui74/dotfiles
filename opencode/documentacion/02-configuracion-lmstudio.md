# 🖥️ Configuración de LM Studio + Proxy

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 🌟 Proveedor principal | 26/07/2026 · rev. 10/10/2026 | Antonio |

> Servidor de inferencia principal con proxy en puerto 4001

---

## 📑 Índice


1. [Descripción general](#descripción-general)
2. [Proxy de LM Studio (`lmstudio-proxy.py`)](#proxy-de-lm-studio)
3. [Script de inicialización (`init-opencode.sh`)](#script-de-inicialización)
4. [Script de arranque rápido (`start-lmstudio.sh`)](#script-de-arranque-rápido)
5. [Lanzador de OpenCode (`start-opencode-server.sh`)](#lanzador-de-opencode)
6. [Settings de LM Studio](#settings-de-lm-studio)
7. [Variables de entorno](#variables-de-entorno)
8. [Servicios systemd](#servicios-systemd)
9. [Flujo completo de arranque](#flujo-completo-de-arranque)
10. [Modelo activo](#modelo-activo)

---

## Descripción general

**LM Studio** es el servidor de inferencia **principal** y **activo** en la configuración de OpenCode. Proporciona el modelo `qwen3.8-9b` con 80K de contexto. Se ejecuta como servidor local en el puerto `1234` y se accede a través de un proxy en el puerto `4001`.

### Arquitectura

```
OpenCode → http://localhost:4001/v1 (proxy) → http://localhost:1234/v1 (LM Studio)
```

- **Puerto LM Studio (1234):** API directa del servidor
- **Puerto Proxy (4001):** Proxy Python de reenvío con métricas (tokens/s) y workaround de Qwen 3.8
- **Provider en OpenCode (V2):** `local/qwen3.8-9b` (id de provider `local`) con baseURL `http://localhost:4001/v1`. En V1 era `lmstudio/qwen3.8-9b`, pero en V2 el id `lmstudio` choca con el provider builtin y no resuelve; por eso se usa un provider propio `local` con el paquete nativo `@opencode/ai/providers/openai-compatible`.

---

## Proxy de LM Studio

### Archivo: `~/.config/opencode/lmstudio-proxy.py`

### ¿Qué hace?

Proxy HTTP **de reenvío** entre OpenCode y LM Studio. **No** carga ni descarga modelos (eso lo hace `start-lmstudio.sh` al arrancar OpenCode, ver más abajo):

1. Recibe las peticiones de OpenCode en el puerto `4001` y las reenvía a `http://localhost:1234`
2. Registra **métricas por petición** (modelo, tokens, tiempo, tok/s) en `data/metrics.json` (`ENABLE_METRICS=true` + `METRICS_EXPORT_PATH` del `.env`); conserva las últimas 500
3. Inyecta `stats.tokens_per_second` en las respuestas **no-streaming** (barra lateral de la TUI)
4. Con streaming (SSE) estima los tokens del buffer (`chars / 4` si LM Studio no reporta `usage`)
5. Aplica un **workaround para Qwen 3.8**: si falta un mensaje con `role: 'user'`, añade uno `'(cont.)'`
6. Quita el prefijo `lmstudio/` del nombre de modelo si llegara con él
7. Usa un **timeout de 300 s** para generaciones largas (no 600)

> ⚠️ El proxy **no** gestiona carga/descarga de modelos ni devuelve `503`.

### Código (extracto real)

```python
LM   = "http://localhost:1234"   # LM Studio API
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4001
METRICS_LOCK = threading.Lock()
MAX_RECORDS  = 500

# Reenvío con timeout de 300 s
r = urllib.request.urlopen(urllib.request.Request(
    f"{LM}{self.path}", data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json"}), timeout=300)

# Workaround Qwen 3.8 (solo si falta un mensaje de usuario)
if not any(m.get('role') == 'user' for m in body.get('messages', [])):
    body['messages'].append({'role': 'user', 'content': '(cont.)'})
```

---

## Script de inicialización

### Archivo: `~/.config/opencode/init-opencode.sh`

Script **completo** de inicialización y verificación (al iniciar sesión vía systemd). Realiza 5 pasos:

> ⚠️ **Estado actual (18/08/2026): el servicio `init-opencode.service` está DESHABILITADO.** > La carga de LM Studio + modelo + proxy ocurre automáticamente al abrir `opencode` u `ocv` > (vía `start-opencode-server.sh`), no al iniciar sesión. `init-opencode.sh` se usa como > comprobación manual (`bash ~/.config/opencode/init-opencode.sh`).

### Paso 1: Servidor LM Studio

```bash
if curl -s -o /dev/null http://127.0.0.1:1234/v1/models; then
    log "✅ Servidor LM Studio ya está corriendo"
else
    $LMSTUDIO_BIN server start  # lms server start
fi
```

### Paso 2: Cargar modelo con 80K contexto

```bash
$LMSTUDIO_BIN load "qwen3.8-9b" -c 81920 -y
```

Verifica que el contexto aplicado sea `81920`. Si no, reintenta. Usa `lms ps` para comprobar el contexto actual.

### Paso 3: Iniciar proxy (puerto 4001)

```bash
nohup python3 "$SCRIPT_DIR/lmstudio-proxy.py" 4001 > /tmp/lmstudio-proxy.log 2>&1 &
```

### Paso 4: Fijar contexto en settings.json

Modifica `~/.lmstudio/settings.json` para que `defaultContextLength` sea `81920`:

```json
{
  "defaultContextLength": {"type": "custom", "value": "81920"}
}
```

### Paso 5: Verificaciones

- Lista modelos disponibles (guarda en `data/available_models.txt`)
- Comprueba persistencia del grafo de memoria
- Verifica index de hardware
- Comprueba archivo `.env`

### Log de inicialización

Todo se registra en: `~/.config/opencode/data/init.log`

---

## Script de arranque rápido

### Archivo: `~/.config/opencode/start-lmstudio.sh`

Versión simplificada para ejecución manual:

```bash
# 1. Arrancar servidor si no responde en 1234
curl -s http://localhost:1234/v1/models >/dev/null || $LMSTUDIO_BIN server start

# 2. Si el modelo YA está cargado (lms ps), se OMITE la recarga
if ! $LMSTUDIO_BIN ps | grep -q "qwen3.8-9b"; then
    $LMSTUDIO_BIN unload --all
    $LMSTUDIO_BIN load "qwen3.8-9b" -c 81920 -y
fi

# 3. Matar proxy previo y arrancar uno limpio
pkill -f lmstudio-proxy
setsid python3 lmstudio-proxy.py 4001 > /tmp/lms-proxy.log 2>&1 &
```

> 💡 Si el modelo ya está en VRAM, `start-lmstudio.sh` **omite** `unload`/`load` para no > recargar ni abrir la GUI de LM Studio innecesariamente (verificado con `lms ps`).

---

## Lanzador de OpenCode

### Archivo: `~/.config/opencode/start-opencode-server.sh`

Script **lanzador real** que ejecuta `opencode`/`ocv` (el binario `~/.local/bin/opencode` es un enlace simbólico a este script):

1. Verifica si `SKIP_LMSTUDIO` está definido (perfil cloud): si NO, carga LM Studio + modelo + proxy
2. Ejecuta `start-lmstudio.sh` (servidor + modelo + proxy) o `start-lmstudio-server.sh` si no existe
3. Ejecuta OpenCode con `exec "${REAL_OPENCODE}" "$@"` (binario real en `/usr/bin/opencode`)

Útil para lanzar OpenCode desde terminal con acceso directo, cargando todo el stack local automáticamente.

> ⚠️ **Nota:** existe también `start-opencode.sh` (interactivo, solo verifica el servidor LM Studio sin cargar modelo ni proxy), pero el **lanzador real** que se usa es `start-opencode-server.sh` (el symlink `~/.local/bin/opencode` apunta a este).

---

## Settings de LM Studio

### Archivo: `~/.config/opencode/settings.lmstudio.json`

Copia de respaldo de la configuración de la GUI de LM Studio. El archivo **vivo** que lee el servidor es `~/.lmstudio/settings.json` (ahí es donde se fija el contexto). Contenido real del respaldo:

| Parámetro | Valor |
|-----------|-------|
| `language` | `es` (español) |
| `downloadsFolder` | `/home/antonio/.lmstudio/models` |
| `developerMode` | `true` (habilitado) |
| `autoLoadBundledLLM` | `true` |
| `modelLoadingGuardrails.mode` | `high` |
| `chat` / `developer` / `ui` / `sidebar` | Preferencias de la interfaz (chat, actualizaciones, barra lateral…) |

El **contexto de 80K** no vive en este respaldo, sino en `~/.lmstudio/settings.json` del servidor, donde `defaultContextLength` es `{"type":"custom","value":"81920"}` (lo fija el PASO 2 de `init-opencode.sh`, verificado el 10/10/2026). Esa ventana permite que el modelo maneje conversaciones largas y archivos grandes sin perder el hilo.

---

## Variables de entorno

Del archivo `.env`:

```bash
# No hay variables específicas de LM Studio en .env
# El proxy se configura directamente en opencode.json:
# "options": {"baseURL": "http://localhost:4001/v1"}
```

El provider en `opencode.json` (sintaxis V2, provider propio `local`):

```json
"providers": {
  "local": {
    "name": "LM Studio (Qwen 3.8)",
    "env": ["LMSTUDIO_API_KEY"],
    "package": "@opencode/ai/providers/openai-compatible",
    "settings": {
      "baseURL": "http://localhost:4001/v1",
      "apiKey": "lm-studio"
    },
    "models": {
      "qwen3.8-9b": {
        "name": "Qwen 3.8 - Tool Calling Excellence",
        "capabilities": { "tools": true, "input": ["text"], "output": ["text"] },
        "limit": { "context": 81920, "output": 8192 }
      }
    }
  }
}
```

> 📌 En V1 el provider se llamaba `lmstudio` y usaba `@ai-sdk/openai-compatible`. En V2 el id > `lmstudio` choca con el provider builtin y no resuelve, por eso se usa el provider propio > `local` con el paquete nativo `@opencode/ai/providers/openai-compatible`.

---

## Servicios systemd

### Servicio de inicialización (systemd user)

**Archivo:** `~/.config/systemd/user/init-opencode.service`

```ini
[Unit]
Description=OpenCode - arranca LM Studio, modelo 80K y proxy
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/home/antonio/.config/opencode/init-opencode.sh
StandardOutput=append:/home/antonio/.config/opencode/data/init.log
StandardError=append:/home/antonio/.config/opencode/data/init.log

[Install]
WantedBy=default.target
```

Se activa con:
```bash
systemctl --user enable init-opencode.service
systemctl --user start init-opencode.service
```

> ⚠️ **Actualmente está DESHABILITADO** (`systemctl --user is-enabled` → `disabled`): > la carga se hace al abrir `opencode`/`ocv` vía `start-opencode-server.sh`.

---

## Flujo completo de arranque

```
1. Abrir opencode / ocv / ocv-local / ocv-cloud (o terminal)
   ↓
2. start-opencode-server.sh (lanzador real)
   ↓
3. start-lmstudio.sh (salvo SKIP_LMSTUDIO=1 en perfil cloud):
   ├── 3.1. lms server start (puerto 1234)
   ├── 3.2. lms unload + lms load qwen3.8-9b -c 81920
   └── 3.3. lmstudio-proxy.py (puerto 4001)
   ↓
4. exec /usr/bin/opencode (con la config del perfil elegido)
   ↓
5. OpenCode → http://localhost:4001/v1 → Proxy → http://localhost:1234/v1 → Modelo
```

> El servicio systemd `init-opencode.service` (arranque al iniciar sesión) está > **DESHABILITADO** desde el 18/08/2026: la carga ocurre al abrir OpenCode.

---

## Modelo activo

| Propiedad | Valor |
|-----------|-------|
| **Modelo** | `qwen3.8-9b` (Qwen 3.8 - 9B parámetros) |
| **Contexto** | 81.920 tokens |
| **Output máximo** | 8.192 tokens |
| **Tool calling** | ✅ Sí |
| **Provider SDK** | `@opencode/ai/providers/openai-compatible` (nativo V2; provider `local`) |
| **Servidor** | LM Studio (puerto 1234) |
| **Proxy** | Python (puerto 4001) |

### 📦 Repos de los modelos (Hugging Face)

Los modelos son **GGUF en cuantización Q6_K** (~7,5 GB) y se descargan de Hugging Face:

| En LM Studio | Repo de Hugging Face |
|--------------|----------------------|
| `qwen3.8-9b` (principal) | `empero-ai/Qwen3.8-9B-Distill-GGUF` |
| `qwen3.5-9b` | `unsloth/Qwen3.5-9B-GGUF` |
| `gemma-4-e4b` | `lmstudio-community/gemma-4-E4B-it-GGUF` |

```bash
lms get empero-ai/Qwen3.8-9B-Distill-GGUF@Q6_K --yes
lms get unsloth/Qwen3.5-9B-GGUF@Q6_K --yes
```

> ⚠️ **Corregido el 22/09/2026:** el PASO 3 de `setup-opencode-completo.sh` usaba > `lms library list` y `lms download` — comandos que **no existen** (los correctos son > `lms ls` y `lms get`) — y el repo `qwen/qwen3.8-9b`, que tampoco es válido. Nunca habría > detectado ni descargado los modelos. Ahora usa el bucle correcto con estos 3 repos. > > ⚠️ El repo `empero-ai/Qwen3.8-9B-Distill` (sin `-GGUF`) solo tiene **safetensors**, que > LM Studio no usa.

---

## Comandos útiles

```bash
# Ver estado de LM Studio
lms status

# Ver procesos cargados
lms ps

# Cargar modelo manualmente
lms load qwen3.8-9b -c 81920 -y

# Descargar modelo
lms unload qwen3.8-9b

# Iniciar/parar servidor
lms server start
lms server stop

# Ver logs del proxy
tail -f /tmp/lmstudio-proxy.log

# Probar conexión
curl http://localhost:1234/v1/models
curl http://localhost:4001/v1/models

# Inicialización completa manual
bash ~/.config/opencode/init-opencode.sh

# Arranque rápido
bash ~/.config/opencode/start-lmstudio.sh
```
