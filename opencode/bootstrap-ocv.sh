#!/usr/bin/env bash
# ==============================================================
# Bootstrap script: OpenCode Voice (OCV) - instalación desde limpio
# ==============================================================
# Uso: chmod +x bootstrap-ocv.sh && ./bootstrap-ocv.sh
# ==============================================================
set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
PLUGIN_DIR="${CONFIG_DIR}/opencode-voice-modified"
LOCAL_BIN="${HOME}/.local/bin"
SHARE_DIR="${HOME}/.local/share"
WHISPER_DIR="${SHARE_DIR}/whisper-cpp"

log()  { echo -e "\e[1;32m[INFO]\e[0m $*"; }
warn() { echo -e "\e[1;33m[WARN]\e[0m $*"; }
err()  { echo -e "\e[1;31m[ERR]\e[0m $*" >&2; }

# ---- 1. Dependencias del sistema ----
log "Instalando dependencias del sistema..."
pkexec apt-get update -qq
pkexec apt-get install -y -qq \
  sox \
  pulseaudio-utils \
  whisper-cpp \
  pipx \
  nodejs npm 2>/dev/null || {
  warn "Algunos paquetes no están disponibles en los repositorios, se instalarán por otros medios."
  pkexec apt-get install -y -qq sox pulseaudio-utils pipx nodejs npm 2>/dev/null || true
}

mkdir -p "${LOCAL_BIN}"

# whisper-cli wrapper (forzando idioma español)
if [ ! -f "${LOCAL_BIN}/whisper-cli" ]; then
  log "Creando wrapper whisper-cli..."
  cat > "${LOCAL_BIN}/whisper-cli" << 'WHISPEREOF'
#!/usr/bin/env bash
exec /usr/bin/whisper-cli -l es "$@"
WHISPEREOF
  chmod +x "${LOCAL_BIN}/whisper-cli"
fi

# ---- 2. edge-tts vía pipx ----
if ! pipx list 2>/dev/null | grep -q edge-tts; then
  log "Instalando edge-tts vía pipx..."
  pipx install edge-tts
else
  log "edge-tts ya instalado vía pipx"
fi

# ---- 3. Modelos whisper ----
log "Verificando modelos whisper..."
mkdir -p "${WHISPER_DIR}"

download_model() {
  local name="$1"
  local file="$2"
  if [ ! -f "${WHISPER_DIR}/${file}" ]; then
    log "Descargando modelo whisper: ${name}..."
    wget -q --show-progress \
      "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${file}" \
      -O "${WHISPER_DIR}/${file}"
  else
    log "Modelo ${name} ya presente"
  fi
}

download_model "large-v3-turbo-q5_0" "ggml-large-v3-turbo-q5_0.bin"
download_model "small"              "ggml-small.bin"
download_model "base"               "ggml-base.bin"

# ---- 4. Directorio del plugin ----
log "Creando plugin opencode-voice..."
mkdir -p "${PLUGIN_DIR}/lib"

# ---- 5. plugin/package.json ----
cat > "${PLUGIN_DIR}/package.json" << 'EOF'
{
  "name": "@renjfk/opencode-voice",
  "version": "0.6.0",
  "description": "Speech-to-text and text-to-speech for OpenCode.",
  "license": "MIT",
  "type": "module",
  "main": "index.js",
  "exports": {
    ".": { "import": "./index.js" },
    "./tui": { "import": "./index.js" }
  },
  "files": ["index.js", "lib"]
}
EOF

# ---- 6. plugin/index.js ----
cat > "${PLUGIN_DIR}/index.js" << 'PLUGINEOF'
// opencode-voice: Speech-to-text and text-to-speech for OpenCode.
import fs from "node:fs";
import os from "node:os";
import { registerSTT } from "./lib/stt.js";
import { registerTTS } from "./lib/tts.js";
import { createClient } from "./lib/llm-client.js";
import { createLogger } from "./lib/logger.js";

function loadPromptFile(filePath, logger, name) {
  if (!filePath) return null;
  const resolved = filePath.replace(/^~(?=\/|$)/, os.homedir());
  try {
    const prompt = fs.readFileSync(resolved, "utf-8").trim() || null;
    logger?.log("plugin", prompt ? `Loaded ${name} prompt: ${resolved}` : `Ignored empty ${name} prompt: ${resolved}`, "debug");
    return prompt;
  } catch (err) {
    logger?.log("Plugin", `Failed to load ${name} prompt ${resolved}: ${err.message}`, "warn");
    return null;
  }
}

