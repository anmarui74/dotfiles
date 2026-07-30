#!/bin/bash
# Comprueba el estado del issue #39164 de OpenCode
# Muestra notificación si está cerrado (arreglado)

ISSUE_URL="https://api.github.com/repos/anomalyco/opencode/issues/39164"
CACHE_FILE="/home/antonio/.config/opencode/data/issue_status.txt"

RESP=$(curl -s "$ISSUE_URL" 2>/dev/null)
STATE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('state','unknown'))" 2>/dev/null)

echo "$STATE" > "$CACHE_FILE"

if [ "$STATE" = "closed" ]; then
    MSG="🎉 ¡El issue #39164 está CERRADO! El fix de tools locales ya está disponible."
    echo "$MSG"
    # Notificación desktop
    notify-send -u critical "OpenCode Fix Disponible" "$MSG" 2>/dev/null || true
elif [ "$STATE" = "open" ]; then
    echo "🔴 Issue #39164: ABIERTO - El bug de tools locales sigue pendiente."
    echo "   https://github.com/anomalyco/opencode/issues/39164"
else
    echo "⚠️ No se pudo verificar el estado del issue."
fi
