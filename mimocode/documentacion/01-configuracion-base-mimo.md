# ⚙️ Configuración Base MiMoCode
Configuración global de MiMoCode, esquema, proveedores y lanzadores.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

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
  "model_groups": {
    "lite": "lmstudio/models-qwen3.8-9b"
  },
  "small_model": "lmstudio/models-qwen3.8-9b",
  "default_agent": "nvidia"
}
```

> El grupo `lite` define un tier; el modelo para tareas baratas se fija con `small_model`. En el perfil cloud, ambos apuntan a `opencode-go/deepseek-v4-flash`.

> 🔒 Los lanzadores exportan `MIMOCODE_ENABLE_ANALYSIS=false` (telemetría desactivada por privacidad).

---

## Proveedores

- `opencode-go` → backend cloud (clave en `~/.local/share/mimocode/auth.json`)
- `nvidia` → Muse Glimmer 30B (whitelist de 8 modelos)
- `lmstudio` → Qwen 3.8 vía proxy 4001 (`only_configured_models: true` para no listar modelos del catálogo que el servidor local no sirve)

---

## Lanzadores ZSH

`mimo`, `mimo-local`, `mimo-cloud`, `mimo-voz*` definidos en `~/.zshrc` como funciones que llaman a `~/.local/bin/start-mimo*.sh`. Los perfiles local/cloud se activan con `MIMOCODE_CONFIG_DIR` (merge sobre el global).

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
