#!/usr/bin/env bash
# ============================================================
# check-mega-pr.sh — Vigila el PR #1174 de meganz/MEGAsync
# (fix de los iconos de estado de MEGAsync en Nautilus 51+)
#
# Consulta estado / merge / comentarios / reviews del PR y avisa
# por notificación cuando cambia algo (mergeado, cerrado o nueva
# actividad). Se ejecuta vía systemd timer (check-mega-pr.timer).
# ============================================================

LOG_FILE="$HOME/.config/opencode/data/mega-pr.log"
STATE_FILE="$HOME/.config/opencode/data/mega-pr-state.json"
PR_API="https://api.github.com/repos/meganz/MEGAsync/pulls/1174"
PR_URL="https://github.com/meganz/MEGAsync/pull/1174"

log() { echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE"; }
notif() { command -v notify-send >/dev/null 2>&1 && notify-send -u "$1" "$2" "$3" 2>/dev/null || true; }

# --- estado actual desde la API ---
CUR=$(curl -s --max-time 15 -H "Accept: application/vnd.github+json" "$PR_API" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
    state=d.get("state","unknown")
    if d.get("merged_at"): state="merged"
    print("|".join([state, d.get("merged_at") or "-", str(d.get("comments",0)), d.get("title","")]))
except Exception:
    print("ERROR|-|0|")
' 2>/dev/null)

if [ -z "$CUR" ] || [ "${CUR%%|*}" = "ERROR" ]; then
    log "⚠️ No se pudo consultar la API de GitHub (sin conexión, rate-limit o API caída)"
    exit 0
fi

STATE="${CUR%%|*}";  REST="${CUR#*|}"
MERGED_AT="${REST%%|*}"; REST="${REST#*|}"
COMMENTS="${REST%%|*}"

REV=$(curl -s --max-time 15 "$PR_API/reviews" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)

# --- estado anterior ---
PREV_STATE=""; PREV_C=0; PREV_R=0
if [ -f "$STATE_FILE" ]; then
    read -r PREV_STATE PREV_C PREV_R < <(python3 -c '
import json
try:
    d=json.load(open("'"$STATE_FILE"'"))
    print(d.get("state",""), int(d.get("comments",0)), int(d.get("reviews",0)))
except Exception:
    print("", 0, 0)
')
fi

# --- evaluar ---
case "$STATE" in
    merged)
        if [ "$PREV_STATE" != "merged" ]; then
            log "🎉 ¡PR #1174 MERGEADO! ($MERGED_AT) — MEGA ha aceptado el arreglo."
            log "👉 Cuando publiquen un nautilus-megasync corregido, retira el parche local (~/.local/share/mega-nautilus-fix/)."
            notif normal "MEGAsync: PR mergeado ✅" "El PR #1174 se ha mergeado. Podrás quitar el parche local cuando salga el paquete corregido."
        else
            log "🔍 PR #1174 sigue MERGEADO (sin novedades)."
        fi
        ;;
    closed)
        if [ "$PREV_STATE" != "closed" ]; then
            log "ℹ️ PR #1174 CERRADO sin mergear. Se mantiene el parche local."
            notif normal "MEGAsync: PR cerrado" "El PR #1174 se cerró sin mergear. Se mantiene el parche local."
        else
            log "🔍 PR #1174 sigue CERRADO (sin novedades)."
        fi
        ;;
    open)
        NEW=$(( COMMENTS + REV )); OLD=$(( PREV_C + PREV_R ))
        if [ "$NEW" -gt "$OLD" ]; then
            log "💬 PR #1174: actividad nueva — comentarios/reviews: $NEW (antes $OLD). Revísalo: $PR_URL"
            notif normal "MEGAsync: actividad en el PR #1174" "Hay comentarios/reviews nuevos. Ábrelo: $PR_URL"
        else
            log "🔍 PR #1174 sigue ABIERTO (sin novedades)."
        fi
        ;;
    *)
        log "⚠️ Estado desconocido del PR: $STATE"
        ;;
esac

# --- guardar estado ---
python3 -c '
import json
json.dump({"state":"'"$STATE"'","comments":int("'"$COMMENTS"'"),"reviews":int("'"$REV"'")},
          open("'"$STATE_FILE"'","w"))
' 2>/dev/null || true
