#!/usr/bin/env bash
# sync-hermes.sh — Sincroniza ~/.hermes/ → ~/Config/hermes/ y regenera el backup
# Uso: bash sync-hermes.sh          (manual, con salida)
#      bash sync-hermes.sh --quiet  (vía systemd, solo log)
# ---------------------------------------------------------------------------
# Sigue el esquema definido en ~/Config/hermes/AGENTS.md

set -euo pipefail

HERMES_ACTIVO="${HERMES_HOME:-$HOME/.hermes}"
BACKUP_BASE="$HOME/Config/hermes"
SESION_DIR="${BACKUP_BASE}/sesion-hermes"
LOG_FILE="${BACKUP_BASE}/sync.log"
LOCK_FILE="${BACKUP_BASE}/.sync.lock"
QUIET="${1:-}"

# Evitar ejecuciones simultáneas
if [ -f "$LOCK_FILE" ]; then
    pid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        [ "$QUIET" != "--quiet" ] && echo "⚠️  Ya hay una sincronización en curso."
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

mkdir -p "$BACKUP_BASE" "$SESION_DIR"

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE"
    if [ "$QUIET" != "--quiet" ]; then echo "$*"; fi
}

log "🔄 Sincronizando ${HERMES_ACTIVO}/ → ${SESION_DIR}/"

# Copia canónica de los ficheros de configuración y credenciales
for f in config.yaml .env auth.json SOUL.md; do
    if [ -f "${HERMES_ACTIVO}/${f}" ]; then
        cp -p "${HERMES_ACTIVO}/${f}" "${SESION_DIR}/${f}"
    fi
done
chmod 700 "$SESION_DIR" 2>/dev/null || true
find "$SESION_DIR" -maxdepth 1 -type f \( -name '.env' -o -name 'auth.json' \) -exec chmod 600 {} + 2>/dev/null || true

# Los scripts de la raíz del respaldo deben reflejar los activos que hay en disco
for s in backup-hermes.sh sync-hermes.sh check-setup-completo.sh bootstrap-hermes.sh; do
    if [ -f "${BACKUP_BASE}/${s}" ]; then
        cp -p "${BACKUP_BASE}/${s}" "${SESION_DIR}/${s}"
    fi
done

# Esquema de dual boot (Linux ↔ Windows) al respaldo canónico
if [ -d "${BACKUP_BASE}/dual-boot" ]; then
    rsync -a --delete "${BACKUP_BASE}/dual-boot/" "${SESION_DIR}/dual-boot/"
fi

log "✅ Archivos sincronizados"

# Regenerar el tarball (la verificación del setup va dentro y aborta si falla)
log "📦 Regenerando tarball de backup..."
if bash "${BACKUP_BASE}/backup-hermes.sh" > /tmp/hermes-backup-last.log 2>&1; then
    log "✅ Backup regenerado: $(grep -E 'Tarball creado' /tmp/hermes-backup-last.log | tail -1 | sed 's/^ *//' || echo ok)"
else
    log "❌ FALLO al regenerar el backup (ver /tmp/hermes-backup-last.log)"
    tail -5 /tmp/hermes-backup-last.log >> "$LOG_FILE"
    exit 1
fi

log "─────────────────────────────────────"
