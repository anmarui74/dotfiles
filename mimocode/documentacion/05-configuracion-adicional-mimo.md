# 🛠️ Configuración Adicional MiMoCode
LSP, MCP, permisos y variables de entorno.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 10/10/2026 | Antonio |

> LSP, MCP, permisos y variables

---

## 📑 Índice
1. [LSP](#lsp)
2. [MCP](#mcp)
3. [Permisos](#permisos)
4. [Variables de entorno](#variables-de-entorno)
5. [Estructura de ficheros](#estructura-de-ficheros-rev-10102026)

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

## Variables de entorno

No hay `.env` en `~/.config/mimocode/` (el proxy lo leería si existiera, pero es opcional). Las variables que maneja MiMoCode son estas:

| Variable | Dónde se define | Efecto |
|----------|-----------------|--------|
| `MIMOCODE_CONFIG_DIR` | `start-mimo-local.sh`, `start-mimo-cloud.sh` | Activa el perfil (`profiles/local`, `profiles/cloud`) con **merge** sobre el global |
| `MIMOCODE_ENABLE_ANALYSIS` | los 3 lanzadores (defecto `false`) | Telemetría; se puede forzar con `=true` |
| `SKIP_LMSTUDIO` | `start-mimo.sh`, `start-mimo-local.sh` | Si está definida, **no** carga el modelo local en VRAM |
| `MIMOCODE_LLAMADO_POR_BACKUP` | `backup-mimocode.sh` → `sync-mimocode.sh` | Guarda anti-bucle (evita que backup ↔ sync se recursen) |
| `LOG_RETENTION_DAYS` | entorno del usuario (defecto `30`) | Retención de tarballs **y** copias fechadas del grafo |
| `METRICS_EXPORT_PATH` / `ENABLE_METRICS` | `.env` opcional del proxy (defecto `true` / `<CONFIG_DIR>/data/metrics.json`) | Ruta y activación de las métricas tok/s |
| `MEMORY_FILE_PATH` | `mimocode.jsonc` → MCP `memory` | Ruta del grafo `data/memory/memory.jsonl` |

```bash
# Telemetría a mano
MIMOCODE_ENABLE_ANALYSIS=true mimo

# Arrancar sin cargar el modelo en VRAM
SKIP_LMSTUDIO=1 mimo-local

# Retención de backups a 7 días
LOG_RETENTION_DAYS=7 bash ~/Config/mimocode/backup-mimocode.sh
```

---

## Estructura de ficheros (rev. 10/10/2026)

Además de la configuración, `~/.config/mimocode/` contiene la **infraestructura propia** y el sistema de backup:

| Fichero / carpeta | Función |
|-------------------|---------|
| `mimocode.jsonc`, `profiles/`, `tui.json` | Configuración (3 perfiles + TUI) |
| `AGENTS.md` | Instrucciones del agente (referenciado en `instructions`) |
| `sync-mimocode.sh` | Sincroniza la copia canónica, borra restos de config en la raíz de `Config/` y **al terminar regenera el tarball** llamando a `backup-mimocode.sh` (guarda anti-bucle `MIMOCODE_LLAMADO_POR_BACKUP=1`) |
| `start-lmstudio.sh`, `start-lmstudio-server.sh`, `lmstudio-proxy.py` | Infraestructura LM Studio **propia** (autónoma de OpenCode) |
| `mimocode-voice-modified/` | Plugin de voz |
| `package.json`, `package-lock.json` | Dependencias npm del config (`@mimo-ai/plugin` 0.1.14); el `node_modules/` del directorio es suyo |
| `check-nvidia-whitelist.{sh,py}` + `.service`/`.timer` | Copia propia del check NVIDIA (días 1 y 16). ⚠️ El que está **instalado y activo** es el de OpenCode (`~/.config/opencode/`); estas copias no están instaladas |
| `data/memory/memory.jsonl` | Grafo de memoria MCP |
| `data/metrics.json` | Métricas del proxy (tokens/s) — se crea en la **primera** petición que atiende el proxy propio de MiMoCode |

| Ruta externa | Función |
|--------------|---------|
| `~/Config/mimocode/backup-mimocode.sh` | Backup (sincroniza + verifica + empaqueta) |
| `~/Config/mimocode/check-setup-completo.sh` | Verifica el setup y los **11 heredocs** del instalador |
| `~/Config/mimocode/sesion-mimocode/setup-mimocode-completo.sh` | Instalador autónomo (14 pasos: PASO 0 → 13) |
| `~/Config/mimocode/backups/mimocode/*.tar.gz` | Tarballs (permisos `600`, directorio `700`) |
| `~/Config/mimocode/backups/mimocode-memory-backup-*.jsonl` | Copias **fechadas** del grafo (una por backup; retención `LOG_RETENTION_DAYS`, 30 días por defecto, **más poda diaria**: solo la última de cada día; NO van a dotfiles) |

> 🔐 **Claves**: van en `~/Config/mimocode/` (tarballs + instalador embebido) y **NUNCA** en `~/Documentos/dotfiles/`.
> Detalle en `06-agents-md-mimo.md` → «Reglas de backup y claves».

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
