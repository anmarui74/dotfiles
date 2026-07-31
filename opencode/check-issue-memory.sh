#!/bin/bash
# Comprueba el estado del issue #39908 (MCP memory outputSchema draft-07)
# Muestra notificación si está cerrado (arreglado) o si hay comentarios nuevos

ISSUE_URL="https://api.github.com/repos/anomalyco/opencode/issues/39908"
DATA_DIR="/home/antonio/.config/opencode/data"
CACHE_FILE="$DATA_DIR/issue_memory_status.txt"
LAST_SEEN_FILE="$DATA_DIR/issue_memory_lastseen.txt"
LOG_FILE="$DATA_DIR/issue_memory.log"

mkdir -p "$DATA_DIR"

RESP=$(curl -s "$ISSUE_URL" 2>/dev/null)
STATE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('state','unknown'))" 2>/dev/null)
N_COMMENTS=$(echo "$RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('comments',[])))" 2>/dev/null || echo "0")
UPDATED=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('updated_at',''))" 2>/dev/null)

LAST_SEEN=""
if [ -f "$LAST_SEEN_FILE" ]; then
    LAST_SEEN=$(cat "$LAST_SEEN_FILE")
fi

echo "state=$STATE comments=$N_COMMENTS updated=$UPDATED last=$LAST_SEEN" >> "$LOG_FILE"

# Notificar si hay novedad (estado cambió o hay comentarios nuevos)
if [ "$STATE" = "closed" ]; then
    MSG="🎉 ¡El issue #39908 está CERRADO! El bug de MCP memory draft-07 está arreglado."
    echo "$MSG"
    notify-send -u critical "OpenCode Fix Disponible" "$MSG" 2>/dev/null || true
elif [ "$STATE" = "open" ]; then
    if [ -n "$N_COMMENTS" ] && [ "$N_COMMENTS" != "0" ] && [ "$N_COMMENTS" != "$LAST_SEEN" ]; then
        MSG="💬 El issue #39908 tiene $N_COMMENTS comentario(s). Los mantenedores han respondido."
        echo "$MSG"
        echo "   https://github.com/anomalyco/opencode/issues/39908"
        notify-send -u normal "OpenCode Issue Actualizado" "$MSG" 2>/dev/null || true
    else
        echo "🟡 Issue #39908: ABIERTO - MCP memory draft-07 sigue pendiente. Sin novedades."
    fi
else
    echo "⚠️ No se pudo verificar el estado del issue."
fi

echo "$N_COMMENTS" > "$LAST_SEEN_FILE"
echo "$STATE" > "$CACHE_FILE"
