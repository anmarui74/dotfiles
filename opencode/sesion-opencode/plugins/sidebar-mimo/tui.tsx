/** @jsxImportSource @opentui/solid */
// opencode-sidebar-mimo — barra lateral estilo MiMoCode para OpenCode V2.
//
// Ubicación oficial de plugins CLI/TUI de V2: <config>/plugins/<nombre>/tui.tsx
// (auto-descubierto). NO lleva entrypoint de servidor (index.ts) a propósito:
// este plugin es solo de TUI.
//
// Añade a la barra lateral:
//   - Context (tokens, % usado, límite del modelo, t/s y coste)
//   - Directorio de trabajo
//   - Instrucciones (AGENTS.md / ficheros de config)
// Requiere desactivar el bloque nativo `opencode.sidebar.context` en cli.json
// (entrada "-opencode.sidebar.context") para no duplicar el Context.
import { Plugin } from "@opencode/plugin/tui"
import { createMemo, For, Show } from "solid-js"
import os from "node:os"
import path from "node:path"
import fs from "node:fs"

const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" })

function compact(value: number): string {
  if (!Number.isFinite(value) || value <= 0) return "0"
  if (value >= 1_000_000) {
    const millions = value / 1_000_000
    return `${Number.isInteger(millions) ? millions : millions.toFixed(1)}M`
  }
  if (value >= 1_000) return `${Math.round(value / 1_000)}k`
  return `${value}`
}

type Usage = {
  tokens: number
  percent: number | null
  limit: number | null
  tps: number | null
  cost: number
}

function ContextView(props: { context: any; sessionID: string }) {
  const theme = () => props.context.theme
  const session = createMemo(() => props.context.data.session.get(props.sessionID))
  const messages = createMemo(() => props.context.data.session.message.list(props.sessionID) ?? [])
  const cost = createMemo(() => props.context.data.session.cost(props.sessionID) ?? 0)
  const models = createMemo(() => {
    const s = session()
    if (!s?.location) return [] as any[]
    return (props.context.data.location.model.list(s.location) ?? []) as any[]
  })

  const state = createMemo<Usage>(() => {
    const last = [...messages()]
      .reverse()
      .find((item: any) => item?.type === "assistant" && item?.tokens && item.tokens.output > 0)
    if (!last) return { tokens: 0, percent: null, limit: null, tps: null, cost: cost() }
    const t = last.tokens
    const tokens =
      (t.input ?? 0) + (t.output ?? 0) + (t.reasoning ?? 0) + (t.cache?.read ?? 0) + (t.cache?.write ?? 0)
    const model = models().find((m: any) => m?.providerID === last.model?.providerID && m?.id === last.model?.id)
    const limit = model?.limit?.context ?? null
    const created = last.time?.created
    const completed = last.time?.completed
    const tps =
      created && completed && completed > created && t.output > 0
        ? (t.output / (completed - created)) * 1000
        : null
    return {
      tokens,
      percent: limit ? Math.round((tokens / limit) * 100) : null,
      limit,
      tps,
      cost: cost(),
    }
  })

  return (
    <box>
      <text fg={theme().text.default}>
        <b>Context</b>
      </text>
      <text fg={theme().text.subdued}>{state().tokens.toLocaleString("en-US")} tokens</text>
      <text fg={theme().text.subdued}>{state().percent ?? 0}% used</text>
      <Show when={state().limit}>
        <text fg={theme().text.subdued}>limit {compact(state().limit!)}</text>
      </Show>
      <Show when={state().tps !== null}>
        <text fg={theme().text.subdued}>{Math.round(state().tps!)} t/s</text>
      </Show>
      <text fg={theme().text.subdued}>{money.format(state().cost)} spent</text>
    </box>
  )
}

function WorkingDirectoryView(props: { context: any }) {
  const directory = createMemo(() => {
    const dir = props.context.location?.directory
    if (!dir) return ""
    try {
      return props.context.ui.format.path(dir)
    } catch {
      return dir
    }
  })
  return (
    <Show when={directory()}>
      <box>
        <text fg={props.context.theme.text.default}>
          <b>Directorio de trabajo</b>
        </text>
        <text fg={props.context.theme.text.subdued}>{directory()}</text>
      </box>
    </Show>
  )
}

// Quita comentarios // y /* */ y comas finales para tolerar JSONC.
function stripJsonComments(input: string): string {
  let out = ""
  let inString = false
  let escaped = false
  let inLine = false
  let inBlock = false
  for (let i = 0; i < input.length; i++) {
    const ch = input[i]
    const next = input[i + 1]
    if (inLine) {
      if (ch === "\n") {
        inLine = false
        out += ch
      }
      continue
    }
    if (inBlock) {
      if (ch === "*" && next === "/") {
        inBlock = false
        i++
      }
      continue
    }
    if (inString) {
      out += ch
      if (escaped) escaped = false
      else if (ch === "\\") escaped = true
      else if (ch === '"') inString = false
      continue
    }
    if (ch === '"') {
      inString = true
      out += ch
      continue
    }
    if (ch === "/" && next === "/") {
      inLine = true
      i++
      continue
    }
    if (ch === "/" && next === "*") {
      inBlock = true
      i++
      continue
    }
    out += ch
  }
  return out.replace(/,(\s*[}\]])/g, "$1")
}

function loadInstructionPaths(): string[] {
  const dir = path.join(os.homedir(), ".config", "opencode")
  for (const file of ["opencode.json", "opencode.jsonc"]) {
    try {
      const raw = fs.readFileSync(path.join(dir, file), "utf8")
      const json = JSON.parse(stripJsonComments(raw))
      const list = Array.isArray(json.instructions) ? json.instructions : []
      return list
        .filter((item: unknown): item is string => typeof item === "string")
        .map((item: string) => (path.isAbsolute(item) ? item : path.join(dir, item)))
    } catch {
      // probar el siguiente formato
    }
  }
  return []
}

function InstructionsView(props: { context: any }) {
  const entries = loadInstructionPaths()
  return (
    <Show when={entries.length > 0}>
      <box>
        <text fg={props.context.theme.text.default}>
          <b>Instrucciones</b>
        </text>
        <For each={entries}>
          {(item) => (
            <box flexDirection="row" gap={1}>
              <text flexShrink={0} fg={props.context.theme.text.subdued}>
                •
              </text>
              <text fg={props.context.theme.text.subdued} wrapMode="word">
                {item}
              </text>
            </box>
          )}
        </For>
      </box>
    </Show>
  )
}

export default Plugin.define({
  id: "antonio.sidebar-mimo",
  setup(context) {
    // prepend: el grupo va ARRIBA del todo en la barra lateral
    // (por delante del bloque nativo de MCP). Orden interno:
    // Context -> Directorio de trabajo -> Instrucciones.
    const disposeContent = context.ui.slot({
      prepend: "sidebar.content",
      render: (props: any) => (
        <>
          <ContextView context={context} sessionID={props.sessionID} />
          <WorkingDirectoryView context={context} />
          <InstructionsView context={context} />
        </>
      ),
    })
    // Versión de OpenCode al final de la barra lateral
    const disposeFooter = context.ui.slot({
      append: "sidebar.footer",
      render: () => <text fg={context.theme.text.subdued}>{`OpenCode ${context.app.version}`}</text>,
    })
    return () => {
      disposeContent?.()
      disposeFooter?.()
    }
  },
})
