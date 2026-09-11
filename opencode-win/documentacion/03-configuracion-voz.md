# 🎤 Configuración Completa de Voz (STT → OpenCode → TTS) en Windows
Flujo de voz en Windows con GPU: STT whisper.cpp (CUDA) → OpenCode → TTS Kokoro (CUDA)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Implementado en Windows (GPU) | 10/09/2026 · rev. 10/09/2026 | Antonio |

> ✅ **Implementado en Windows el 10/09/2026.** STT con **whisper.cpp build CUDA** (RTX 4070 Ti SUPER, ~15x tiempo real) y TTS con **Kokoro v1.0 ONNX en GPU** (onnxruntime-gpu 1.26 + CUDA 12). El plugin `opencode-voice-modified` está portado y registrado en `tui.json`. El resto del manual conserva la descripción original de Linux como referencia.
>
> 📁 Scripts: `C:\Users\evo01\.config\opencode\voice\` (`stt.ps1`, `speak.ps1`, `kokoro-tts.py`) · Plugin: `C:\Users\evo01\.config\opencode\opencode-voice-modified\` · Instalación del stack: `D:\Linux\Config\opencode-win\scripts\setup-voz.ps1`

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
9. [Instalador `instalar-opencode-win.ps1`](#instalador-bootstrap-ocvsh)
10. [Comandos y atajos de teclado](#comandos-y-atajos)
11. [Personalización](#personalización)

---

## ✅ Implementación en Windows (resumen)

El sistema de voz está **portado y operativo en Windows con GPU**. Componentes:

| Función | Implementación Windows | Ruta / detalle |
|---------|------------------------|----------------|
| 🎤 **STT** | `ffmpeg` (captura DirectShow) + **whisper.cpp build CUDA** | `voice\stt.ps1` · modelo `ggml-large-v3-turbo-q5_0.bin` en `~\.local\models\whisper\` |
| 🔊 **TTS** | **Kokoro v1.0 ONNX en GPU** (onnxruntime-gpu 1.26 + CUDA 12) | `voice\speak.ps1` + `voice\kokoro-tts.py` · voces en `~\.local\models\kokoro\` |
| 🗣️ Reserva TTS | edge-tts / SAPI5 | `speak.ps1 -Engine edge` / `-Engine sapi` |
| 🧩 **Plugin** | `opencode-voice-modified` (portado) | `~\.config\opencode\opencode-voice-modified\` · registrado en `tui.json` |
| 📦 Instalación | `setup-voz.ps1` (o `instalar-opencode-win.ps1 -WithVoice`) | `D:\Linux\Config\opencode-win\scripts\setup-voz.ps1` |

**Atajos (plugin):** `Ctrl+R` grabar/transcribir · `Leader+R` grabar+enviar · `Leader+S` leer última respuesta · `Leader+V` TTS on/off · **`Ctrl+Q` parar**.

**Comportamiento del TTS (equivalente a Linux):**
- Se locutan **párrafos/líneas por separado** con pausa entre ellos (y entre celdas de tabla y tras `: ; —`).
- Se **filtran emojis, ANSI, dibujos de caja y markdown** antes de sintetizar.
- Una locución nueva **corta** la anterior (no se solapan).
- Pausas configurables: `SPEAK_PAUSE` (0,8 s), `SPEAK_PAUSE_SENT` (0,35 s), `SPEAK_PAUSE_CLAUSE` (0,3 s).

**Detalles técnicos clave (Windows):**
- El texto viaja por **stdin** (plugin → `speak.ps1`) y por **fichero UTF-8** (`speak.ps1` → `kokoro-tts.py`) para no romper acentos ni comillas.
- `onnxruntime-gpu` **1.26.0** (CUDA 12); la 1.27+ exige CUDA 13 (no disponible por pip).
- Regla Windows: los `.ps1` invocados con `powershell -File` (plugin/`.cmd`) **no deben usar `begin/process/end`** (no reciben parámetros).

---

## Descripción general

> ℹ️ Las secciones siguientes describen el sistema tal como estaba en Linux (referencia). La **implementación Windows ya operativa** está resumida en el bloque anterior.

El sistema de voz de Linux se compone de:

- **Plugin TUI:** `opencode-voice-modified` (carpeta local)
- **STT:** `sox` (grabar) + `whisper-cpp` (transcribir) + LLM (normalizar)
- **TTS:** `Kokoro v1.0` (ONNX, GPU CUDA) vía `speak-kokoro-gpu` + `paplay` (reproducir)
- **Normalización:** LLM local (Qwen 3.8) para limpiar transcripciones

> **Cambio de motor TTS (08/09/2026, Linux):** el plugin pasó de `edge-tts` (nube Microsoft) a **Kokoro v1.0 en local con GPU** (voz `ef_dora`). Kokoro da voz mucho más natural y no depende de internet; el arranque de la voz es ~1-2 s en vez de 4-6 s. Detalle del benchmark en [la sección TTS](#tts-text-to-speech).

### Equivalente previsto en Windows (plan, no implementado)

| Componente Linux | Equivalente Windows previsto | Estado |
|------------------|------------------------------|--------|
| `sox` (grabación) | Módulo de audio de **LM Studio** o `ffmpeg` (si se instala) | ⚠️ Pendiente |
| `whisper-cpp` | **whisper.cpp para Windows** (build precompilado) | ⚠️ Pendiente |
| `Kokoro v1.0` + `paplay` | **SAPI5 (`System.Speech`)** o **Piper**; reproducción con el reproductor por defecto | ⚠️ Pendiente |
| `edge-tts` (fallback) | `edge-tts` vía `pip` (existe en Windows) | ⚠️ Pendiente |
| Plugin TUI + atajos | Sin portar (no hay atajos de voz en Windows) | 🔴 No existe |

---

## Diagrama de flujo

> ⚠️ **No aplica en Windows (pendiente de portar).** Los atajos y utilidades que se muestran (`Ctrl+R`, `sox`, `whisper-cli`, `paplay`) son de Linux y no existen en este setup de Windows.

### 🎙️ STT: Tú hablas → OpenCode recibe texto (Linux)

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

### 🔊 TTS: OpenCode responde → Tú escuchas (Linux)

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

### Equivalente previsto en Windows (plan)

```
STT:  micrófono → ffmpeg/LM Studio (WAV 16 kHz mono)
                 → whisper.cpp (whisper-cli.exe) -l es
                 → normalización LLM vía proxy 4001
                 → appendPrompt / submitPrompt en OpenCode

