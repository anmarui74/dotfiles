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

log "✅ Copia canónica sincronizada"
