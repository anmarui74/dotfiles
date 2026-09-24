# 🎤 Configuración Completa de Voz (STT → OpenCode → TTS) en Windows
Stack de voz en Windows con GPU: STT whisper.cpp (CUDA) → OpenCode → TTS Kokoro (CUDA) con servidor persistente

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Implementado y optimizado (GPU) | 10/09/2026 · rev. 24/09/2026 | Antonio |

> ✅ **Operativo en OpenCode V2 (2.0.16).** STT con **whisper.cpp build CUDA** (RTX 4070 Ti SUPER, ~12-15x tiempo real) y TTS con **Kokoro v1.0 ONNX en GPU**. Desde el **24/09/2026** el TTS usa un **servidor persistente** que mantiene el modelo cargado y reduce cada locución de ~2,1 s a ~0,5-1,5 s.

> 📁 Scripts: `C:\Users\evo01\.config\opencode\voice\` (`stt.ps1`, `speak.ps1`, `kokoro-tts.py`, `kokoro-server.py`, `tts-server.ps1`) · Plugin: `C:\Users\evo01\.config\opencode\opencode-voice-modified\` · Instalación: `D:\Linux\Config\opencode-win\scripts\setup-voz.ps1`

---

## 📑 Índice

1. [Implementación en Windows (resumen)](#implementación-en-windows-resumen)
2. [Plugin de voz](#plugin-de-voz)
3. [STT - Speech-to-Text](#stt---speech-to-text)
4. [TTS - Text-to-Speech](#tts---text-to-speech)
5. [Servidor TTS persistente](#servidor-tts-persistente)
6. [Configuración en `cli.json`](#configuración-en-clijson)
7. [LLM Client (normalización)](#llm-client-normalización)
8. [Instalación del stack](#instalación-del-stack)
9. [Comandos y atajos](#comandos-y-atajos)
10. [Personalización](#personalización)
11. [Comandos útiles](#comandos-útiles)

---

## ✅ Implementación en Windows (resumen)

| Función | Implementación Windows | Ruta / detalle |
|---------|------------------------|----------------|
| 🎤 **STT** | `ffmpeg` (DirectShow) + **whisper.cpp build CUDA** | `voice\stt.ps1` · modelo `ggml-large-v3-turbo-q5_0.bin` en `~\.local\models\whisper\` |
| 🔊 **TTS** | **Kokoro v1.0 ONNX en GPU** (onnxruntime-gpu 1.26 + CUDA 12) | `voice\speak.ps1` + `voice\kokoro-server.py` |
| 🚀 **Servidor TTS** | Proceso Python persistente (HTTP en `127.0.0.1:4210`) | `voice\kokoro-server.py` · gestión con `voice\tts-server.ps1` |
| 🗣️ Reserva TTS | edge-tts / SAPI5 | `speak.ps1 -Engine edge` / `-Engine sapi` |
| 🧩 **Plugin** | `opencode-voice-modified` con entrada V2 (`tui.js`) | `~\.config\opencode\opencode-voice-modified\` · registrado en `cli.json` |
| 📦 Instalación | `setup-voz.ps1` (o `instalar-opencode-win.ps1 -WithVoice`) | `D:\Linux\Config\opencode-win\scripts\setup-voz.ps1` |

**Atajos (plugin):** `Ctrl+R` grabar/transcribir · `Leader+R` grabar + enviar · `Leader+S` leer última respuesta · `Leader+V` TTS on/off · **`Ctrl+Q` parar**.

**Comportamiento del TTS:**
- Se locutan **párrafos/líneas por separado** con pausa entre ellos (y entre celdas de tabla y tras `: ; —`).
- Se **filtran emojis, ANSI, dibujos de caja y markdown** antes de sintetizar.
- Una locución nueva **corta** la anterior (no se solapan).
- Pausas configurables: `SPEAK_PAUSE` (0,8 s), `SPEAK_PAUSE_SENT` (0,35 s), `SPEAK_PAUSE_CLAUSE` (0,3 s).

**Rendimiento medido (RTX 4070 Ti SUPER, 24/09/2026):**

| Tarea | Tiempo |
|-------|--------|
| Transcripción whisper (GPU) | ~0,8 s por audio |
| Transcripción whisper (CPU, sin GPU) | ~10,5 s (**12x más lento**) |
| Locución TTS — servidor (texto corto) | ~0,5 s |
| Locución TTS — servidor (texto largo) | ~1,3-1,5 s |
| Locución TTS — arranque en frío (antes) | ~2,1 s |

---

## 🧩 Plugin de voz

### Archivo: `C:\Users\evo01\.config\opencode\opencode-voice-modified\`

Estructura (portada a Windows y adaptada a **OpenCode V2**):

```
opencode-voice-modified/
├── index.js          # Entrada V1 (legacy, conservada)
├── tui.js            # Entrada V2 (@opencode/plugin/tui) ← la que usa OpenCode 2
├── package.json      # exports: "." → index.js · "./tui" → tui.js
├── README.md
├── LICENSE           # MIT
├── PORT-WINDOWS.md   # Notas del port a Windows
└── lib/
    ├── stt.js        # Speech-to-Text (ffmpeg + whisper.cpp)
    ├── tts.js        # Text-to-Speech (Kokoro vía speak.ps1)
    ├── llm-client.js # Cliente LLM para normalización
    ├── session.js    # Gestión de sesiones
    └── logger.js     # Logger
