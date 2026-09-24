# 📋 Los Tres Perfiles de `mimocode.jsonc`
Perfiles global, local y cloud, MCPs y plugin de voz.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 23/09/2026 | Antonio |

> Perfiles global / local / cloud, MCPs y plugin de voz

---

## 📑 Índice
1. [Descripción general](#descripción-general)
2. [Perfil global (`mimocode.jsonc`)](#perfil-global)
3. [Perfil local (`profiles/local`)](#perfil-local)
4. [Perfil cloud (`profiles/cloud`)](#perfil-cloud)
5. [Agentes](#agentes)
6. [Comparativa de perfiles](#comparativa)
7. [Plugin de voz](#plugin-de-voz)
8. [Cambio entre perfiles](#cambio-entre-perfiles)

---

## Descripción general

Existen **tres configuraciones** para MiMoCode, basadas en OpenCode:

| Perfil | Ubicación | Propósito |
|--------|-----------|-----------|
| Global | `~/.config/mimocode/mimocode.jsonc` | Perfil por defecto - Todos los agentes y plugin de voz |
| Local | `~/.config/mimocode/profiles/local/mimocode.jsonc` | Agente local primario, MCPs esenciales |
| Cloud | `~/.config/mimocode/profiles/cloud/mimocode.jsonc` | Sin LM Studio, agente cloud primario |

La selección se hace con `MIMOCODE_CONFIG_DIR` en los lanzadores `start-mimo*.sh`. **Nada se copia sobre el global**.

| Lanzador | Config | Agente | LM Studio | Voz |
|----------|--------|--------|-----------|-----|
| `mimo` | Global | nvidia | ✅ | ✅ Plugin mimocode-voice-modified |
| `mimo-local` | profiles/local | local | ✅ | ✅ Plugin |
| `mimo-cloud` | profiles/cloud | cloud | ❌ | ✅ Plugin |

> 🎙️ Las funciones `mimo-voz`, `mimo-voz-local` y `mimo-voz-cloud` se **retiraron el 16/09/2026**: el plugin de voz se carga en los 3 lanzamientos, así que bastan las tres de arriba.

---

## Perfil global

### Archivo: `~/.config/mimocode/mimocode.jsonc`

Perfil por defecto para `mimo`. Incluye `model` principal, `model_groups.lite` (modelo barato), `default_agent`, `permission` con `external_directory`, los **7 agentes**, los 3 proveedores (`opencode-go`, `nvidia`, `lmstudio`) y los **5 MCP**. **El plugin de voz NO va aquí** (los plugins TUI van en `tui.json`).

```jsonc
{
  "$schema": "https://mimo.xiaomi.com/mimocode/config.json",
  "model": "nvidia/meta/muse-glimmer-30b",
  "model_groups": {
    "lite": "opencode-go/deepseek-v4.1-flash"
  },
  "default_agent": "nvidia",
  "share": "manual",
  "autoupdate": "notify",
  "agent":    { /* 7 agentes — ver sección «Agentes» */ },
  "provider": { /* opencode-go, nvidia (whitelist 7), lmstudio */ },
  "mcp":      { /* context7, filesystem, memory, fetch, sequential_thinking */ }
}
```

> ⚠️ **`small_model` NO se usa en MiMoCode**: no está definido en ninguno de los 3 perfiles. El modelo barato se fija con `model_groups.lite` (`opencode-go/deepseek-v4.1-flash` en global y cloud; `lmstudio/models-qwen3.8-9b` en local).
>
> ⚠️ El `model` top-level del global sigue en `nvidia/meta/muse-glimmer-30b`, pero el **agente** `nvidia` —que es el `default_agent`— apunta desde el 23/09/2026 a `nvidia/nvidia/nemotron-3-ultra-550b-a55b`. El top-level no lo usa ningún agente.

---

## Perfil local

### Archivo: `~/.config/mimocode/profiles/local/mimocode.jsonc`

Replica `opencode-local.json` con esquema MiMoCode. Agente por defecto `local`. Carga el modelo local (LM Studio/Qwen) y declara sus MCP **explícitamente**: activos solo `filesystem`, `memory` y `fetch` (`context7` y `sequential_thinking` con `enabled: false`). Es lo que muestra la TUI al arrancar: 3 MCP `Connected`.

**Atajos de voz:** `Ctrl+R` grabar/parar STT, `Ctrl+Q` parar locución.

---

## Perfil cloud

### Archivo: `~/.config/mimocode/profiles/cloud/mimocode.jsonc`

Replica `opencode-cloud.json`. Desactiva el proveedor local (`disabled_providers: ["lmstudio"]`), `default_agent: cloud`, `model` = `opencode-go/deepseek-v4.1-flash`, `share`/`autoupdate` definidos y `permission.external_directory` añadido. Carga los **5 MCP** igual que el perfil global, pero **NO** carga el modelo local.

> 🔴 **El agente `local` va con `disable: true`** (22/09/2026), replicando el `disabled: true` de `opencode-cloud.json`. Es coherente con `disabled_providers: ["lmstudio"]`: no habría modelo local que usar. El agente `title` también apunta a la nube (`opencode-go/deepseek-v4.1-flash`).

> 🤖 **Modelo de `opencode-go` = `deepseek-v4.1-flash` (11/09/2026):** en los 3 perfiles se sustituyó `opencode-go/deepseek-v4-flash` por `opencode-go/deepseek-v4.1-flash` en el modelo de trabajo (`model` top-level y agentes `build`, `plan` y `cloud`) y en `model_groups.lite`. `provider.opencode-go` no admite un campo de "modelo por defecto" en el esquema, así que el predeterminado se fija en las claves `model` / `model_groups` / `agent.<nombre>.model`.

---

## TUI config: `~/.config/mimocode/tui.json`

Los plugins TUI y los keybinds van en el archivo TUI separado `tui.json` (NO en `mimocode.jsonc`, cuya clave `plugin` es para plugins de servidor):

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

---

## Agentes

Los **7 agentes** están replicados en los 3 perfiles a partir de la configuración **activa** de OpenCode
(`~/.config/opencode/opencode.json`, `opencode-local.json` y `opencode-cloud.json`), traducidos al
esquema de MiMoCode:

| OpenCode | MiMoCode |
|----------|----------|
| `system` | `prompt` |
| `permissions: [{action, resource, effect}]` | `permission: {…}` |
| `disabled: true` | `disable: true` |
| provider `local/…` | provider `lmstudio/…` |

| Agente | `mode` | Global | Local | Cloud |
|--------|--------|--------|-------|-------|
| `title` | (def.) | `lmstudio/models-qwen3.8-9b` | `lmstudio/models-qwen3.8-9b` | `opencode-go/deepseek-v4.1-flash` |
| `build` | (def.) | `opencode-go/deepseek-v4.1-flash` | `opencode-go/deepseek-v4.1-flash` | `opencode-go/deepseek-v4.1-flash` |
| `plan` | (def.) | `opencode-go/deepseek-v4.1-flash` | `opencode-go/deepseek-v4.1-flash` | `opencode-go/deepseek-v4.1-flash` |
| `local` | `primary` | `lmstudio/models-qwen3.8-9b` | `lmstudio/models-qwen3.8-9b` | 🔴 `disable: true` |
| `cloud` | `primary` | `opencode-go/deepseek-v4.1-flash` | `opencode-go/deepseek-v4.1-flash` | `opencode-go/deepseek-v4.1-flash` |
| `nvidia` | `all` | `nvidia/nvidia/nemotron-3-ultra-550b-a55b` | igual | igual |
| `multimodal` | `all` | `opencode-go/mimo-v2.5` | igual | igual |

> 🤖 `build` y `plan` conservan el prompt que en OpenCode era `{file:./prompts/read-agents.txt}`, con la ruta adaptada a `~/.config/mimocode/AGENTS.md` y el texto **inline** (MiMoCode ya carga `AGENTS.md` vía `instructions`, así que es un recordatorio redundante pero fiel al original). `multimodal` mantiene su prompt de sistema original.
> 🔐 El agente `cloud` declara `permission { actor: allow, task: allow }` — el equivalente MiMoCode del `permissions: [{action: "subagent"}]` de OpenCode — para poder delegar en subagentes.
> ⚠️ `mode: all` permite usar el agente tanto como primario (Shift+Tab) como de subagente; `primary` lo limita a primario.
> ⚠️ `nvidia` ya no lleva `temperature: 1` / `top_p: 0.95` (eran un ajuste específico de Muse Glimmer); ahora apunta a **Nemotron 3 Ultra 550B**, actualizado el 23/09/2026.
> ✅ Verificado con `mimo debug config` el 23/09/2026: los 3 perfiles cargan los 7 agentes sin error de esquema.

Comprobación rápida de coherencia (debe listar **7** agentes en los tres, con `local` `OFF` solo en cloud):

```bash
for p in "" profiles/local profiles/cloud; do
  echo "== ${p:-GLOBAL}"
  MIMOCODE_CONFIG_DIR="$HOME/.config/mimocode/$p" mimo debug config 2>/dev/null \
    | python3 -c "import json,sys;a=json.load(sys.stdin)['agent'];print(' agentes',len(a),'|',{k:(v.get('mode','def'),'OFF' if v.get('disable') else v.get('model')) for k,v in a.items()})"
done
```

> 📌 El `default_agent` **no** se replica: en OpenCode el global usa `cloud`, pero en MiMoCode el global sigue en `nvidia` (decisión propia del 17/09/2026); local y cloud mantienen `local` y `cloud`.

---

## Comparativa

| Característica | Global | Local | Cloud |
|----------------|--------|-------|-------|
| `model` | nvidia/meta/muse-glimmer-30b | lmstudio/models-qwen3.8-9b | opencode-go/deepseek-v4.1-flash |
| `default_agent` | nvidia | local | cloud |
| Agentes | **7** | **7** | **7** (`local` desactivado) |
| LM Studio | ✅ | ✅ | ❌ |
| MCP activos | **5** (todos) | **3**: `filesystem`, `memory`, `fetch` | **5** (todos) |
| MCP desactivados | - | `context7`, `sequential_thinking` | - |
| LSP | 11 servidores | 11 servidores | 11 servidores |
| `disabled_providers` | - | - | `lmstudio` |
| `share` | manual | manual | manual |
| `autoupdate` | notify | false | false |
| `permission.external_directory` | /tmp/** ask | /tmp/** ask | /tmp/** ask |
| Memoria | `~/.config/mimocode/data/memory/memory.jsonl` | compartida | compartida |
| Plugin voz | ✅ | ✅ | ✅ |

> ⚠️ **Merge de configuraciones:** `MIMOCODE_CONFIG_DIR` hace **merge** sobre la config global (no la sustituye). Los perfiles local/cloud heredan claves del global como `voice`, `permission`, etc. No son configuraciones completamente aisladas. La memoria MCP es compartida entre los 3 perfiles (misma ruta `data/memory/memory.jsonl`).

> 📌 **Los bloques `lsp` y `mcp` se repiten COMPLETOS en los 3 archivos a propósito:** cada perfil es autodescriptivo y se entiende por sí solo, sin tener que mirar otro archivo. Lo único que cambia es el `enabled` de cada MCP según el perfil (ver tabla). ⚠️ Al añadir o modificar un LSP o un MCP hay que **replicarlo a mano en los 3**: `mimocode.jsonc`, `profiles/local/mimocode.jsonc` y `profiles/cloud/mimocode.jsonc`.

> 🔍 Para comprobar la configuración efectiva de un perfil: `MIMOCODE_CONFIG_DIR=<dir> mimo debug config`. Vuelca la config resuelta e incluye `mcp_origins.<mcp>.source`, que indica **de qué archivo procede cada entrada**.

---

## Plugin de voz

El plugin `mimocode-voice-modified` se registra en `tui.json` (config TUI global) y se hereda por perfiles. STT: `sox` + `whisper-cli` CUDA. TTS: `~/.local/bin/speak-kokoro-gpu` voz `ef_dora`. Keybinds: `Ctrl+R` (STT) y `Ctrl+Q` (parar locución). `Ctrl+R` se libera de renombrar sesión con `keybinds.session_rename: "none"`.

---

## Cambio entre perfiles

Usa los lanzadores ZSH:

```bash
mimo          # global
mimo-local    # profiles/local
mimo-cloud    # profiles/cloud
```

> 🎙️ No hay lanzador de voz: el plugin se carga en los 3 perfiles, basta con `/voice` en la TUI.
> 🎨 Los tres se ejecutan en la ventana actual (no abren ventana nueva). ⚠️ El fondo translúcido de la TUI es un **bug oficial de MiMoCode** (issue #1146) que **no se arregla por configuración**: ver `bug-fondo-translucido-mimocode.md`.

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