export default {
  id: "opencode-voice",
  tui: async (api, options) => {
    const { kv } = api;
    const logger = createLogger(api.client);
    logger.log("plugin", "Initializing", "debug");
    const { complete } = createClient(options, logger);
    const prompts = {
      stt: loadPromptFile(options?.sttPrompt, logger, "STT"),
      ttsAuto: loadPromptFile(options?.ttsAutoPrompt, logger, "TTS auto"),
      ttsManual: loadPromptFile(options?.ttsManualPrompt, logger, "TTS manual"),
    };
    const sttCommands = registerSTT(api, kv, complete, prompts, options, logger);
    const ttsCommands = registerTTS(api, kv, logger);
    api.command.register(() => [...sttCommands, ...ttsCommands]);
  },
};
PLUGINEOF

# ---- 7. plugin/lib/*.js ----

cat > "${PLUGIN_DIR}/lib/logger.js" << 'LOGGEREOF'
export function createLogger(client) {
  async function log(scope, message, level = "debug") {
    try {
      await client?.app?.log?.({ body: { service: "opencode-voice", level, message, extra: { scope } } });
    } catch {}
  }
  return { log };
}
LOGGEREOF

cat > "${PLUGIN_DIR}/lib/session.js" << 'SESSIONEOF'
export async function getSessionTitle(client, sessionID) {
  if (!sessionID) return "";
  try {
    const result = await client.session.list();
    const session = result.data?.find((s) => s.id === sessionID);
    return session?.title || "";
  } catch { return ""; }
}

export async function getActiveSessionTitle(client) {
  try {
    const result = await client.session.list();
    if (!result.data || result.data.length === 0) return "";
    const active = result.data.sort((a, b) => b.time.updated - a.time.updated)[0];
    return active?.title || "";
  } catch { return ""; }
}
SESSIONEOF

cat > "${PLUGIN_DIR}/lib/llm-client.js" << 'LLMCLIENTEOF'
export function createClient(pluginOptions, logger) {
  const DEFAULTS = { maxTokens: 2048, reasoningEffort: null, chatTemplateKwargs: null, retries: 2 };

  function getConfig() {
    return {
      endpoint: pluginOptions?.endpoint,
      model: pluginOptions?.model,
      apiKeyEnv: pluginOptions?.apiKeyEnv,
      maxTokens: pluginOptions?.maxTokens ?? DEFAULTS.maxTokens,
      reasoningEffort: pluginOptions?.reasoningEffort ?? DEFAULTS.reasoningEffort,
      chatTemplateKwargs: pluginOptions?.chatTemplateKwargs ?? DEFAULTS.chatTemplateKwargs,
      retries: pluginOptions?.retries ?? DEFAULTS.retries,
    };
  }

  async function complete({ system, prompt, config: overrides }) {
    const cfg = { ...getConfig(), ...overrides };
    if (!cfg.endpoint || !cfg.model) return { text: null, error: "LLM not configured" };
    const apiKey = cfg.apiKeyEnv ? process.env[cfg.apiKeyEnv] : null;
    const endpoint = cfg.endpoint.replace(/\/+$/, "") + "/chat/completions";
    const messages = [];
    if (system) messages.push({ role: "system", content: system });
    messages.push({ role: "user", content: prompt });
    const body = { model: cfg.model, max_tokens: cfg.maxTokens, messages };
    if (cfg.reasoningEffort) body.reasoning_effort = cfg.reasoningEffort;
    if (cfg.chatTemplateKwargs) body.chat_template_kwargs = cfg.chatTemplateKwargs;

    for (let attempt = 0; attempt <= cfg.retries; attempt++) {
      try {
        const response = await fetch(endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json", ...(apiKey ? { Authorization: "Bearer " + apiKey } : {}) },
          body: JSON.stringify(body),
        });
        if (!response.ok) {
          if (attempt < cfg.retries && (response.status === 408 || response.status === 429 || response.status >= 500)) {
            await new Promise(r => setTimeout(r, 250 * 2 ** attempt));
            continue;
          }
          return { text: null, error: `LLM request failed (${response.status})` };
        }
        const data = await response.json();
        const text = data?.choices?.[0]?.message?.content || null;
        if (text) return { text };
        if (attempt < cfg.retries) {
          await new Promise(r => setTimeout(r, 250 * 2 ** attempt));
          continue;
        }
        return { text: null, error: "Empty LLM response" };
      } catch (err) {
        if (attempt < cfg.retries) {
          await new Promise(r => setTimeout(r, 250 * 2 ** attempt));
          continue;
        }
        return { text: null, error: `LLM error: ${err.message}` };
      }
    }
    return { text: null, error: "LLM request failed after retries" };
  }
  return { complete };
}
LLMCLIENTEOF

