# 🚑 Playbook Recuperación MiMoCode
Restaurar la configuración, el grafo de memoria y el sistema completo desde un backup o desde cero.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 🛟 Recuperación | 10/09/2026 · rev. 23/09/2026 | Antonio |

> Procedimiento paso a paso para restaurar MiMoCode desde un tarball, recuperar el
> grafo de memoria o instalar todo desde cero con el instalador autónomo.

---

## 📑 Índice
1. [Antes de empezar](#antes-de-empezar)
2. [Escenario A: restaurar el grafo de memoria](#escenario-a-restaurar-el-grafo-de-memoria)
3. [Escenario B: restaurar desde el tarball](#escenario-b-restaurar-desde-el-tarball)
4. [Escenario C: instalación desde cero](#escenario-c-instalación-desde-cero)
5. [Escenario D: recuperar un solo archivo](#escenario-d-recuperar-un-solo-archivo)
6. [Verificación final](#verificación-final)
7. [Problemas comunes](#problemas-comunes)

---

## Antes de empezar

### 🔑 Rutas clave

| Elemento | Ruta |
|----------|------|
| Config activa | `~/.config/mimocode/` |
| Copia canónica (la usa el instalador) | `~/Config/mimocode/sesion-mimocode/config/` |
| Instalador desde cero | `~/Config/mimocode/sesion-mimocode/setup-mimocode-completo.sh` |
| Script de backup | `~/Config/mimocode/backup-mimocode.sh` |
| Verificación del setup | `~/Config/mimocode/check-setup-completo.sh` |
| Tarballs | `~/Config/mimocode/backups/mimocode/mimocode-backup-*.tar.gz` |
| Grafo de memoria (activo) | `~/.config/mimocode/data/memory/memory.jsonl` |
| Grafo de memoria (en dotfiles) | `~/Documentos/dotfiles/mimocode/sesion-mimocode/config/data/memory/memory.jsonl` |
| Credenciales de proveedores | `~/.local/share/mimocode/auth.json` (dentro del tarball en `credenciales/auth.json`) |
| Infraestructura LM Studio propia | `~/.config/mimocode/start-lmstudio*.sh` + `lmstudio-proxy.py` |

### ⏸️ Detener el timer antes de restaurar

```bash
systemctl --user stop mimocode-sync.timer 2>/dev/null
pkill -f "lmstudio-proxy" 2>/dev/null
```

> ⚠️ El timer `mimocode-sync.timer` sincroniza cada 30 min; detenerlo evita que interfiera.
> Al terminar, reactivarlo con `systemctl --user start mimocode-sync.timer`.

---

## Escenario A: restaurar el grafo de memoria

Cuando el grafo se pierde o se corrompe.

1. **Localizar el backup más reciente** (el grafo viaja en la copia canónica y en dotfiles):

   ```bash
   ls -t ~/Config/mimocode/sesion-mimocode/config/data/memory/memory.jsonl
   ```

2. **Guardar el actual por seguridad** y copiar el bueno:

   ```bash
   cp ~/.config/mimocode/data/memory/memory.jsonl ~/.config/mimocode/data/memory/memory.jsonl.corrupto 2>/dev/null
   cp ~/Config/mimocode/sesion-mimocode/config/data/memory/memory.jsonl \
      ~/.config/mimocode/data/memory/memory.jsonl
   ```

3. **Verificar que es JSONL válido**:

   ```bash
   python3 -c "import json; [json.loads(l) for l in open('$HOME/.config/mimocode/data/memory/memory.jsonl') if l.strip()]; print('✅ grafo OK')"
   ```

4. Reiniciar MiMoCode. El servidor MCP memory lee `MEMORY_FILE_PATH`.

> 📌 El grafo también está dentro del tarball en `config.tar.gz` y en
> `~/Documentos/dotfiles/mimocode/sesion-mimocode/config/data/memory/memory.jsonl`.

---

## Escenario B: restaurar desde el tarball

Para recuperar la configuración completa (incluidas credenciales) desde un backup.

1. **Localizar el tarball más reciente**:

   ```bash
   ls -t ~/Config/mimocode/backups/mimocode/mimocode-backup-*.tar.gz | head -1
   ```

2. **Descomprimir y restaurar**:

   ```bash
   mkdir -p /tmp/mimo-restore
   tar xzf ~/Config/mimocode/backups/mimocode/mimocode-backup-XXXX.tar.gz -C /tmp/mimo-restore
   bash /tmp/mimo-restore/restore.sh
   ```

   El `restore.sh` restaura:
   - `config.tar.gz` → `~/.config/mimocode/`
   - `credenciales/auth.json` → `~/.local/share/mimocode/auth.json` (permisos `600`)
   - `setup.tar.gz` → `~/Config/mimocode/sesion-mimocode/`
   - `backup-mimocode.sh` y `check-setup-completo.sh` → `~/Config/mimocode/`

3. Si un plugin necesita dependencias: `cd ~/.config/mimocode && npm install`

---

## Escenario C: instalación desde cero

El instalador `setup-mimocode-completo.sh` es **autónomo**: deja MiMoCode igual que la
instalación activa partiendo de un sistema limpio. **13 pasos**:

```bash
bash ~/Config/mimocode/setup-mimocode-completo.sh
```

| Paso | Qué hace |
|------|----------|
| 0 | Dependencias base (node, npm, python3, curl, git) — las instala con `pacman` si faltan |
| 1 | Binario `mimo` (instalador oficial si no está) |
| 2 | Estructura de directorios |
| 3 | Restaura la configuración completa desde `sesion-mimocode/config/` |
| 4 | 🔐 **Credenciales `auth.json` embebidas** |
| 5 | Lanzadores `start-mimo*.sh` |
| 6 | Funciones ZSH + `PATH` |
| 7 | Timer systemd `mimocode-sync.timer` |
| 8 | `npm install` del plugin de voz |
| 9 | Estructura `~/Config/mimocode/` + scripts de backup + symlink |
| 10 | **Infraestructura LM Studio propia** + instala LM Studio y los modelos si faltan |
| 11 | Servidores LSP |
| 12 | Dependencias de voz |
| 13 | Verificación final + sincronización |

> 🔐 **El instalador embebe `auth.json` con las claves reales** (a propósito, para que quede
> operativo). La copia de **dotfiles se sanea** automáticamente. **NUNCA** sanear el instalador
> canónico de `~/Config/mimocode/sesion-mimocode/`.

> ⚠️ **Verificación automática**: `check-setup-completo.sh` compara los **11 heredocs embebidos**
> con los ficheros activos. Si alguno difiere, el backup se **ABORTA**.

---

## Escenario D: recuperar un solo archivo

```bash
# 1. Extraer del tarball
tar xzf ~/Config/mimocode/backups/mimocode/mimocode-backup-XXXX.tar.gz \
  -C /tmp/mimo-restore config.tar.gz
tar xzf /tmp/mimo-restore/config.tar.gz -C /tmp/mimo-restore

# 2. Copiar el archivo concreto
cp /tmp/mimo-restore/mimocode/mimocode.jsonc ~/.config/mimocode/mimocode.jsonc

# 3. Re-sincronizar la copia canónica
bash ~/.config/mimocode/sync-mimocode.sh
```

---

## Verificación final

```bash
# 1. Verificación del setup (instalador, copia canónica, heredocs)
bash ~/Config/mimocode/check-setup-completo.sh

# 2. Reactivar el timer
systemctl --user start mimocode-sync.timer

# 3. Regenerar el backup (sincroniza + verifica + empaqueta)
bash ~/Config/mimocode/backup-mimocode.sh
```

| # | Comprobación | Comando |
|---|--------------|---------|
| 1 | LM Studio en 1234 | `curl -s http://localhost:1234/v1/models \| head` |
| 2 | Proxy en 4001 | `curl -s http://localhost:4001/v1/models \| head` |
| 3 | Grafo de memoria | `wc -l ~/.config/mimocode/data/memory/memory.jsonl` |
| 4 | Timer de sync | `systemctl --user status mimocode-sync.timer` |
| 5 | Config efectiva de los 3 perfiles | `MIMOCODE_CONFIG_DIR=... mimo debug config` |
| 6 | Lanzadores | `mimo`, `mimo-local`, `mimo-cloud` |

---

## Problemas comunes

| Problema | Causa probable | Solución |
|----------|----------------|----------|
| Error `-32602` al añadir observaciones | Falta `entityName` en el array | Ver `AGENTS.md` → Recordatorio MCP memory |
| El proxy no responde en 4001 | Proceso no arrancado | `bash ~/.config/mimocode/start-lmstudio-server.sh` |
| `mimo` no carga el modelo | LM Studio o el modelo no están | El instalador los baja solo; a mano: `lms get empero-ai/Qwen3.8-9B-Distill-GGUF@Q6_K --yes` |
| El backup se ABORTA | Un heredoc del instalador difiere del fichero activo | Replicar el cambio en el instalador (ver `AGENTS.md`) |
| Fondo translúcido en la TUI | Bug oficial de MiMoCode (issue #1146) | No se arregla por configuración: ver `bug-fondo-translucido-mimocode.md` |

---

> 📁 `~/Config/mimocode/` - Copia de seguridad e instalador · `~/.config/mimocode/` - Configuración activa
