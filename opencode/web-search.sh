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

# Intento 1: DuckDuckGo JSON API (la más rápida y confiable)
RESULT=$(curl -s --max-time "${TIMEOUT}" \
    -H "User-Agent: ${USER_AGENT}" \
    "https://api.duckduckgo.com/?q=${SAFE_QUERY}&format=json&no_redirect=1" 2>/dev/null || echo "")

if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
    # El resultado ya es JSON válido, lo enviamos tal cual
    echo "{\"result\": ${RESULT}}"
    exit 0
fi

# Intento 2: DuckDuckGo HTML API (si la JSON falla)
RESULT=$(curl -s --max-time "${TIMEOUT}" \
    -H "User-Agent: ${USER_AGENT}" \
    "https://html.duckduckgo.com/html/?q=${SAFE_QUERY}&ia=answer" 2>/dev/null | head -c 4096 || echo "")

if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
    # Convertir HTML a JSON básico para MCP
    cat << 'JSONEOF'
{"result": {"type": "html", "content": "<div class="search-result">
JSONEOF
    # Insertar el contenido HTML (limpiado de etiquetas <script> y estilos)
    CLEANED=$(printf '%s' "$RESULT" | sed -E 's/<[^<]+>//g; s/<\/?[a-z0-9]+//gi')
    echo "   ${CLEANED}"
    cat << 'JSONEOF2'
</div></div>"}}
JSONEOF2
    exit 0
fi

# Intento 3: Bing (último recurso)
RESULT=$(curl -s --max-time "${TIMEOUT}" \
    -H "User-Agent: ${USER_AGENT}" \
    "https://api.bing.microsoft.com/v7.0/search?q=${SAFE_QUERY}&count=5&mkt=es-ES&safe=moderate" 2>/dev/null | head -c 4096 || echo "")

if [ $? -eq 0 ] && [ -n "$RESULT" ]; then
    # El formato de Bing ya es JSON, pero puede tener problemas con la codificación
    if printf '%s' "$RESULT" | grep -q '"_type"'; then
        echo "{\"result\": ${RESULT}}"
    else
        cat << 'JSONEOF3'
{"result": {"type": "html", "content": "<div class="bing-error">Error al conectar con Bing. Revisa tu conexión a internet.</div>"}}
JSONEOF3
    fi
    exit 0
fi

# Último recurso: error genérico
cat << 'ERRMSG'
{"result": {"type": "html", "content": "<div class=\"error\">Error al realizar búsqueda.\n\nPosibles causas:\n- Conexión a internet desconectada\n- Límite de API alcanzado (espera unos minutos)\n- La consulta contiene palabras prohibidas por el proveedor\n\nPrueba con una pregunta sencilla como \"tiempo mañanPechina\"."}}
ERRMSG
exit 1
