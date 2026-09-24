#!/usr/bin/env bash
# start-lmstudio-server.sh - Solo servidor LM Studio sin cargar modelo en VRAM
set -euo pipefail

LMSTUDIO="/home/antonio/.lmstudio/bin/lms"
PORT_LM=1234
PORT_PROXY=4001

echo "╔════════════════════════════════════════════════════╗"
echo "║  LM Studio Server (sin modelo cargado en VRAM)   ║"
echo "║  Esperando carga manual desde OpenCode/OCV       ║"
echo "╚════════════════════════════════════════════════════╝"

# Verificar binario
if [ ! -f "$LMSTUDIO" ]; then
    echo "❌ Binario no encontrado: $LMSTUDIO"
    exit 1
fi

# Descargar y cargar modelos previos para liberar VRAM
echo "▶️  Descargando modelos previos..."
"$LMSTUDIO" download --all >/dev/null 2>&1 || true

# Liberar TODOS los modelos cargados
echo "▶️  Liberando VRAM..."
"$LMSTUDIO" unload --all >/dev/null 2>&1 || true
sleep 2

# Verificar estado antes de iniciar servidor
MODELS_BEFORE=$("$LMSTUDIO" ps 2>/dev/null || echo "")
if [ -n "$MODELS_BEFORE" ]; then
    echo "⚠️  Advertencia: Hay modelos cargados:"
    echo "$MODELS_BEFORE" | grep -v "^$" | head -3
fi

# Iniciar servidor LM Studio si no está corriendo
echo "▶️  Verificando servidor LM Studio..."
if curl -s http://localhost:$PORT_LM/v1/models >/dev/null 2>&1; then
    echo "✅ LM Studio ya está corriendo en puerto ${PORT_LM}"
else
    echo "▶️  Arrancando LM Studio server..."
    "$LMSTUDIO" server start >/dev/null 2>&1
    sleep 3
    
    # Verificar que el servidor responde
    if ! curl -s http://localhost:$PORT_LM/v1/models >/dev/null 2>&1; then
        echo "❌ Falló al iniciar LM Studio. Asegúrate de que la GUI esté abierta o usa: lms server start"
        exit 1
    fi
fi

# Verificar estado final (debería estar vacío)
MODELS_AFTER=$("$LMSTUDIO" ps 2>/dev/null || echo "")
echo "✅ LM Studio activo en puerto ${PORT_LM}"

if [ -n "$MODELS_AFTER" ] && ! echo "$MODELS_AFTER" | grep -q "^$"; then
    VRAM_USO=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
    echo "⚠️  Advertencia: Modelo cargado (debería estar vacío):"
    echo "$MODELS_AFTER" | grep -v "^$" | head -3
    echo "   VRAM usada: ${VRAM_USO} MB"
else
    VRAM_USO=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
    echo "✅ VRAM libre: ${VRAM_USO} MB / 16376 MB"
fi

# Matar proxies zombies y arrancar uno limpio
echo "▶️  Iniciando proxy en puerto ${PORT_PROXY}..."
if pgrep -f "lmstudio-proxy" >/dev/null 2>&1; then
    pkill -f "lmstudio-proxy" 2>/dev/null || true
    sleep 1
fi

setsid python3 /home/antonio/.config/opencode/lmstudio-proxy.py "$PORT_PROXY" < /dev/null > /tmp/lms-proxy.log 2>&1 &
sleep 2
echo "✅ Proxy activo en http://localhost:${PORT_PROXY}"

echo ""
echo "════════════════════════════════════════════════════"
echo "  Servidor listo! Modelo NO cargado en VRAM."
echo "  Carga automática cuando uses: ocv o opencode"
echo "  API: http://localhost:${PORT_PROXY}/v1/chat/completions"
echo "════════════════════════════════════════════════════"
