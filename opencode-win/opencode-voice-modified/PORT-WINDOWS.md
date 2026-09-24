# 🎙️ Port a Windows de opencode-voice-modified

Nota del port del plugin `@renjfk/opencode-voice` v0.6.0 (ESM) de Linux a Windows.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

> Solo se han parcheado las partes dependientes del sistema operativo. La lógica del plugin se mantiene idéntica.

---

## 📑 Índice
1. [Origen y destino](#origen-y-destino)
2. [Cambios aplicados](#cambios-aplicados)
3. [Rutas usadas](#rutas-usadas)
4. [Limitaciones conocidas](#limitaciones-conocidas)

---

## Origen y destino

- **Origen:** `D:\Linux\Config\opencode\sesion-opencode\opencode-voice-modified\`
- **Destino:** `C:\Users\evo01\.config\opencode\opencode-voice-modified\`

---

## Cambios aplicados

### `lib/stt.js`
- `WAV_FILE` → `path.join(os.tmpdir(), "opencode-stt.wav")` (temp de Windows).
- `MODELS_DIRS` → añadida `C:\Users\evo01\.local\models\whisper` como **primera** ruta.
- **Grabación** (`startRecording`): se sustituye `sox` por **ffmpeg** con DirectShow:
  - Ejecutable: `C:\Users\evo01\.local\bin\ffmpeg\bin\ffmpeg.exe`
  - Args: `-f dshow -i "audio=<mic>" -r 16000 -ac 1 -c:a pcm_s16le -y <wav>`
  - `mic` por defecto: `Micrófono (TONOR TD510 Air Mic)`
  - `stdio: ["pipe","ignore","pipe"]` (stdin en pipe para poder parar) + `windowsHide`.
- **Parada** (`stopRecording`): escribe `"q\n"` en `stdin` y lo cierra; además `kill()` como respaldo.
- **forceKillSox**: eliminado `execSync("pkill ...")`; queda solo `process.kill`.
- **Transcripción**: `whisper-cli` → `C:\Users\evo01\.local\bin\whisper.cpp-cuda\Release\whisper-cli.exe` con `windowsHide`.

### `lib/tts.js`
- Importados `node:os` y `node:path`.
- `speakScript` → `C:\Users\evo01\.config\opencode\voice\speak.ps1`.
- Spawn → `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <speak.ps1> -Text <texto>` con `windowsHide`.
- Eliminado el envío de texto por `stdin` (ya no se usa).

### Sin cambios
- `index.js`, `package.json`, `lib/llm-client.js`, `lib/logger.js`, `lib/session.js` (cross-platform).

---

## Rutas usadas

| Elemento | Ruta |
|----------|------|
| ffmpeg | `C:\Users\evo01\.local\bin\ffmpeg\bin\ffmpeg.exe` |
| whisper-cli (CUDA) | `C:\Users\evo01\.local\bin\whisper.cpp-cuda\Release\whisper-cli.exe` |
| Modelos whisper | `C:\Users\evo01\.local\models\whisper` |
| WAV temporal | `%TEMP%\opencode-stt.wav` |
| speak.ps1 | `C:\Users\evo01\.config\opencode\voice\speak.ps1` |
| Micrófono por defecto | `Micrófono (TONOR TD510 Air Mic)` |

---

## Limitaciones conocidas

- `listInputDevices()` sigue usando `system_profiler` (macOS); en Windows devuelve lista vacía. La grabación funciona igual porque el micrófono por defecto está fijado. El comando `/stt-mic` mostrará "No input devices found".
- Las rutas Linux/macOS de `MODELS_DIRS` se conservan como respaldo inofensivo (no existen en Windows).

> 📁 `C:\Users\evo01\.config\opencode\opencode-voice-modified\`
