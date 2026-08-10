#!/usr/bin/env bash
# setup-models.sh — Verifica modelos disponibles en LM Studio
# Uso: bash setup-models.sh
# Los modelos se descargan desde la interfaz gráfica de LM Studio o con:
#   lms get <modelo>
# Ejemplo: lms get qwen/qwen3.5-9b

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }

echo "=============================================="
echo "  Verificación de modelos en LM Studio"
echo "=============================================="
echo ""

LMS_BIN="/home/antonio/.lmstudio/bin/lms"
LMS_PORT=1234

# Verificar que LM Studio responde
if curl -s -o /dev/null -w "" "http://127.0.0.1:${LMS_PORT}/v1/models" 2>/dev/null; then
    info "LM Studio responde en el puerto ${LMS_PORT}"
else
    err "LM Studio no responde en el puerto ${LMS_PORT}."
    info "Asegúrate de que el servidor esté iniciado: lms server start"
    exit 1
fi

# Listar modelos disponibles desde LM Studio
echo ""
echo "Modelos disponibles en LM Studio:"
echo "----------------------------------"
curl -s "http://127.0.0.1:${LMS_PORT}/v1/models" | python3 -c "
import json, sys
data = json.load(sys.stdin)
models = data.get('data', [])
if not models:
    print('  No hay modelos cargados.')
    print('  Descarga uno desde la GUI de LM Studio o con: lms get <modelo>')
else:
    for m in models:
        print(f'  - {m[\"id\"]}')
" 2>/dev/null || warn "No se pudieron listar los modelos"

echo ""
echo "Modelo principal recomendado para OpenCode:"
echo "  qwen/qwen3.5-9b"
echo ""
echo "Para descargar un modelo:"
echo "  1. Abre LM Studio"
echo "  2. Busca el modelo en la pestaña 'Descubrir'"
echo "  3. O desde terminal: lms get <modelo>"
echo ""
echo "Para más información:"
echo "  lms --help"
echo ""
