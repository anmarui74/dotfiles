# 📋 Los Tres Perfiles de `mimocode.jsonc`
Perfiles global, local y cloud, MCPs y plugin de voz.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

> Perfiles global / local / cloud, MCPs y plugin de voz

---

## 📑 Índice
1. [Descripción general](#descripción-general)
2. [Perfil global (`mimocode.jsonc`)](#perfil-global)
3. [Perfil local (`profiles/local`)](#perfil-local)
4. [Perfil cloud (`profiles/cloud`)](#perfil-cloud)
5. [Comparativa de perfiles](#comparativa)
6. [Plugin de voz](#plugin-de-voz)
7. [Cambio entre perfiles](#cambio-entre-perfiles)

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
| `mimo` / `mimo-voz` | Global | nvidia | ✅ | ✅ Plugin mimocode-voice-modified |
| `mimo-local` / `mimo-voz-local` | profiles/local | local | ✅ | ✅ Plugin |
| `mimo-cloud` / `mimo-voz-cloud` | profiles/cloud | cloud | ❌ | ✅ Plugin |

---

## Perfil global

### Archivo: `~/.config/mimocode/mimocode.jsonc`

Perfil por defecto para `mimo` / `mimo-voz`. Incluye `model` principal, `model_groups.lite`, `small_model`, `share`, `autoupdate`, `permission` con `external_directory` y proveedores `opencode-go`, `nvidia` y `lmstudio`. **El plugin de voz NO va aquí** (los plugins TUI van en `tui.json`).

```jsonc
{
  "$schema": "https://mimo.xiaomi.com/mimocode/config.json",
  "model": "nvidia/meta/muse-glimmer-30b",
  "model_groups": {
    "lite": "lmstudio/models-qwen3.8-9b"
  },
  "small_model": "lmstudio/models-qwen3.8-9b",
  "default_agent": "nvidia",
  "share": "manual",
  "autoupdate": false
}
```

> Se añadió `model` top-level para modelo por defecto explícito, `share` y `autoupdate` para trazabilidad y `permission.external_directory` para limitar acceso fuera del proyecto.

---

## Perfil local

### Archivo: `~/.config/mimocode/profiles/local/mimocode.jsonc`

Replica `opencode-local.json` con esquema MiMoCode. Agente por defecto `local`.

**Atajos de voz:** `Ctrl+R` grabar/parar STT, `Ctrl+Q` parar locución.

---

## Perfil cloud

### Archivo: `~/.config/mimocode/profiles/cloud/mimocode.jsonc`

Replica `opencode-cloud.json`. Desactiva `lmstudio`, `default_agent: cloud`, `model` = `opencode-go/deepseek-v4-flash`, `share`/`autoupdate` definidos y `permission.external_directory` añadido. El campo `disable` no estándar de `agent.local` ha sido eliminado.

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

## Comparativa

| Característica | Global | Local | Cloud |
|----------------|--------|-------|-------|
| `model` | nvidia/meta/muse-glimmer-30b | lmstudio/models-qwen3.8-9b | opencode-go/deepseek-v4-flash |
| `default_agent` | nvidia | local | cloud |
| LM Studio | ✅ | ✅ | ❌ |
| `disabled_providers` | - | - | `lmstudio` |
| `share` | manual | manual | manual |
| `autoupdate` | false | false | false |
| `permission.external_directory` | /tmp/** ask | /tmp/** ask | /tmp/** ask |
| Memoria | `~/.config/mimocode/data/memory/memory.jsonl` | compartida | compartida |
| Plugin voz | ✅ | ✅ | ✅ |

> ⚠️ **Merge de configuraciones:** `MIMOCODE_CONFIG_DIR` hace **merge** sobre la config global (no la sustituye). Los perfiles local/cloud heredan claves del global como `voice`, `permission`, etc. No son configuraciones completamente aisladas. La memoria MCP es compartida entre los 3 perfiles (misma ruta `data/memory/memory.jsonl`).

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
mimo-voz      # global con voz
mimo-voz-local
mimo-voz-cloud
```

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
