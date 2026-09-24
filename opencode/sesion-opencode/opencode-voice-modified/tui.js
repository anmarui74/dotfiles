// opencode-voice — entrada para OpenCode V2 (@opencode/plugin/tui).
//
// Adapta el plugin original de V1 (index.js) a la API de plugins CLI/TUI de
// OpenCode 2 mediante un "puente" que expone a lib/stt.js y lib/tts.js la misma
// superficie que esperaban de la API V1 (api.kv, api.ui, api.command,
// api.event, api.route, api.state.session, api.client).
//
// La lógica de STT/TTS de lib/ NO se toca.
import { Plugin } from "@opencode/plugin/tui"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { registerSTT } from "./lib/stt.js"
import { registerTTS } from "./lib/tts.js"
import { createClient } from "./lib/llm-client.js"
import { createLogger } from "./lib/logger.js"

const KV_FILE = path.join(os.homedir(), ".local", "state", "opencode", "voice-kv.json")

function createKV() {
  let data = {}
  try {
    data = JSON.parse(fs.readFileSync(KV_FILE, "utf8"))
  } catch {
    data = {}
  }
  const save = () => {
    try {
      fs.mkdirSync(path.dirname(KV_FILE), { recursive: true })
      fs.writeFileSync(KV_FILE, JSON.stringify(data, null, 2))
    } catch {
      // La persistencia no debe romper la voz.
    }
  }
  return {
    get(key, def) {
      return key in data ? data[key] : def
    },
    set(key, value) {
      data[key] = value
      save()
    },
  }
}

function loadPromptFile(filePath, logger, name) {
  if (!filePath) return null
  const resolved = filePath.replace(/^~(?=\/|$)/, os.homedir())
  try {
    const prompt = fs.readFileSync(resolved, "utf-8").trim() || null
    logger?.log("plugin", prompt ? `Loaded ${name} prompt: ${resolved}` : `Ignored empty ${name} prompt: ${resolved}`, "debug")
    return prompt
  } catch (err) {
    logger?.log("Plugin", `Failed to load ${name} prompt ${resolved}: ${err.message}`, "warn")
    return null
  }
}

// Los keybinds se pasan TAL CUAL: V2 usa el mismo formato que V1, con angulos
// ("<leader>r", "ctrl+r").
// ⚠️ NO convertir "<leader>" a "leader+": el parser de V2 interpreta "leader+r"
// como una secuencia LITERAL de teclas que empieza por "l", lo que deja la "l"
// como prefijo pendiente y hace que se trague su primera pulsacion en TODA la
// TUI (bug real detectado el 16/09/2026; ver issue #49244).
function normalizeBind(bind) {
  if (!bind) return undefined
  return bind
}

function normalizeRoute(current) {
  if (!current) return { name: "unknown" }
  if (current.name) return current
  if (current.type === "session") return { name: "session", params: { sessionID: current.sessionID } }
  return { name: current.type ?? "unknown", params: current }
}

// V2 no expone el compositor a los plugins CLI: `context.ui` tiene
// dialog/toast/format/router/panel/tabs/slot, pero NO `prompt` (verificado con
// un plugin de sondeo). La vía nativa para entregar texto es
// `context.data.session.prompt({ sessionID, text })`, que es la misma función
// que usa la TUI al pulsar Enter: hace POST a /api/session/<id>/prompt con
// pintado optimista del mensaje. Se conserva el contrato de dos pasos de
// lib/stt.js (appendPrompt -> submitPrompt) guardando el texto entre ambos.
function currentSessionID(context) {
  const route = context.ui.router.current()
  if (!route) return undefined
  return (
    route.sessionID ??
    route.params?.sessionID ??
    (route.name === "session" ? route.params?.sessionID : undefined)
  )
}

