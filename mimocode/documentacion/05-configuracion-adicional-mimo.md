# 🛠️ Configuración Adicional MiMoCode
LSP, MCP, permisos y variables de entorno.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 23/09/2026 | Antonio |

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

---

## Estructura de ficheros (rev. 23/09/2026)

Además de la configuración, `~/.config/mimocode/` contiene la **infraestructura propia** y el sistema de backup:

| Fichero / carpeta | Función |
|-------------------|---------|
| `mimocode.jsonc`, `profiles/`, `tui.json` | Configuración (3 perfiles + TUI) |
| `AGENTS.md` | Instrucciones del agente (referenciado en `instructions`) |
| `sync-mimocode.sh` | Sincroniza la copia canónica; borra restos de config en la raíz de `Config/` |
| `start-lmstudio.sh`, `start-lmstudio-server.sh`, `lmstudio-proxy.py` | Infraestructura LM Studio **propia** (autónoma de OpenCode) |
| `mimocode-voice-modified/` | Plugin de voz |
| `data/memory/memory.jsonl` | Grafo de memoria MCP |
| `data/metrics.json` | Métricas del proxy (tokens/s) |

| Ruta externa | Función |
|--------------|---------|
| `~/Config/mimocode/backup-mimocode.sh` | Backup (sincroniza + verifica + empaqueta) |
| `~/Config/mimocode/check-setup-completo.sh` | Verifica el setup y los **11 heredocs** del instalador |
| `~/Config/mimocode/sesion-mimocode/setup-mimocode-completo.sh` | Instalador autónomo (13 pasos) |
| `~/Config/mimocode/backups/mimocode/*.tar.gz` | Tarballs (permisos `600`, directorio `700`) |

> 🔐 **Claves**: van en `~/Config/mimocode/` (tarballs + instalador embebido) y **NUNCA** en `~/Documentos/dotfiles/`.
> Detalle en `06-agents-md-mimo.md` → «Reglas de backup y claves».

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
