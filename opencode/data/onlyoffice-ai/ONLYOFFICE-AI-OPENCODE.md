# 🤖 OnlyOffice IA + OpenCode Local (proveedor OpenAI-compatible)

> **Fecha:** 09/08/2026
> **Autor:** Antonio (configurado por OpenCode)
> **Ubicación del backup:** `~/Config/opencode/data/onlyoffice-ai/`

---

## 📌 Resumen

Integración del **plugin IA de ONLYOFFICE Desktop Editors** con **opencode local**
(modelo Qwen 3.5 Q6_K) usando el endpoint OpenAI-compatible que opencode expone
a través de su proxy en el puerto **4001**.

De esta forma, el asistente de IA de OnlyOffice (chat, resumen, traducción,
análisis de texto, ayuda con código...) usa el modelo local, **sin depender de
servicios en la nube ni enviar datos fuera del equipo**.

---

## 🔧 Datos técnicos

| Parámetro | Valor |
|---|---|
| **Proveedor (nombre)** | `OpenCode Local` |
| **URL base** | `http://localhost:4001/v1` |
| **Modelo** | `models-qwen3.5-9b` |
| **API key** | `lm-studio` (cualquiera; el proxy no la valida) |
| **Capacidades** | 511 (todas: chat, resumen, traducción, análisis, código, etc.) |
| **Aplicación** | ONLYOFFICE Desktop Editors |
| **Plugin IA** | `asc.{9DC93CDB-B576-4F0C-B55E-FCC9C48DD007}` (versión 3.2.2) |

### Arquitectura

```
OnlyOffice (plugin IA)
        │  peticiones OpenAI-compatible
        ▼
http://localhost:4001/v1  ← lmstudio-proxy.py (proxy opencode)
        │  reenvía
        ▼
http://localhost:1234     ← LM Studio server (modelo Qwen 3.5 Q6_K)
```

---

## 📋 Pasos seguidos (configuración realizada)

### 1. Verificación del backend de opencode

Comprobado que el proxy responde y el modelo está cargado:

```bash
curl -s http://localhost:4001/v1/models          # → lista modelos (OK)
curl -s http://localhost:4001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"models-qwen3.5-9b","messages":[{"role":"user","content":"di hola"}]}'
# → {"choices":[{"message":{"content":"¡Hola!"}}]}  (OK)
```

### 2. Localización del almacenamiento del plugin IA

El plugin IA guarda su configuración en el `localStorage` interno de OnlyOffice,
que en Linux se encuentra en un **LevelDB**:

```
~/.local/share/onlyoffice/desktopeditors/data/cache/Local Storage/leveldb/000003.log
```

- **Clave:** `_onlyoffice://plugin\x00\x01onlyoffice_ai_plugin_storage_key`
- **Valor:** `\x01` + JSON (el `\x01` es el marcador de codificación UTF-8 de Chromium)

### 3. Backup de seguridad previo

Antes de tocar nada se copió el almacenamiento completo:

```bash
cp -r ~/.local/share/onlyoffice/desktopeditors/data/cache/Local\ Storage/ \
      ~/LocalStorage-backup-<fecha>/
```

### 4. Análisis del formato LevelDB

Se escribió un parser en Python (sin dependencias externas) para leer los
records del log de LevelDB:
- Checksum **CRC32C** enmascarado (`masked crc32c + 0xa282ead8`)
- Cabecera: checksum(4) + longitud(2) + tipo(1)
- Payload: WriteBatch con `sequence(8) + count(4) + entradas(key/value con varint32)`

### 5. Inyección del proveedor

Se añadió un **nuevo record** (`Put`) al final del log con una `sequence` mayor
que las existentes (el último `Put` de una clave es el que gana al abrir):

```json
"OpenCode Local": {
  "name": "OpenCode Local",
  "url": "http://localhost:4001/v1",
  "key": "lm-studio",
  "models": [{ "id": "models-qwen3.5-9b", "endpoints": [1], ... }]
}
```

Y el modelo registrado para todas las tareas:

```json
{
  "capabilities": 511,
  "provider": "OpenCode Local",
  "name": "OpenCode Local [models-qwen3.5-9b]",
  "id": "models-qwen3.5-9b"
}
```

### 6. Verificación final

- Checksum del record nuevo: **OK**
- Relectura del log tras abrir OnlyOffice: la configuración persiste ✅
- Resultado: el proveedor aparece en **IA → Ajustes → Editar modelos de IA**

---

