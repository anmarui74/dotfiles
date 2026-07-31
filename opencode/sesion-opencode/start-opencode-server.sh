#!/usr/bin/env bash
# start-opencode-server.sh - Carga LM Studio + modelo Qwen3.5-9B + proxy, luego abre OpenCode/OCV
set -e

# Colores para output
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
ROJO='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${VERDE}[+]${NC} $1"; }
aviso() { echo -e "${AMARILLO}[!]${NC} $1"; }
error() { echo -e "${ROJO}[X]${NC} $1"; }

LMS_SCRIPT="/home/antonio/.config/opencode/start-lmstudio.sh"
REAL_OPENCODE="${REAL_OPENCODE:-/usr/bin/opencode}"

# 1. Cargar LM Studio + modelo Qwen3.5-9B + proxy
if [ -x "$LMS_SCRIPT" ]; then
    info "Cargando LM Studio (modelo Qwen3.5-9B + proxy)..."
    bash "$LMS_SCRIPT" || {
        error "Falló al cargar LM Studio + modelo."
        exit 1
    }
else
    aviso "start-lmstudio.sh no encontrado, usando start-lmstudio-server.sh"
    bash /home/antonio/.config/opencode/start-lmstudio-server.sh || {
        error "Falló al iniciar LM Studio."
        exit 1
    }
fi

# 2. Ejecutar OpenCode (binario real)
info "Lanzando ${REAL_OPENCODE}..."
exec "${REAL_OPENCODE}" "$@"
