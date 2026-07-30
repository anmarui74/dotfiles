#!/bin/bash

# Script para cambiar entre configuraciones de OpenCode (local/cloud)
# Uso: switch-mcp-profile.sh [local|cloud]

CONFIG_DIR="$HOME/.config/opencode"

if [ -z "$1" ]; then
    echo "Uso: $0 [local|cloud]"
    echo ""
    echo "  local  - Filesystem, fetch y memory (para modelos locales)"
    echo "  cloud  - Context7, memory, fetch y sequential_thinking (para modelos cloud)"
    exit 1
fi

PROFILE="$1"

if [ "$PROFILE" != "local" ] && [ "$PROFILE" != "cloud" ]; then
    echo "Error: Perfil no válido. Usa 'local' o 'cloud'"
    exit 1
fi

SOURCE_FILE="$CONFIG_DIR/opencode-$PROFILE.json"
TARGET_FILE="$CONFIG_DIR/opencode.json"

if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: No existe $SOURCE_FILE"
    exit 1
fi

cp "$SOURCE_FILE" "$TARGET_FILE"

echo "✅ Configuración cambiada a: $PROFILE"
echo ""
echo "MCPs activos:"
if [ "$PROFILE" = "local" ]; then
    echo "  - filesystem"
    echo "  - fetch"
    echo "  - memory"
else
    echo "  - context7"
    echo "  - memory"
    echo "  - fetch"
    echo "  - sequential_thinking"
fi

echo ""
echo "⚠️  Reinicia OpenCode para aplicar los cambios:"
echo "   exit"
echo "   ocv"