function createApi(context, kv) {
  let stashedPrompt = null
  const client = new Proxy(context.client ?? {}, {
    get(target, prop) {
      if (prop === "tui") {
        return {
          appendPrompt: async ({ text } = {}) => {
            stashedPrompt = text ?? ""
          },
          submitPrompt: async () => {
            const sessionID = currentSessionID(context)
            const text = stashedPrompt
            stashedPrompt = null
            if (!text) return
            if (!sessionID) throw new Error("no hay una sesión activa donde enviar la transcripción")
            try {
              // Vía nativa del cliente interno (misma que usa la TUI al enviar).
              await context.data.session.prompt({ sessionID, text })
            } catch (err) {
              // Fallback: cliente generado de V2.
              if (context.client?.session?.prompt) {
                await context.client.session.prompt({ sessionID, text })
              } else {
                throw err
              }
            }
          },
        }
      }
      return target[prop]
    },
  })

  return {
    client,
    kv,
    route: {
      get current() {
        return normalizeRoute(context.ui.router.current())
      },
    },
    state: {
      session: {
        messages: (sessionID) => context.data.session.message.list(sessionID) ?? [],
        get: (sessionID) => context.data.session.get(sessionID),
      },
    },
    ui: {
      toast(input, variant, duration) {
        if (typeof input === "string") {
          context.ui.toast.show({ message: input, variant, duration: duration ?? 3000 })
        } else if (input && typeof input === "object") {
          context.ui.toast.show(input)
        }
      },
      dialog: {
        replace(render) {
          try {
            render()
          } catch {
            // noop
          }
        },
        clear() {
          try {
            context.ui.dialog.clear()
          } catch {
            // noop
          }
        },
      },
      DialogSelect(config) {
        Promise.resolve()
          .then(() =>
            context.ui.dialog.select({
              title: config?.title,
              current: config?.current,
              options: (config?.options ?? []).map((option) => ({
                title: option.title,
                value: option.value,
                description: option.description,
                disabled: option.disabled,
              })),
            }),
          )
          .then((selected) => {
            if (selected === undefined || selected === null) return
            const option = (config?.options ?? []).find((item) => item.value === selected)
            option?.onSelect?.(selected)
          })
          .catch(() => {
            // cancelado o no disponible
          })
        return null
      },
    },
    // En V2 la capa de teclado solo puede registrarse dentro del árbol de
    // componentes (dentro de un slot), no durante setup. Se realiza en setup().
    command: {
      register() {
        // no-op: la registración real ocurre en el slot "app"
      },
    },
    event: {
      on(type, handler) {
        // V2 renombró "question.asked" al sistema de formularios.
        const mapped = type === "question.asked" ? "form.created" : type
        try {
          return context.data.on(mapped, (event) => {
            handler({ type: mapped, properties: event?.data ?? event })
          })
        } catch {
          return () => {}
        }
      },
    },
  }
}

export default Plugin.define({
  id: "opencode-voice",
  async setup(context) {
    const kv = createKV()
    const api = createApi(context, kv)
    const logger = createLogger(api.client)
    logger.log("plugin", "Initializing", "debug")

    const options = context.options ?? {}
    const { complete } = createClient(options, logger)

    const prompts = {
      stt: loadPromptFile(options?.sttPrompt, logger, "STT"),
      ttsAuto: loadPromptFile(options?.ttsAutoPrompt, logger, "TTS auto"),
      ttsManual: loadPromptFile(options?.ttsManualPrompt, logger, "TTS manual"),
    }

    const sttCommands = registerSTT(api, kv, complete, prompts, options, logger)
    const ttsCommands = registerTTS(api, kv, logger)
    const commands = [...sttCommands, ...ttsCommands]

    // La capa de teclado/comandos debe registrarse dentro del árbol de
    // componentes; usamos el slot "app" (patrón documentado en V2).
    return context.ui.slot({
      append: "app",
      render: () => {
        context.keymap.layer(() => ({
          mode: "global",
          commands: commands.map((command) => ({
            id: command.value ?? command.title,
            title: command.title,
            description: command.description,
            bind: normalizeBind(command.keybind),
            palette: true,
            slash: command.slash,
            run: async () => {
              await command.onSelect?.()
            },
          })),
        }))
        return null
      },
    })
  },
})