TTS:  texto → cleanMarkdown → SAPI5 (System.Speech) o Piper
             → WAV temporal → reproducción con el reproductor por defecto
```

---

## Plugin de voz

### Archivo: `C:\Users\evo01\.config\opencode\opencode-voice-modified\`

> ⚠️ **No aplica en Windows (pendiente de portar).** El plugin `opencode-voice-modified` es el de Linux: sus módulos `stt.js`/`tts.js` invocan `sox`, `whisper-cli` y `speak-kokoro-gpu` con rutas POSIX y `spawn`, y **no funcionaría tal cual en Windows**. No se ha creado una versión Windows.

Estructura del plugin (referencia Linux):

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

> ⚠️ **No aplica en Windows (pendiente de portar).** El STT actual depende de `sox` y `whisper-cpp` con rutas POSIX. En Windows **no está implementado**; abajo se describe el plan de equivalencia.

### Archivo (Linux): `opencode-voice-modified/lib/stt.js`

### Componentes (Linux)

| Componente | Herramienta | Propósito |
|------------|-------------|-----------|
| Grabación | `sox` | Captura audio del micrófono |
| Transcripción | `whisper-cli` (whisper-cpp) | Convierte audio a texto |
| Normalización | LLM (Qwen 3.8) | Limpia y corrige el texto transcrito |

### Componentes previstos (Windows, pendiente)

| Componente | Equivalente Windows | Propósito | Estado |
|------------|---------------------|-----------|--------|
| Grabación | Módulo de audio de LM Studio o `ffmpeg` | Captura audio del micrófono | ⚠️ Pendiente |
| Transcripción | `whisper-cli.exe` (whisper.cpp para Windows) | Convierte audio a texto | ⚠️ Pendiente |
| Normalización | LLM local (Qwen 3.8) vía proxy `4001` | Limpia y corrige el texto | ⚠️ Pendiente |

### Flujo detallado STT (Linux)

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

> En Windows estos mismos modelos `.bin` de whisper.cpp serían reutilizables con el `whisper-cli.exe` nativo, pero **el plugin aún no los invoca** (pendiente de portar).

### ⚡ Whisper con GPU (CUDA) — Linux verificado

El build local de whisper.cpp de Linux (`~/.local/share/whisper-cpp/bin/`) está **compilado con CUDA** y usa la GPU **por defecto** (en v1.9.1 no existe `-ngl`; el flag es `-ng`/`--no-gpu`, desactivado por defecto). Verificado con audio real:

- Transcripción en GPU: **~1,1 GB de VRAM** extra durante la transcripción.
- Rendimiento: **15x real-time** (11 s de voz → 0,76 s).
- No requiere ninguna flag especial: el build CUDA detecta la GPU automáticamente.

> ⚠️ **No aplica en Windows (pendiente de portar).** En Windows habría que usar un build de whisper.cpp con CUDA (o Vulkan) y verificar el rendimiento; no se ha hecho todavía.

---

## TTS - Text-to-Speech

> ⚠️ **No aplica en Windows (pendiente de portar).** El TTS actual usa `Kokoro v1.0` (ONNX + CUDA) y reproduce con `paplay` (PulseAudio de Linux). En Windows **no está implementado**; abajo se describe el plan de equivalencia.

### Archivo (Linux): `opencode-voice-modified/lib/tts.js`

El TTS usa el script local `~/.local/bin/speak-kokoro-gpu` (Kokoro v1.0 con GPU). El plugin spawnea ese script, le envía el texto por stdin y reproduce el audio generado.

### Motor: Kokoro v1.0 (ONNX + CUDA) — Linux

| Dato | Valor |
|------|-------|
| Modelo | `kokoro-v1.0.onnx` (310 MB) + `voices-v1.0.bin` (27 MB) |
| Ubicación | `~/.local/share/kokoro/` |
| Voz en español | `ef_dora` (femenina), `em_alex` / `em_santa` (masculinas) |
| Runtime | `onnxruntime-gpu` en venv `~/.local/share/tts-local/venv313` |
| Provider | `CUDAExecutionProvider` (RTX 4070 Ti SUPER) |
| Python | `python3.13` (instalado junto a `python3.14`, sin conflicto) |

### Equivalente previsto en Windows (pendiente)

| Opción | Tecnología | Ventajas | Estado |
|--------|-----------|----------|--------|
| SAPI5 | `System.Speech.Synthesis` (PowerShell/.NET) | Nativo, sin dependencias, voces del sistema | ⚠️ Pendiente |
| Piper | Binario Piper para Windows | Voces neuronales locales, rápido | ⚠️ Pendiente |
| Kokoro | `onnxruntime-gpu` en Windows | Máxima calidad (requiere portar el script) | ⚠️ Pendiente |
| edge-tts | `edge-tts` vía `pip` | Voces Azure, requiere internet | ⚠️ Pendiente |

> La reproducción en Windows se haría con el **reproductor por defecto** (p. ej. `Start-Process` sobre el WAV o `(New-Object Media.SoundPlayer).PlaySync()`), ya que **no existe `paplay`**.

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

Antes de enviar el texto al motor TTS, se elimina:

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

### Benchmark (RTX 4070 Ti SUPER, 08/09/2026, Linux)

| Motor | TTFB 1ª frase | Total 1500c | RTF | Naturalidad |
|-------|---------------|-------------|-----|-------------|
| `edge-tts` (cloud) | 4-6 s | ~4,2 s | - | ⭐⭐⭐ Azure |
| `speak-piper` (CPU) | 0,24 s | 1,16 s | 0,03 | ⭐⭐ sintética |
| `speak-kokoro` (CPU) | 1,15 s | 5,97 s | 0,14 | ⭐⭐⭐ StyleTTS-2 |
| `speak-kokoro-gpu` (CUDA) | ~1 s | 1,49 s | **0,038** | ⭐⭐⭐ StyleTTS-2 |

> Kokoro va ~26x tiempo real con GPU (un texto de 39 s de voz se sintetiza en ~1,5 s) y su voz es la más natural de los motores locales. Estas cifras son del setup de **Linux**; en Windows no se ha medido.

---

## Scripts de locución (`~/.local/bin/`)

> ⚠️ **No aplica en Windows (pendiente de portar).** No existe `~/.local/bin/` ni los scripts `speak*` en este setup. Se documentan como referencia del plan de portabilidad.

### `speak` (edge-tts, reserva/fallback)

Script Python que:
1. Lee texto línea por línea desde stdin
2. Limpia caracteres ANSI y Unicode (recuadros)
3. Genera audio WAV con `edge-tts` (nube Microsoft)
4. Reproduce con `paplay` (PulseAudio)

> Actualmente el plugin NO usa este script (usa `speak-kokoro-gpu`), pero se mantiene como fallback y para instalaciones desde limpio.

### `speak-kokoro-gpu` (motor actual en Linux)

Script Python que usa **Kokoro v1.0 en GPU** (venv `python3.13` + onnxruntime-gpu):
1. Lee texto línea por línea desde stdin
2. Limpia caracteres ANSI, Unicode y emojis (locucionero)
3. Carga el modelo una sola vez (Kokoro + CUDA)
4. Divide en bloques y locuta cada uno en cuanto está sintetizado
5. Reproduce con `paplay` (arranque ~1 s)

### `speak-piper` (alternativa CPU, muy rápida)

Script Python que usa **Piper** (RTF 0,03, arranque ~0,24 s) pero con voz menos natural. Disponible como alternativa ligera en CPU.

### Variables de entorno (Linux)

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

### Archivo: `C:\Users\evo01\.config\opencode\tui.json`

> ⚠️ **No aplica en Windows (pendiente de portar).** El bloque de plugin de voz de abajo apunta a rutas POSIX y a un plugin que no existe en Windows. En este setup `tui.json` **no registra el plugin de voz**; solo se mantiene `opencode-throughput`.

```json
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "session_rename": "f8"
  },
  "plugin": [
    [
      "C:\\Users\\evo01\\.config\\opencode\\opencode-voice-modified\\index.js",
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
["C:\\Users\\evo01\\.config\\opencode\\opencode-voice-modified\\index.js", {
  "endpoint": "https://api.anthropic.com/v1",
  "model": "claude-haiku-4-5",
  "apiKeyEnv": "ANTHROPIC_API_KEY",
  "maxTokens": 2048
}]
```

---

## LLM Client

### Archivo (Linux): `opencode-voice-modified/lib/llm-client.js`

Cliente HTTP para llamar a cualquier endpoint compatible con OpenAI.

> ⚠️ **No aplica en Windows (pendiente de portar).** Este módulo pertenece al plugin de voz y no está presente en el setup Windows. Su lógica (fetch HTTP a un endpoint OpenAI-compatible) sería portable, pero queda pendiente.

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

## Instalador `instalar-opencode-win.ps1`

### Archivo: `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1`

> ⚠️ **No aplica en Windows todavía.** El instalador `bootstrap-ocv.sh` de Linux instala el sistema de voz completo. En Windows, el instalador de referencia es `instalar-opencode-win.ps1`, pero **NO incluye el sistema de voz** (pendiente de portar).

Script de instalación **desde cero** del sistema de voz en Linux. Realizaba:

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

### Plan de instalación en Windows (pendiente)

El instalador Windows (`instalar-opencode-win.ps1`) ya cubre Node.js, Python 3.14, LM Studio, OpenCode, el proxy y las tareas programadas, pero **falta**:

1. Descargar un build de **whisper.cpp para Windows** y los modelos `ggml-*.bin`.
2. Instalar **ffmpeg** (vía `winget install Gyan.FFmpeg` o `ffmpeg` en el PATH) como sustituto de `sox` para capturar/convertir audio.
3. Crear un wrapper `whisper-cli.cmd`/`.ps1` que fuerce español (`-l es`).
4. Portar el plugin `opencode-voice-modified` a Windows (rutas, `spawn`, reproducción con el reproductor por defecto).
5. Portar el motor TTS (SAPI5 o Piper) y el script `speak`.
6. Registrar el plugin en `tui.json` y definir atajos.

> Mientras no se implemente, el sistema de voz en Windows se considera **no disponible**.

### Wrapper whisper-cli (Linux, referencia)

```bash
#!/bin/bash
# Wrapper whisper-cli con CUDA: añade el directorio local a LD_LIBRARY_PATH
export LD_LIBRARY_PATH="/home/antonio/.local/share/whisper-cpp/bin:${LD_LIBRARY_PATH}"
exec /home/antonio/.local/share/whisper-cpp/bin/whisper-cli "$@"
```

El wrapper apunta al **build local con CUDA** (`~/.local/share/whisper-cpp/bin/whisper-cli`) y añade su directorio a `LD_LIBRARY_PATH` para que se resuelvan `libggml-cuda.so.0` y las librerías del toolkit CUDA (`/opt/cuda`). El idioma español se fuerza con `-l es` **en la llamada del plugin** (`stt.js`), no en el wrapper.

⚠️ Si el build local no existiera, el wrapper fallaría. Se instala/compila con CUDA desde `bootstrap-ocv.sh` (requiere `nvcc` + `cmake`; si no hay `nvcc`, cae al binario CPU oficial).

> ⚠️ **No aplica en Windows.** `LD_LIBRARY_PATH` y `bash` no existen aquí. El equivalente sería un `.cmd`/`.ps1` que anteponga la carpeta del build al `PATH` y llame a `whisper-cli.exe`.

---

## Comandos y atajos

> ⚠️ **No aplica en Windows (pendiente de portar).** Los atajos de teclado del plugin de voz **no existen en Windows todavía**, porque el plugin no está portado.

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

> ⚠️ **No aplica en Windows (pendiente de portar).** Estas variables y opciones pertenecen a los scripts de voz de Linux. En Windows no existen; se listan como referencia para el futuro port.

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
  ["C:\\Users\\evo01\\.config\\opencode\\opencode-voice-modified", {
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
    "sttPrompt": "C:\\Users\\evo01\\.config\\opencode\\prompts\\stt-normalize.txt",
    "ttsAutoPrompt": "C:\\Users\\evo01\\.config\\opencode\\prompts\\tts-auto.txt",
    "ttsManualPrompt": "C:\\Users\\evo01\\.config\\opencode\\prompts\\tts-manual.txt"
  }]
]
```

Actualmente no se usan prompts externos.

---

## Comandos útiles

> ⚠️ **No aplica en Windows (pendiente de portar).** Los comandos de abajo son de Linux (`speak-kokoro-gpu`, `speak`, `whisper-cli`, `arecord`, `sox`). En Windows **no existen**; se muestra a la derecha el equivalente previsto, aún sin implementar.

```bash
# (Linux) Probar la locución con Kokoro-GPU (voz Dora)
echo "Hola, soy OpenCode" | speak-kokoro-gpu

# (Linux) Cambiar de voz puntualmente
echo "Hola" | SPEAK_VOICE_KOKORO=em_alex speak-kokoro-gpu

# (Linux) Comparar con los otros motores
echo "Hola" | speak-piper      # Piper (CPU, rapidísimo)
echo "Hola" | speak            # edge-tts (nube, fallback)

# (Linux) Probar edge-tts directamente (fallback)
edge-tts --voice es-ES-AlvaroNeural --text "Hola, soy OpenCode" --write-media /tmp/test.wav && paplay /tmp/test.wav

# (Linux) Ver voces disponibles de Kokoro
speak-kokoro-gpu 2>/dev/null   # (usa ef_dora por defecto)

# (Linux) Probar transcripción local
whisper-cli -m ~/.local/share/whisper-cpp/ggml-large-v3-turbo-q5_0.bin -f /tmp/prueba.wav -np -nt -l es

# (Linux) Ver micrófonos disponibles
arecord -l

# (Linux) Probar grabación con sox
sox -d -r 16000 -c 1 -b 16 /tmp/prueba.wav

# Ver logs del plugin (en OpenCode TUI)
# Los logs se envían al sistema de logging de OpenCode
```

### Equivalentes previstos en Windows (pendiente)

```powershell
# TTS con SAPI5 (voz del sistema, sin dependencias)
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$s.Speak("Hola, soy OpenCode")

# Reproducir un WAV con el reproductor por defecto
Start-Process "C:\ruta\audio.wav"

# Transcripción con whisper.cpp para Windows (cuando esté instalado)
whisper-cli.exe -m C:\ruta\ggml-large-v3-turbo-q5_0.bin -f C:\Temp\prueba.wav -np -nt -l es

# Captura de audio (sin sox): con ffmpeg, si se instala
ffmpeg -f dshow -i audio="Micrófono" -ar 16000 -ac 1 -c:a pcm_s16le C:\Temp\prueba.wav
```

---

> 📁 `C:\Users\evo01\.config\opencode\` · `C:\Users\evo01\.lmstudio\` · `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1`
