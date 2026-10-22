# 🤖 OnlyOffice IA + OpenCode (proveedores local y nube)

> **Fecha:** 09/08/2026 · **rev.:** 22/10/2026
> **Autor:** Antonio (configurado por OpenCode)
> **Ubicación del backup:** `~/Config/opencode/data/onlyoffice-ai/`

---

## 📌 Resumen

Integración del **AI agent / Chat de IA de ONLYOFFICE Desktop Editors** con dos
proveedores OpenAI-compatible servidos por OpenCode:

| Proveedor en OnlyOffice | Origen | Puerto | Privacidad |
|---|---|---|---|
| `OpenCode Local` | LM Studio (Qwen 3.8 9B) | `4001` | 100 % local 🔒 |
| `OpenCode Go` | Suscripción OpenCode Go (nube) | `4002` | Datos al proveedor ☁️ |

Ambos conviven: puedes elegir el modelo por conversación según necesites
privacidad o potencia.

> 📖 **Detalle completo de OpenCode Go:** `documentacion/10-onlyoffice-ia-opencode-go.md`

---

## 🔧 Datos técnicos

| Parámetro | Local | OpenCode Go |
|---|---|---|
| **Proveedor (nombre)** | `OpenCode Local` | `OpenCode Go` |
| **URL base** | `http://localhost:4001/v1` | `http://localhost:4002/v1` |
| **Modelos** | `qwen3.8-9b` | `glm-5.3-flash`, `deepseek-v4.1-flash`, `kimi-k2.7-code`, `mimo-v2.6-flash`, `minimax-m3.1-flash-free` |
| **API key en OnlyOffice** | `lm-studio` (no se valida) | `opencode-go` (no se valida) |
| **Clave real** | ninguna (LM Studio) | `OPENCODE_GO_ONLYOFFICE_KEY` en `.env` |
| **Capacidades** | 511 (todas) | 511 (todas) |
| **Servicio** | dentro de `start-lmstudio.sh` | `opencode-go-proxy.service` |

| Dato | Valor |
|---|---|
| **Aplicación** | ONLYOFFICE Desktop Editors 10.0.0 (`onlyoffice-bin`) |
| **Plugin IA** | `asc.{9DC93CDB-B576-4F0C-B55E-FCC9C48DD007}` (v3.2.99) |
| **Dónde se configura** | Barra lateral → **Chat de IA** → Ajustes → **Connection / Add provider** |
| **Dónde persiste** | `onlyoffice_ai_plugin_storage_key` (LevelDB del localStorage, formato v4) |

### Arquitectura

```
OnlyOffice (AI agent / Chat de IA)
        │  OpenAI-compatible + CORS + Private Network Access
        ├──────────────► http://localhost:4001/v1  ← lmstudio-proxy.py
        │                       └──► LM Studio :1234 (Qwen 3.8 9B)
        └──────────────► http://localhost:4002/v1  ← opencode-go-proxy.py
                                └──► opencode.ai/inference/go/openai/v1
```

---

## 📋 Pasos seguidos

### 1. Verificación de los backends

```bash
curl -s http://localhost:4001/v1/models          # LM Studio
curl -s http://localhost:4002/v1/models          # OpenCode Go (filtrado)
```

### 2. Localización del almacenamiento

El AI agent guarda su configuración en el `localStorage` interno de OnlyOffice,
un **LevelDB**:

```
~/.local/share/onlyoffice/desktopeditors/data/cache/Local Storage/leveldb/000003.log
```

- **Clave:** `_onlyoffice://plugin\x00\x01onlyoffice_ai_plugin_storage_key`
- **Valor:** `\x01` + JSON (marcador de codificación UTF-8 de Chromium)

### 3. Backup de seguridad previo

```bash
cp -r ~/.local/share/onlyoffice/desktopeditors/data/cache/Local\ Storage/leveldb \
      ~/Config/opencode/data/onlyoffice-ai/localstorage-snapshot/
```

### 4. Inyección de los proveedores

| Script | Proveedor | Cuándo usarlo |
|---|---|---|
| `inject-provider.py` | `OpenCode Local` (:4001) | Tras reinstalar / perfil nuevo |
| `inject-go-provider.py` | `OpenCode Go` (:4002) | Tras reinstalar / perfil nuevo |

⚠️ **OnlyOffice debe estar cerrado** al ejecutarlos.

### 5. Verificación final

```bash
python3 inject-provider.py --check
python3 inject-go-provider.py --check
```

---

## 🖱️ Configuración por la interfaz (método oficial)

