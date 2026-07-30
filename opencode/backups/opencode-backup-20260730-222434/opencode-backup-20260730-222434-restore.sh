#!/bin/bash
# Restaurar OpenCode desde backup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}"
DEST_CONFIG="/home/antonio/.config/opencode"

echo "=== Restaurando OpenCode ==="

if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Directorio de backup no encontrado: $SOURCE_DIR"
    exit 1
fi

# Crear directorio destino si no existe
mkdir -p "$DEST_CONFIG"

# Copiar archivos (excluyendo el propio restore.sh)
rsync -av --exclude='${BACKUP_NAME}-restore.sh' "$SOURCE_DIR/" "$DEST_CONFIG/" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Restauración completada en $DEST_CONFIG"
    
    # Verificar archivos críticos
    if [ -f "${DEST_CONFIG}/opencode.json" ] && \
       [ -f "${DEST_CONFIG}/AGENTS.md" ] && \
       [ -f "${DEST_CONFIG}/init-opencode.sh" ]; then
        echo "✅ Archivos principales verificados correctamente"
        
        # Inicializar si es necesario
        if [ -x "${DEST_CONFIG}/init-opencode.sh" ]; then
            echo ""
            echo "🚀 Ejecutando inicialización..."
            bash "${DEST_CONFIG}/init-opencode.sh"
        fi
    else
        echo "⚠️ Algunos archivos faltantes. Revisa la restauración."
    fi
else
    echo "❌ Error al copiar archivos"
    exit 1
fi

echo ""
echo "✅ Backup restaurado correctamente"