cat > "${PLUGIN_DIR}/lib/stt.js" << 'STTEOF'
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { spawn, execSync } from "node:child_process";
import { getActiveSessionTitle } from "./session.js";

const WAV_FILE = "/tmp/opencode-stt.wav";
const MODELS_DIRS = [
  path.join(os.homedir(), ".local", "share", "whisper-cpp"),
  "/opt/homebrew/share/whisper-cpp/models",
  "/usr/local/share/whisper-cpp/models",
];
const MODELS = {
  "large-v3-turbo-q5_0": { label: "Large v3 Turbo Q5 (recommended)", file: "ggml-large-v3-turbo-q5_0.bin" },
  "large-v3-turbo-q8_0": { label: "Large v3 Turbo Q8", file: "ggml-large-v3-turbo-q8_0.bin" },
  "large-v3-turbo": { label: "Large v3 Turbo (full)", file: "ggml-large-v3-turbo.bin" },
  "small.en": { label: "Small English", file: "ggml-small.en.bin" },
  small: { label: "Small Multilingual", file: "ggml-small.bin" },
  "base.en": { label: "Base English", file: "ggml-base.en.bin" },
  base: { label: "Base Multilingual", file: "ggml-base.bin" },
  "tiny.en": { label: "Tiny English (fastest)", file: "ggml-tiny.en.bin" },
  tiny: { label: "Tiny Multilingual (fastest)", file: "ggml-tiny.bin" },
};
const DEFAULT_MODEL = "large-v3-turbo-q5_0";
const STT_SYSTEM_PROMPT = `You are a speech-to-text normalizer for a coding assistant CLI.

Clean up raw whisper transcription into a clear, well-punctuated prompt. Rules:
- Fix punctuation, capitalization, and grammar
- Remove filler words (um, uh, like, you know, etc.)
- Keep technical terms, file names, and code references exact
- If the user is dictating code, format it appropriately
- Use the session context above to resolve ambiguous references (e.g. "that function", "the file", "it")
- Output ONLY the cleaned text, nothing else
- Do not add any commentary or explanation
- Keep the user's intent and meaning intact

CRITICAL DOMAIN CORRECTIONS - Fix common STT homophone errors in software engineering contexts:
- "locks" -> "logs" (unless explicitly talking about mutexes/concurrency)
- "note" / "no" -> "node"
- "app and" -> "append"
- "sink" -> "sync"
- "a sink" -> "async"
- "doc" / "talker" -> "docker"
- "cash" -> "cache"
- "rap" -> "wrap"
- "Jason" -> "JSON"
- "get" -> "Git"
- "react" -> "React"
- "types creep" / "type script" -> "TypeScript"
- "bite" -> "byte"
- "string" -> "String"
- "int" -> "Int"
- "bullion" -> "boolean"

Rely heavily on context to fix words that sound similar to programming terminology.`;

export function isOpenRouterEndpoint(endpoint) {
  return /(^https?:\/\/)?([^/]+\.)?openrouter\.ai(\/|$)/i.test(endpoint || "");
}

function getModelsDir() {
  for (const dir of MODELS_DIRS) { if (fs.existsSync(dir)) return dir; }
  return MODELS_DIRS[0];
}

function listInputDevices() {
  try {
    const json = execSync("system_profiler SPAudioDataType -json 2>/dev/null", { encoding: "utf-8", timeout: 5000 });
    const data = JSON.parse(json);
    return (data.SPAudioDataType?.[0]?._items || []).filter(d => d.coreaudio_input_source != null).map(d => d.coreaudio_device_name || d._name);
  } catch { return []; }
}

let soxProc = null, soxStderr = "", recording = false, processing = false;
let sttApiEndpoint = null, sttApiModel = null, sttApiKeyEnv = null;

function forceKillSox(logger) {
  if (soxProc) { try { process.kill(soxProc.pid, "SIGKILL"); } catch {}; soxProc = null; }
  try { execSync("pkill -9 -f 'sox.*opencode-stt'", { stdio: "ignore" }); } catch {}
}

