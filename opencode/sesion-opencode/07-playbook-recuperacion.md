# 🛟 Playbook de Recuperación de OpenCode

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 🛟 Recuperación | 05/09/2026 | Antonio |

> Procedimiento paso a paso para restaurar OpenCode desde un backup o una
> reinstalación desde limpio, recuperar el grafo de memoria y re-sincronizar
> todo el sistema.

---

## 📑 Índice

1. [Antes de empezar](#antes-de-empezar)
2. [Escenario A: restaurar el grafo de memoria (pérdida/corrupción)](#escenario-a-restaurar-el-grafo-de-memoria)
3. [Escenario B: reinstalación desde limpio (tarball de backup)](#escenario-b-reinstalación-desde-limpio)
4. [Escenario C: recuperar solo un archivo de configuración](#escenario-c-recuperar-solo-un-archivo)
5. [Re-sincronización y verificación](#re-sincronización-y-verificación)
6. [Checklist de verificación final](#checklist-de-verificación-final)
7. [Soluciones a problemas comunes](#soluciones-a-problemas-comunes)

---

## Antes de empezar

### 🔑 Rutas clave

| Elemento | Ruta |
|----------|------|
| Config activa | `~/.config/opencode/` |
| Copia de seguridad | `~/Config/opencode/` |
| Tarballs de backup | `~/Config/opencode/backups/opencode/opencode-backup-*.tar.gz` |
| Grafo de memoria (activo) | `~/.config/opencode/data/memory/memory.jsonl` |
| Grafo de memoria (backup) | `~/Config/opencode/backups/mcp-memory-backup-*.jsonl` |
| Variables de entorno | `~/.config/opencode/.env` |
| Base de datos de sesiones | `~/.local/share/opencode/opencode.db` |
| Cache de plugins npm | `~/.cache/opencode/node_modules/` |

### ⏸️ Detener servicios antes de restaurar

```bash
systemctl --user stop opencode-sync.timer 2>/dev/null
pkill -f "lmstudio-proxy" 2>/dev/null
pkill -f "opencode" 2>/dev/null
```

> ⚠️ Detener el timer evita que el sync automático (cada 30 min) interfiera
> mientras restauras archivos. Al terminar, vuelve a arrancarlo.

---

## Escenario A: restaurar el grafo de memoria

Para cuando el grafo se pierde o corrompe (el servidor MCP memory no carga,
errores de entidades vacías, archivo dañado, etc.).

### Paso 1 — Localizar el backup más reciente

```bash
ls -t ~/Config/opencode/backups/mcp-memory-backup-*.jsonl | head -1
```

Guarda la ruta resultante, por ejemplo:
`/home/antonio/Config/opencode/backups/mcp-memory-backup-20260905_0042.jsonl`

### Paso 2 — Hacer copia del grafo actual (por seguridad)

```bash
cp ~/.config/opencode/data/memory/memory.jsonl ~/.config/opencode/data/memory/memory.jsonl.corrupto 2>/dev/null
```

### Paso 3 — Copiar el backup a la ruta activa

```bash
cp /home/antonio/Config/opencode/backups/mcp-memory-backup-XXXX.jsonl \
   ~/.config/opencode/data/memory/memory.jsonl
```

### Paso 4 — Verificar que el archivo es JSONL válido

```bash
python3 -c "import json; [json.loads(l) for l in open('/home/antonio/.config/opencode/data/memory/memory.jsonl') if l.strip()]; print('✅ grafo OK')"
```

### Paso 5 — Reiniciar OpenCode

El servidor MCP memory lee `MEMORY_FILE_PATH` (vía `environment` en el bloque
`mcp.memory` de los 3 perfiles JSON). Al abrir `opencode`/`ocv` se recarga el
grafo automáticamente.

---

## Escenario B: reinstalación desde limpio

Para cuando reinstalas el sistema o OpenCode desde cero.

### Paso 1 — Localizar el tarball más reciente

```bash
ls -t ~/Config/opencode/backups/opencode/opencode-backup-*.tar.gz | head -1
```

### Paso 2 — Instalar OpenCode y dependencias base

```bash
# OpenCode (CachyOS/Arch)
pkexec pacman -S opencode

# Servidores LSP (el setup los instala, pero conviene verificar)
pkexec pacman -S --needed shellcheck shfmt marksman clang
```

### Paso 3 — Ejecutar el instalador completo desde el tarball

Extrae el tarball y ejecuta el `setup-opencode-completo.sh` que contiene:

```bash
mkdir -p /tmp/opencode-restore
tar xzf ~/Config/opencode/backups/opencode/opencode-backup-XXXX.tar.gz -C /tmp/opencode-restore
ls /tmp/opencode-restore   # debe contener setup-opencode-completo.sh + restore.sh
```

> 📌 El instalador `setup-opencode-completo.sh` (con todos los heredocs
> embebidos) reinstala configuración, scripts, perfiles, skills, voz y MCPs.
> El `restore.sh` coloca el setup en `~/Config/opencode/sesion-opencode/`.

Ejecuta el instalador:

```bash
bash /tmp/opencode-restore/setup-opencode-completo.sh
```

> ⚠️ Si aparece una ventana de `pkexec`, introduce tu contraseña (el script la
> usa para instalar paquetes con privilegios).

### Paso 4 — Restaurar el grafo de memoria

Siguiendo el [Escenario A](#escenario-a-restaurar-el-grafo-de-memoria), copia
el backup del grafo a la ruta activa.

### Paso 5 — Restaurar la base de datos de sesiones (opcional)

```bash
cp ~/Config/opencode/backups/opencode/opencode-backup-XXXX.tar.gz /tmp/ && \
cd /tmp && tar xzf opencode-backup-XXXX.tar.gz opencode.db 2>/dev/null
cp /tmp/opencode.db ~/.local/share/opencode/opencode.db
```

> Este paso recupera el historial de sesiones y peticiones (TUI timeline).

### Paso 6 — Re-sincronizar y verificar

Sigue la sección [Re-sincronización](#re-sincronización-y-verificación).

---

## Escenario C: recuperar solo un archivo

Para cuando solo necesitas un fichero concreto (un JSON, script o doc).

### Paso 1 — Extraer el archivo del tarball

```bash
tar xzf ~/Config/opencode/backups/opencode/opencode-backup-XXXX.tar.gz \
  -C /tmp/opencode-restore .config/opencode/opencode.json
```

### Paso 2 — Copiar a la ruta activa

```bash
cp /tmp/opencode-restore/.config/opencode/opencode.json ~/.config/opencode/opencode.json
```

### Paso 3 — Re-sincronizar a Config/opencode

```bash
bash ~/.config/opencode/sync-opencode.sh
```

---

## Re-sincronización y verificación

Tras cualquier restauración, ejecuta en orden:

```bash
# 1. Cargar variables de entorno
set -a; source ~/.config/opencode/.env; set +a

# 2. Inicializar componentes (LM Studio, modelo, proxy, PWAs, memoria)
bash ~/.config/opencode/init-opencode.sh

# 3. Arrancar el timer de sync de nuevo
systemctl --user start opencode-sync.timer

# 4. Regenerar el backup (verifica el setup; si falla, aborta)
bash ~/Config/opencode/backup-opencode.sh
```

---

## Checklist de verificación final

| # | Comprobación | Comando |
|---|--------------|---------|
| 1 | Servidor LM Studio en puerto 1234 | `curl -s http://localhost:1234/v1/models | head` |
| 2 | Proxy en puerto 4001 | `curl -s http://localhost:4001/v1/models | head` |
| 3 | Dashboard de métricas en 4200 | `curl -s http://localhost:4200/api/metrics` |
| 4 | Grafo de memoria cargado | `wc -l ~/.config/opencode/data/memory/memory.jsonl` |
| 5 | PWAs en el Escritorio | `ls /home/antonio/Escritorio/chrome-*.desktop` |
| 6 | Timer de sync activo | `systemctl --user status opencode-sync.timer` |
| 7 | Variables de entorno | `echo $MEMORY_FILE_PATH` |
| 8 | Historial de sesiones | `timeline-completo --sesiones` |
| 9 | Plugin TUI de voz + throughput | abrir `opencode` y verificar barra lateral |

---

## Soluciones a problemas comunes

| Problema | Causa probable | Solución |
|----------|----------------|----------|
| MCP memory no carga sus herramientas | Issue #39908 (draft-07 vs 2020-12) | Ver seguimiento-issue-memory.md; usar el grafo desde backups |
| Error `-32602` al añadir observaciones | Falta `entityName` en el array | Revisar AGENTS.md → Recordatorio MCP memory |
| El proxy no responde en 4001 | Proceso no arrancado | `bash ~/.config/opencode/start-lmstudio-server.sh` |
| El dashboard no muestra datos | `ENABLE_METRICS=false` o proxy viejo | Verificar `.env` y que `lmstudio-proxy.py` sea la versión con métricas |
| TUI no muestra historial completo | Límite hardcodeado (~6 peticiones, PR #26861) | Usar `timeline-completo` |
| Modelo de OpenCode Go requiere opt-in | Migración a hosting en China | Activar toggle en https://opencode.ai/workspace/wrk_01KWNJZHA9QS258DM0M2KY8PNZ/go |

---

> 📁 Este playbook vive en `~/.config/opencode/07-playbook-recuperacion.md`
> (activo) y `~/Config/opencode/documentacion/07-playbook-recuperacion.md`
> (backup). Sincronizado en el setup vía heredoc `PLAYBOOKEOF`.
