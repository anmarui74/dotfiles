# 🚑 Playbook Recuperación MiMoCode

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 09/09/2026 · rev. 09/09/2026 | Antonio |

> Restaurar configuración y memoria

---

## 📑 Índice
1. [Backup](#backup)
2. [Restaurar memoria](#restaurar-memoria)
3. [Restaurar config](#restaurar-config)

---

## Backup

Config independiente en `~/.config/mimocode/`. Memoria en `data/memory/memory.jsonl`.

---

## Restaurar memoria

Copiar backup a `~/.config/mimocode/data/memory/memory.jsonl` y reiniciar MiMoCode.

---

## Restaurar config

Recopiar `mimocode.jsonc`, `profiles/` y `AGENTS.md` desde backup.

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
