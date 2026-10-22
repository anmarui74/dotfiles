# 🤖 OnlyOffice IA con OpenCode Go
Cómo conectar el **AI agent** («Chat de IA») de ONLYOFFICE Desktop a la suscripción OpenCode Go mediante un proxy local.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 22/10/2026 · rev. 22/10/2026 | Antonio |

> 💡 Convive con el proveedor local `OpenCode Local` (LM Studio, puerto 4001): puedes tener los dos y elegir por conversación.

---

## 📑 Índice
1. [Por qué hace falta un proxy](#por-qué-hace-falta-un-proxy)
2. [Arquitectura](#arquitectura)
3. [Configuración por la interfaz (método oficial)](#configuración-por-la-interfaz-método-oficial)
4. [Requisitos CORS y Private Network Access](#requisitos-cors-y-private-network-access)
5. [Componentes instalados](#componentes-instalados)
6. [Inyección sin interfaz](#inyección-sin-interfaz)
7. [Modelos disponibles](#modelos-disponibles)
8. [Mantenimiento y logs](#mantenimiento-y-logs)
9. [Solución de problemas](#solución-de-problemas)

---

## Por qué hace falta un proxy

El endpoint OpenAI-compatible de OpenCode Go es:

```
https://opencode.ai/inference/go/openai/v1/chat/completions
```

Llamado directamente **sin la cabecera `x-opencode-session`**, devuelve:

```
HTTP 400
{"type":"error","error":{"type":"MissingSessionID",
 "message":"Request is missing x-opencode-session and cannot be routed efficiently."}}
```

La documentación de Go («Where can I use it?») exige que el cliente:

1. Envíe tráfico típico de agente de código.
2. Se identifique con su **propio User-Agent**.
3. Mande un **`x-opencode-session` estable** por conversación (routing y caché).

El AI agent de ONLYOFFICE no permite añadir cabeceras personalizadas, así que la
solución es un **proxy local** que las añade.

> 📌 Nota: la ruta `https://opencode.ai/zen/go/v1` también existe y su `/models`
> responde 200, pero **el chat sigue exigiendo `x-opencode-session`**. No evita el proxy.

---

## Arquitectura

```
ONLYOFFICE Desktop (AI agent / Chat de IA)
        │  OpenAI-compatible, Origin: onlyoffice://plugin
        ▼
http://localhost:4002/v1        ← opencode-go-proxy.py (servicio de usuario)
        │  añade Authorization, x-opencode-session, User-Agent y CORS/PNA
        ▼
https://opencode.ai/inference/go/openai/v1   ← OpenCode Go (suscripción)
```

| Puerto | Proxy | Destino | Uso |
|--------|-------|---------|-----|
| `4001` | `lmstudio-proxy.py` | LM Studio (1234) | OpenCode local y `OpenCode Local` en OnlyOffice |
| `4002` | `opencode-go-proxy.py` | OpenCode Go | `OpenCode Go` en OnlyOffice |

---

## Configuración por la interfaz (método oficial)

Según el Help Center, *Integrating AI* → pestaña **Connection** → **Add provider**.

En ONLYOFFICE Desktop 10 la pestaña se llama **Chat de IA** en la barra lateral
izquierda. Al abrirla por primera vez aparece **«Conecte un modelo de IA»** con el
formulario *Añadir modelo*.

| Campo | Valor |
|-------|-------|
| **Proveedor** | `OpenAI` (o *OpenAI Compatible*, según versión) |
| **Nombre del perfil** | `OpenCode Go` |
| **URL base** | `http://localhost:4002/v1` |
| **Clave de la API** | `opencode-go` (el proxy no la valida; la real vive en el `.env`) |
| **Modelo** | Al desplegar carga la lista del proxy → `glm-5.3-flash` |
| Botón | **Añadir modelo** |

⚠️ El desplegable de **Modelo** solo se rellena si el proxy responde el preflight
CORS correctamente (ver sección siguiente). Si sale vacío o «error al pegar la API
key», es un problema de CORS, no de la clave.

---

## Requisitos CORS y Private Network Access

La wiki oficial («Adding custom providers» → *CORS requirements*) exige que el
endpoint responda al preflight con:

```
Access-Control-Allow-Origin: onlyoffice://plugin   (o *)
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Allow-Methods: GET, POST, OPTIONS
```

Y el preflight debe contestar **200/204**, nunca un redirect.

A eso hay que sumar dos cosas que **no** menciona la wiki pero que bloquean la
petición en la práctica, y que fueron la causa del fallo:

| Requisito | Por qué |
|-----------|---------|
| `Access-Control-Allow-Credentials: true` + **reflejar el `Origin`** | El AI agent hace peticiones con credenciales; con `Allow-Origin: *` el navegador las rechaza |
| `Access-Control-Allow-Private-Network: true` | **Private Network Access**: Chrome/CEF no permite que `onlyoffice://` llame a `localhost` sin este permiso explícito |

**Síntoma típico de esto:** el log del proxy muestra varios `OPTIONS` seguidos y
**ningún `GET`**. El navegador completó el preflight pero descartó la petición real.

Verificación manual:

```bash
curl -i -X OPTIONS 'http://localhost:4002/v1/models' \
  -H 'Origin: onlyoffice://plugin' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: authorization,content-type' \
  -H 'Access-Control-Request-Private-Network: true'
```

Debe devolver `204` con `Allow-Origin: onlyoffice://plugin`,
`Allow-Credentials: true` y `Allow-Private-Network: true`.

---

## Componentes instalados

| Archivo | Función |
|---------|---------|
| `~/.config/opencode/opencode-go-proxy.py` | Proxy OpenAI-compatible con CORS/PNA y cabecera de sesión |
| `~/.config/systemd/user/opencode-go-proxy.service` | Arranque automático en cada sesión |
| `~/.config/opencode/data/onlyoffice-ai/inject-go-provider.py` | Registra el proveedor sin pasar por la interfaz |
| `~/.config/opencode/.env` | Guarda `OPENCODE_GO_ONLYOFFICE_KEY` (clave dedicada) |

La clave del `.env` es **exclusiva para OnlyOffice**. El proxy la lee en orden:
variable de entorno → `.env` → `auth.json` de OpenCode.

---

## Inyección sin interfaz

Útil tras reinstalar o para dejar la configuración lista de serie.

⚠️ **OnlyOffice debe estar CERRADO**: al salir reescribe el LevelDB y perdería el cambio.

```bash
python3 ~/.config/opencode/data/onlyoffice-ai/inject-go-provider.py
python3 ~/.config/opencode/data/onlyoffice-ai/inject-go-provider.py --check
```

Se escribe en la clave `onlyoffice_ai_plugin_storage_key` del LevelDB
(`~/.local/share/onlyoffice/desktopeditors/data/cache/Local Storage/leveldb/000003.log`),
que es donde el AI agent guarda los proveedores (formato `version: 4`).

> ℹ️ Existe otra clave `providers` con un array `[{type,name,key,baseUrl}]`, pero
> **no** es la que usa el chat: en las pruebas permaneció vacía mientras el chat
> funcionaba con la configuración anterior.

Tras inyectar, abre OnlyOffice y comprueba que el proveedor aparece. Si la interfaz
muestra el aviso de conectar, basta con volver a añadirlo desde el formulario.

---

## Modelos disponibles

Solo funcionan con este proxy los modelos servidos por `/openai/v1/chat/completions`.
Los de `/anthropic` y `/responses` (Claude Haiku, Qwen3.8, Grok, GPT Luna, Muse
Spark) **no** valen. El proxy filtra `/v1/models` para ofrecer solo los válidos.

| Modelo | Cuota/mes | Uso recomendado |
|--------|-----------|-----------------|
| `glm-5.3-flash` | 60 $ | ⭐ Chat, resumen y traducción (rápido) |
| `deepseek-v4.1-flash` | 80 $ | Análisis y redacción larga (razona) |
| `kimi-k2.7-code` | 60 $ | Código y fórmulas |
| `mimo-v2.6-flash` | 60 $ | Alternativa rápida |
| `minimax-m3.1-flash-free` | Gratis | Pruebas sin gastar |

> ⚠️ `deepseek-v4.1-flash` emite `reasoning_content` antes del texto: con límites
> de tokens muy bajos puede devolver contenido vacío. Para tareas cortas,
> `glm-5.3-flash`.

---

## Mantenimiento y logs

| Elemento | Ruta / comando |
|----------|----------------|
| Log del proxy | `~/.config/opencode/data/opencode-go-proxy.log` |
| Estado | `systemctl --user status opencode-go-proxy` |
| Reiniciar | `systemctl --user restart opencode-go-proxy` |
| Arranque manual | `python3 ~/.config/opencode/opencode-go-proxy.py 4002` |

El log registra el `Origin`, las cabeceras pedidas y si la petición trae
`Private-Network`, lo que permite diagnosticar CORS al instante.

---

## Solución de problemas

| Síntoma | Causa | Solución |
|---------|-------|----------|
| `MissingSessionID` | Llamada directa a OpenCode Go | Usar el proxy del 4002 |
| Varios `OPTIONS` y ningún `GET` en el log | CORS o Private Network Access | Verificar `Allow-Credentials`, `Origin` reflejado y `Allow-Private-Network` |
| «Error al pegar la API key» | El preflight falla | Es CORS, no la clave: revisar el log del proxy |
| Lista de modelos vacía | Proxy parado o 404 en `/v1/models` | `systemctl --user restart opencode-go-proxy` |
| `401 Unauthorized` | Clave caducada o revocada | Regenerarla en el console y actualizar `.env` |
| Respuesta vacía | Modelo con razonamiento y `max_tokens` bajo | Cambiar a `glm-5.3-flash` |
| El proveedor desaparece | Se inyectó con OnlyOffice abierto | Cerrar OnlyOffice y volver a inyectar |

---

> 📁 `~/.config/opencode/documentacion/10-onlyoffice-ia-opencode-go.md` · `~/.config/opencode/opencode-go-proxy.py` · `~/.config/opencode/data/onlyoffice-ai/inject-go-provider.py`
> 📖 Wiki oficial: [Integrating AI](https://helpcenter.onlyoffice.com/desktop/configuration/desktop-AI-agent.aspx) · [Adding custom providers](https://api.onlyoffice.com/docs/ai/guides/custom-providers)
