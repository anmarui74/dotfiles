// Text-to-speech: edge-tts playback via speak script.

import fs from "node:fs";
import { spawn } from "node:child_process";
import { getSessionTitle } from "./session.js";

// ---- Streaming text cache ----
// Captures text parts during streaming to avoid API calls on idle.

const streamingTexts = new Map();

// Limpieza de iconos/símbolos para la locución (independiente del motor TTS).
const TTS_ANSI_RE = /\x1b\[[0-9;]*[a-zA-Z]|\x1b\][^\x1b]*\x1b\\|[\x1b][PX^_]/g
const TTS_BOX_RE = /[\u2500-\u257f\u2580-\u259f\u25a0-\u25ff]/g
const TTS_EMOJI_RE =
  /[\u{1F300}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{25A0}-\u{25FF}\u{2B05}-\u{2B55}\u{2934}-\u{2935}\u{3030}\u{303D}\u{3297}\u{3299}\u{FE00}-\u{FE0F}\u{200D}]/gu
const TTS_SYMBOLS_RE = /[⬝■▣●▸▀▄╹┃╻━┏┓┗┛┣┫┳┻╋┠┨┷┯┥┝┰┱┲┳┴┵┶┷┸┹┺┻┼┽┾┿╀╁╂╃╄╅╆╇╈╉╊╋▰▱▔▏▎▍▌▋▊▉✓✔✗✘→←↑↓•◦▪▫▬►◄▶◀]/g

function resetStreamingCache() {
  streamingTexts.clear();
}

// ---- Session helpers ----

function roleOf(msg) {
  return msg?.type ?? msg?.role;
}

function textOf(msg) {
  const parts = msg?.content ?? msg?.parts ?? [];
  return parts
    .filter((p) => p?.type === "text")
    .map((p) => p.text || "")
    .join("\n\n")
    .trim();
}

async function getTurnAssistantText(client, api) {
  const route = api.route.current;
  if (route.name !== "session") return null;

  const sessionID = route.params.sessionID;
  const stateMessages = api.state.session.messages(sessionID);
  if (!stateMessages || stateMessages.length === 0) return null;

  const assistantMsgs = [];
  for (let i = stateMessages.length - 1; i >= 0; i--) {
    if (roleOf(stateMessages[i]) === "user") break;
    if (roleOf(stateMessages[i]) === "assistant") {
      assistantMsgs.unshift(stateMessages[i]);
    }
  }
  if (assistantMsgs.length === 0) return null;

  // Fast path: texto directo del mensaje (V2: .content) o caché de streaming.
  const allText = [];
  for (const msg of assistantMsgs) {
    const text = (textOf(msg) || streamingTexts.get(msg.id) || "").trim();
    if (text) allText.push(text);
  }

  // Fallback: pedir el mensaje completo al cliente (por si el estado no trae .content).
  if (allText.length === 0) {
    for (const msg of assistantMsgs) {
      try {
        const fullMsg = await client.session
          .message({ sessionID, messageID: msg.id }, { throwOnError: true })
          .then((r) => r.data);
        const text = textOf(fullMsg);
        if (text) allText.push(text);
      } catch {
        // Skip messages that fail to fetch
      }
    }
  }

  if (allText.length === 0) return null;

  return {
    lastMessageID: assistantMsgs[assistantMsgs.length - 1].id,
    text: allText.join("\n\n"),
  };
}

// ---- Public API for TUI plugin ----