```

### `package.json`

```json
{
  "name": "@renjfk/opencode-voice",
  "version": "0.6.0",
  "description": "Speech-to-text and text-to-speech for OpenCode (entrada V2 en tui.js).",
  "type": "module",
  "main": "index.js",
  "exports": {
    ".": { "import": "./index.js" },
    "./tui": { "import": "./tui.js" }
  }
}
```

### `tui.js` — puente V1 → V2

OpenCode V2 cambió la API de plugins. `tui.js` expone a `lib/stt.js` y `lib/tts.js`
la misma superficie que esperaban de la V1 (`api.kv`, `api.ui`, `api.event`,
`api.route`, `api.state.session`, `api.client`), sin tocar la lógica de `lib/`.

Adaptaciones específicas de V2 (verificadas con el binario 2.0.16):

| Necesidad | V1 (lib/) | V2 (evento real del servidor) |
|-----------|-----------|-------------------------------|
| Inicio de ejecución | `session.status` busy | `session.execution.started` |
| Fin de ejecución | `session.idle` | `session.execution.succeeded` / `.failed` / `.interrupted` |
| Texto en streaming | `message.part.updated` | `session.text.started` / `.delta` / `.ended` |
| Preguntas | `question.asked` | `form.created` |
| Formato de mensajes | `role` + `parts[]` | `type` + `content[]` |

> ⚠️ Los eventos de texto en V2 son `session.text.*` **sin** el prefijo `next.` (el
> binario muestra internamente `session.next.text.*`, pero el servidor emite sin `next.`).

> 🐛 **Fix 24/09/2026:** el plugin usaba los nombres/formatos V1, por lo que el TTS
> automático no se disparaba (la respuesta se veía en pantalla pero no se locutaba).
> La corrección se aplica íntegra en `tui.js` (mapeo de eventos + adaptador de mensajes).

### `lib/stt.js` — corrección de audio

> 🐛 **Fix 24/09/2026:** `checkAudioSilence()` fallaba en Windows por alineación del
> búfer (`new Int16Array(buf.buffer, 44)`) y su `catch` asumía **silencio**, abortando
> la transcripción en silencio. Ahora usa `buf.slice()` y, ante error, **no** asume
> silencio (deja decidir a whisper).

---

## 🎙️ STT - Speech-to-Text

### Flujo (Windows)

```
Tú hablas al micrófono (TONOR TD510 Air Mic)
    ↓
Ctrl+R  → ffmpeg (DirectShow) graba WAV 16 kHz mono
    ↓
Ctrl+R  → ffmpeg se detiene (se escribe "q" en stdin)
    ↓
whisper-cli.exe (CUDA) transcribe → texto crudo
    ↓
LLM (Qwen 3.8 vía proxy 4001) normaliza el texto
    ↓
OpenCode añade el texto al prompt (appendPrompt / submitPrompt)
    ↓
