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

log "✅ Copia canónica sincronizada"