export function registerTTS(api, kv, logger) {
  const client = api.client;

  function toast(message, variant = "info") {
    api.ui.toast({ message, variant, duration: 3000 });
  }

  // ---- Audio pipeline (edge-tts via speak script) ----

  let speakProc = null;

  function killProcs() {
    if (speakProc) {
      try {
        speakProc.kill("SIGTERM");
      } catch {}
      speakProc = null;
    }
  }

  function cleanLine(line) {
    return line
      .replace(TTS_ANSI_RE, '')
      .replace(TTS_BOX_RE, ' ')
      .replace(TTS_EMOJI_RE, ' ')
      .replace(TTS_SYMBOLS_RE, ' ')
      .replace(/```[\s\S]*?```/g, 'código')
      .replace(/`([^`]+)`/g, '$1')
      .replace(/\*\*(.*?)\*\*/g, '$1')
      .replace(/__(.*?)__/g, '$1')
      .replace(/\*(.*?)\*/g, '$1')
      .replace(/_(.*?)_/g, '$1')
      .replace(/~~(.*?)~~/g, '$1')
      .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
      .replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1')
      .replace(/^#{1,6}\s+/gm, '')
      .replace(/^>\s+/gm, '')
      .replace(/^---+\s*$/gm, '')
      .replace(/^[\s]*[-*+]\s+/gm, '')
      .replace(/^[\s]*\d+\.\s+/gm, '')
      .replace(/\s+/g, ' ')
      .replace(/\.([a-zA-Z])/g, ' punto $1')
      .replace(/\s+/g, ' ')
      .replace(/[*_`~]/g, '')
      .trim();
  }

  function cleanTableRow(line) {
    // Limpiar una fila de tabla: quitar pipes exteriores y reemplazar pipes internos
    let cleaned = line.replace(/^\s*\|\s*/, '').replace(/\s*\|\s*$/, '');
    cleaned = cleaned.replace(/\s*\|\s*/g, ': ');
    return cleanLine(cleaned);
  }

  function cleanMarkdown(text) {
    return text
      .split(/\n\n+/)
      .flatMap(p => {
        const rawLines = p.split('\n').filter(l => l.trim().length > 0);
        const isList = rawLines.some(l => /^\s*[-*+]\s/.test(l) || /^\s*\d+\.\s/.test(l));
        const isTable = rawLines.some(l => /^\s*\|/.test(l));

        if (isList) {
          return rawLines
            .map(l => cleanLine(l))
            .filter(l => l.length >= 4);
        } else if (isTable) {
          // Tabla: cada fila se locuta por separado, saltar fila separadora
          return rawLines
            .filter(l => !/^\s*\|?[\s:-]+\|[\s:-]+\|?\s*$/.test(l))
            .map(l => cleanTableRow(l))
            .filter(l => l.length >= 4);
        } else {
          const cleaned = cleanLine(p);
          return cleaned.length >= 4 ? [cleaned] : [];
        }
      })
      .join('\n');
  }

  function speak(text) {
    if (!text) return Promise.resolve();
    const cleaned = cleanMarkdown(text);
    if (!cleaned) return Promise.resolve();

    killProcs();

    const speakScript = "/home/antonio/.local/bin/speak-kokoro-gpu";
    if (!fs.existsSync(speakScript)) {
      logger?.log?.("TTS", `speak script not found: ${speakScript}`, "warn");
      toast(`speak script not found`, "warning");
      return Promise.resolve();
    }

    logger?.log?.("TTS", `Speak requested chars=${cleaned.length}`, "debug");

    return new Promise((resolve) => {
      const proc = spawn(speakScript, [], { stdio: ["pipe", "ignore", "ignore"] });
      speakProc = proc;

      proc.on("close", () => {
        // Solo borrar speakProc si sigue apuntando a este proceso
        // (no al siguiente que ya haya empezado)
        if (speakProc === proc) {
          speakProc = null;
        }
        resolve();
      });

      proc.on("error", (err) => {
        logger?.log?.("TTS", `speak error: ${err.message}`, "error");
        if (speakProc === proc) {
          speakProc = null;
        }
        resolve();
      });

      if (proc?.stdin && !proc.stdin.destroyed) {
        // Enviar todos los parrafos separados por saltos de linea
        // El script speak lee linea por linea y locuta cada parrafo
        // con una pausa natural entre ellos
        proc.stdin.write(cleaned);
        proc.stdin.end();
      }
    });
  }

  // ---- Session-prefixed announcements ----

  async function speakWithSessionPrefix(sessionID, message, suffix) {
    const sessionTitle = await getSessionTitle(client, sessionID);
    const parts = [];
    if (sessionTitle) parts.push(`Session: ${sessionTitle}.`);
    parts.push(message);
    if (suffix) parts.push(suffix);
    await speak(parts.join(" "));
  }

  function stopSpeech() {
    const wasPlaying = speakProc !== null;
    killProcs();
    return wasPlaying;
  }

  // ---- Streaming text cache ----
  // Captures text parts during streaming to avoid API calls on idle.

  api.event.on("message.part.updated", (event) => {
    const part = event.properties?.part;
    if (part?.type === "text") {
      const msgID = part.messageID;
      const prev = streamingTexts.get(msgID) || "";
      const delta = event.properties?.delta;
      const newText = delta ? prev + delta : part.text;
      streamingTexts.set(msgID, newText);
    }
  });

  // ---- Auto mode ----

  let lastSpokenMessageID = null;
  let lastSpokenText = null;
  let speakTimer = null;

  api.event.on("session.execution.started", (event) => {
    resetStreamingCache();
    if (speakTimer) {
      clearTimeout(speakTimer);
      speakTimer = null;
    }
  });

  api.event.on("session.execution.succeeded", () => {
    if (kv.get("tts.mode", "on") !== "on") return;
    // V2 emite session.execution.succeeded varias veces por turno: debounce para
    // locutar una sola vez y evitar eco/dobles lecturas.
    if (speakTimer) clearTimeout(speakTimer);
    speakTimer = setTimeout(async () => {
      speakTimer = null;
      const result = await getTurnAssistantText(client, api);
      if (!result || !result.text) return;
      if (result.lastMessageID === lastSpokenMessageID && result.text === lastSpokenText) return;
      lastSpokenMessageID = result.lastMessageID;
      lastSpokenText = result.text;
      await speak(result.text);
    }, 900);
  });

  api.event.on("permission.asked", async (event) => {
    if (kv.get("tts.mode", "on") !== "on") return;
    await speakWithSessionPrefix(
      event.properties?.sessionID,
      "Permission requested. Please check your screen.",
    );
  });

  api.event.on("question.asked", async (event) => {
    if (kv.get("tts.mode", "on") !== "on") return;
    await speakWithSessionPrefix(
      event.properties?.sessionID,
      "A question needs your answer. Please check your screen.",
    );
  });

  // ---- Manual mode ----

  async function speakLastResponse() {
    const result = await getTurnAssistantText(client, api);
    if (!result || !result.text) {
      toast("No assistant response to speak", "warning");
      return;
    }

    toast("Speaking last response");
    await speak(result.text);
  }

  // ---- Commands ----

  return [
    {
      title: "TTS: speak last response",
      value: "tts.speak-last",
      description: "Read the last assistant response aloud (detailed)",
      keybind: "<leader>s",
      slash: { name: "tts-speak" },
      onSelect() {
        speakLastResponse();
      },
    },
    {
      title: "TTS: toggle",
      value: "tts.mode",
      description: "Toggle auto text-to-speech on/off",
      keybind: "<leader>v",
      slash: { name: "tts-mode" },
      onSelect() {
        const current = kv.get("tts.mode", "on");
        const next = current === "on" ? "off" : "on";
        kv.set("tts.mode", next);
        if (next === "off") stopSpeech();
        toast(next === "on" ? "TTS on (edge-tts)" : "TTS off");
      },
    },
    {
      title: "TTS: stop playback",
      value: "tts.stop",
      description: "Stop current TTS playback",
      keybind: "ctrl+q",
      slash: { name: "tts-stop" },
      onSelect() {
        if (stopSpeech()) toast("TTS stopped");
      },
    },

  ];
}
