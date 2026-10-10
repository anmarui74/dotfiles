#!/usr/bin/env bash
# sync-mimocode.sh — Sincroniza ~/.config/mimocode/ → ~/Config/mimocode/sesion-mimocode/config/
# Uso: bash sync-mimocode.sh            (manual con output)
#      bash sync-mimocode.sh --quiet    (via systemd, solo log)
# -------------------------------------------------------------------
# Mantiene la copia canónica que usa el instalador (setup-mimocode-completo.sh).
# NO regenera el tarball: eso lo hace backup-mimocode.sh.

set -euo pipefail

ACTIVO="$HOME/.config/mimocode"
CANON="$HOME/Config/mimocode/sesion-mimocode/config"
BACKUP="$HOME/Config/mimocode"
LOG="$ACTIVO/data/sync.log"
LOCK="/tmp/mimocode-sync.lock"
QUIET="${1:-}"

# Evitar ejecuciones simultáneas
if [ -f "$LOCK" ]; then
    pid=$(cat "$LOCK" 2>/dev/null || true)
    if kill -0 "$pid" 2>/dev/null; then
        [ "$QUIET" != "--quiet" ] && echo "⚠️  Ya hay una sincronización en curso."
        exit 0
    fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

mkdir -p "$ACTIVO/data" "$CANON"

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG"
    [ "$QUIET" != "--quiet" ] && echo "$*" || true
}

log "🔄 Sincronizando ~/.config/mimocode/ → Config/mimocode/sesion-mimocode/config/..."

rsync -a --delete \
    --exclude 'node_modules' \
    --exclude '*.bak*' \
    --exclude 'data/sync.log' \
    --exclude 'data/setup-check.log' \
    "$ACTIVO"/ "$CANON"/

# Eliminar restos de configuración en la RAÍZ del respaldo. MiMoCode solo lee la config
# de sus rutas oficiales (~/.config/mimocode/ y el perfil indicado por MIMOCODE_CONFIG_DIR),
# así que una copia en esta raíz es INERTE y confunde. En la raíz solo deben vivir:
# AGENTS.md, backup-mimocode.sh, check-setup-completo.sh, el symlink
# setup-mimocode-completo.sh y los directorios backups/, documentacion/ y sesion-mimocode/.
rm -f "$BACKUP"/mimocode.json "$BACKUP"/mimocode.jsonc \
      "$BACKUP"/mimocode-local.json "$BACKUP"/mimocode-local.jsonc \
      "$BACKUP"/mimocode-cloud.json "$BACKUP"/mimocode-cloud.jsonc \
      "$BACKUP"/tui.json "$BACKUP"/cli.json 2>/dev/null || true

# El AGENTS.md vive en 3 sitios: activo, RAÍZ del respaldo y copia canónica. El rsync de
# arriba ya actualiza la canónica; la de la raíz antes había que copiarla A MANO y quedaba
# desfasada (detectado 09/10/2026: 2,6 KB de diferencia). Este script la propaga ya,
# igual que sync-opencode.sh hace con el AGENTS.md de OpenCode.
if [ -f "$ACTIVO/AGENTS.md" ]; then
    if ! cmp -s "$ACTIVO/AGENTS.md" "$BACKUP/AGENTS.md"; then
        cp "$ACTIVO/AGENTS.md" "$BACKUP/AGENTS.md"
        log "🔄 AGENTS.md propagado a la raíz del respaldo (~/Config/mimocode/AGENTS.md)"
    fi
fi

log "✅ Copia canónica sincronizada"

# ─── Regenerar el tarball de backup (paridad con sync-opencode.sh) ───
# El backup vuelve a llamar a este script (su paso 0) para sincronizar la copia
# canónica; con la guarda MIMOCODE_LLAMADO_POR_BACKUP=1 se corta esa vuelta para
# no regenerar el tarball dos veces (ni entrar en bucle al lanzar el backup a mano).
if [ "${MIMOCODE_LLAMADO_POR_BACKUP:-0}" = "1" ]; then
    log "⏭  Tarball no regenerado: este sync lo ha lanzado backup-mimocode.sh"
elif [ -x "$BACKUP/backup-mimocode.sh" ]; then
    log "📦 Regenerando tarball de backup..."
    if MIMOCODE_LLAMADO_POR_BACKUP=1 bash "$BACKUP/backup-mimocode.sh" > /tmp/mimocode-backup-last.log 2>&1; then
        log "✅ Backup regenerado: $(grep -E 'Backup creado' /tmp/mimocode-backup-last.log | tail -1 | sed 's/^ *//' || echo ok)"
    else
        log "❌ FALLO al regenerar el backup (ver /tmp/mimocode-backup-last.log)"
        tail -5 /tmp/mimocode-backup-last.log >> "$LOG"
        exit 1
    fi
else
    log "⚠️  No existe $BACKUP/backup-mimocode.sh: tarball no regenerado."
fi

log "─────────────────────────────────────"
