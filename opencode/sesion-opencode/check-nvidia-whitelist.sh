#!/usr/bin/env bash
# ============================================================
# check-nvidia-whitelist.sh — Verificación automática del
# whitelist de modelos NVIDIA (metodología 05/09/2026)
#
# Se ejecuta automáticamente CADA 15 DÍAS vía el timer
# systemd check-nvidia-whitelist.timer (días 1 y 16 de mes).
#
# Qué hace:
#   1. Verifica que los modelos del whitelist actual (3 perfiles
#      JSON) siguen operativos con HTTP 200 real.
#   2. Los que devuelven HTTP 410 Gone (end of life) se ELIMINAN
#      del whitelist de los 3 perfiles.
#   3. Escanea el catálogo real (GET /v1/models) buscando modelos
#      NUEVOS (no vistos en la última ejecución).
#   4. A los nuevos les aplica la metodología completa:
#      HTTP 200 real → velocidad ≥ 10 tok/s → tool calling real.
#   5. Los que pasan TODO quedan como CANDIDATOS (log + notificación)
#      para revisión de Antonio — NO se añaden automáticamente.
#   6. Registra todo en data/nvidia-whitelist.log y guarda el
#      estado en data/nvidia-whitelist-state.json.
#   7. Notificación de escritorio si hay retirados o candidatos.
#
# No toca nada si no hay conexión o falta la API key.
# ============================================================

set -u

CONFIG_DIR="$HOME/.config/opencode"
AUTH_FILE="$HOME/.local/share/opencode/auth.json"
LOG_FILE="$CONFIG_DIR/data/nvidia-whitelist.log"
STATE_FILE="$CONFIG_DIR/data/nvidia-whitelist-state.json"
API_URL="https://integrate.api.nvidia.com/v1"
JSONS=("$CONFIG_DIR/opencode.json" "$CONFIG_DIR/opencode-local.json" "$CONFIG_DIR/opencode-cloud.json")
MIN_TOKENS_PER_SEC=10
GENERATION_TOKENS=200
MAX_NEW_MODELS_PER_RUN=10   # límite de modelos nuevos probados por ejecución
CURL_TIMEOUT=60

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE"
}

# ------------------------------------------------------------
# 1. Obtener API key de NVIDIA desde auth.json de OpenCode
# ------------------------------------------------------------
get_api_key() {
    if [ ! -f "$AUTH_FILE" ]; then
        echo ""
        return 1
    fi
    python3 -c "
import json, sys
try:
    with open('$AUTH_FILE') as f:
        d = json.load(f)
    nv = d.get('nvidia', {})
    key = nv.get('key', '') if isinstance(nv, dict) else ''
    print(key)
except Exception:
    print('')
"
}

# ------------------------------------------------------------
# 2. Leer el whitelist actual del primer perfil (todos iguales)
# ------------------------------------------------------------
get_current_whitelist() {
    python3 -c "
import json, sys
with open('$CONFIG_DIR/opencode.json') as f:
    d = json.load(f)
wl = d.get('provider', {}).get('nvidia', {}).get('whitelist', [])
print('\n'.join(wl))
"
}

# ------------------------------------------------------------
# 3. Leer el estado guardado de la última ejecución
# ------------------------------------------------------------
load_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo '{"modelos_vistos": [], "descartados": {}, "retirados": {}}'
    fi
}

# ------------------------------------------------------------
# 4. Petición POST /chat/completions a un modelo
#    Devuelve: HTTP_CODE|completion_tokens|segundos|tool_calls
# ------------------------------------------------------------
chat_test() {
    local model="$1"
    local payload="$2"
    local start end seconds
    local resp code

    start=$(date +%s.%N)
    resp=$(curl -s --max-time "$CURL_TIMEOUT" -w '\n%{http_code}' -X POST \
        "$API_URL/chat/completions" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null)
    code="${resp##*$'\n'}"
    resp="${resp%$'\n'*}"

    if [ "$code" = "200" ]; then
        end=$(date +%s.%N)
        seconds=$(python3 -c "print(f'{$end - $start:.2f}')")
        # Extraer completion_tokens y tool_calls del JSON
        echo "$resp" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    ct = d.get('usage', {}).get('completion_tokens', 0)
    msg = d.get('choices', [{}])[0].get('message', {})
    tc = 1 if msg.get('tool_calls') else 0
    print(f'200|{ct}|$seconds|{tc}')
except Exception:
    print('200|0|$seconds|0')
"
    else
        echo "$code|0|0|0"
    fi
}

