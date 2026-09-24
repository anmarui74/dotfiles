// nvidia-filter — filtro de modelos NVIDIA para OpenCode V2.
//
// En V2 el campo V1 `provider.nvidia.whitelist` se IGNORA ("unsupported legacy
// setting"). Este plugin de servidor lo sustituye: lee el whitelist de los
// perfiles (la misma fuente de verdad que mantiene check-nvidia-whitelist.sh) y
// elimina del catálogo los modelos NVIDIA que no estén en él, de modo que el
// selector /models no muestre modelos retirados ni descartados.
//
// API V2 (v2.0.5): el transform de modelos es `ctx.model.transform`, cuyo
// editor expone `{ list(providerID?), get(providerID, modelID), update, remove }`.
// NOTA: `ctx.catalog.transform` NO existe en este build (fallaba con
// "undefined is not an object (evaluating 'ctx.catalog.transform')").
import fs from "node:fs"
import os from "node:os"
import path from "node:path"

function loadWhitelist(): string[] {
  const dir = path.join(os.homedir(), ".config", "opencode")
  const candidates = [process.env.OPENCODE_CONFIG, path.join(dir, "opencode.json")].filter(
    (item): item is string => typeof item === "string" && item.length > 0,
  )
  for (const file of candidates) {
    try {
      const json = JSON.parse(fs.readFileSync(file, "utf8"))
      const list = json?.provider?.nvidia?.whitelist ?? json?.providers?.nvidia?.whitelist
      if (Array.isArray(list) && list.length > 0) {
        return list.filter((item: unknown): item is string => typeof item === "string")
      }
    } catch {
      // probar el siguiente candidato
    }
  }
  return []
}

export default {
  id: "antonio.nvidia-filter",
  async setup(ctx: any) {
    if (typeof ctx?.model?.transform !== "function") {
      console.warn("[nvidia-filter] ctx.model.transform no disponible en este build; whitelist no aplicado")
      return
    }
    // Relee la whitelist desde disco en cada transform, para que los cambios
    // en opencode.json (o check-nvidia-whitelist.sh) se apliquen sin reiniciar
    // el servicio.
    await ctx.model.transform((editor: any) => {
      const allowed = new Set(loadWhitelist())
      if (allowed.size === 0) return
      for (const model of editor.list("nvidia")) {
        if (!allowed.has(model.id)) editor.remove("nvidia", model.id)
      }
    })
  },
}