OpenCode procesa la petición
```

### Componentes

| Componente | Ruta |
|------------|------|
| ffmpeg | `C:\Users\evo01\.local\bin\ffmpeg\bin\ffmpeg.exe` |
| whisper-cli (CUDA) | `C:\Users\evo01\.local\bin\whisper.cpp-cuda\Release\whisper-cli.exe` |
| Modelo por defecto | `C:\Users\evo01\.local\models\whisper\ggml-large-v3-turbo-q5_0.bin` (548 MB) |
| WAV temporal | `%TEMP%\opencode-stt.wav` |
| Micrófono | `Micrófono (TONOR TD510 Air Mic)` |

### Modelos whisper disponibles

| Modelo | Archivo | Calidad |
|--------|---------|---------|
| `large-v3-turbo-q5_0` | `ggml-large-v3-turbo-q5_0.bin` | ⭐ Recomendado (por defecto) |
| `large-v3-turbo-q8_0` | `ggml-large-v3-turbo-q8_0.bin` | Alta |
| `large-v3-turbo` | `ggml-large-v3-turbo.bin` | Máxima (lento) |
| `small` | `ggml-small.bin` | Media |
| `base` | `ggml-base.bin` | Básica |
| `tiny` | `ggml-tiny.bin` | Rápida |

> El español se fuerza con `-l es` en `lib/stt.js`.

### Whisper con GPU (CUDA)

El build `whisper.cpp-cuda` usa la GPU **por defecto** (la flag para desactivarla es
`-ng`/`--no-gpu`). Verificado con audio real:

- Transcripción en GPU: **~0,8 s** por audio.
- Transcripción en CPU (`--no-gpu`): **~10,5 s** → **12x más lento**.
- Extra de VRAM durante la transcripción: ~0,5 GB.

### Script `voice\stt.ps1` (utilidad CLI)

Graba del micrófono y transcribe desde consola (independiente del plugin):

```powershell
stt.ps1 -Seconds 8                                  # grabar 8 s y transcribir
stt.ps1 -AudioFile "C:\tmp\prueba.wav"              # transcribir un WAV
stt.ps1 -Seconds 5 -OutFile "C:\tmp\texto.txt"      # guardar el texto
```

---

## 🔊 TTS - Text-to-Speech

### Flujo (Windows)

```
OpenCode genera respuesta (streaming)
    ↓
Plugin captura el texto (session.text.delta) y, al terminar
(session.execution.succeeded), dispara el TTS automático
    ↓
