# 🕓 Historial de migración a OpenCode V2 y decisiones retiradas
Cronología técnica de la migración V1 → V2, vigilantes retirados y decisiones que ya no aplican.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo (archivo histórico) | 24/10/2026 · rev. 24/10/2026 | Antonio |

> Este documento nace el 24/10/2026 al adelgazar `AGENTS.md` (731 → ~450 líneas):
> la cronología se movió aquí para no inyectarla en cada petición. `AGENTS.md`
> conserva solo las reglas y procedimientos operativos, con punteros a este archivo.

---

## 📑 Índice
1. [Migración V1 → V2](#migración-v1--v2)
2. [Vigilancias retiradas](#vigilancias-retiradas)
3. [Whitelist NVIDIA rehecha](#whitelist-nvidia-rehecha)
4. [Decisiones sobre skills](#decisiones-sobre-skills)

---

## Migración V1 → V2

Antonio migró el **16/09/2026** de OpenCode V1 (1.18.x) a **V2** (2.1.3 a fecha 24/10/2026). Cambios que afectaron a esta configuración:

| Tema | Antes (V1) | Ahora (V2) |
|---|---|---|
| Config de la TUI | `tui.json` | **`cli.json`** (archivado el V1 en `~/Config/opencode/legacy/`) |
| Ciclo de agentes | `Tab` | **`Shift+Tab`** (`agent.cycle`); fallback `Ctrl+X` → `A` |
| Plugins TUI | `index.ts` | `plugins/<nombre>/tui.tsx` con `Plugin.define({ id, setup })` |
| Modelo pequeño | `small_model` | **`agents.title.model`** (agente oculto `title`) |
| Providers bloqueados | `disabled_providers` | **`policies`** (`action: provider.use`, `effect: deny`) |
| LSP | Servidores LSP integrados | **No existe**: sin diagnósticos ni indicador |
| `instructions` | Cargaba ficheros | Se acepta pero **no carga nada** (`AGENTS.md` se autodescubre) |

### Detalles por fecha

- **16/09/2026 · tecla de agente y barra lateral.** El ciclo pasó a `Shift+Tab`, verificado en una TUI aislada (`opencode --standalone` + `ESC[Z`). En `cli.json` solo se sobrescribe `session.rename` → `f8`. Ese día se retiró `tui.json` y se creó la barra lateral estilo MiMoCode (`plugins/sidebar-mimo/tui.tsx`, `prepend: "sidebar.content"`) con Context (tokens, %, límite, t/s, coste), directorio de trabajo, instrucciones y versión. El footer nativo se desactiva para no duplicar la ruta.
- **16/09/2026 · bloque `lsp` retirado** de `opencode.json` (copia en `~/Config/opencode/legacy/lsp-block-v1.json`). Para tipos y lint, por terminal: `basedpyright`, `tsc --noEmit`, `cargo clippy`, `shellcheck`.
- **17/09/2026 · bug `prompt_cache_key` resuelto.** El runtime OpenAI-compatible de V2 2.0.3 inyectaba `prompt_cache_key` y la API de NVIDIA lo rechazaba (`Validation: Unsupported parameter(s)`). Corregido en 2.0.4+ (PR [#49121](https://github.com/anomalyco/opencode/pull/49121), merge 15/09/2026). El issue [#49240](https://github.com/anomalyco/opencode/issues/49240) (duplicado de [#45113](https://github.com/anomalyco/opencode/issues/45113)) se cerró el 05/10/2026 confirmando el arreglo. Se retiró el vigilante `check-nvidia-prompt-cache.sh`.
- **19/09/2026 · sintaxis canónica.** Los 3 perfiles pasaron a `providers`, `agents`, `permissions`, `mcp.servers`, `system`, `disabled`. Se retiró `instructions` por inerte. ⚠️ El schema público `opencode.ai/config.json` aún solo valida claves V1, así que el editor puede marcarlas como desconocidas.
- **21/09/2026 · últimas claves V1.** `small_model` → `agents.title.model` y `disabled_providers` → `policies`. Se añadió `model` raíz (`opencode-go/deepseek-v4.1-flash` en base/cloud, `local/qwen3.8-9b` en local) y `session.tps: true` en `cli.json`.
- **22/10/2026 · `policies` y actualizaciones.** La wiki V2 marcó `experimental.policies` como deprecada; la canónica es `policies` en la raíz. Las actualizaciones pasan a **CachyOS/pacman** (`opencode` en `cachyos-extra-znver4`, `opencode-desktop-bin` en `chaotic-aur`), con el updater interno desactivado (`"update": "disable"`).
- **22/10/2026 · provider local.** En V2 el id `lmstudio` **no resuelve** (choca con el builtin). Se usa el provider propio `local` (`@opencode/ai/providers/openai-compatible`, `baseURL` = proxy `http://localhost:4001/v1`) con el modelo `qwen3.8-9b`.
- **NVIDIA whitelist (permanente).** La clave `providers.nvidia.whitelist` está **ignorada** por V2: no tiene equivalente. La aplica el plugin `plugins/nvidia-filter/index.ts` (`ctx.model.transform`), que lee la lista de `opencode.json`. `check-nvidia-whitelist.sh` sigue siendo la fuente de verdad.
- **Ollama retirado.** Se usa LM Studio (ver `02-configuracion-lmstudio.md`).

---

## Vigilancias retiradas

| Vigilante | Retirado | Motivo |
|---|---|---|
| `check-timeline-fix.sh` + timer | 12/10/2026 | El PR #26861 quedó **cerrado sin mergear** (10/10/2026). `timeline-completo` sigue siendo necesario (la TUI mantiene el límite de ~6 peticiones) |
| `check-fix.sh` + timer | 12/10/2026 | El issue [#39164](https://github.com/anomalyco/opencode/issues/39164) se cerró el 11/10/2026 como **not_planned** (cierre masivo de issues de V1 al salir V2). El tool calling local funciona en V2 |
| `check-key-l-issue.sh` + timer | 16/09/2026 | La tecla `l` tragada **no era un bug de OpenCode**: era `normalizeBind()` del plugin de voz convirtiendo `<leader>r` en `leader+r`. Corregido, verificado (4 pulsaciones → 4 `l`) y el issue [#49244](https://github.com/anomalyco/opencode/issues/49244) se cerró |
| `check-nvidia-prompt-cache.sh` + timer | 17/09/2026 | Bug corregido en OpenCode 2.0.4+ (ver arriba) |

> ⚠️ Lección que se mantiene vigente: cuando un vigilante se retira, se retiran
> **script + timer + service** y se deja constancia aquí del motivo y la fecha.

---

## Whitelist NVIDIA rehecha

### 24/10/2026 · pasada completa de la metodología (8 + 1 modelos)

Se rehizo la lista desde cero con datos reales: HTTP 200, generación de ~200 tokens para medir
velocidad (mínimo 10 tok/s) y tool calling con `tool_choice: auto`. Los casos dudosos se
**reintentaron** (3 mediciones) antes de decidir.

**Quedan 6 modelos:** `nemotron-3.5-super-vl-120b-a12b` (93,8 tok/s, el agente),
`nemotron-3.5-lightning-30b-a3b` (81,1), `nemotron-3.5-bolt-e4b` (53,9, nuevo),
`llama-3.2-11b-vision-instruct` (39,4), `nemotron-3-ultra-550b-a55b` (35,0) y
`muse-glimmer-30b` (11,1).

| Salieron | Motivo |
|---|---|
| `nemotron-3-super-120b-a12b` | HTTP **404**: sin endpoint de chat (antes 93,4 tok/s) |
| `openai/gpt-oss-20b` | **8,0 tok/s** estables (8,1 / 8,0 / 4,6): bajo el mínimo de 10 (antes 34,2) |
| `nemotron-3-nano-omni-30b-a3b-reasoning` | **503 en 2 de 3** intentos de tool calling: inestable |

> 🔎 Lección: un modelo puede **degradarse sin retirarse**. El check quincenal solo comprobaba
> HTTP 200 de los modelos existentes, así que una caída de 34 → 8 tok/s pasaba desapercibida.
> Candidata a mejora: que el check mida también velocidad de los ya presentes.

---

## Decisiones sobre skills

### 24/10/2026 · de 50 skills activas a 4

**Diagnóstico:** las 50 skills activas inyectaban **21.485 caracteres de descripciones**
(≈ 6.100 tokens) en **cada petición**. La base de sesiones (87 sesiones, 14.157 mensajes,
05/07 → 24/10/2026) demuestra que **no se invocó ninguna**: la única skill usada fue
`customize-opencode` (built-in, 5 veces).

**Decisión:** dejar 4 con descripción recortada a ≤140 caracteres y mover las otras 46 a
`skills-disabled/` (recuperables con un `mv`).

| Skill activa | Por qué |
|---|---|
| `python-pro` | Lenguaje real: vllm, tokenizers, harnesses, scripts |
| `debugging-wizard` | Diagnóstico de fallos, uso más frecuente |
| `cli-developer` | Scripts, argv, completions |
| `prompt-engineer` | Prompts de agentes (Hermes, OpenCode) |

**Resultado:** 6.100 → ~110 tokens por petición (98 % menos), 3,1 MB → 272 KB en activas.

**Criterio para el futuro:** una skill solo se activa si (a) la tarea se repite y (b) el
agente necesita *cómo hacerla*, no datos. Las candidatas naturales son las **propias**
(metodología NVIDIA, protocolo de backups, revisión de manuales), no las genéricas de
terceros. Revisar el contador de invocaciones (`session_message`, `tool = "skill"`) antes
de reactivar nada.

---

> 📁 `~/.config/opencode/documentacion/12-historial-migracion-v2.md` · espejo en
> `~/Config/opencode/documentacion/` y en el vault de Obsidian (`💻 12 Historial de migración V2.md`)
