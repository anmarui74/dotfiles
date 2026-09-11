# 🐛 Seguimiento: Issue MCP memory — outputSchema draft-07 (Windows)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ⚠️ en seguimiento | 10/09/2026 · rev. 10/09/2026 | Antonio |

> 📋 Seguimiento del problema de compatibilidad de esquemas del servidor MCP memory.
> El fallo es **independiente del sistema operativo**: se reproduce igual en
> Windows (PowerShell 5.1) y en Linux.

---

## 📌 Issue

| Campo | Valor |
|-------|-------|
| URL | <https://github.com/anomalyco/opencode/issues/39908> |
| Título | [MCP] memory server tools fail to load: outputSchema uses JSON Schema draft-07, validator only supports 2020-12 |
| Repo | `anomalyco/opencode` |
| Reportado por | anmarui74 (Antonio) |
| Fecha creación | 31/07/2026 |

## ⚠️ Problema

Las herramientas del servidor MCP memory (`@modelcontextprotocol/server-memory`)
no cargan en OpenCode 1.18.8:

```
Tool 'search_nodes' has an invalid outputSchema: JSON Schema declares an unsupported
dialect ("$schema": "http://json-schema.org/draft-07/schema#"). The default validator
supports JSON Schema 2020-12 only; pass a pre-configured Ajv instance to AjvJs
```

**Causa:** el servidor genera esquemas con draft-07 (`zod-to-json-schema` por
defecto) y OpenCode solo valida 2020-12. El SDK oficial de MCP ya tiene el fix.

## 🖥️ Comprobación en Windows

| Elemento | Ruta / Comando |
|----------|----------------|
| Grafo de memoria | `C:\Users\evo01\.config\opencode\data\memory\memory.jsonl` |
| Variable de entorno | `MEMORY_FILE_PATH` (la usa el servidor MCP) |
| Config activa | `C:\Users\evo01\.config\opencode\opencode.jsonc` |
| Ver el grafo | `Get-Content C:\Users\evo01\.config\opencode\data\memory\memory.jsonl` |
| Comprobar tamaño | `(Get-Item C:\Users\evo01\.config\opencode\data\memory\memory.jsonl).Length` |

> ⚠️ **No aplica en Windows:** el comando `sqlite3` (usado en Linux para otras
> comprobaciones) no está instalado. Usar el módulo `sqlite3` de Python:
> ```powershell
> python -c "import sqlite3; print(sqlite3.sqlite_version)"
> ```

## 📊 Estado

| Etapa | Estado |
|-------|--------|
| Creado (31/07/2026) | ✅ |
| Respuesta de mantenedores | ⬜ Pendiente |
| Arreglado | ⬜ Pendiente |
| Verificado tras arreglo | ⬜ Pendiente |