function startRecording(kv, toast, logger) {
  if (soxProc) return;
  forceKillSox(logger);
  try { fs.unlinkSync(WAV_FILE); } catch {}
  soxStderr = "";
  const mic = kv.get("stt.mic", "") || null;
  const inputArgs = mic ? ["-t", "coreaudio", mic] : ["-d"];
  soxProc = spawn("sox", [...inputArgs, "-r", "16000", "-c", "1", "-b", "16", WAV_FILE], { stdio: ["ignore", "ignore", "pipe"], detached: false });
  soxProc.stderr.on("data", (chunk) => { soxStderr += chunk.toString(); });
  soxProc.on("error", (err) => { soxProc = null; if (recording) { recording = false; toast("Recording failed: " + err.message, "error"); } });
  soxProc.on("exit", (code) => { soxProc = null; if (recording && code !== 0 && code !== null && !processing) { recording = false; toast("Recording error"); } });
  recording = true;
}

function stopRecording(logger) { if (soxProc) soxProc.kill("SIGINT"); }

async function waitForSoxExit(logger, timeoutMs = 5000) {
  const start = Date.now();
  while (soxProc && Date.now() - start < timeoutMs) await new Promise(r => setTimeout(r, 100));
  if (soxProc) forceKillSox(logger);
}

function getModelName(kv) { const m = kv.get("stt.model", DEFAULT_MODEL); return MODELS[m] ? m : DEFAULT_MODEL; }
function getModelPath(kv) { return path.join(getModelsDir(), MODELS[getModelName(kv)].file); }

function transcribe(kv, logger) {
  const mp = getModelPath(kv);
  if (!fs.existsSync(mp)) return Promise.resolve({ error: "Model not found: " + getModelName(kv) });
  if (!fs.existsSync(WAV_FILE)) return Promise.resolve({ error: "No recording file" });
  if (fs.statSync(WAV_FILE).size <= 44) return Promise.resolve({ error: "Recording is empty" });
  return new Promise((resolve) => {
    let stdout = "", stderr = "";
    const proc = spawn("whisper-cli", ["-m", mp, "-f", WAV_FILE, "-np", "-nt"], { stdio: ["ignore", "pipe", "pipe"] });
    proc.stdout.on("data", (c) => { stdout += c.toString(); });
    proc.stderr.on("data", (c) => { stderr += c.toString(); });
    const timer = setTimeout(() => { proc.kill("SIGKILL"); resolve({ error: "Transcription timed out (60s)" }); }, 60000);
    proc.on("error", (err) => { clearTimeout(timer); resolve({ error: err.message }); });
    proc.on("exit", (code) => {
      clearTimeout(timer);
      if (code !== 0) { resolve({ error: stderr.trim().split("\n").pop() || "whisper-cli exited (" + code + ")" }); return; }
      resolve({ text: stdout.replace(/\[.*?\]/g, "").replace(/\(.*?\)/g, "").replace(/\s+/g, " ").trim() });
    });
  });
}

async function normalizeTranscription(complete, rawText, sessionTitle, systemPrompt, logger) {
  const contextLine = sessionTitle ? " The user is currently working on: \"" + sessionTitle + "\"" : "";
  return await complete({ system: systemPrompt + contextLine, prompt: "Clean up this speech-to-text transcription:\n\n" + rawText });
}

async function doTranscribePipeline(kv, complete, client, toast, systemPrompt, submit, logger, api) {
  processing = true;
  try {
    stopRecording(logger);
    await waitForSoxExit(logger);
    toast("Transcribing...");
    const result = await transcribe(kv, logger);
    if (result.error) { toast(result.error, "error"); return; }
    if (!result.text) { toast("No speech detected", "warning"); return; }
    if (submit && result.text) {
      await client.tui.appendPrompt({ text: result.text });
      await new Promise(r => setTimeout(r, 50));
      await client.tui.submitPrompt();
    }
    toast(submit ? "Transcription submitted" : "Transcription added to prompt", "success");
  } catch (err) { toast("STT error: " + err.message, "error"); }
  finally { processing = false; recording = false; }
}

