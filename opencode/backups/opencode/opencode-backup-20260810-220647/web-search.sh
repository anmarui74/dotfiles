#!/bin/bash
# MCP Server de búsqueda con DuckDuckGo (sin dependencias)
# Devuelve resultados en formato JSON para el protocolo MCP

QUERY="${1:-}"
TIMEOUT=45
USER_AGENT="Mozilla/5.0 (compatible; MCP/Search)"

if [ -z "$QUERY" ]; then
    echo '{"error": "No query provided"}' >&2
    exit 1
fi

# Sanitizar la consulta para evitar problemas con caracteres especiales
SAFE_QUERY=$(printf '%s' "$QUERY" | sed 's/[^a-zA-Z0-9._ -]//g')

if [ -z "$SAFE_QUERY" ]; then
    echo '{"result": {"type": "html", "content": "<div class=\"error\">La consulta está vacía o no es válida.</div>"}}'
    exit 1
fi

# Intento 1: DuckDuckGo JSON API
RESULT=$(curl -s --max-time "${TIMEOUT}" \
    -H "User-Agent: ${USER_AGENT}" \
    "https://api.duckduckgo.com/?q=${SAFE_QUERY}&format=json&no_redirect=1" 2>/dev/null)

if [ -n "$RESULT" ] && echo "$RESULT" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "{\"result\": ${RESULT}}"
    exit 0
fi

# Intento 2: DuckDuckGo HTML API (fallback)
RESULT_HTML=$(curl -s --max-time "${TIMEOUT}" \
    -H "User-Agent: ${USER_AGENT}" \
    "https://html.duckduckgo.com/html/?q=${SAFE_QUERY}" 2>/dev/null)

if [ -n "$RESULT_HTML" ]; then
    CLEANED=$(printf '%s' "$RESULT_HTML" | sed -E 's/<script[^>]*>.*<\/script>//g; s/<style[^>]*>.*<\/style>//g; s/<[^>]+>//g; s/\s+/ /g' | head -c 4096)
    echo "{\"result\": {\"type\": \"html\", \"content\": \"${CLEANED}\"}}"
    exit 0
fi

# Error genérico
cat << 'ERRMSG'
{"result": {"type": "html", "content": "<div class=\"error\">Error al realizar búsqueda.\n\nPosibles causas:\n- Conexión a internet desconectada\n- Límite de API alcanzado (espera unos minutos)\n- La consulta contiene palabras prohibidas por el proveedor\n\nPrueba con una pregunta sencilla como \"tiempo Pechina\"."}}
ERRMSG
exit 1
