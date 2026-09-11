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
DOC_DIR="${CONFIG_BACKUP}/documentacion"
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

mkdir -p "$CONFIG_ACTIVO/data" "$CONFIG_ACTIVO/documentacion" "$SESION_DIR" "$DOC_DIR"

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE"
    [ "$QUIET" != "--quiet" ] && echo "$*" || true
}

# ─── 1. Copiar archivos críticos de config a sesion-opencode ───
log "🔄 Sincronizando .config/opencode/ → Config/opencode/sesion-opencode/..."

for f in "$CONFIG_ACTIVO"/*.json "$CONFIG_ACTIVO"/*.sh "$CONFIG_ACTIVO"/*.js "$CONFIG_ACTIVO"/*.py "$CONFIG_ACTIVO"/*.yaml "$CONFIG_ACTIVO"/.env "$CONFIG_ACTIVO"/.gitignore; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
        package.json|package-lock.json) continue ;;
    esac
    cp "$f" "$SESION_DIR/" 2>/dev/null || true
done

# AGENTS.md es configuración (no manual): se respalda en la raíz de Config/opencode/
if [ -f "$CONFIG_ACTIVO/AGENTS.md" ]; then
    cp "$CONFIG_ACTIVO/AGENTS.md" "$CONFIG_BACKUP/AGENTS.md" 2>/dev/null || true
fi

# Manuales de configuración: ~/.config/opencode/documentacion/ → ~/Config/opencode/documentacion/
if [ -d "$CONFIG_ACTIVO/documentacion" ]; then
    cp "$CONFIG_ACTIVO/documentacion/"*.md "$DOC_DIR/" 2>/dev/null || true
fi

# Eliminar manuales obsoletos que pudieran quedar en sesion-opencode
rm -f "$SESION_DIR"/*.md 2>/dev/null || true

# Directorios (sin data/, models/, node_modules/) — sincronizar: borrar destino antes
# para que la copia refleje exactamente el origen (elimina obsoletos)
for dir in commands prompts skills skills-disabled; do
    if [ -d "$CONFIG_ACTIVO/$dir" ]; then
        rm -rf "$SESION_DIR/$dir"
        cp -r "$CONFIG_ACTIVO/$dir" "$SESION_DIR/" 2>/dev/null || true
    fi
done

# Plugin de voz
if [ -d "$CONFIG_ACTIVO/opencode-voice-modified" ]; then
    rm -rf "$SESION_DIR/opencode-voice-modified"
    cp -r "$CONFIG_ACTIVO/opencode-voice-modified" "$SESION_DIR/opencode-voice-modified"
    log "✅ Plugin de voz sincronizado"
fi

log "✅ Archivos sincronizados"

# ─── 2. Regenerar backup ───
log "📦 Regenerando tarball de backup..."
bash "$CONFIG_ACTIVO/backup-opencode.sh" 2>&1 | tail -1
log "✅ Backup regenerado"

log "─────────────────────────────────────"