export function registerSTT(api, kv, complete, prompts, opts, logger) {
  const client = api.client;
  const systemPrompt = prompts?.stt || STT_SYSTEM_PROMPT;
  function toast(msg, variant = "info") { api.ui.toast({ message: msg, variant, duration: 3000 }); }
  if (opts?.sttEndpoint) { sttApiEndpoint = opts.sttEndpoint; sttApiModel = opts.sttModel || "whisper-large-v3-turbo"; sttApiKeyEnv = opts.sttApiKeyEnv || null; }

  return [
    { title: "STT: record/transcribe", value: "stt.record", description: "Toggle recording; press again to stop and transcribe", keybind: "ctrl+r", slash: { name: "stt-record" },
      onSelect() { if (processing) return; if (recording) { toast("Stopping, transcribing..."); doTranscribePipeline(kv, complete, client, toast, systemPrompt, true, logger, api); } else { startRecording(kv, toast, logger); if (recording) toast("Recording... press again to transcribe"); } } },
    { title: "STT: submit recording", value: "stt.submit", description: "Stop recording, transcribe, and submit prompt", keybind: "<leader>r", slash: { name: "stt-submit" },
      onSelect() { if (processing) { toast("STT busy, please wait..."); return; } if (!recording) { toast("No recording in progress", "warning"); return; } toast("Stopping, transcribing..."); doTranscribePipeline(kv, complete, client, toast, systemPrompt, true, logger, api); } },
    { title: "STT: cancel recording", value: "stt.stop", description: "Cancel current recording", slash: { name: "stt-stop" },
      onSelect() { if (recording) { recording = false; forceKillSox(logger); toast("Recording cancelled"); } } },
    { title: "STT: select model", value: "stt.model", description: "Choose whisper model", slash: { name: "stt-model" },
      async onSelect() {
        const current = getModelName(kv);
        api.ui.dialog.replace(() => api.ui.DialogSelect({
          title: "Select whisper model", current,
          options: Object.entries(MODELS).map(([key, v]) => ({ title: v.label, value: key, onSelect() { kv.set("stt.model", key); toast("Whisper model: " + v.label); api.ui.dialog.clear(); } })),
        }));
      } },
    { title: "STT: select microphone", value: "stt.mic", description: "Choose audio input device", slash: { name: "stt-mic" },
      onSelect() {
        const current = kv.get("stt.mic", "");
        const devices = listInputDevices();
        if (devices.length === 0) { toast("No input devices found"); return; }
        api.ui.dialog.replace(() => api.ui.DialogSelect({
          title: "Select microphone", current,
          options: [{ title: "System default", value: "", onSelect() { kv.set("stt.mic", ""); toast("Mic: system default"); api.ui.dialog.clear(); } }, ...devices.map((name) => ({ title: name, value: name, onSelect() { kv.set("stt.mic", name); toast("Mic: " + name); api.ui.dialog.clear(); } }))],
        }));
      } },
  ];
}
STTEOF

cat > "${PLUGIN_DIR}/lib/tts.js" << 'TTSEOF'
import fs from "node:fs";
import { spawn } from "node:child_process";
import { getSessionTitle } from "./session.js";

const streamingTexts = new Map();
function resetStreamingCache() { streamingTexts.clear(); }

async function getTurnAssistantText(client, api) {
  const route = api.route.current;
  if (route.name !== "session") return null;
  const sessionID = route.params.sessionID;
  const stateMessages = api.state.session.messages(sessionID);
  if (!stateMessages || stateMessages.length === 0) return null;
  const assistantIDs = [];
  for (let i = stateMessages.length - 1; i >= 0; i--) {
    if (stateMessages[i].role === "user") break;
    if (stateMessages[i].role === "assistant") assistantIDs.unshift(stateMessages[i].id);
  }
  if (assistantIDs.length === 0) return null;
  const allText = [];
  for (const msgID of assistantIDs) {
    const cached = streamingTexts.get(msgID);
    if (cached && cached.trim()) allText.push(cached.trim());
  }
  if (allText.length > 0) return { lastMessageID: assistantIDs[assistantIDs.length - 1], text: allText.join("\n\n") };
  for (const msgID of assistantIDs) {
    try {
      const fullMsg = await client.session.message({ sessionID, messageID: msgID }, { throwOnError: true }).then(r => r.data);
      const text = (fullMsg?.parts || []).filter(p => p.type === "text").map(p => p.text || "").join("\n\n").trim();
      if (text) allText.push(text);
    } catch {}
  }
  if (allText.length === 0) return null;
  return { lastMessageID: assistantIDs[assistantIDs.length - 1], text: allText.join("\n\n") };
}

