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

// ⚠️ V2 cambió el formato de los mensajes: usa `type` ("assistant"/"user"/…)
// y `content[]` ({type:"text",text}) en lugar de `role` y `parts[]`. lib/tts.js
// espera el formato V1 (`role` + `parts[]`), así que se adapta aquí SIN tocar
// la lógica de lib/.
function adaptMessage(msg) {
  if (!msg || typeof msg !== "object") return msg
  const adapted = { ...msg }
  if (adapted.type && !adapted.role) adapted.role = adapted.type
  if (Array.isArray(adapted.content) && !adapted.parts) {
    adapted.parts = adapted.content.map((c) => {
      if (!c || typeof c !== "object") return c
      if (c.type === "text" || c.type === "reasoning") return { ...c, text: c.text }
      if (c.type === "tool") return { ...c, tool: c.name, state: c.state }
      return c
    })
  }
  return adapted
}

function createApi(context, kv) {
  let stashedPrompt = null
  // Evita disparar el "busy" más de una vez por ejecución (execution.started
  // y/o next.text.started pueden llegar ambos). Se resetea al terminar (idle).
  let busyFired = false
  const client = new Proxy(context.client ?? {}, {
    get(target, prop) {
      if (prop === "session") {
        // Adapta client.session.message() para devolver mensajes en formato V1.
        const sessionApi = target.session ?? {}
        return new Proxy(sessionApi, {
          get(sTarget, sProp) {
            if (sProp === "message") {
              return async (input, opts) => {
                const res = await sTarget.message(input, opts)
                if (res && res.data) return { ...res, data: adaptMessage(res.data) }
                return res
              }
            }
            return sTarget[sProp]
          },
        })
      }
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
        messages: (sessionID) =>
          (context.data.session.message.list(sessionID) ?? []).map(adaptMessage),
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
        const register = (name, adapt) => {
          try {
            return context.data.on(name, (event) => {
              const data = event?.data ?? event
              const props = adapt ? adapt(data) : data
              if (props == null) return
              handler({ type: name, properties: props })
            })
          } catch {
            return () => {}
          }
        }

        // ⚠️ V2 renombró los eventos. Se traducen los nombres V1 que usa lib/ a
        // los de V2 (verificado con "opencode api" + binario 2.0.16).
        if (type === "question.asked") {
          // V2: sistema de formularios.
          return register("form.created")
        }

        if (type === "session.idle") {
          // V2: session.execution.succeeded / failed / interrupted.
          const unsubs = [
            "session.execution.succeeded",
            "session.execution.failed",
            "session.execution.interrupted",
          ].map((name) =>
            register(name, (data) => {
              busyFired = false
              return data
            }),
          )
          return () => unsubs.forEach((u) => { try { u() } catch {} })
        }

        if (type === "session.status") {
          // V2: el "busy" llega como session.execution.started; si por lo que sea
          // no se emite, se usa session.text.started como respaldo. Solo se
          // dispara una vez por ejecución para no resetear el caché a mitad.
          const fireBusy = () => {
            if (busyFired) return null
            busyFired = true
            return { status: { type: "busy" } }
          }
          const unsubs = [
            register("session.execution.started", fireBusy),
            register("session.text.started", fireBusy),
          ]
          return () => unsubs.forEach((u) => { try { u() } catch {} })
        }

        if (type === "message.part.updated") {
          // V2: session.text.delta / .ended (⚠️ SIN prefijo "next.").
          // Se traduce al formato V1 que espera lib/tts.js (part + delta).
          const unsubs = [
            register("session.text.delta", (data) => ({
              part: { type: "text", messageID: data?.assistantMessageID },
              delta: data?.delta,
            })),
            register("session.text.ended", (data) => ({
              part: { type: "text", messageID: data?.assistantMessageID, text: data?.text },
            })),
          ]
          return () => unsubs.forEach((u) => { try { u() } catch {} })
        }

        return register(type)
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

    // Diagnóstico opcional: si existe %TEMP%\voice-debug-on, registra en
    // %TEMP%\opencode-voice-events.log los eventos que llegan al plugin.
    try {
      const dbgFlag = path.join(os.tmpdir(), "voice-debug-on")
      if (fs.existsSync(dbgFlag)) {
        const dbgFile = path.join(os.tmpdir(), "opencode-voice-events.log")
        const dbg = (m) => { try { fs.appendFileSync(dbgFile, new Date().toISOString() + " " + m + "\n") } catch {} }
        dbg("=== plugin loaded ===")
        try {
          context.data.listen?.((e) => {
            const t = e?.details?.type ?? e?.type ?? "?"
            if (/text\.(started|delta|ended)$|execution\./.test(t)) {
              let payload = ""
              try { payload = " " + JSON.stringify(e?.details?.data ?? e?.data ?? {}).slice(0, 240) } catch {}
              dbg("listen " + t + payload)
            } else {
              dbg("listen " + t)
            }
          })
        } catch (e) { dbg("listen error: " + e.message) }
        for (const n of [
          "session.execution.started",
          "session.execution.succeeded",
          "session.text.started",
          "session.text.delta",
          "session.text.ended",
        ]) {
          try { context.data.on(n, () => dbg("on " + n)) } catch (e) { dbg("on error " + n + ": " + e.message) }
        }
      }
    } catch {}

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