# ------------------------------------------------------------
# 5. Prueba completa de un modelo nuevo (metodología 05/09/2026)
#    HTTP 200 → velocidad ≥ 10 tok/s → tool calling real
#    Salida: OK|tok/s|motivo  o  KO|0|motivo
# ------------------------------------------------------------
full_test_new_model() {
    local model="$1"
    local payload result code ct seconds tc toks

    # Paso A: petición con tools para medir velocidad Y tool calling
    payload='{
        "model": "'"$model"'",
        "messages": [{"role": "user", "content": "Escribe un texto de unas 180 palabras sobre la historia de la informática."}],
        "max_tokens": '"$GENERATION_TOKENS"',
        "tools": [{
            "type": "function",
            "function": {
                "name": "get_current_time",
                "description": "Devuelve la hora actual",
                "parameters": {"type": "object", "properties": {}}
            }
        }],
        "tool_choice": "auto"
    }'

    result=$(chat_test "$model" "$payload")
    code="${result%%|*}"
    rest="${result#*|}"
    ct="${rest%%|*}"
    rest="${rest#*|}"
    seconds="${rest%%|*}"
    tc="${rest##*|}"

    if [ "$code" != "200" ]; then
        case "$code" in
            410) echo "KO|0|HTTP 410 Gone (end of life)" ;;
            404) echo "KO|0|HTTP 404 sin endpoint de chat" ;;
            429) echo "KO|0|HTTP 429 rate limit" ;;
            *)   echo "KO|0|HTTP $code" ;;
        esac
        return
    fi

    # Calcular tok/s (evitar división por cero)
    toks=$(python3 -c "
ct = float('$ct'); sec = float('$seconds')
if sec <= 0 or ct <= 0: print('0')
else: print(f'{ct/sec:.1f}')
")

    # Paso B: exigir velocidad mínima
    if python3 -c "exit(0 if float('$toks') >= $MIN_TOKENS_PER_SEC else 1)"; then
        # Paso C: exigir tool calling real
        if [ "$tc" = "1" ]; then
            echo "OK|$toks|tool calling OK"
        else
            echo "KO|$toks|sin tool calling (inutilizable en OpenCode)"
        fi
    else
        echo "KO|$toks|solo $toks tok/s (mínimo $MIN_TOKENS_PER_SEC)"
    fi
}

# ------------------------------------------------------------
# 6. Actualizar el whitelist en los 3 perfiles JSON
# ------------------------------------------------------------
update_whitelist() {
    local new_wl="$1"
    local wl_json
    wl_json=$(python3 -c "
import json
wl = '''$new_wl'''.strip().split('\n')
wl = [m for m in wl if m.strip()]
print(json.dumps(wl))
")
    local ok=1
    for jf in "${JSONS[@]}"; do
        if [ -f "$jf" ]; then
            cp "$jf" "$jf.bak" 2>/dev/null
            if python3 -c "
import json
with open('$jf') as f:
    d = json.load(f)
d.setdefault('provider', {}).setdefault('nvidia', {})['whitelist'] = json.loads('''$wl_json''')
with open('$jf', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write('\n')
" 2>>"$LOG_FILE"; then
                log "✅ Whitelist actualizado en $jf"
            else
                log "❌ ERROR actualizando $jf (restaurando backup)"
                cp "$jf.bak" "$jf" 2>/dev/null
                ok=0
            fi
        fi
    done
    return $ok
}

# ============================================================
# MAIN
# ============================================================
mkdir -p "$CONFIG_DIR/data"

API_KEY=$(get_api_key)
if [ -z "$API_KEY" ]; then
    log "❌ No se encontró la API key de NVIDIA en $AUTH_FILE. Abortando."
    exit 1
fi

# Comprobar conexión con el catálogo
CATALOG=$(curl -s --max-time 30 "$API_URL/models" -H "Authorization: Bearer $API_KEY" 2>/dev/null)
if [ -z "$CATALOG" ] || ! echo "$CATALOG" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    log "⚠️ Sin conexión con la API de NVIDIA o respuesta inválida. No se toca nada."
    exit 0
fi

# Lista de modelos del catálogo real
CATALOG_MODELS=$(echo "$CATALOG" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('\n'.join(m.get('id', '') for m in d.get('data', []) if m.get('id')))
")

# Whitelist actual
CURRENT_WL=$(get_current_whitelist)
log "🔍 Verificación quincenal del whitelist NVIDIA (${CURRENT_WL:-vacío})"

# Estado previo
STATE=$(load_state)
SEEN=$(echo "$STATE" | python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin).get('modelos_vistos', [])))")

CHANGES=""
NEW_WL="$CURRENT_WL"
RETIRED=""
ADDED=""

# --- Fase 1: verificar los modelos del whitelist actual ---
if [ -n "$CURRENT_WL" ]; then
    while IFS= read -r model; do
        [ -z "$model" ] && continue
        payload='{"model": "'"$model"'", "messages": [{"role": "user", "content": "hola"}], "max_tokens": 5}'
        result=$(chat_test "$model" "$payload")
        code="${result%%|*}"
        # Reintentar sobrecarga/errores transitorios (metodología 05/09/2026):
        # 429/500/503/timeout(000) se reintentan con más margen antes de decidir
        if [ "$code" = "429" ] || [ "$code" = "500" ] || [ "$code" = "503" ] || [ "$code" = "000" ]; then
            log "🔄 $model → HTTP $code, reintentando (sobrecarga/transitorio)..."
            sleep 5
            result=$(chat_test "$model" "$payload")
            code="${result%%|*}"
        fi
        case "$code" in
            200)
                log "✅ $model operativo (HTTP 200)"
                ;;
            410)
                log "🔴 $model RETIRADO (HTTP 410 Gone) → se elimina del whitelist"
                RETIRED="$RETIRED
