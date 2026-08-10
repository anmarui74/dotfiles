#!/bin/bash
# Inicialización completa de OpenCode
# Arranca LM Studio, carga modelo con 80K contexto, inicia proxy
# Se ejecuta automáticamente al iniciar sesión vía systemd --user

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/opencode.json"
LOG_FILE="${SCRIPT_DIR}/data/init.log"
DATA_DIR="${SCRIPT_DIR}/data"
LMSTUDIO_BIN="/home/antonio/.lmstudio/bin/lms"
MODELO="models-qwen3.5-9b"
CONTEXTO=81920
PUERTO_LM=1234
PUERTO_PROXY=4001

mkdir -p "$DATA_DIR"

echo "=== Inicialización OpenCode - $(date '+%d/%m/%Y %H:%M') ===" > "$LOG_FILE"
echo "" >> "$LOG_FILE"

log() {
    echo "[$(date '+%H:%M')] $1" | tee -a "$LOG_FILE"
}

# ─── 1. Arrancar servidor LM Studio ───
iniciar_lmstudio() {
    log "--- 1. Servidor LM Studio ---"
    if curl -s -o /dev/null -w "" http://127.0.0.1:$PUERTO_LM/v1/models 2>/dev/null; then
        log "✅ Servidor LM Studio ya está corriendo en puerto $PUERTO_LM."
    else
        log "🔄 Arrancando servidor LM Studio..."
        $LMSTUDIO_BIN server start 2>/dev/null
        sleep 3
        if curl -s -o /dev/null -w "" http://127.0.0.1:$PUERTO_LM/v1/models 2>/dev/null; then
            log "✅ Servidor LM Studio arrancado correctamente."
        else
            log "❌ No se pudo arrancar LM Studio. Ejecuta 'lms server start' manualmente."
            return 1
        fi
    fi
    return 0
}

# ─── 2. Cargar modelo con 80K de contexto ───
cargar_modelo() {
    log "--- 2. Modelo ($MODELO) ---"
    local ctx_actual
    ctx_actual=$($LMSTUDIO_BIN ps 2>/dev/null | grep "$MODELO" | awk '{print $6}')

    if [ "$ctx_actual" = "$CONTEXTO" ]; then
        log "✅ Modelo $MODELO ya cargado con contexto $CONTEXTO."
        return 0
    fi

    log "🔄 Cargando $MODELO con contexto $CONTEXTO..."
    $LMSTUDIO_BIN unload "$MODELO" 2>/dev/null
    $LMSTUDIO_BIN load "$MODELO" -c $CONTEXTO -y 2>/dev/null

    ctx_actual=$($LMSTUDIO_BIN ps 2>/dev/null | grep "$MODELO" | awk '{print $6}')
    if [ "$ctx_actual" = "$CONTEXTO" ]; then
        log "✅ Modelo cargado con contexto $CONTEXTO."
    else
        log "⚠️  Contexto cargado: $ctx_actual (se esperaba $CONTEXTO). Reintentando..."
        sleep 2
        $LMSTUDIO_BIN unload "$MODELO" 2>/dev/null
        $LMSTUDIO_BIN load "$MODELO" -c $CONTEXTO -y 2>/dev/null
        ctx_actual=$($LMSTUDIO_BIN ps 2>/dev/null | grep "$MODELO" | awk '{print $6}')
        if [ "$ctx_actual" = "$CONTEXTO" ]; then
            log "✅ Contexto correcto tras reintento."
        else
            log "❌ Contexto sigue siendo $ctx_actual. Revisa LM Studio manualmente."
        fi
    fi
}

# ─── 3. Iniciar proxy ───
iniciar_proxy() {
    log "--- 3. Proxy (puerto $PUERTO_PROXY) ---"
    if curl -s -o /dev/null -w "" http://127.0.0.1:$PUERTO_PROXY/v1/models 2>/dev/null; then
        log "✅ Proxy ya activo en puerto $PUERTO_PROXY."
        return 0
    fi

    if pgrep -f "lmstudio-proxy.py" > /dev/null 2>&1; then
        log "✅ Proxy ya presente (aunque no respondía rápido). Se mantiene."
        return 0
    fi

    log "🔄 Iniciando proxy en puerto $PUERTO_PROXY..."
    setsid python3 "$SCRIPT_DIR/lmstudio-proxy.py" $PUERTO_PROXY < /dev/null > /tmp/lmstudio-proxy.log 2>&1 &
    sleep 2

    if curl -s -o /dev/null -w "" http://127.0.0.1:$PUERTO_PROXY/v1/models 2>/dev/null; then
        log "✅ Proxy iniciado correctamente."
    else
        log "❌ Proxy no responde. Revisa /tmp/lmstudio-proxy.log"
    fi
}

# ─── 4. Asegurar settings.json con 80K ───
fijar_contexto_settings() {
    local settings_file="$HOME/.lmstudio/settings.json"
    if [ -f "$settings_file" ]; then
        local valor_actual
        valor_actual=$(python3 -c "
import json
try:
    d = json.load(open('$settings_file'))
    v = d.get('defaultContextLength', {}).get('value', '')
    print(v)
except: print('')
" 2>/dev/null)
        if [ "$valor_actual" != "$CONTEXTO" ]; then
            python3 -c "
import json
d = json.load(open('$settings_file'))
d['defaultContextLength'] = {'type': 'custom', 'value': '$CONTEXTO'}
json.dump(d, open('$settings_file', 'w'), indent=2)
" 2>/dev/null && log "✅ defaultContextLength fijado a $CONTEXTO en settings.json"
        fi
    fi
}

# ─── 5. Verificaciones ───
check_models() {
    log "--- 4. Modelos disponibles ---"
    sleep 1
    local respuesta
    respuesta=$(curl -s http://127.0.0.1:$PUERTO_LM/v1/models)
    if [ -n "$respuesta" ]; then
        echo "$respuesta" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 > "${DATA_DIR}/available_models.txt" 2>/dev/null || true
        local count=$(wc -l < "${DATA_DIR}/available_models.txt" 2>/dev/null || echo 0)
        log "✅ $count modelo(s) disponible(s)."
    else
        log "⚠️ No se pudo listar modelos."
    fi
}

check_memory() {
    if [ -f "${DATA_DIR}/memory_status.txt" ]; then
        log "✅ Persistencia de datos presente."
    else
        echo "initialized at $(date '+%d/%m/%Y %H:%M')" > "${DATA_DIR}/memory_status.txt"
        log "✅ Persistencia de datos inicializada."
    fi
}

check_hardware() {
    if [ -f "${DATA_DIR}/hardware/index.json" ]; then
        log "✅ Index de hardware disponible."
    else
        log "⚠️ Index de hardware no encontrado."
    fi
}

check_env() {
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        log "✅ Archivo .env presente."
    else
        log "⚠️ .env no encontrado."
    fi
}

# ─── MAIN ───
log "🚀 INICIO - Inicialización de OpenCode"

fijar_contexto_settings
iniciar_lmstudio
cargar_modelo
iniciar_proxy
check_models
check_memory
check_hardware
check_env

log ""
log "✅ INICIALIZACIÓN COMPLETADA"
log "   LM Studio : http://127.0.0.1:$PUERTO_LM/v1"
log "   Proxy     : http://127.0.0.1:$PUERTO_PROXY/v1"
log "   Contexto  : $CONTEXTO tokens"

echo ""
echo "✅ OpenCode listo. Detalles en: $LOG_FILE"
tail -5 "$LOG_FILE"
