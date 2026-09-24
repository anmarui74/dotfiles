#!/usr/bin/env bash
# ============================================================
# check-timeline-fix.sh — Vigila el PR #26861 de OpenCode
# (fix del timeline: historial completo en la TUI)
#
# Consulta el estado del PR en GitHub. Si está MERGEADO,
# avisa para que podamos retirar el script timeline-completo.
# Se ejecuta automáticamente vía systemd timer.
# ============================================================

LOG_FILE="$HOME/.config/opencode/data/timeline-fix.log"
PR_URL="https://api.github.com/repos/anomalyco/opencode/pulls/26861"

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Consultar el estado del PR
STATUS=$(curl -s --max-time 10 "$PR_URL" 2>/dev/null | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
    state = d.get('state', 'unknown')
    merged = d.get('merged_at')
    title = d.get('title', '')
    if merged:
        print(f'MERGEADO|{merged}|{title}')
    else:
        print(f'{state}|-|{title}')
except Exception:
    print('ERROR|-|-')
" 2>/dev/null)

if [ -z "$STATUS" ] || [ "$STATUS" = "ERROR|-|-" ]; then
    log "⚠️ No se pudo consultar GitHub (sin conexión o API caída)"
    exit 0
fi

STATE="${STATUS%%|*}"
REST="${STATUS#*|}"
MERGED="${REST%%|*}"

case "$STATE" in
    MERGEADO)
        log "🎉 ¡EL PR #26861 SE HA MERGEADO! Fecha: $MERGED"
        log "👉 Ya se puede retirar el script timeline-completo."
        log "👉 Comprobar si la nueva versión de OpenCode incluye el fix."
        # Notificación de escritorio (opcional, si hay notify-send)
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u normal "OpenCode: fix del timeline mergeado" \
                "El PR #26861 se ha mergeado ($MERGED). Ya puedes dejar de usar timeline-completo." 2>/dev/null || true
        fi
        ;;
    open)
        log "🔍 PR #26861 sigue ABIERTO (sin mergear). Se mantiene timeline-completo."
        ;;
    closed)
        log "ℹ️ PR #26861 CERRADO sin mergear. Se mantiene timeline-completo."
        ;;
    *)
        log "⚠️ Estado desconocido del PR: $STATE"
        ;;
esac
