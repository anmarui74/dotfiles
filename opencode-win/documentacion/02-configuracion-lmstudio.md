# 🖥️ Configuración de LM Studio + Proxy (Windows)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Proveedor principal local | 10/09/2026 · rev. 10/09/2026 | Antonio |

> Servidor de inferencia local con proxy en puerto 4001 · equivalente Windows del setup Linux

---

## 📑 Índice

1. [Descripción general](#descripción-general)
2. [Proxy de LM Studio (`lmstudio-proxy.py`)](#proxy-de-lm-studio)
3. [Script de arranque (`start-lmstudio.ps1`)](#script-de-arranque)
4. [Lanzador de OpenCode (`ocv`)](#lanzador-de-opencode)
5. [Settings de LM Studio](#settings-de-lm-studio)
6. [Variables de entorno](#variables-de-entorno)
7. [Servicios y tareas programadas](#servicios-y-tareas-programadas)
8. [Flujo completo de arranque](#flujo-completo-de-arranque)
9. [Modelo activo](#modelo-activo)
10. [Comandos útiles](#comandos-útiles)

---

## Descripción general

**LM Studio** es el servidor de inferencia **local** de la configuración de OpenCode en
Windows. Proporciona el modelo `qwen3.8-9b` (Qwen 3.8, 9B, Q6_K) con 80K de contexto.
Se ejecuta como servidor local en el puerto `1234` y se accede a través de un proxy
Python en el puerto `4001`.

### Arquitectura

```
OpenCode → http://localhost:4001/v1 (proxy) → http://localhost:1234/v1 (LM Studio)
```

- **Puerto LM Studio (1234):** API directa del servidor
- **Puerto Proxy (4001):** `lmstudio-proxy.py` — reenvía peticiones y mide tokens/s
- **Provider en OpenCode:** `lmstudio/qwen3.8-9b` con baseURL `http://localhost:4001/v1`

El modelo es de **razonamiento** ("thinking"): genera `reasoning_content` antes del
contenido final. El tool calling funciona nativamente.

---

## Proxy de LM Studio

### Archivo: `C:\Users\evo01\.config\opencode\lmstudio-proxy.py`

### ¿Qué hace?

Proxy HTTP entre OpenCode y LM Studio con **métricas de rendimiento**:

1. Recibe peticiones de OpenCode en el puerto `4001`
2. Las reenvía a LM Studio (`127.0.0.1:1234`)
3. Para respuestas **no streaming**, inyecta `stats.tokens_per_second` (y prompt/completion tokens, latencia)
4. Para respuestas **streaming**, mide TTFT y tokens/s (con `usage` del último chunk si viene)
5. Guarda un histórico en `C:\Users\evo01\.config\opencode\data\metrics.json`
   (últimas 500 peticiones + media de tokens/s)

### Características técnicas

| Aspecto | Detalle |
|---------|---------|
| Lenguaje | Python 3.14 (solo **stdlib**: `http.server`, `urllib`) |
| Sin dependencias | ✅ No necesita `pip install` |
| Endpoint de salud | `GET http://127.0.0.1:4001/health` |
| Timeout upstream | 600 s (generaciones largas) |
| Variable de entorno | `PROXY_PORT`, `LMSTUDIO_UPSTREAM`, `METRICS_EXPORT_PATH`, `ENABLE_METRICS` |

> ⚠️ **Diferencia con Linux:** el proxy de Linux hacía *cambio automático de modelo*
> (descarga/carga vía `lms`). En Windows el proxy es un **reenvío con métricas**; la
> carga del modelo la gestiona `start-lmstudio.ps1` con `lms load`. Es más simple y
> robusto.

---

## Script de arranque

### Archivo: `C:\Users\evo01\.config\opencode\start-lmstudio.ps1`

Equivalente Windows de `start-lmstudio.sh` / `init-opencode.sh`. Es **portable**
(autodetecta `lms.exe` y `python.exe`) e **idempotente** (no reinicia lo que ya está):

| Paso | Qué hace |
|------|----------|
| 1 | `lms server start` si el servidor no responde en el puerto 1234 |
| 2 | `lms load qwen3.8-9b --gpu max -c 80000 -y` si el modelo no está en VRAM |
| 3 | Arranca `lmstudio-proxy.py` (oculto) si el puerto 4001 no responde |

```powershell
# Uso manual
powershell -ExecutionPolicy Bypass -File "C:\Users\evo01\.config\opencode\start-lmstudio.ps1"

# Con parámetros
powershell -ExecutionPolicy Bypass -File "C:\Users\evo01\.config\opencode\start-lmstudio.ps1" `
  -Model "qwen3.8-9b" -ContextLength 80000 -ProxyPort 4001
```

---

## Lanzador de OpenCode

En Windows no hay scripts `.sh` ni symlinks: los lanzadores son **funciones del perfil
de PowerShell** (`C:\Users\evo01\OneDrive\Documentos\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`).

| Comando | Qué hace |
|---------|----------|
| `ocv` | Ejecuta `start-lmstudio.ps1` y abre OpenCode con `OPENCODE_CONFIG=opencode-local.json` (agente `local`, todos los MCPs) |
| `ocv-local` | Igual, pero con `opencode-local-min.json` (agente `local`, solo MCPs `fetch`, `filesystem`, `memory`) |
| `ocv-cloud` | Abre OpenCode con la config global (agente `cloud`, sin LM Studio) |
| `ocv-status` | Muestra estado del servidor (1234), modelo en VRAM y proxy (4001) |

`ocv` restaura la variable `OPENCODE_CONFIG` al salir, para no dejar la sesión "pegada"
al perfil local.

> ⚠️ **No aplica en Windows:** `start-opencode-server.sh`, `start-opencode.sh` y el
> symlink `~/.local/bin/opencode` no existen. El `opencode` real se instala global por
> npm (`opencode-ai`).

---

## Settings de LM Studio

En Windows no se modifica `~/.lmstudio/settings.json` desde el instalador. El contexto
se fija **explícitamente** en la carga:

```powershell
lms load qwen3.8-9b --gpu max -c 80000 -y
```

| Parámetro | Valor |
|-----------|-------|
| Contexto cargado | 80.000 tokens (`lms ps` muestra `80128`) |
| GPU | `--gpu max` (RTX 4070 Ti SUPER, 16 GB VRAM) |
| Modelo en disco | `C:\Users\evo01\.lmstudio\models\Qwen\Qwen3.8-9B\Qwen3.8-9B-Q6_K.gguf` |

---

## Variables de entorno

No hay variables específicas de LM Studio: el proxy y el modelo se configuran en
`opencode-local.json`:

```json
"lmstudio": {
  "npm": "@ai-sdk/openai-compatible",
  "name": "LM Studio (local, proxy 4001)",
  "options": { "baseURL": "http://127.0.0.1:4001/v1" },
  "models": {
    "qwen3.8-9b": {
      "name": "Qwen3.8-9B Q6_K (local)",
      "reasoning": true,
      "tool_call": true,
      "temperature": true,
      "limit": { "context": 80000, "output": 32000 }
    }
  }
}
```

---

## Servicios y tareas programadas

> ⚠️ **No aplica en Windows (systemd):** los servicios `init-opencode.service` y los
> timers de Linux no existen. La carga de LM Studio + modelo + proxy ocurre **al
> ejecutar `ocv`** (función del perfil), no al iniciar sesión.

Si se quiere automatizar (backup diario, verificación NVIDIA), el instalador soporta la
creación de tareas en el **Programador de tareas** de Windows:

```powershell
# Durante la instalación
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\instalar-opencode-win.ps1" -WithTasks
```

---

## Flujo completo de arranque

```
1. Abrir una ventana NUEVA de PowerShell y escribir: ocv
   ↓
2. Función ocv del perfil:
   ├── 2.1. start-lmstudio.ps1
   │        ├── lms server start (puerto 1234)
   │        ├── lms load qwen3.8-9b --gpu max -c 80000
   │        └── lmstudio-proxy.py (puerto 4001, oculto)
   └── 2.2. $env:OPENCODE_CONFIG = opencode-local.json
   ↓
3. opencode (con el perfil local y el agente 'local')
   ↓
4. OpenCode → http://localhost:4001/v1 → Proxy → http://localhost:1234/v1 → Modelo
```

---

## Modelo activo

| Propiedad | Valor |
|-----------|-------|
| **Modelo** | `qwen3.8-9b` (Qwen 3.8 - 9B parámetros, Q6_K, 7,04 GB) |
| **Contexto** | 80.000 tokens |
| **Output máximo** | 32.000 tokens (config) |
| **Razonamiento** | ✅ Sí (`reasoning_content`) |
| **Tool calling** | ✅ Sí |
| **Provider SDK** | `@ai-sdk/openai-compatible` |
| **Servidor** | LM Studio (puerto 1234) |
| **Proxy** | Python (puerto 4001) |
| **Velocidad medida** | ~100-120 tok/s en RTX 4070 Ti SUPER |

---

## Comandos útiles

```powershell
# Ver estado de LM Studio (CLI en C:\Users\evo01\.lmstudio\bin\lms.exe)
lms server status
lms ps

# Cargar / descargar el modelo manualmente
lms load qwen3.8-9b --gpu max -c 80000 -y
lms unload qwen3.8-9b

# Iniciar / parar servidor
lms server start
lms server stop

# Probar conexión
Invoke-RestMethod -Uri "http://127.0.0.1:1234/v1/models"
Invoke-RestMethod -Uri "http://127.0.0.1:4001/v1/models"
Invoke-RestMethod -Uri "http://127.0.0.1:4001/health"

# Ver métricas del proxy
Get-Content "C:\Users\evo01\.config\opencode\data\metrics.json" | ConvertFrom-Json

# Arranque completo
ocv
ocv-status

# Liberar VRAM
lms unload --all
```

---

> 📁 `C:\Users\evo01\.config\opencode\lmstudio-proxy.py` · `start-lmstudio.ps1` · `opencode-local.json`
> 📁 Backup: `D:\Linux\Config\opencode-win\config\`