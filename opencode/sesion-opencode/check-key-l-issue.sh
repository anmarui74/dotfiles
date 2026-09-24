#!/usr/bin/env bash
# ============================================================
# check-key-l-issue.sh — Vigila el issue #49244 de OpenCode V2
# (primera pulsación de la letra 'l' se traga en la TUI).
#
# Consulta el estado del issue en GitHub. Si está CERRADO,
# avisa de que el bug podría estar corregido para retirar el
# vigilante. Se ejecuta automáticamente vía systemd timer.
# ============================================================

LOG_FILE="$HOME/.config/opencode/data/key-l-issue.log"
ISSUE_URL="https://api.github.com/repos/anomalyco/opencode/issues/49244"

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE"
}

STATE=$(curl -s --max-time 15 "$ISSUE_URL" 2>/dev/null | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
    print(d.get('state','unknown') + '|' + (d.get('closed_at') or '-') + '|' + (d.get('title') or ''))
except Exception:
    print('ERROR|-|-')
" 2>/dev/null)

if [ -z "$STATE" ] || [ "$STATE" = "ERROR|-|-" ]; then
    log "⚠️ No se pudo consultar GitHub (sin conexión o API caída)"
    exit 0
fi

ST="${STATE%%|*}"
REST="${STATE#*|}"
CLOSED="${REST%%|*}"

case "$ST" in
    closed)
        log "🎉 El issue #49244 está CERRADO (fecha: $CLOSED). Revisar si V2 ya escribe 'l' con una pulsación."
        log "👉 Si funciona, retirar este vigilante (script + timer)."
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u normal "OpenCode: issue #49244 cerrado" \
                "El bug de la tecla 'l' podría estar corregido. Prueba a escribir 'l' en la TUI." 2>/dev/null || true
        fi
        ;;
    open)
        log "🔴 Issue #49244 sigue ABIERTO (tecla 'l' se traga en V2)."
        ;;
    *)
        log "⚠️ Estado desconocido del issue: $ST"
        ;;
esac
