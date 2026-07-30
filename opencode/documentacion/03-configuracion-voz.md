# 🎤 Configuración Completa de Voz (STT → OpenCode → TTS)

> **Fecha:** 26/07/2026 | **Usuario:** Antonio

---

## Índice

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
- **TTS:** `edge-tts` vía pipx + script `speak` + `paplay` (reproducir)
- **Normalización:** LLM local (Qwen 3.5) para limpiar transcripciones

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
LLM (Qwen 3.5) normaliza el texto
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
edge-tts genera audio WAV
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
    ├── tts.js        # Text-to-Speech (edge-tts)
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
| Normalización | LLM (Qwen 3.5) | Limpia y corrige el texto transcrito |

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

El **modelo por defecto** es `large-v3-turbo-q5_0` (~4 GB). El wrapper `whisper-cli` fuerza idioma español con `-l es`.

---

## TTS - Text-to-Speech

### Archivo: `opencode-voice-modified/lib/tts.js`

### Funcionamiento

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

Antes de enviar el texto a edge-tts, se elimina:

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
  
  // Llama al script speak (edge-tts)
  const proc = spawn(speakScript, [], { stdio: ["pipe", "ignore", "ignore"] });
  proc.stdin.write(cleaned);
  proc.stdin.end();
}
```

El script `speak` (Python) recibe el texto por stdin, genera audio con edge-tts y lo reproduce con paplay.

---

## Script `speak` (edge-tts)

### Archivo: `~/.local/bin/speak`

Script Python que:
1. Lee texto línea por línea desde stdin
2. Limpia caracteres ANSI y Unicode (recuadros)
3. Acumula texto hasta encontrar un delimitador (`.`, `?`, `!`, `:`, `...`)
4. Genera audio WAV con `edge-tts`
5. Reproduce con `paplay` (PulseAudio)

### Variables de entorno

| Variable | Valor por defecto | Descripción |
|----------|-------------------|-------------|
| `SPEAK_VOICE` | `es-ES-AlvaroNeural` | Voz de edge-tts |
| `SPEAK_RATE` | `+5%` | Velocidad de habla |
| `SPEAK_PITCH` | `+0Hz` | Tono de voz |

### Código simplificado

```python
VOICE = os.environ.get("SPEAK_VOICE", "es-ES-AlvaroNeural")
RATE = os.environ.get("SPEAK_RATE", "+5%")
PITCH = os.environ.get("SPEAK_PITCH", "+0Hz")

def speak(text):
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        cmd = ["edge-tts", "--voice", VOICE, "--rate", RATE, 
               "--pitch", PITCH, "--text", text, "--write-media", f.name]
        subprocess.run(cmd, timeout=30)
        subprocess.run(["paplay", f.name])

# Acumula texto y locuta al encontrar . ? ! :
for line in sys.stdin:
    buffer += clean_line(line) + " "
    if clean.endswith((".", "?", "!", ":", "...")):
        speak(buffer)
        buffer = ""
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
    "/home/antonio/.config/opencode/opencode-voice-modified"
  ]
}
```

El plugin se carga como **plugin TUI** de OpenCode. No tiene opciones adicionales (usa valores por defecto).

Si quisieras pasar opciones (por ejemplo, para normalización externa), sería:

```json
["/ruta/plugin", {
  "endpoint": "http://localhost:4001/v1",
  "model": "qwen/qwen3.5-9b",
  "maxTokens": 2048
}]
```

Actualmente el plugin **no tiene opciones** configuradas, por lo que usa los valores por defecto: la normalización se hace con el mismo LLM configurado en el provider de OpenCode.

---

## LLM Client

### Archivo: `opencode-voice-modified/lib/llm-client.js`

Cliente HTTP para llamar a cualquier endpoint compatible con OpenAI.

### Configuración

Se pasa desde `tui.json` en `options` del plugin:

```javascript
const cfg = {
  endpoint: pluginOptions?.endpoint,      // Ej: http://localhost:4001/v1
  model: pluginOptions?.model,            // Ej: qwen/qwen3.5-9b
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
#!/usr/bin/env bash
exec /usr/bin/whisper-cli -l es "$@"
```

Esto es **fundamental** porque fuerza la transcripción en español. Sin el flag `-l es`, whisper intentaría detectar el idioma automáticamente, lo que puede fallar con acentos o vocabulario técnico.

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

### Cambiar la voz de edge-tts

```bash
export SPEAK_VOICE="es-ES-AlvaroNeural"  # Voz española masculina
export SPEAK_VOICE="es-MX-JorgeNeural"   # Voz mexicana masculina
export SPEAK_VOICE="es-ES-ElviraNeural"  # Voz española femenina
```

### Cambiar velocidad

```bash
export SPEAK_RATE="+10%"  # Más rápido
export SPEAK_RATE="-10%"  # Más lento
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
# Probar edge-tts directamente
edge-tts --voice es-ES-AlvaroNeural --text "Hola, soy OpenCode" --write-media /tmp/test.wav && paplay /tmp/test.wav

# Ver voces disponibles
edge-tts --list-voices | grep es-

# Probar transcripción local
whisper-cli -m ~/.local/share/whisper-cpp/ggml-large-v3-turbo-q5_0.bin -f /tmp/prueba.wav -np -nt -l es

# Ver micrófonos disponibles
arecord -l

# Probar grabación con sox
sox -d -r 16000 -c 1 -b 16 /tmp/prueba.wav

# Ver logs del plugin (en OpenCode TUI)
# Los logs se envían al sistema de logging de OpenCode
```