cleanMarkdown() elimina markdown (```, **, tablas, etc.)
    ↓
speak.ps1 → servidor Kokoro persistente (127.0.0.1:4210) → WAV
    ↓
ffplay reproduce el audio por los altavoces
    ↓
¡Escuchas la respuesta!
```

### Motor: Kokoro v1.0 (ONNX + CUDA)

| Dato | Valor |
|------|-------|
| Modelo | `kokoro-v1.0.onnx` + `voices-v1.0.bin` |
| Ubicación | `C:\Users\evo01\.local\models\kokoro\` |
| Voz en español | `ef_dora` (femenina, por defecto), `em_alex` / `em_santa` (masculinas) |
| Runtime | venv `C:\Users\evo01\.config\opencode\voice\venv` |
| Provider | `CUDAExecutionProvider` (RTX 4070 Ti SUPER) |
| Python venv | `C:\Users\evo01\.config\opencode\voice\venv\Scripts\python.exe` |

### Reproducción

`speak.ps1` reproduce con **ffplay** (`-nodisp -autoexit -loglevel quiet`). Antes de
cada locución mata cualquier `ffplay` en curso, para no solapar voces.

### Limpieza de markdown (`cleanMarkdown` / `cleanLine`)

| Elemento | Reemplazo |
|----------|-----------|
| ` ```código``` ` | "código" |
| `` `inline code` `` | inline code |
| `**negrita**` | negrita |
| `[enlace](url)` | enlace |
| `# Títulos` | (eliminado) |
| `> blockquotes` | (eliminado) |
| Listas `- item` | item |
| Tablas `\| col \|` | "col: valor" |

### Script `voice\speak.ps1`

Recibe el texto del plugin por **stdin** y elige el motor:

| Motor | Descripción |
|-------|-------------|
| `kokoro` (por defecto) | Usa el **servidor persistente**; si no está, lo arranca; si falla, usa `kokoro-tts.py` en frío |
| `edge` | `edge-tts` (voz neuronal en la nube, requiere internet) |
| `sapi` | `System.Speech` (voz del sistema, offline) |

```powershell
# Ejemplos
speak.ps1 -Text "Hola Antonio" -OutFile "$env:TEMP\salida.wav"
speak.ps1 -Engine edge -Text "Hola"
speak.ps1 -Engine sapi -Text "Hola"
```

---

## 🚀 Servidor TTS persistente

**Motivo:** `kokoro-tts.py` cargaba el modelo ONNX completo (**~2,1 s**) en **cada**
locución. El servidor lo carga **una sola vez** y cada locución solo sintetiza
(~0,2-0,5 s).

### Archivo: `voice\kokoro-server.py`

Servidor HTTP local (solo `127.0.0.1`, puerto **4210** por defecto):

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/health` | GET | Estado: `{"ok": true, "voice": "ef_dora", "providers": [...]}` |
| `/tts` | POST | Body JSON `{text, voice, speed, lang}` → WAV (`audio/wav`) |
| `/shutdown` | POST | Detiene el servidor |

```powershell
# Arrancar manualmente
C:\Users\evo01\.config\opencode\voice\venv\Scripts\python.exe `
  C:\Users\evo01\.config\opencode\voice\kokoro-server.py --port 4210
```

### Gestión: `voice\tts-server.ps1`

```powershell
tts-server status    # estado (voz + providers activos)
tts-server start     # arranca y espera a que cargue el modelo (~3-5 s)
tts-server stop      # detiene (libera VRAM)
tts-server restart
```

> 💡 La función `tts-server` del perfil PowerShell envuelve este script.

### Arranque automático

- **Desde el plugin:** `speak.ps1` comprueba `/health`; si no responde, arranca el
  servidor y espera (hasta 20 s). Solo la primera locución tras un arranque en frío
  paga la carga.
- **Desde el perfil:** `ocv`, `ocv-local` y `ocv-cloud` llaman a
  `Start-TtsServerIfNeeded` (no bloqueante) al abrir OpenCode.
- **`ocv-status`** muestra el estado del servidor TTS.

### Fallback

Si el servidor no está disponible, `speak.ps1` cae a `kokoro-tts.py` (carga en frío,
~2,1 s). Si tampoco, usa el motor indicado (`edge` / `sapi`).

---

## ⚙️ Configuración en `cli.json`

En OpenCode V2 el plugin de voz se registra en **`cli.json`** (ya no en `tui.json`,
que era de la V1):

### Archivo: `C:\Users\evo01\.config\opencode\cli.json`

```json
{
  "$schema": "https://opencode.ai/v2/cli.json",
  "plugins": [
    {
      "package": "C:/Users/evo01/.config/opencode/opencode-voice-modified",
      "options": {
        "endpoint": "http://localhost:4001/v1",
        "model": "qwen3.8-9b"
      }
    },
    "-opencode.sidebar.context",
    "-opencode.sidebar.footer"
  ]
}
```

| Opción | Valor | Propósito |
|--------|-------|-----------|
| `endpoint` | `http://localhost:4001/v1` | Endpoint del proxy LM Studio para la **normalización STT** |
| `model` | `qwen3.8-9b` | Modelo local usado en la normalización |

> `cli.json` también configura el tema, keybinds (`session.rename` → `f8`), diffs y
> la sesión (sidebar, thinking, tps).

---

## 🧠 LLM Client (normalización)

### Archivo: `opencode-voice-modified/lib/llm-client.js`

Cliente HTTP para cualquier endpoint compatible con OpenAI. Se configura desde las
`options` del plugin (en `cli.json`):

```javascript
const cfg = {
  endpoint: pluginOptions?.endpoint,      // Ej: http://localhost:4001/v1
  model: pluginOptions?.model,            // Ej: qwen3.8-9b
  apiKeyEnv: pluginOptions?.apiKeyEnv,    // Variable de entorno con API key
  maxTokens: 2048,
  retries: 2,
};
```

`complete()` hace `POST /chat/completions` con reintentos y backoff exponencial.

> ⚠️ Si no se configura `endpoint`, la normalización STT **no se realiza** (se usa el
> texto crudo de whisper).

### Prompt de normalización (resumen)

El prompt (`STT_SYSTEM_PROMPT` en `lib/stt.js`) corrige puntuación, elimina muletillas
y arregla homófonos típicos del reconocimiento de voz en contextos técnicos, p. ej.:

| Se oye | Debe ser |
|--------|----------|
| "bullion" | "boolean" |
| "async" / "sync" | se mantienen (términos técnicos) |
| "a ver" / "haber" | según contexto |
| "por que" / "porqué" / "por qué" | según contexto |

---

## 📦 Instalación del stack

### `setup-voz.ps1`

```
D:\Linux\Config\opencode-win\scripts\setup-voz.ps1
```

Instala:

1. **ffmpeg** portable → `~\.local\bin\ffmpeg`
2. **whisper.cpp build CUDA** → `~\.local\bin\whisper.cpp-cuda`
3. **Modelo whisper** `large-v3-turbo-q5_0` → `~\.local\models\whisper`
4. **edge-tts** (reserva) → pip del sistema
5. **venv de Kokoro** + `onnxruntime-gpu==1.26.0` + libs CUDA 12 → `voice\venv`
6. **Modelo Kokoro** `kokoro-v1.0.onnx` + voces → `~\.local\models\kokoro`

Se ejecuta como parte del instalador principal con `-WithVoice`:

```powershell
D:\Linux\Config\opencode-win\instalar-opencode-win.ps1 -WithVoice
```

> ⚠️ `onnxruntime-gpu` **1.26.0** es la última compatible con CUDA 12; la 1.27+ exige CUDA 13.

---

## ⌨️ Comandos y atajos

### STT (grabación)

| Atajo | Comando | Descripción |
|-------|---------|-------------|
| `Ctrl+R` | `stt-record` | Grabar / parar y transcribir |
| `Leader+R` | `stt-submit` | Grabar + transcribir + **enviar** el prompt |
| `/stt-stop` | `stt-stop` | Cancelar la grabación |
| `/stt-model` | — | Elegir modelo whisper |
| `/stt-mic` | — | Elegir micrófono (en Windows la lista sale vacía: usa el predeterminado) |

### TTS (locución)

| Atajo | Comando | Descripción |
|-------|---------|-------------|
| `Leader+S` | `tts-speak` | Leer la última respuesta |
| `Leader+V` | `tts-mode` | Activar/desactivar el TTS automático |
| `Ctrl+Q` | `tts-stop` | Detener la reproducción |

> La tecla **leader** por defecto es `\`.

---

## 🎛️ Personalización

### Cambiar la voz de Kokoro

```powershell
tts-server stop
# editar voice\kokoro-server.py: --voice <voz> o la variable SPEAK_VOICE_KOKORO
tts-server start
```

Voces habituales: `ef_dora` (femenina), `em_alex`, `em_santa` (masculinas).

### Cambiar la velocidad

`speak.ps1 -Rate 1.2` (1.0 = normal).

### Cambiar pausas

Variables de entorno leídas por `kokoro-tts.py`/`kokoro-server.py`:

| Variable | Por defecto | Descripción |
|----------|-------------|-------------|
| `SPEAK_PAUSE` | `0.8` | Pausa al final de párrafo (s) |
| `SPEAK_PAUSE_SENT` | `0.35` | Pausa tras `.` `!` `?` (s) |
| `SPEAK_PAUSE_CLAUSE` | `0.3` | Pausa tras `:` `;` `—` (s) |

### Variables relevantes

| Variable | Por defecto | Descripción |
|----------|-------------|-------------|
| `SPEAK_VOICE_KOKORO` | `ef_dora` | Voz de Kokoro |
| `SPEAK_SPEED` | `1.0` | Velocidad de habla |
| `KOKORO_TTS_PORT` | `4210` | Puerto del servidor TTS |
| `ONNX_PROVIDER` | `CUDAExecutionProvider` | Provider de onnxruntime (GPU) |

---

## 🧰 Comandos útiles

```powershell
# Estado del servidor TTS
tts-server status

# Probar la locución (genera WAV sin reproducir)
speak.ps1 -Text "Prueba de locución" -OutFile "$env:TEMP\test.wav"

# Probar el motor de reserva
speak.ps1 -Engine edge -Text "Prueba edge-tts"
speak.ps1 -Engine sapi -Text "Prueba SAPI"

# Ver voces disponibles de Kokoro
voice\venv\Scripts\python.exe voice\kokoro-tts.py --list-voices

# Probar la transcripción con un WAV existente
stt.ps1 -AudioFile "$env:TEMP\prueba.wav"

# Liberar VRAM (parar servidores)
tts-server stop
& "C:\Users\evo01\.lmstudio\bin\lms.exe" unload --all

# Logs
Get-Content "$env:TEMP\opencode-voice.log" -Tail 30      # locuciones
Get-Content "$env:TEMP\opencode-voice-events.log" -Tail 30  # (si VOICE_DEBUG activo)
```

### Diagnóstico de eventos V2 (opcional)

Para depurar qué eventos recibe el plugin, crear el archivo flag
`%TEMP%\voice-debug-on` y reiniciar OpenCode. El plugin escribirá en
`%TEMP%\opencode-voice-events.log`. Al borrar el flag, el diagnóstico se desactiva.

---

> 📁 `C:\Users\evo01\.config\opencode\voice\` · `C:\Users\evo01\.config\opencode\opencode-voice-modified\` · `D:\Linux\Config\opencode-win\documentacion\03-configuracion-voz.md`
