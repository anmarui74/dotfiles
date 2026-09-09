# 🎤 Configuración Completa de Voz (STT → OpenCode → TTS)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 🗣️ Sistema de voz | 08/09/2026 · rev. 08/09/2026 | Antonio |

> Flujo completo: sox + whisper (STT) → OpenCode → Kokoro v1.0 GPU (TTS local)

---

## 📑 Índice


1. [Descripción general](#descripción-general)
2. [Diagrama de flujo](#diagrama-de-flujo)
3. [Plugin de voz (`opencode-voice-modified`)](#plugin-de-voz)
4. [STT - Speech-to-Text (grabar voz → texto)](#stt-speech-to-text)
5. [TTS - Text-to-Speech (texto → audio)](#tts-text-to-speech)
6. [Script `speak` (edge-tts)](#script-speak-edge-tts)
7. [Configuración en `tui.json`](#configuración-en-tuijson)
8. [LLM Client (normalización)](#llm-client)
9. [Instalador `bootstrap-ocv.sh`](#instalador-bootstrap-ocvsh)
10. [Comandos y atajos de teclado](#comandos-y-atajos)
11. [Personalización](#personalización)

---

## Descripción general

El sistema de voz permite **hablarle a OpenCode** (STT) y que OpenCode **te responda con audio** (TTS). Se compone de:

- **Plugin TUI:** `opencode-voice-modified` (carpeta local)
- **STT:** `sox` (grabar) + `whisper-cpp` (transcribir) + LLM (normalizar)
- **TTS:** `Kokoro v1.0` (ONNX, GPU CUDA) vía `speak-kokoro-gpu` + `paplay` (reproducir)
- **Normalización:** LLM local (Qwen 3.8) para limpiar transcripciones

> **Cambio de motor TTS (08/09/2026):** el plugin pasó de `edge-tts` (nube Microsoft) a **Kokoro v1.0 en local con GPU** (voz `ef_dora`). Kokoro da voz mucho más natural y no depende de internet; el arranque de la voz es ~1-2 s en vez de 4-6 s. Detalle del benchmark en [la sección TTS](#tts-text-to-speech).

---

## Diagrama de flujo

### 🎙️ STT: Tú hablas → OpenCode recibe texto

```
Tú hablas al micrófono
    ↓
Ctrl+R (inicia grabación con sox)
    ↓
Ctrl+R (detiene grabación)
    ↓
whisper-cli transcribe el audio → texto crudo
    ↓
LLM (Qwen 3.8) normaliza el texto
    ↓
OpenCode añade el texto al prompt (appendPrompt)
    ↓
OpenCode procesa la petición
```

### 🔊 TTS: OpenCode responde → Tú escuchas

```
OpenCode genera respuesta (streaming)
    ↓
Plugin captura el texto vía message.part.updated
    ↓
Al terminar (session.idle), se activa TTS automático
    ↓
cleanMarkdown() elimina markdown (```, **, etc.)
    ↓
speak-kokoro-gpu (Kokoro v1.0 + CUDA) genera audio WAV
    ↓
paplay reproduce el audio por los altavoces
    ↓
¡Escuchas la respuesta!
```

---

## Plugin de voz

### Archivo: `~/.config/opencode/opencode-voice-modified/`

Estructura del plugin:

```
opencode-voice-modified/
├── index.js          # Punto de entrada
├── package.json      # Metadatos (name: @renjfk/opencode-voice)
├── README.md         # Documentación
├── LICENSE           # MIT
└── lib/
    ├── stt.js        # Speech-to-Text (sox + whisper)
    ├── tts.js        # Text-to-Speech (Kokoro vía speak-kokoro-gpu)
    ├── llm-client.js  # Cliente LLM para normalización
    ├── session.js    # Gestión de sesiones
    └── logger.js     # Logger
```

### `index.js` - Punto de entrada

```javascript
export default {
  id: "opencode-voice",
  tui: async (api, options) => {
    const { kv } = api;
    const { complete } = createClient(options, logger);
    
    // Carga prompts de normalización (desde archivo o por defecto)
    const prompts = {
      stt: loadPromptFile(options?.sttPrompt, logger, "STT"),
      ttsAuto: loadPromptFile(options?.ttsAutoPrompt, logger, "TTS auto"),
      ttsManual: loadPromptFile(options?.ttsManualPrompt, logger, "TTS manual"),
    };
    
    // Registra comandos STT y TTS
    const sttCommands = registerSTT(api, kv, complete, prompts, options, logger);
    const ttsCommands = registerTTS(api, kv, logger);
    api.command.register(() => [...sttCommands, ...ttsCommands]);
  },
};
```

### `package.json`

```json
{
  "name": "@renjfk/opencode-voice",
  "version": "0.6.0",
  "description": "Speech-to-text and text-to-speech for OpenCode.",
  "type": "module",
  "main": "index.js"
}
```

---

## STT - Speech-to-Text

### Archivo: `opencode-voice-modified/lib/stt.js`

### Componentes

| Componente | Herramienta | Propósito |
|------------|-------------|-----------|
| Grabación | `sox` | Captura audio del micrófono |
| Transcripción | `whisper-cli` (whisper-cpp) | Convierte audio a texto |
| Normalización | LLM (Qwen 3.8) | Limpia y corrige el texto transcrito |

### Flujo detallado STT

#### 1. Iniciar grabación

```javascript
function startRecording(kv, toast, logger) {
  // Usa sox para grabar: 16kHz, mono, 16-bit, WAV
  soxProc = spawn("sox", [
    ...inputArgs,         // Micrófono o default
    "-r", "16000",        // Frecuencia
    "-c", "1",            // Mono
    "-b", "16",           // 16 bits
    WAV_FILE              // /tmp/opencode-stt.wav
  ]);
}
```

#### 2. Detener y transcribir

```javascript
async function doTranscribePipeline(...) {
  stopRecording(logger);
  await waitForSoxExit(logger);
  
  // Verificar silencio
  if (checkAudioSilence(WAV_FILE)) {
    toast("No se detectó voz");
    return;
  }
  
  // Transcribir con whisper-cli (forzado a español: -l es)
  const result = await transcribe(kv, logger);
  // whisper-cli -m <modelo> -f /tmp/opencode-stt.wav -np -nt
}
```

#### 3. Normalizar con LLM

El plugin incluye un **system prompt** específico para normalizar transcripciones:

**Propósito:** Limpiar el texto crudo de whisper, corrigiendo:
- Puntuación y mayúsculas
- Palabras de relleno (um, uh, like)
- Homófonos técnicos

**Correcciones críticas de dominio (STT → programación):**

| Lo que dice | Lo que significa |
|-------------|------------------|
| "locks" | "logs" |
| "note" / "no" | "node" |
| "app and" | "append" |
| "sink" | "sync" |
| "a sink" | "async" |
| "doc" / "talker" | "docker" |
| "cash" | "cache" |
| "rap" | "wrap" |
| "Jason" | "JSON" |
| "get" | "Git" |
| "react" | "React" |
| "types creep" | "TypeScript" |
| "bite" | "byte" |
| "bullion" | "boolean" |

#### 4. Enviar a OpenCode

```javascript
await client.tui.appendPrompt({ text: result.text });
await client.tui.submitPrompt();
```

### Modelos whisper disponibles

| Modelo | Archivo | Calidad |
|--------|---------|---------|
| `large-v3-turbo-q5_0` | `ggml-large-v3-turbo-q5_0.bin` | ⭐ Recomendado |
| `large-v3-turbo-q8_0` | `ggml-large-v3-turbo-q8_0.bin` | Alta |
| `large-v3-turbo` | `ggml-large-v3-turbo.bin` | Máxima (lento) |
| `small` | `ggml-small.bin` | Media |
| `base` | `ggml-base.bin` | Básica |
| `tiny` | `ggml-tiny.bin` | Rápida |

El **modelo por defecto** es `large-v3-turbo-q5_0` (**548 MB** en disco). El español se fuerza con `-l es` en la llamada del plugin (`stt.js`).

### ⚡ Whisper con GPU (CUDA) — verificado

El build local de whisper.cpp (`~/.local/share/whisper-cpp/bin/`) está **compilado con CUDA** y usa la GPU **por defecto** (en v1.9.1 no existe `-ngl`; el flag es `-ng`/`--no-gpu`, desactivado por defecto). Verificado con audio real:

- Transcripción en GPU: **~1,1 GB de VRAM** extra durante la transcripción.
- Rendimiento: **15x real-time** (11 s de voz → 0,76 s).
- No requiere ninguna flag especial: el build CUDA detecta la GPU automáticamente.

---

## TTS - Text-to-Speech

### Archivo: `opencode-voice-modified/lib/tts.js`

El TTS usa el script local `~/.local/bin/speak-kokoro-gpu` (Kokoro v1.0 con GPU). El plugin spawnea ese script, le envía el texto por stdin y reproduce el audio generado.

### Motor: Kokoro v1.0 (ONNX + CUDA)

| Dato | Valor |
|------|-------|
| Modelo | `kokoro-v1.0.onnx` (310 MB) + `voices-v1.0.bin` (27 MB) |
| Ubicación | `~/.local/share/kokoro/` |
| Voz en español | `ef_dora` (femenina), `em_alex` / `em_santa` (masculinas) |
| Runtime | `onnxruntime-gpu` en venv `~/.local/share/tts-local/venv313` |
| Provider | `CUDAExecutionProvider` (RTX 4070 Ti SUPER) |
| Python | `python3.13` (instalado junto a `python3.14`, sin conflicto) |

#### Funcionamiento

#### Eventos que disparan TTS automático

```javascript
// 1. Captura texto en streaming
api.event.on("message.part.updated", (event) => {
  // Acumula texto del asistente mientras escribe
  streamingTexts.set(msgID, newText);
});

// 2. Cuando la sesión pasa a idle (terminó de responder)
api.event.on("session.idle", async () => {
  if (kv.get("tts.mode", "on") !== "on") return;
  
  const result = await getTurnAssistantText(client, api);
  await speak(result.text);  // ← Aquí se locuta
});

// 3. Cuando pide permiso
api.event.on("permission.asked", async () => {
  speak("Permission requested. Please check your screen.");
});

// 4. Cuando hace una pregunta
api.event.on("question.asked", async () => {
  speak("A question needs your answer. Please check your screen.");
});
```

#### Limpieza de markdown (`cleanMarkdown`)

Antes de enviar el texto a Kokoro, se elimina:

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

#### Función `speak(text)`

```javascript
function speak(text) {
  const cleaned = cleanMarkdown(text);
  
  // Llama al script speak-kokoro-gpu (Kokoro local + GPU)
  const speakScript = "/home/antonio/.local/bin/speak-kokoro-gpu";
  const proc = spawn(speakScript, [], { stdio: ["pipe", "ignore", "ignore"] });
  proc.stdin.write(cleaned);
  proc.stdin.end();
}
```

El script `speak-kokoro-gpu` (Python) recibe el texto por stdin, genera audio con Kokoro v1.0 (CUDA) y lo reproduce con paplay.

### Benchmark (RTX 4070 Ti SUPER, 08/09/2026)

| Motor | TTFB 1ª frase | Total 1500c | RTF | Naturalidad |
|-------|---------------|-------------|-----|-------------|
| `edge-tts` (cloud) | 4-6 s | ~4,2 s | - | ⭐⭐⭐ Azure |
| `speak-piper` (CPU) | 0,24 s | 1,16 s | 0,03 | ⭐⭐ sintética |
| `speak-kokoro` (CPU) | 1,15 s | 5,97 s | 0,14 | ⭐⭐⭐ StyleTTS-2 |
| `speak-kokoro-gpu` (CUDA) | ~1 s | 1,49 s | **0,038** | ⭐⭐⭐ StyleTTS-2 |

> Kokoro va ~26x tiempo real con GPU (un texto de 39 s de voz se sintetiza en ~1,5 s) y su voz es la más natural de los motores locales.

---

## Scripts de locución (`~/.local/bin/`)

### `speak` (edge-tts, reserva/fallback)

Script Python que:
1. Lee texto línea por línea desde stdin
2. Limpia caracteres ANSI y Unicode (recuadros)
3. Genera audio WAV con `edge-tts` (nube Microsoft)
4. Reproduce con `paplay` (PulseAudio)

> Actualmente el plugin NO usa este script (usa `speak-kokoro-gpu`), pero se mantiene como fallback y para instalaciones desde limpio.

### `speak-kokoro-gpu` (motor actual)

Script Python que usa **Kokoro v1.0 en GPU** (venv `python3.13` + onnxruntime-gpu):
1. Lee texto línea por línea desde stdin
2. Limpia caracteres ANSI, Unicode y emojis (locucionero)
3. Carga el modelo una sola vez (Kokoro + CUDA)
4. Divide en bloques y locuta cada uno en cuanto está sintetizado
5. Reproduce con `paplay` (arranque ~1 s)

### `speak-piper` (alternativa CPU, muy rápida)

Script Python que usa **Piper** (RTF 0,03, arranque ~0,24 s) pero con voz menos natural. Disponible como alternativa ligera en CPU.

### Variables de entorno

| Variable | Valor por defecto | Descripción |
|----------|-------------------|-------------|
| `SPEAK_VOICE_KOKORO` | `ef_dora` | Voz de Kokoro (ef_dora / em_alex / em_santa) |
| `SPEAK_SPEED` | `1.0` | Velocidad de habla de Kokoro |
| `ONNX_PROVIDER` | `CUDAExecutionProvider` | Provider de onnxruntime (GPU) |
| `CUDA_MODULE_LOADING` | `LAZY` | Carga perezosa de módulos CUDA |
| `SPEAK_VOICE` | `es-ES-AlvaroNeural` | Voz de edge-tts (solo para `speak`) |

> El script `speak-kokoro-gpu` fuerza por defecto `ONNX_PROVIDER=CUDAExecutionProvider` y `CUDA_MODULE_LOADING=LAZY` internamente, para usar la RTX 4070 Ti SUPER sin que el paquete intente TensorRT.

### Código simplificado de `speak-kokoro-gpu`

```python
from kokoro_onnx import Kokoro, EspeakConfig
cfg = EspeakConfig(lib_path="/usr/lib/libespeak-ng.so", data_path="/usr/share/espeak-ng-data")
engine = Kokoro("~/.local/share/kokoro/kokoro-v1.0.onnx",
                "~/.local/share/kokoro/voices-v1.0.bin", espeak_config=cfg)

def speak_block(text):
    audio, sr = engine.create(text, voice="ef_dora", lang="es", speed=1.0)
    sf.write(tmp.wav, audio, sr)
    subprocess.run(["paplay", tmp.wav])
```

---

## Configuración en `tui.json`

### Archivo: `~/.config/opencode/tui.json`

```json
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "session_rename": "f8"
  },
  "plugin": [
    [
      "/home/antonio/.config/opencode/opencode-voice-modified/index.js",
      {
        "endpoint": "http://localhost:4001/v1",
        "model": "models-qwen3.8-9b"
      }
    ],
    ["opencode-throughput", {}]
  ]
}
```

El plugin se carga como **plugin TUI** de OpenCode apuntando directamente a `index.js` (desde el 18/08/2026). Tiene **opciones configuradas**:

| Opción | Valor | Propósito |
|--------|-------|-----------|
| `endpoint` | `http://localhost:4001/v1` | Endpoint del proxy LM Studio usado para la **normalización STT** |
| `model` | `models-qwen3.8-9b` | Modelo local Qwen 3.8 usado en la normalización |

Estas opciones se añadieron el **18/08/2026** para que la normalización STT use explícitamente el modelo local vía el proxy (antes usaba valores por defecto).

Si quisieras pasar opciones adicionales (por ejemplo, para normalización externa), sería:

```json
["/home/antonio/.config/opencode/opencode-voice-modified/index.js", {
  "endpoint": "https://api.anthropic.com/v1",
  "model": "claude-haiku-4-5",
  "apiKeyEnv": "ANTHROPIC_API_KEY",
  "maxTokens": 2048
}]
```

---

## LLM Client

### Archivo: `opencode-voice-modified/lib/llm-client.js`

Cliente HTTP para llamar a cualquier endpoint compatible con OpenAI.

### Configuración

Se pasa desde `tui.json` en `options` del plugin:

```javascript
const cfg = {
  endpoint: pluginOptions?.endpoint,      // Ej: http://localhost:4001/v1
  model: pluginOptions?.model,            // Ej: models-qwen3.8-9b
  apiKeyEnv: pluginOptions?.apiKeyEnv,    // Variable de entorno con API key
  maxTokens: 2048,
  reasoningEffort: null,
  chatTemplateKwargs: null,
  retries: 2,
};
```

### Función `complete()`

Hace una petición `POST /chat/completions` con:
- `system` + `user` messages
- Reintentos con backoff exponencial (250ms × 2^intento)
- Timeout de red (no configurado, depende del fetch por defecto)

**Nota importante:** Si no se configura endpoint, la normalización STT **no se realiza** (se usa el texto crudo de whisper).

---

## Instalador `bootstrap-ocv.sh`

### Archivo: `~/.config/opencode/bootstrap-ocv.sh`

Script de instalación **desde cero** del sistema de voz. Realiza:

| Paso | Acción |
|------|--------|
| 1 | Instala dependencias del sistema: `sox`, `pulseaudio-utils`, `whisper-cpp`, `pipx`, `nodejs`, `npm` |
| 2 | Crea wrapper `whisper-cli` en `~/.local/bin/` que fuerza español (`-l es`) |
| 3 | Instala `edge-tts` vía pipx |
| 4 | Descarga modelos whisper: large-v3-turbo-q5_0 (recomendado), small, base |
| 5 | Crea plugin `opencode-voice-modified` con todos sus archivos |
| 6 | Instala script `speak` en `~/.local/bin/` |
| 7 | Configura `tui.json` con la ruta del plugin |
| 8 | Instala dependencias npm del plugin |
| 9 | Verifica todo |

### Wrapper whisper-cli

```bash
#!/bin/bash
# Wrapper whisper-cli con CUDA: añade el directorio local a LD_LIBRARY_PATH
export LD_LIBRARY_PATH="/home/antonio/.local/share/whisper-cpp/bin:${LD_LIBRARY_PATH}"
exec /home/antonio/.local/share/whisper-cpp/bin/whisper-cli "$@"
```

El wrapper apunta al **build local con CUDA** (`~/.local/share/whisper-cpp/bin/whisper-cli`) y añade su directorio a `LD_LIBRARY_PATH` para que se resuelvan `libggml-cuda.so.0` y las librerías del toolkit CUDA (`/opt/cuda`). El idioma español se fuerza con `-l es` **en la llamada del plugin** (`stt.js`), no en el wrapper.

⚠️ Si el build local no existiera, el wrapper fallaría. Se instala/compila con CUDA desde `bootstrap-ocv.sh` (requiere `nvcc` + `cmake`; si no hay `nvcc`, cae al binario CPU oficial).

---

## Comandos y atajos

### STT (grabación)

| Comando | Atajo | Descripción |
|---------|-------|-------------|
| `/stt-record` | `Ctrl+R` | Inicia/detiene grabación y transcribe |
| `/stt-submit` | `Leader+R` | Detiene grabación, transcribe y envía |
| `/stt-stop` | — | Cancela la grabación actual |
| `/stt-model` | — | Selecciona modelo whisper |
| `/stt-mic` | — | Selecciona micrófono |

### TTS (locución)

| Comando | Atajo | Descripción |
|---------|-------|-------------|
| `/tts-mode` | `Leader+V` | Activa/desactiva TTS automático |
| `/tts-speak` | `Leader+S` | Lee la última respuesta en voz alta |
| `/tts-stop` | `Escape` | Detiene la reproducción actual |

### Estados visuales

- **Grabando:** Toast "Recording... press again to transcribe"
- **Transcribiendo:** Toast "Transcribing..."
- **Transcripción lista:** Toast "Transcription submitted"
- **TTS activo:** Se escucha la voz por los altavoces
- **TTS desactivado:** No hay locución automática

---

## Personalización

### Cambiar la voz de Kokoro

Las voces en español v1.0 de Kokoro son `ef_dora` (femenina), `em_alex` y `em_santa` (masculinas).

```bash
export SPEAK_VOICE_KOKORO="ef_dora"   # Voz femenina (actual)
export SPEAK_VOICE_KOKORO="em_alex"   # Voz masculina
export SPEAK_VOICE_KOKORO="em_santa"  # Voz masculina más grave
```

### Cambiar velocidad de Kokoro

```bash
export SPEAK_SPEED="0.95"  # Un poco más lento
export SPEAK_SPEED="1.1"   # Un poco más rápido
```

### Cambiar la voz de edge-tts (solo `speak`, fallback)

```bash
export SPEAK_VOICE="es-ES-AlvaroNeural"  # Voz española masculina
export SPEAK_VOICE="es-MX-JorgeNeural"   # Voz mexicana masculina
export SPEAK_VOICE="es-ES-ElviraNeural"  # Voz española femenina
```

### Añadir opciones de normalización externa

Si quieres usar un endpoint externo para normalizar (ej. Claude en vez del modelo local):

```json
// tui.json
"plugin": [
  ["/home/antonio/.config/opencode/opencode-voice-modified", {
    "endpoint": "https://api.anthropic.com/v1",
    "model": "claude-haiku-4-5",
    "apiKeyEnv": "ANTHROPIC_API_KEY",
    "maxTokens": 2048
  }]
]
```

### Prompts personalizados

El plugin soporta archivos de prompt externos para STT, TTS auto y TTS manual:

```json
// tui.json (opciones)
"plugin": [
  ["/ruta/plugin", {
    "sttPrompt": "~/.config/opencode/prompts/stt-normalize.txt",
    "ttsAutoPrompt": "~/.config/opencode/prompts/tts-auto.txt",
    "ttsManualPrompt": "~/.config/opencode/prompts/tts-manual.txt"
  }]
]
```

Actualmente no se usan prompts externos.

---

## Comandos útiles

```bash
# Probar la locución con Kokoro-GPU (voz Dora)
echo "Hola, soy OpenCode" | speak-kokoro-gpu

# Cambiar de voz puntualmente
echo "Hola" | SPEAK_VOICE_KOKORO=em_alex speak-kokoro-gpu

# Comparar con los otros motores
echo "Hola" | speak-piper      # Piper (CPU, rapidísimo)
echo "Hola" | speak            # edge-tts (nube, fallback)

# Probar edge-tts directamente (fallback)
edge-tts --voice es-ES-AlvaroNeural --text "Hola, soy OpenCode" --write-media /tmp/test.wav && paplay /tmp/test.wav

# Ver voces disponibles de Kokoro
speak-kokoro-gpu 2>/dev/null   # (usa ef_dora por defecto)

# Probar transcripción local
whisper-cli -m ~/.local/share/whisper-cpp/ggml-large-v3-turbo-q5_0.bin -f /tmp/prueba.wav -np -nt -l es

# Ver micrófonos disponibles
arecord -l

# Probar grabación con sox
sox -d -r 16000 -c 1 -b 16 /tmp/prueba.wav

# Ver logs del plugin (en OpenCode TUI)
# Los logs se envían al sistema de logging de OpenCode
```