$model"
                NEW_WL=$(echo "$NEW_WL" | grep -v "^$model$")
                CHANGES="yes"
                ;;
            *)
                log "⚠️ $model respuesta inesperada (HTTP $code). Se mantiene."
                ;;
        esac
    done <<< "$CURRENT_WL"
fi

# --- Fase 2: buscar modelos NUEVOS en el catálogo ---
NEW_CANDIDATES=$(echo "$CATALOG_MODELS" | grep -vxF -f <(printf '%s\n' "$SEEN" "$CURRENT_WL" | grep -v '^$') || true)
NEW_CANDIDATES=$(echo "$NEW_CANDIDATES" | grep -v '^$' || true)

if [ -n "$NEW_CANDIDATES" ]; then
    log "🔎 Modelos nuevos detectados en el catálogo: $(echo "$NEW_CANDIDATES" | wc -l)"
    COUNT=0
    while IFS= read -r model; do
        [ -z "$model" ] && continue
        COUNT=$((COUNT + 1))
        [ "$COUNT" -gt "$MAX_NEW_MODELS_PER_RUN" ] && { log "⏸️  Límite de $MAX_NEW_MODELS_PER_RUN modelos nuevos por ejecución alcanzado."; break; }
        log "🧪 Probando modelo nuevo: $model"
        verdict=$(full_test_new_model "$model")
        status="${verdict%%|*}"
        detail="${verdict#*|}"
        if [ "$status" = "OK" ]; then
            toks="${detail%%|*}"
            log "🎉 $model PASA la metodología ($toks tok/s, tool calling OK) → CANDIDATO para el whitelist (revisión manual)"
            ADDED="$ADDED
$model"
        else
            motivo="${detail#*|}"
            log "❌ $model descartado: $motivo"
        fi
    done <<< "$NEW_CANDIDATES"
else
    log "✅ Sin modelos nuevos en el catálogo."
fi

# --- Fase 3: aplicar cambios al whitelist si hay retirados ---
if [ "$CHANGES" = "yes" ]; then
    NEW_WL=$(echo "$NEW_WL" | grep -v '^$' | sort -u)
    if update_whitelist "$NEW_WL"; then
        log "📝 Whitelist actualizado ($(echo "$NEW_WL" | wc -l) modelos):"
        echo "$NEW_WL" | while IFS= read -r m; do log "   - $m"; done
    else
        log "❌ Error al actualizar los perfiles. Revisar backups .bak."
    fi
else
    log "ℹ️ Sin retirados: el whitelist no se modifica."
fi

# --- Fase 3b: notificar si hubo cambios o candidatos ---
if [ "$CHANGES" = "yes" ] || [ -n "$ADDED" ]; then
    if command -v notify-send >/dev/null 2>&1; then
        MSG=""
        [ -n "$RETIRED" ] && MSG="${MSG}Retirados (eliminados del whitelist):\n$(echo "$RETIRED" | grep -v '^$' | sed 's/^/  • /')\n"
        [ -n "$ADDED" ] && MSG="${MSG}Candidatos nuevos (revisar para añadir):\n$(echo "$ADDED" | grep -v '^$' | sed 's/^/  • /')\n"
        notify-send -u normal "OpenCode: verificación NVIDIA quincenal" \
            "$(printf "$MSG")" 2>/dev/null || true
    fi
fi

# --- Fase 4: guardar estado de la ejecución ---
python3 -c "
import json
state = json.loads('''$STATE''')
state['ultima_ejecucion'] = '$(date '+%Y-%m-%dT%H:%M:%S')'
# modelos_vistos = todo el catálogo actual
state['modelos_vistos'] = '''$CATALOG_MODELS'''.strip().split('\n')
state['modelos_vistos'] = [m for m in state['modelos_vistos'] if m]
# guardar retirados
import datetime
hoy = '$(date '+%Y-%m-%d')'
ret = '''$RETIRED'''.strip().split('\n')
for m in ret:
    if m:
        state.setdefault('retirados', {})[m] = {'fecha': hoy, 'http': 410}
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2, ensure_ascii=False)
    f.write('\n')
" 2>>"$LOG_FILE" || log "⚠️ No se pudo guardar el estado en $STATE_FILE"

log "🏁 Verificación completada."
exit 0
