#!/bin/bash
# Restaurar OpenCode desde backup - generado automáticamente por backup-opencode.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}"
DEST_CONFIG="/home/antonio/.config/opencode"

echo "=== Restaurando OpenCode ==="
echo "Fuente: $SOURCE_DIR"
echo "Destino: ${DEST_CONFIG}"
echo ""

if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ ERROR: Directorio de backup no encontrado: $SOURCE_DIR"
    exit 1
fi

# Crear directorio destino si no existe
mkdir -p "$DEST_CONFIG"

# Copiar archivos (excluyendo el propio restore.sh y el setup completo)
echo "Copiando archivos..."
rsync -ah --exclude='*-restore.sh' \
       --exclude='setup-opencode-completo.sh' \
       "$SOURCE_DIR/" "${DEST_CONFIG}/."

# Restaurar respaldo OnlyOffice-IA en Config/opencode/data/
if [ -d "${SOURCE_DIR}/data/onlyoffice-ai" ]; then
    mkdir -p "/home/antonio/Config/opencode/data"
    cp -r "${SOURCE_DIR}/data/onlyoffice-ai" "/home/antonio/Config/opencode/data/onlyoffice-ai"
    echo "✅ Respaldo OnlyOffice-IA restaurado en Config/opencode/data/"
fi

# El setup-opencode-completo.sh vive solo en la copia de seguridad
if [ -f "$SOURCE_DIR/setup-opencode-completo.sh" ]; then
    mkdir -p "/home/antonio/Config/opencode/sesion-opencode"
    cp "$SOURCE_DIR/setup-opencode-completo.sh" \
       "/home/antonio/Config/opencode/sesion-opencode/setup-opencode-completo.sh"
    echo "✅ setup-opencode-completo.sh restaurado en Config/opencode/sesion-opencode/"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Restauración completada en ${DEST_CONFIG}"

    # Verificar archivos críticos
    if [ -f "${DEST_CONFIG}/opencode.json" ] && \
       [ -f "${DEST_CONFIG}/AGENTS.md" ] && \
       [ -f "${DEST_CONFIG}/init-opencode.sh" ]; then
        echo "✅ Archivos principales verificados correctamente"

        # Inicializar si es necesario
        if [ -x "${DEST_CONFIG}/init-opencode.sh" ]; then
            echo ""
            echo "🚀 Ejecutando inicialización de OpenCode..."
            bash "${DEST_CONFIG}/init-opencode.sh"
        fi
    else
        echo "⚠️  Algunos archivos faltantes. Revisa la restauración:"
        ls -la "${DEST_CONFIG}" | head -20
    fi

    echo ""
    echo "✅ Backup restaurado correctamente"
else
    echo "❌ ERROR: Fallo al copiar archivos"
    exit 1
fi