## 🖱️ Método alternativo (manual, sin tocar LevelDB)

Si en el futuro se quiere añadir otro proveedor por la interfaz:

1. Abrir un documento en OnlyOffice
2. Pestaña **IA** → **Ajustes** → **Editar modelos de IA**
3. **+** → rellenar URL `http://localhost:4001/v1`, modelo `models-qwen3.5-9b`,
   API key `lm-studio`
4. Marcar las tareas deseadas → **OK**

### Archivo de proveedor personalizado (JS)

También se puede subir un archivo JS (método oficial de ONLYOFFICE para
proveedores personalizados) — ver `opencode-provider.js` en esta carpeta:

```js
"use strict";

class Provider extends AI.Provider {
    constructor() {
        super("OpenCode Local", "http://localhost:4001", "lm-studio", "v1");
    }
}
```

Ruta de subida: **IA → Ajustes → Editar modelos de IA → + → Custom providers → +**

---

## ♻️ Restauración de esta configuración

Hay **tres niveles** de restauración, de más a menos fino:

### Opción A — Script de inyección (recomendada)

```bash
# Requisito: cerrar OnlyOffice primero
python3 ~/Config/opencode/data/onlyoffice-ai/inject-provider.py
# Comprobar sin modificar:
python3 ~/Config/opencode/data/onlyoffice-ai/inject-provider.py --check
```

Reconstruye el proveedor y el modelo sobre la configuración existente o la crea
desde cero si no hay ninguna.

### Opción B — Copia del LevelDB completo (snapshot)

Restaurar el directorio completo del snapshot:

```bash
# SoloOffice cerrado:
cp -r ~/Config/opencode/data/onlyoffice-ai/localstorage-snapshot/leveldb/* \
      ~/.local/share/onlyoffice/desktopeditors/data/cache/Local\ Storage/leveldb/
```

⚠️ Restaura también el resto de claves del localStorage de esa fecha.

### Opción C — Configuración JSON legible

El archivo `onlyoffice-ai-config.json` contiene la configuración completa
(15 proveedores + modelo OpenCode Local) por si se necesita inspeccionar,
editar o migrar.

---

## 🚀 Instalación automática (setup-opencode-completo.sh)

El instalador completo `setup-opencode-completo.sh` incluye el **PASO 19**
que automatiza todo este proceso:

1. **Instala** OnlyOffice Desktop Editors desde **pacman** (repos extra):
   `pkexec pacman -S --needed --noconfirm onlyoffice-desktopeditors`
2. **Embe** el script `inject-provider.py` y este documento en
   `~/.config/opencode/data/onlyoffice-ai/`
3. **Inicializa el perfil** de OnlyOffice (primera ejecución breve) si no
   existe el almacenamiento del plugin IA
4. **Inyecta el proveedor** "OpenCode Local" automáticamente y lo verifica
   con `--check`

Al reinstalar el sistema desde cero, basta con ejecutar el setup y la
integración IA de OnlyOffice queda lista sin intervención manual.

---

## 📁 Archivos incluidos en este backup

| Archivo | Descripción |
|---|---|
| `ONLYOFFICE-AI-OPENCODE.md` | Este documento |
| `onlyoffice-ai-config.json` | Configuración completa del plugin IA (legible) |
| `inject-provider.py` | Script de restauración del proveedor (autocontenido) |
| `opencode-provider.js` | Archivo JS del proveedor (método manual oficial) |
| `localstorage-snapshot/` | Snapshot del LevelDB del localStorage (estado exacto) |

---

## ⚠️ Consideraciones

- **Modelo en VRAM:** para que OnlyOffice responda, el modelo debe estar cargado
  (arrancar con `opencode` u `ocv`, o `bash ~/.config/opencode/start-lmstudio.sh`).
  Si no, LM Studio devuelve error de modelo no cargado.
- **Solo local:** el proxy escucha en `127.0.0.1:4001`, por lo que esta
  configuración funciona únicamente en este equipo.
- **Document Server (Docker):** si se usara OnlyOffice en Docker, habría que:
  1. Hacer que el proxy escuche en `0.0.0.0`
  2. Usar `http://host.docker.internal:4001/v1` (o IP del host) como URL
  3. Añadir cabeceras CORS al proxy (`Access-Control-Allow-Origin`)
- **Privacidad:** al ser 100% local, los documentos no salen del equipo. 🔒
- **Seguridad:** el backup de esta carpeta debe incluirse en cualquier copia
  general de `~/Config/opencode/`.
