// opencode-voice: Speech-to-text and text-to-speech for OpenCode.
//
// Modificado (v0.6.0): se eliminó la normalización por LLM y la transcripción vía API,
//     que no se usaban en este setup.
//
// STT: record with sox, transcribe locally with whisper-cpp, append to the prompt.
// TTS: auto-speak assistant responses (or read on demand) via speak-kokoro-gpu,
//      with local regex markdown cleanup (no LLM).
//
// Prerequisites:
//   STT: sox + whisper-cpp (whisper-cli) + ggml model in ~/.local/share/whisper-cpp/
//   TTS: ~/.local/bin/speak-kokoro-gpu
//
// Commands:
//   /stt-record (ctrl+r)   - start/stop recording + transcribe
//   /stt-submit (leader+r) - stop recording + transcribe + submit
//   /stt-stop              - cancel recording
//   /stt-model             - select whisper model
//   /stt-mic               - select microphone
//   /tts-speak (leader+s)  - read last response aloud
//   /tts-mode (leader+v)   - toggle auto TTS on/off
//   /tts-stop (ctrl+q)     - stop playback

import { registerSTT } from "./lib/stt.js";
import { registerTTS } from "./lib/tts.js";
import { createLogger } from "./lib/logger.js";

export default {
  id: "opencode-voice",
  tui: async (api) => {
    const logger = createLogger(api.client);
    try {
      const { kv } = api;
      logger.log("plugin", "Initializing", "debug");

      const sttCommands = registerSTT(api, kv, logger);
      const ttsCommands = registerTTS(api, kv, logger);

      api.command.register(() => [...sttCommands, ...ttsCommands]);
    } catch (err) {
      console.error("PLUGIN: opencode-voice tui error:", err);
      logger.log("plugin", `TUI error: ${err.message}`, "error");
    }
  },
};
