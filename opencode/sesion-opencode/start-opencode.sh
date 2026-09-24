#!/usr/bin/env bash
# Lanzador de OpenCode: verifica/arranca LM Studio, luego abre OpenCode
set -e

# Colores para output
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
ROJO='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${VERDE}[+]${NC} $1"; }
aviso() { echo -e "${AMARILLO}[!]${NC} $1"; }
error() { echo -e "${ROJO}[X]${NC} $1"; }

LMS_BIN="/home/antonio/.lmstudio/bin/lms"
LM_PORT=1234

# 1. Verificar / arrancar LM Studio (servidor API en puerto 1234)
if curl -s -o /dev/null -w "" "http://127.0.0.1:${LM_PORT}/v1/models" 2>/dev/null; then
    info "LM Studio ya está corriendo en el puerto ${LM_PORT}"
else
    aviso "Servidor de LM Studio no responde en el puerto ${LM_PORT}. Iniciándolo..."
    if command -v lms &>/dev/null; then
        lms server start
    elif [ -x "$LMS_BIN" ]; then
        "$LMS_BIN" server start
    else
        error "No se encuentra el comando 'lms' ni en PATH ni en ${LMS_BIN}"
        exit 1
    fi
    # Esperar a que responda
    for i in $(seq 1 15); do
        if curl -s -o /dev/null -w "" "http://127.0.0.1:${LM_PORT}/v1/models" 2>/dev/null; then
            info "LM Studio arrancado correctamente"
            break
        fi
        sleep 1
    done
    if ! curl -s -o /dev/null -w "" "http://127.0.0.1:${LM_PORT}/v1/models" 2>/dev/null; then
        error "No se pudo arrancar el servidor de LM Studio."
        error "Asegúrate de que LM Studio (GUI) esté abierto o ejecuta manualmente: lms server start"
        exit 1
    fi
fi

# 2. Ejecutar OpenCode (binario real)
REAL_OPENCODE="${REAL_OPENCODE:-/usr/bin/opencode}"
info "Lanzando ${REAL_OPENCODE}..."
exec "${REAL_OPENCODE}" "$@"
