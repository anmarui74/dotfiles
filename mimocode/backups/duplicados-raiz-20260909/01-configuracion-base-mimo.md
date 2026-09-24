# ⚙️ Configuración Base MiMoCode

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 09/09/2026 · rev. 09/09/2026 | Antonio |

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

`~/.config/mimocode/mimocode.jsonc` contiene `small_model`, `default_agent`, `voice`, `plugin` y MCPs.

---

## Esquema

```jsonc
{
  "$schema": "https://mimo.xiaomi.com/mimocode/config.json",
  "small_model": "lmstudio/models-qwen3.8-9b",
  "default_agent": "nvidia",
  "plugin": [ ... ]
}
```

---

## Proveedores

- `opencode-go` → backend cloud
- `nvidia` → Muse Glimmer 30B
- `lmstudio` → Qwen 3.8 via proxy 4001

---

## Lanzadores ZSH

`mimo`, `mimo-local`, `mimo-cloud`, `mimo-voz*` definidos en `~/.zshrc`.

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
