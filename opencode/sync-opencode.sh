#!/usr/bin/env bash
# sync-opencode.sh — Sincroniza .config/opencode/ → Config/opencode/ + regenera backup
# Se ejecuta automáticamente al detectar cambios via systemd watcher

set -euo pipefail

HOME_DIR="$HOME"
CONFIG_ACTIVO="$HOME_DIR/.config/opencode"
CONFIG_BACKUP="$HOME_DIR/Config/opencode"
LOG_FILE="$CONFIG_ACTIVO/data/sync.log"
LOCK_FILE="/tmp/opencode-sync.lock"

# Evitar ejecuciones simultáneas
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

mkdir -p "$CONFIG_ACTIVO/data" "$CONFIG_BACKUP"

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE"
    echo "$*"
}

# ─── 1. Sincronizar archivos del activo al backup ───
log "🔄 Sincronizando archivos..."

# Archivos individuales
for f in "$CONFIG_ACTIVO"/*; do
    base=$(basename "$f")
    case "$base" in
        __pycache__|node_modules|build|.*) continue ;;
    esac
    if [ -f "$f" ]; then
        cp "$f" "$CONFIG_BACKUP/$base" 2>/dev/null || true
    fi
done

# Directorios (commands, prompts, data, skills)
for dir in commands prompts data skills; do
    if [ -d "$CONFIG_ACTIVO/$dir" ]; then
        rm -rf "$CONFIG_BACKUP/$dir"
        cp -r "$CONFIG_ACTIVO/$dir" "$CONFIG_BACKUP/$dir" 2>/dev/null || true
    fi
done

# ─── 2. Sincronizar scripts duplicados ───
# sesion-opencode/scripts/
if [ -d "$CONFIG_BACKUP/sesion-opencode/scripts" ]; then
    cp "$CONFIG_BACKUP/sesion-opencode/setup-opencode-completo.sh" "$CONFIG_BACKUP/sesion-opencode/scripts/setup-opencode-completo.sh" 2>/dev/null || true
fi

log "✅ Archivos sincronizados"

# ─── 3. Regenerar backup ───
if [ -f "$CONFIG_BACKUP/backup-opencode.sh" ]; then
    log "📦 Regenerando tarball de backup..."
    bash "$CONFIG_BACKUP/backup-opencode.sh" 2>&1 | tail -1
    log "✅ Backup regenerado"
fi

log "─────────────────────────────────────"
