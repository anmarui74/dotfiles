# ⚙️ Configuración Base MiMoCode
Configuración global de MiMoCode, esquema, proveedores y lanzadores.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 23/09/2026 | Antonio |

> Configuración global, esquema, proveedores y lanzadores

---

## 📑 Índice
1. [Descripción general](#descripción-general)
2. [Archivo principal](#archivo-principal)
3. [Esquema](#esquema)
4. [Proveedores](#proveedores)
5. [Lanzadores ZSH](#lanzadores-zsh)

---

## Descripción general

MiMoCode hereda la estructura de OpenCode pero con esquema propio `https://mimo.xiaomi.com/mimocode/config.json`. Config global en `~/.config/mimocode/mimocode.jsonc` y perfiles en `profiles/`.

---

## Archivo principal

`~/.config/mimocode/mimocode.jsonc` contiene `model_groups` (grupo `lite` para tareas baratas), `default_agent`, `permission`, los agentes, los proveedores y los MCPs. La configuración TUI (keybinds y plugin de voz) NO va aquí: va en `~/.config/mimocode/tui.json` (los plugins TUI deben exportar `tui()`; ponerlos en `mimocode.jsonc` da error `must default export an object with server()`).

---

## Esquema

```jsonc
{
  "$schema": "https://mimo.xiaomi.com/mimocode/config.json",
  "model": "nvidia/meta/muse-glimmer-30b",
  "model_groups": {
    "lite": "opencode-go/deepseek-v4.1-flash"
  },
  "default_agent": "nvidia",
  "share": "manual",
  "autoupdate": "notify"
}
```

> El grupo `lite` define un tier de modelo barato. **`small_model` NO se usa en MiMoCode** (no está definido en ninguno de los 3 perfiles). Valores reales de `lite`: `opencode-go/deepseek-v4.1-flash` en global y cloud, `lmstudio/models-qwen3.8-9b` en local.

> 🔒 Los lanzadores exportan `MIMOCODE_ENABLE_ANALYSIS=false` (telemetría desactivada por privacidad).

---

## Proveedores

- `opencode-go` → backend cloud (clave en `~/.local/share/mimocode/auth.json`)
- `nvidia` → **whitelist de 7 modelos** (rev. 11/09/2026). El agente `nvidia` usa `nvidia/nvidia/nemotron-3-ultra-550b-a55b` (**Nemotron 3 Ultra 550B A55B**) desde el 23/09/2026 — antes Nemotron 3 Super 120B.
- `lmstudio` → Qwen 3.8 vía proxy 4001 (`only_configured_models: true` para no listar modelos del catálogo que el servidor local no sirve)

### Infraestructura LM Studio (propia desde el 22/09/2026)

MiMoCode es **autónomo**: NO depende de `~/.config/opencode/`. Tiene su propia copia de la infraestructura de LM Studio en `~/.config/mimocode/`:

| Fichero | Función |
|---------|---------|
| `start-lmstudio.sh` | Carga el modelo + arranca el proxy (con health-check de los puertos 1234/4001) |
| `start-lmstudio-server.sh` | Solo servidor + proxy, sin cargar el modelo |
| `lmstudio-proxy.py` | Proxy del puerto 4001 con métricas tok/s (autocontenido: usa su propio directorio) |

> 📦 **Modelos** (GGUF Q6_K, ~7,5 GB, descargados de Hugging Face): `qwen3.8-9b` ← `empero-ai/Qwen3.8-9B-Distill-GGUF`; `qwen3.5-9b` ← `unsloth/Qwen3.5-9B-GGUF`. El instalador los descarga si faltan.

### Agentes

Los **7 agentes** (`title`, `build`, `plan`, `local`, `cloud`, `nvidia`, `multimodal`) están replicados en los 3 perfiles desde la config activa de OpenCode. Detalle completo en `04-perfiles-mimocode-json.md` → sección «Agentes».

---

## Lanzadores ZSH

`mimo`, `mimo-local` y `mimo-cloud` definidos en `~/.zshrc` como funciones que llaman a `~/.local/bin/start-mimo*.sh`. Los perfiles local/cloud se activan con `MIMOCODE_CONFIG_DIR` (merge sobre el global). **No hay funciones `mimo-voz*`** (retiradas el 16/09/2026): el plugin de voz se carga en los 3 lanzamientos, así que basta con `/voice` en la TUI. Se ejecutan **en la ventana actual** (no abren ventana nueva). ⚠️ El fondo translúcido de la TUI es un **bug oficial de MiMoCode** (issue #1146, PR #1382 sin fusionar) y **no se arregla por configuración**: ver `bug-fondo-translucido-mimocode.md`.

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
