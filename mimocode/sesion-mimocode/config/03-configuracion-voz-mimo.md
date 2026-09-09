# 🎙️ Configuración de Voz MiMoCode

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 09/09/2026 · rev. 09/09/2026 | Antonio |
> Replicación exacta de `ocv` de OpenCode con plugin `mimocode-voice-modified` independiente

---

## 📑 Índice
1. [Arquitectura](#arquitectura)
2. [Componentes](#componentes)
3. [Plugin registrado](#plugin-registrado)
4. [Atajos](#atajos)
5. [Prerrequisitos](#prerrequisitos)

---

## Arquitectura

MiMoCode usa el plugin independiente `mimocode-voice-modified` para STT y TTS:

**STT**
`sox` record 16k mono → `whisper-cli` CUDA → normalización LLM Qwen 3.8

**TTS**
Texto asistente → `cleanMarkdown()` → `~/.local/bin/speak-kokoro-gpu` Kokoro v1.0 GPU voz `ef_dora` → `paplay`

Auto-TTS en `session.idle`, anuncios en `permission.asked`/`question.asked`.

---

## Componentes

- STT: `~/.local/bin/sox` + `~/.local/bin/whisper-cli` → `~/.local/share/whisper-cpp/bin/whisper-cli`
- LLM normalizado: `http://localhost:4001/v1` modelo `models-qwen3.8-9b`
- TTS: `~/.local/bin/speak-kokoro-gpu` modelos `~/.local/share/kokoro/`
- Plugin: `/home/antonio/.config/mimocode/mimocode-voice-modified/index.js`

---

## Plugin registrado

El plugin TUI se registra en `~/.config/mimocode/tui.json` (archivo TUI separado, NO en `mimocode.jsonc` que es para plugins de servidor con `server()`):

```jsonc
{
  "$schema": "https://mimo.xiaomi.com/mimocode/tui.json",
  "keybinds": {
    "session_rename": "none"
  },
  "plugin": [
    ["/home/antonio/.config/mimocode/mimocode-voice-modified/index.js", {
      "endpoint": "http://localhost:4001/v1",
      "model": "models-qwen3.8-9b"
    }]
  ]
}
```

> ⚠️ **Clave:** los plugins TUI (que exportan `tui()`) van en `tui.json`, no en `mimocode.jsonc`. Ponerlos en `mimocode.jsonc` da error: `must default export an object with server()`.
>
> Los campos `voice.asr_model` y `voice.control_model` son valores por defecto del esquema MiMoCode (`xiaomi/mimo-v2.5-asr` y `xiaomi/mimo-v2.5`). No es necesario declararlos en el JSONC a menos que se quiera usar un modelo diferente.

---

## Atajos

| Acción | Atajo |
|--------|-------|
| Iniciar/parar STT | `Ctrl+R` |
| Parar locución TTS | `Ctrl+Q` |
| TTS hablar manual | `Leader+S` |
| Cambiar modo TTS | `Leader+V` |

>`Ctrl+R` estaba asignado por defecto a renombrar la sesión; se desactiva con `keybinds.session_rename: "none"` en `tui.json` para liberar la tecla para la grabación de voz.

Cambios realizados en `lib/stt.js` y `lib/tts.js` para evitar colisiones con MiMoCode.

---

## Prerrequisitos

- `sox` instalado en `~/.local/bin/sox`
- `whisper-cli` CUDA disponible
- LM Studio proxy en puerto 4001 con modelo Qwen 3.8 cargado
- Kokoro GPU y `speak-kokoro-gpu` operativo

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