export function registerTTS(api, kv, logger) {
  const client = api.client;
  function toast(msg, variant = "info") { api.ui.toast({ message: msg, variant, duration: 3000 }); }

  let speakProc = null;
  function killProcs() { if (speakProc) { try { speakProc.kill("SIGKILL"); } catch {}; speakProc = null; } }

  function cleanMarkdown(text) {
    return text.replace(/```[\s\S]*?```/g, 'código').replace(/`([^`]+)`/g, '$1').replace(/\*\*(.*?)\*\*/g, '$1').replace(/__(.*?)__/g, '$1').replace(/\*(.*?)\*/g, '$1').replace(/_(.*?)_/g, '$1').replace(/~~(.*?)~~/g, '$1').replace(/\[([^\]]*)\]\([^)]*\)/g, '$1').replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1').replace(/^#{1,6}\s+/gm, '').replace(/^>\s+/gm, '').replace(/^---+\s*$/gm, '').replace(/^[\s]*[-*+]\s+/gm, '').replace(/^[\s]*\d+\.\s+/gm, '').replace(/\s+/g, ' ').trim();
  }

  function speak(text) {
    if (!text) return Promise.resolve();
    const line = cleanMarkdown(text);
    if (!line) return Promise.resolve();
    killProcs();
    const speakScript = "/home/antonio/.local/bin/speak";
    if (!fs.existsSync(speakScript)) { toast("speak script not found", "warning"); return Promise.resolve(); }
    return new Promise((resolve) => {
      speakProc = spawn(speakScript, [], { stdio: ["pipe", "ignore", "ignore"] });
      speakProc.on("close", () => { speakProc = null; resolve(); });
      speakProc.on("error", () => { speakProc = null; resolve(); });
      if (speakProc?.stdin && !speakProc.stdin.destroyed) { speakProc.stdin.write(line + "\n"); speakProc.stdin.end(); }
    });
  }

  async function speakWithSessionPrefix(sessionID, message, suffix) {
    const sessionTitle = await getSessionTitle(client, sessionID);
    const parts = [];
    if (sessionTitle) parts.push("Session: " + sessionTitle + ".");
    parts.push(message);
    if (suffix) parts.push(suffix);
    await speak(parts.join(" "));
  }

  function stopSpeech() { const was = speakProc !== null; killProcs(); return was; }

  api.event.on("message.part.updated", (event) => {
    const part = event.properties?.part;
    if (part?.type === "text") {
      const msgID = part.messageID;
      const prev = streamingTexts.get(msgID) || "";
      const delta = event.properties?.delta;
      streamingTexts.set(msgID, delta ? prev + delta : part.text);
    }
  });

  let lastSpokenMessageID = null, wasBusy = false;
  api.event.on("session.status", (event) => {
    if (event.properties?.status?.type === "busy") { resetStreamingCache(); wasBusy = true; }
  });

  api.event.on("session.idle", async () => {
    if (kv.get("tts.mode", "on") !== "on" || !wasBusy) return;
    wasBusy = false;
    const result = await getTurnAssistantText(client, api);
    if (!result || !result.text) return;
    if (result.lastMessageID === lastSpokenMessageID) return;
    lastSpokenMessageID = result.lastMessageID;
    await speak(result.text);
  });

  api.event.on("permission.asked", async (event) => {
    if (kv.get("tts.mode", "on") !== "on") return;
    await speakWithSessionPrefix(event.properties?.sessionID, "Permission requested. Please check your screen.");
  });

  api.event.on("question.asked", async (event) => {
    if (kv.get("tts.mode", "on") !== "on") return;
    await speakWithSessionPrefix(event.properties?.sessionID, "A question needs your answer. Please check your screen.");
  });

  async function speakLastResponse() {
    const result = await getTurnAssistantText(client, api);
    if (!result || !result.text) { toast("No assistant response to speak", "warning"); return; }
    toast("Speaking last response");
    await speak(result.text);
  }

  return [
    { title: "TTS: speak last response", value: "tts.speak-last", description: "Read the last assistant response aloud", keybind: "<leader>s", slash: { name: "tts-speak" }, onSelect() { speakLastResponse(); } },
    { title: "TTS: toggle", value: "tts.mode", description: "Toggle auto text-to-speech on/off", keybind: "<leader>v", slash: { name: "tts-mode" },
      onSelect() { const cur = kv.get("tts.mode", "on"); const next = cur === "on" ? "off" : "on"; kv.set("tts.mode", next); if (next === "off") stopSpeech(); toast(next === "on" ? "TTS on (edge-tts)" : "TTS off"); } },
    { title: "TTS: stop playback", value: "tts.stop", description: "Stop current TTS playback", keybind: "escape", slash: { name: "tts-stop" }, onSelect() { if (stopSpeech()) toast("TTS stopped"); } },
  ];
}
TTSEOF

# ---- 8. script speak (edge-tts) ----
log "Instalando script speak..."
cat > "${LOCAL_BIN}/speak" << 'SPEAKEOF'
#!/usr/bin/env python3
import sys, subprocess, tempfile, os, time, re

ANSI_RE = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]|\x1b\][^\x1b]*\x1b\\|\x1b[PX^_]|[^\x1b]*\x1b\\|\x1b][0-9;]*[\x07\x1b]|\x1b[=<>FGH]|\x1b[NOPQ\\]')
BOX_RE = re.compile(r'[\u2500-\u257f\u2500-\u257f\u2580-\u259f\u25a0-\u25ff]')

VOICE = os.environ.get("SPEAK_VOICE", "es-ES-AlvaroNeural")
RATE = os.environ.get("SPEAK_RATE", "+5%")
PITCH = os.environ.get("SPEAK_PITCH", "+0Hz")

def speak(text):
    text = text.strip()
    if not text or len(text) < 3: return
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f: fname = f.name
    try:
        cmd = ["edge-tts", "--voice", VOICE, "--rate", RATE, "--pitch", PITCH, "--text", text, "--write-media", fname]
        subprocess.run(cmd, capture_output=True, timeout=30)
        subprocess.run(["paplay", fname], capture_output=True)
    except Exception: pass
    finally:
        try: os.unlink(fname)
        except OSError: pass

def clean_line(text):
    text = ANSI_RE.sub("", text)
    text = BOX_RE.sub("", text)
    text = ' '.join(text.split())
    return text.strip()

def main():
    buffer = ""
    for line in sys.stdin:
        line = line.rstrip("\n")
        print(line, flush=True)
        clean = clean_line(line)
        if not clean or len(clean) < 4: continue
        if clean.lower() in ('build', 'opencode zen', 'max', 'tab', 'agents', 'ctrl+p', 'commands', 'tip'): continue
        buffer += clean + " "
        if clean.endswith((".", "?", "!", ":", "...")):
            speak(buffer)
            time.sleep(0.2)
            buffer = ""
    if buffer.strip(): speak(buffer)

if __name__ == "__main__": main()
SPEAKEOF
chmod +x "${LOCAL_BIN}/speak"

# ---- 9. tui.json ----
log "Configurando tui.json..."
cat > "${CONFIG_DIR}/tui.json" << 'TUIEOF'
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "session_rename": "none"
  },
  "plugin": [
    "/home/antonio/.config/opencode/opencode-voice-modified"
  ]
}
TUIEOF

# ---- 10. npm dependencies del plugin ----
log "Instalando dependencias npm..."
cd "${CONFIG_DIR}"
if [ ! -f package.json ]; then
  cat > package.json << 'PKGEOF'
{
  "dependencies": {
    "@opencode-ai/plugin": "1.17.13",
    "@renjfk/opencode-voice": "^0.6.0"
  }
}
PKGEOF
fi
npm install --no-audit --no-fund 2>/dev/null || npm install

# ---- 11. Verificación final ----
log ""
log "=================================="
log " Instalación completada"
log "=================================="
log ""
log "Archivos instalados:"
ls -la "${PLUGIN_DIR}/"
ls -la "${PLUGIN_DIR}/lib/"
ls -la "${LOCAL_BIN}/speak"
ls -la "${CONFIG_DIR}/tui.json"
ls -la "${WHISPER_DIR}/"
log ""
log "Para usar OCV:"
log "  1. edge-tts está listo (voz: es-ES-AlvaroNeural)"
log "  2. Modelos whisper: large-v3-turbo-q5_0, small, base"
log "  3. Inicia opencode en el TUI"
log "  4. Usa Ctrl+R para grabar voz, Leader+V para toggle TTS"
log ""
log "Variables de entorno disponibles:"
log "  SPEAK_VOICE  (voz edge-tts, ej: es-ES-AlvaroNeural)"
log "  SPEAK_RATE   (velocidad, ej: +5%)"
log "  SPEAK_PITCH  (tono, ej: +0Hz)"
