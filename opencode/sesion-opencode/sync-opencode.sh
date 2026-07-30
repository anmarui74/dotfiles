#!/usr/bin/env bash
# sync-opencode.sh — Sincroniza .config/opencode/ → Config/opencode/ + regenera backup
# Uso: bash sync-opencode.sh          (manual con output)
#      bash sync-opencode.sh --quiet  (via systemd, solo log)
# -------------------------------------------------------------------
# Sigue la estructura de backup definida en AGENTS.md

set -euo pipefail

HOME_DIR="$HOME"
CONFIG_ACTIVO="$HOME_DIR/.config/opencode"
CONFIG_BACKUP="$HOME_DIR/Config/opencode"
SESION_DIR="${CONFIG_BACKUP}/sesion-opencode"
LOG_FILE="$CONFIG_ACTIVO/data/sync.log"
LOCK_FILE="/tmp/opencode-sync.lock"
QUIET="${1:-}"

# Evitar ejecuciones simultáneas
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
        [ "$QUIET" != "--quiet" ] && echo "⚠️  Ya hay una sincronización en curso."
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

mkdir -p "$CONFIG_ACTIVO/data" "$SESION_DIR"

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE"
    [ "$QUIET" != "--quiet" ] && echo "$*"
}

# ─── 1. Copiar archivos críticos de config a sesion-opencode ───
log "🔄 Sincronizando .config/opencode/ → Config/opencode/sesion-opencode/..."

for f in "$CONFIG_ACTIVO"/*.json "$CONFIG_ACTIVO"/*.sh "$CONFIG_ACTIVO"/*.md "$CONFIG_ACTIVO"/.env; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
        package.json|package-lock.json) continue ;;
    esac
    cp "$f" "$SESION_DIR/" 2>/dev/null || true
done

# Directorios (sin data/, models/, node_modules/)
for dir in commands prompts skills tui.json; do
    [ -d "$CONFIG_ACTIVO/$dir" ] && cp -r "$CONFIG_ACTIVO/$dir" "$SESION_DIR/" 2>/dev/null || true
done

# ─── 2. Sincronizar copias espejo de setup-opencode-completo.sh ───
if [ -f "$SESION_DIR/setup-opencode-completo.sh" ]; then
    mkdir -p "$SESION_DIR/scripts"
    cp "$SESION_DIR/setup-opencode-completo.sh" "$SESION_DIR/scripts/setup-opencode-completo.sh"
    # Copia a .config/opencode/sesion-opencode/scripts/
    mkdir -p "$CONFIG_ACTIVO/sesion-opencode/scripts"
    cp "$SESION_DIR/setup-opencode-completo.sh" "$CONFIG_ACTIVO/sesion-opencode/scripts/setup-opencode-completo.sh"
    log "✅ Copias espejo de setup-opencode-completo.sh sincronizadas"
fi

log "✅ Archivos sincronizados"

# ─── 3. Regenerar backup ───
log "📦 Regenerando tarball de backup..."
bash "$CONFIG_ACTIVO/backup-opencode.sh" 2>&1 | tail -1
log "✅ Backup regenerado"

log "─────────────────────────────────────"
