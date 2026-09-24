// Text-to-speech: edge-tts playback via speak script.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn, execSync } from "node:child_process";
import { getSessionTitle } from "./session.js";

// ---- Streaming text cache ----
// Captures text parts during streaming to avoid API calls on idle.

const streamingTexts = new Map();

function resetStreamingCache() {
  streamingTexts.clear();
}

// ---- Session helpers ----

async function getTurnAssistantText(client, api) {
  const route = api.route.current;
  if (route.name !== "session") return null;

  const sessionID = route.params.sessionID;
  const stateMessages = api.state.session.messages(sessionID);
  if (!stateMessages || stateMessages.length === 0) return null;

  const assistantIDs = [];
  for (let i = stateMessages.length - 1; i >= 0; i--) {
    if (stateMessages[i].role === "user") break;
    if (stateMessages[i].role === "assistant") {
      assistantIDs.unshift(stateMessages[i].id);
    }
  }
  if (assistantIDs.length === 0) return null;

  // Fast path: use cached streaming text (no API call)
  const allText = [];
  for (const msgID of assistantIDs) {
    const cached = streamingTexts.get(msgID);
    if (cached && cached.trim()) {
      allText.push(cached.trim());
    }
  }
  if (allText.length > 0) {
    return {
      lastMessageID: assistantIDs[assistantIDs.length - 1],
      text: allText.join("\n\n"),
    };
  }

  // Fallback: fetch full message via API (only if cache was missed)
  for (const msgID of assistantIDs) {
    try {
      const fullMsg = await client.session
        .message({ sessionID, messageID: msgID }, { throwOnError: true })
        .then((r) => r.data);

      const textParts = (fullMsg?.parts || []).filter((p) => p.type === "text");
      const text = textParts
        .map((p) => p.text || "")
        .join("\n\n")
        .trim();
      if (text) allText.push(text);
    } catch {
      // Skip messages that fail to fetch
    }
  }

  if (allText.length === 0) return null;

  return {
    lastMessageID: assistantIDs[assistantIDs.length - 1],
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
      const pid = speakProc.pid;
      if (process.platform === "win32" && pid) {
        try { execSync(`taskkill /T /F /PID ${pid}`, { stdio: "ignore" }); } catch {}
      }
      try { speakProc.kill("SIGTERM"); } catch {}
      speakProc = null;
    }
    // Cortar cualquier reproduccion en curso (ffplay) para no superponer locuciones
    if (process.platform === "win32") {
      try { execSync("taskkill /F /IM ffplay.exe", { stdio: "ignore" }); } catch {}
    }
  }

  function cleanLine(line) {
    return line
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

  const VOICE_LOG = path.join(os.tmpdir(), "opencode-voice.log");
  function vlog(m) { try { fs.appendFileSync(VOICE_LOG, new Date().toISOString() + " TTS " + m + "\n"); } catch {} }

  function speak(text) {
    if (!text) return Promise.resolve();
    const cleaned = cleanMarkdown(text);
    vlog("speak called raw=" + text.length + " cleaned=" + (cleaned ? cleaned.length : 0));
    if (!cleaned) return Promise.resolve();

    killProcs();

    const speakScript = path.join(os.homedir(), ".config", "opencode", "voice", "speak.ps1");
    if (!fs.existsSync(speakScript)) {
      logger?.log?.("TTS", `speak script not found: ${speakScript}`, "warn");
      toast(`speak script not found`, "warning");
      return Promise.resolve();
    }

    logger?.log?.("TTS", `Speak requested chars=${cleaned.length}`, "debug");

    return new Promise((resolve) => {
      const proc = spawn(
        "powershell.exe",
        ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", speakScript],
        { stdio: ["pipe", "ignore", "ignore"], windowsHide: true },
      );
      speakProc = proc;
      // Texto por stdin (evita problemas de comillas/caracteres especiales en el arg)
      try {
        if (proc.stdin && !proc.stdin.destroyed) {
          proc.stdin.write(cleaned);
          proc.stdin.end();
        }
      } catch {}
      vlog("speak spawn pid=" + (proc.pid || "?"));

      proc.on("close", () => {
        // Solo borrar speakProc si sigue apuntando a este proceso
        // (no al siguiente que ya haya empezado)
        if (speakProc === proc) {
          speakProc = null;
        }
        resolve();
      });

      proc.on("error", (err) => {
        vlog("speak error: " + err.message);
        logger?.log?.("TTS", `speak error: ${err.message}`, "error");
        if (speakProc === proc) {
          speakProc = null;
        }
        resolve();
      });
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
  let wasBusy = false;

  api.event.on("session.status", (event) => {
    if (event.properties?.status?.type === "busy") {
      resetStreamingCache();
      wasBusy = true;
    }
  });

  api.event.on("session.idle", async (event) => {
    vlog("idle fired mode=" + kv.get("tts.mode", "on") + " wasBusy=" + wasBusy);
    if (kv.get("tts.mode", "on") !== "on") return;
    if (!wasBusy) return;
    wasBusy = false;

    // Use cached streaming text (fast, no API call)
    const result = await getTurnAssistantText(client, api);
    vlog("idle text=" + (result && result.text ? result.text.length : 0));
    if (!result || !result.text) return;

    if (result.lastMessageID === lastSpokenMessageID) return;
    lastSpokenMessageID = result.lastMessageID;

    await speak(result.text);
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