Válido para ambos proveedores. En ONLYOFFICE Desktop 10 la entrada es la barra
lateral → **Chat de IA**; si no hay proveedor aparece «Conecte un modelo de IA».

1. **Proveedor:** `OpenAI` (o *OpenAI Compatible*)
2. **Nombre del perfil:** `OpenCode Local` u `OpenCode Go`
3. **URL base:** `http://localhost:4001/v1` o `http://localhost:4002/v1`
4. **Clave de la API:** `lm-studio` u `opencode-go` (los proxies no las validan)
5. **Modelo:** desplegar y elegir (la lista viene de `/v1/models`)
6. **Añadir modelo**

> ⚠️ Si el desplegable de modelo sale vacío o da «error al pegar la API key», es
> **CORS / Private Network Access**, no la clave. Ver el manual 10.

### Archivo de proveedor personalizado (JS)

Método oficial de ONLYOFFICE para proveedores personalizados — ver
`opencode-provider.js`:

```js
"use strict";

class Provider extends AI.Provider {
    constructor() {
        super("OpenCode Local", "http://localhost:4001", "lm-studio", "v1");
    }
}
```

Ruta: pestaña **IA** del editor → Ajustes → Editar modelos de IA → lápiz →
**Custom providers** → **+** → subir el JS.

---

## ♻️ Restauración de esta configuración

### Opción A — Script de inyección (recomendada)

```bash
# Con OnlyOffice cerrado
python3 ~/Config/opencode/data/onlyoffice-ai/inject-provider.py
python3 ~/Config/opencode/data/onlyoffice-ai/inject-go-provider.py
```

### Opción B — Copia del LevelDB completo (snapshot)

```bash
# Con OnlyOffice cerrado
cp -r ~/Config/opencode/data/onlyoffice-ai/localstorage-snapshot/leveldb/* \
      ~/.local/share/onlyoffice/desktopeditors/data/cache/Local\ Storage/leveldb/
```

⚠️ Restaura también el resto de claves de esa fecha.

### Opción C — Configuración JSON legible

`onlyoffice-ai-config.json` contiene la configuración completa (proveedores y
modelos) del último volcado, para inspeccionar, editar o migrar.

---

## 🚀 Instalación automática (setup-opencode-completo.sh)

El **PASO 19** del instalador automatiza todo:

1. Instala OnlyOffice desde pacman: `pkexec pacman -S --needed onlyoffice-desktopeditors`
2. Embebe `inject-provider.py`, `inject-go-provider.py` y este documento
3. Inicializa el perfil de OnlyOffice si no existe
4. Inyecta **OpenCode Local** (19.5) y **OpenCode Go** (19.6), y verifica ambos
5. Instala y habilita `opencode-go-proxy.service`

Tras reinstalar desde cero, la integración queda lista sin pasos manuales.

---

## 📁 Archivos incluidos en este backup

| Archivo | Descripción |
|---|---|
| `ONLYOFFICE-AI-OPENCODE.md` | Este documento |
| `onlyoffice-ai-config.json` | Configuración completa del plugin (legible) |
| `inject-provider.py` | Inyecta el proveedor `OpenCode Local` |
| `inject-go-provider.py` | Inyecta el proveedor `OpenCode Go` |
| `opencode-provider.js` | Proveedor personalizado (método manual oficial) |
| `localstorage-snapshot/` | Snapshot del LevelDB (estado exacto) |

---

## ⚠️ Consideraciones

- **OpenCode Local:** el modelo debe estar cargado en VRAM (abrir `opencode`/`ocv`
  o `bash ~/.config/opencode/start-lmstudio.sh`).
- **OpenCode Go:** el proxy del 4002 arranca solo con la sesión
  (`opencode-go-proxy.service`); no requiere abrir OpenCode.
- **Solo local:** ambos proxies escuchan en `127.0.0.1`, así que esta configuración
  funciona únicamente en este equipo.
- **Document Server (Docker):** habría que escuchar en `0.0.0.0`, usar
  `http://host.docker.internal:4001|4002/v1` y permitir el origen del Document
  Server en CORS.
- **`deepseek-v4.1-flash` razona antes de responder**: con límites de tokens bajos
  puede devolver texto vacío. Para tareas cortas, `glm-5.3-flash`.

---

> 📁 `~/.config/opencode/data/onlyoffice-ai/` · 📖 `documentacion/10-onlyoffice-ia-opencode-go.md` · 🖥️ [Integrating AI (wiki)](https://helpcenter.onlyoffice.com/desktop/configuration/desktop-AI-agent.aspx)
