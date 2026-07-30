# 🖥️ Configuración de LM Studio + Proxy

> **Fecha:** 26/07/2026 | **Usuario:** Antonio

---

## Índice

1. [Descripción general](#descripción-general)
2. [Proxy de LM Studio (`lmstudio-proxy.py`)](#proxy-de-lm-studio)
3. [Script de inicialización (`init-opencode.sh`)](#script-de-inicialización)
4. [Script de arranque rápido (`start-lmstudio.sh`)](#script-de-arranque-rápido)
5. [Lanzador de OpenCode (`start-opencode.sh`)](#lanzador-de-opencode)
6. [Settings de LM Studio](#settings-de-lm-studio)
7. [Variables de entorno](#variables-de-entorno)
8. [Servicios systemd](#servicios-systemd)
9. [Flujo completo de arranque](#flujo-completo-de-arranque)
10. [Modelo activo](#modelo-activo)

---

## Descripción general

**LM Studio** es el servidor de inferencia **principal** y **activo** en la configuración de OpenCode. Proporciona el modelo `qwen/qwen3.5-9b` con 80K de contexto. Se ejecuta como servidor local en el puerto `1234` y se accede a través de un proxy en el puerto `4001`.

### Arquitectura

```
OpenCode → http://localhost:4001/v1 (proxy) → http://localhost:1234/v1 (LM Studio)
```

- **Puerto LM Studio (1234):** API directa del servidor
- **Puerto Proxy (4001):** Proxy Python que gestiona carga/descarga automática de modelos
- **Provider en OpenCode:** `lmstudio/qwen/qwen3.5-9b` con baseURL `http://localhost:4001/v1`

---

## Proxy de LM Studio

### Archivo: `~/.config/opencode/lmstudio-proxy.py`

### ¿Qué hace?

Proxy HTTP entre OpenCode y LM Studio con **cambio automático de modelo**:

1. Recibe peticiones de OpenCode en el puerto `4001`
2. Si el modelo solicitado **no está cargado**, lo descarga automáticamente y carga el nuevo
3. Si el modelo **ya está cargado**, reenvía la petición directamente
4. Aplica un **workaround para Qwen 3.5**: si no hay mensaje con `role: 'user'`, añade uno de continuación
5. Maneja timeouts largos (600 segundos) para generaciones extensas

### Código completo comentado

```python
LM = "http://localhost:1234"  # LM Studio API
PORT = 4001                    # Puerto del proxy
LMS = "/home/antonio/.lmstudio/bin/lms"  # CLI de LM Studio

_loading = False  # Estado de carga del modelo
_load_lock = threading.Lock()  # Evita cargas concurrentes
```

### Función `_do_switch(target)` - Cambio de modelo

```python
# 1. Descarga cualquier modelo que no sea el target (excepto embeddings)
for m in _get_loaded():
    if m != target and "embedding" not in m.lower():
        subprocess.run([LMS, "unload", m], ...)

# 2. Carga el modelo solicitado
r = subprocess.run([LMS, "load", target, "-y"], capture_output=True, timeout=180)
```

### Workaround para Qwen 3.5

```python
# Qwen 3.5 rechaza peticiones sin mensaje con role='user'
msgs = body.get('messages', [])
if not any(m.get('role') == 'user' for m in msgs):
    body['messages'].append({
        'role': 'user',
        'content': '(continuación)'
    })
```

### Respuesta 503 durante la carga

Si el modelo no está cargado, el proxy responde con `503` y un mensaje como:
```json
{"error": "Cargando qwen/qwen3.5-9b... (intento 1)"}
```
OpenCode reintenta automáticamente.

---

## Script de inicialización

### Archivo: `~/.config/opencode/init-opencode.sh`

Script **completo** que se ejecuta al iniciar sesión (vía systemd). Realiza 5 pasos:

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
$LMSTUDIO_BIN load "qwen/qwen3.5-9b" -c 81920 -y
```

Verifica que el contexto aplicado sea `81920`. Si no, reintenta.
Usa `lms ps` para comprobar el contexto actual.

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
# 1. Arrancar servidor si no está
$LMSTUDIO_BIN server start

# 2. Descargar modelo actual y cargar con 80K
$LMSTUDIO_BIN unload "qwen/qwen3.5-9b"
$LMSTUDIO_BIN load "qwen/qwen3.5-9b" -c 81920 -y

# 3. Iniciar proxy si no está corriendo
nohup python3 lmstudio-proxy.py 4001 > /tmp/lmstudio-proxy.log 2>&1 &
```

---

## Lanzador de OpenCode

### Archivo: `~/.config/opencode/start-opencode.sh`

Script **interactivo** para lanzar OpenCode:

1. Verifica que LM Studio responda en el puerto `1234`
2. Si no, lo arranca con `lms server start` (espera hasta 15 segundos)
3. Ejecuta OpenCode con `exec "${REAL_OPENCODE}" "$@"`

Útil para lanzar OpenCode desde terminal con acceso directo.

---

## Settings de LM Studio

### Archivo: `~/.config/opencode/settings.lmstudio.json`

Configuración persistente de LM Studio:

| Parámetro | Valor |
|-----------|-------|
| `language` | `es` (español) |
| `defaultContextLength` | `81920` (tokens) |
| `devMode` | Habilitado |
| `chatConfig` | Configuración de chat por defecto |

La ventana de 80K de contexto permite que el modelo maneje conversaciones largas y archivos grandes sin perder el hilo.

---

## Variables de entorno

Del archivo `.env`:

```bash
# No hay variables específicas de LM Studio en .env
# El proxy se configura directamente en opencode.json:
# "options": {"baseURL": "http://localhost:4001/v1"}
```

El provider en `opencode.json`:

```json
"lmstudio": {
  "npm": "@ai-sdk/openai-compatible",
  "name": "Qwen 3.5",
  "model": "qwen/qwen3.5-9b",
  "options": {"baseURL": "http://localhost:4001/v1"},
  "models": {
    "qwen/qwen3.5-9b": {
      "name": "Qwen 3.5 - Tool Calling Excellence",
      "tools": true,
      "limit": {"context": 81920, "output": 8192}
    }
  }
}
```

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

---

## Flujo completo de arranque

```
1. Inicio de sesión
   ↓
2. systemd --user → init-opencode.service
   ↓
3. init-opencode.sh:
   ├── 3.1. lms server start (puerto 1234)
   ├── 3.2. lms load qwen/qwen3.5-9b -c 81920
   ├── 3.3. lmstudio-proxy.py (puerto 4001)
   ├── 3.4. Fijar contexto en settings.json
   └── 3.5. Verificaciones (modelos, memoria, hardware, .env)
   ↓
4. OpenCode listo para usar
   ↓
5. OpenCode → http://localhost:4001/v1 → Proxy → http://localhost:1234/v1 → Modelo
```

---

## Modelo activo

| Propiedad | Valor |
|-----------|-------|
| **Modelo** | `qwen/qwen3.5-9b` (Qwen 3.5 - 9B parámetros) |
| **Contexto** | 81.920 tokens |
| **Output máximo** | 8.192 tokens |
| **Tool calling** | ✅ Sí |
| **Provider SDK** | `@ai-sdk/openai-compatible` v3.0.7 |
| **Servidor** | LM Studio (puerto 1234) |
| **Proxy** | Python (puerto 4001) |

---

## Comandos útiles

```bash
# Ver estado de LM Studio
lms status

# Ver procesos cargados
lms ps

# Cargar modelo manualmente
lms load qwen/qwen3.5-9b -c 81920 -y

# Descargar modelo
lms unload qwen/qwen3.5-9b

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
