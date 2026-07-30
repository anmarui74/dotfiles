#!/usr/bin/env bash
# start-lmstudio.sh - Qwen3.5-9B Q6_K + RTX 4070 Ti SUPER (80k contexto)
set -euo pipefail

LMSTUDIO="/home/antonio/.lmstudio/bin/lms"
MODEL_ID="models-qwen3.5-9b"
CONTEXTO=81920
PORT_LM=1234
PORT_PROXY=4001

echo "╔════════════════════════════════════════════════════╗"
echo "║  Qwen3.5-9B Q6_K - 80k contexto                  ║"
echo "║  RTX 4070 Ti SUPER 16GB + Ryzen 9 7900 Zen4      ║"
echo "╚════════════════════════════════════════════════════╝"

# Verificar binario
if [ ! -f "$LMSTUDIO" ]; then
    echo "❌ Binario no encontrado: $LMSTUDIO"
    exit 1
fi

# Iniciar servidor LM Studio si no está corriendo
if ! curl -s http://localhost:$PORT_LM/v1/models >/dev/null 2>&1; then
    echo "▶️  Arrancando LM Studio server..."
    "$LMSTUDIO" server start >/dev/null 2>&1
    sleep 3
fi
echo "✅ LM Studio activo puerto ${PORT_LM}"

# Descargar modelos previos para liberar VRAM
echo "▶️  Liberando VRAM..."
"$LMSTUDIO" unload --all >/dev/null 2>&1 || true
sleep 2

# Cargar Q6_K con 80k contexto
echo "▶️  Cargando Qwen3.5-9B Q6_K con ${CONTEXTO} tokens de contexto..."
if ! "$LMSTUDIO" load "$MODEL_ID" -c "$CONTEXTO" -y >/dev/null 2>&1; then
    echo "⚠️  Carga directa falló, intentando sin contexto específico..."
    "$LMSTUDIO" load "$MODEL_ID" -y >/dev/null 2>&1
fi
sleep 2

CONTEXTO_REAL=$("$LMSTUDIO" ps 2>/dev/null | grep -m1 "$MODEL_ID" | awk '{print $6}')
echo "✅ Modelo cargado: ${CONTEXTO_REAL:-desconocido} tokens de contexto"

VRAM_USO=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
echo "✅ VRAM usado: ${VRAM_USO} MB / 16376 MB"

# Matar proxies zombies y arrancar uno limpio
if pgrep -f "lmstudio-proxy" >/dev/null 2>&1; then
    pkill -f "lmstudio-proxy" 2>/dev/null || true
    sleep 1
fi
echo "▶️  Iniciando proxy en puerto ${PORT_PROXY}..."
setsid python3 /home/antonio/.config/opencode/lmstudio-proxy.py "$PORT_PROXY" < /dev/null > /tmp/lms-proxy.log 2>&1 &
sleep 2
echo "✅ Proxy activo en http://localhost:${PORT_PROXY}"

echo ""
echo "════════════════════════════════════════════════════"
echo "  Sistema listo para usar!"
echo "  API: http://localhost:${PORT_PROXY}/v1/chat/completions"
echo "  Modelo: $MODEL_ID"
echo "  Contexto: ${CONTEXTO} tokens"
echo "  Tokens/s: incluido en cada respuesta"
echo "════════════════════════════════════════════════════"
