# 🛠️ Configuración Adicional MiMoCode
LSP, MCP, permisos y variables de entorno.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

> LSP, MCP, permisos y variables

---

## 📑 Índice
1. [LSP](#lsp)
2. [MCP](#mcp)
3. [Permisos](#permisos)

---

## LSP

Servidores de lenguaje en `lsp` del config global: python, c, cpp, rust, typescript, go, json, yaml, bash, zsh, markdown.

---

## MCP

- `context7`, `filesystem`, `memory`, `fetch`, `sequential_thinking`
- Memoria en `~/.config/mimocode/data/memory/memory.jsonl`

---

## Permisos

`edit: ask`, reglas `bash` granulares y `external_directory` para limitar acceso fuera del proyecto. El comodín `*` va **PRIMERO**: la última regla que coincide gana.

```jsonc
"permission": {
  "edit": "ask",
  "bash": {
    "*": "ask",
    "sudo *": "deny",
    "pkexec *": "allow"
  },
  "external_directory": {
    "/tmp/**": "ask"
  }
}
```

> `external_directory` protege el acceso a rutas fuera del directorio de trabajo. En los tres perfiles se aplica `/tmp/**` como `ask`.

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
