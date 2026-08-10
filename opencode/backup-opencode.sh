#!/bin/bash
# Backup de OpenCode - Script oficial según AGENTS.md
# Genera tarball con restore.sh actualizado
# Puntos de AGENTS.md líneas 59-68:
#   - Copia desde .config/opencode/ a Config/opencode/
#   - Actualiza backup-opencode.sh y bootstrap-ocv.sh
#   - restore.sh va dentro del tarball (lo genera este script)

set -euo pipefail

CONFIG_ACTIVO="/home/antonio/.config/opencode"
CONFIG_BACKUP="/home/antonio/Config/opencode"
BACKUP_DIR="${CONFIG_BACKUP}/backups/opencode"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="opencode-backup-${DATE}"

BACKUP_ROOT="${BACKUP_DIR}/${BACKUP_NAME}"

echo "=== Backup OpenCode - $(date '+%d/%m/%Y %H:%M') ==="

# ─── 0. VERIFICACIÓN OBLIGATORIA DEL SETUP (AGENTS.md) ───
# El setup-opencode-completo.sh debe estar CORRECTO y COMPLETO antes
# de generar el backup. Si la verificación falla, se ABORTA.
echo "🔍 Verificando setup-opencode-completo.sh (check-setup-completo.sh)..."
if [ -f "$HOME/.config/opencode/check-setup-completo.sh" ]; then
    if bash "$HOME/.config/opencode/check-setup-completo.sh"; then
        echo "✅ Setup verificado correctamente. Continuando backup..."
    else
        echo ""
        echo "❌❌❌ VERIFICACIÓN DEL SETUP FALLIDA ❌❌❌"
        echo "   El setup-opencode-completo.sh no está correcto/completo."
        echo "   Corrige el setup ANTES de hacer el backup (ver AGENTS.md)."
        echo "   El backup se ABORTA para no guardar un setup defectuoso."
        exit 1
    fi
else
    echo "⚠️ check-setup-completo.sh no encontrado. ¿Se instaló correctamente?"
fi

mkdir -p "${BACKUP_DIR}" "${BACKUP_ROOT}"

# ─── 1. Copiar estructura de .config/opencode/ excluyendo runtime y backups viejos
echo "📦 Copiando configuración desde ~/.config/opencode/..."
rsync -ah --delete \
  --exclude='backups/' \
  --exclude='sesion-opencode/' \
  --exclude='node_modules/' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='data/memory/' \
  --exclude='data/dmi/' \
  --exclude='data/init.log' \
  --exclude='data/sync.log' \
  --exclude='data/common-cmds.log' \
  --exclude='models/' \
  --exclude='build/' \
  --exclude='.git/' \
  --exclude='package-lock.json' \
  --exclude='package.json' \
  --exclude='*.tar.gz' \
  --exclude='opencode-backup-*/' \
  --exclude='opencode-sync-*.tar.gz' \
  --exclude='setup-opencode-completo.sh' \
  "${CONFIG_ACTIVO}/." "${BACKUP_ROOT}/"

# ─── 1b. Incluir respaldo OnlyOffice-IA en el tarball ───
if [ -d "${CONFIG_BACKUP}/data/onlyoffice-ai" ]; then
    mkdir -p "${BACKUP_ROOT}/data"
    cp -r "${CONFIG_BACKUP}/data/onlyoffice-ai" "${BACKUP_ROOT}/data/onlyoffice-ai"
    echo "   ✅ Respaldo OnlyOffice-IA incluido en el backup"
fi

# ─── 2. Generar restore.sh dentro del backup
echo "🔧 Creando restore.sh..."
cat > "${BACKUP_ROOT}/${BACKUP_NAME}-restore.sh" << 'RESTORE_EOF'
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
RESTORE_EOF

chmod +x "${BACKUP_ROOT}/${BACKUP_NAME}-restore.sh"
echo "   ✅ restore.sh creado"

# ─── 3. Copiar scripts de instalación (si existen en Config)
echo ""
echo "📋 Verificando scripts de instalación..."

if [ -f "${CONFIG_BACKUP}/sesion-opencode/setup-opencode-completo.sh" ]; then
    cp "${CONFIG_BACKUP}/sesion-opencode/setup-opencode-completo.sh" \
       "${BACKUP_ROOT}/setup-opencode-completo.sh" && \
    echo "   ✅ setup-opencode-completo.sh copiado" || \
    echo "   ⚠️  setup-opencode-completo.sh no encontrado en Config/"
fi

if [ -f "${CONFIG_BACKUP}/sesion-opencode/bootstrap-ocv.sh" ]; then
    cp "${CONFIG_BACKUP}/sesion-opencode/bootstrap-ocv.sh" \
       "${BACKUP_ROOT}/bootstrap-ocv.sh" && \
    echo "   ✅ bootstrap-ocv.sh copiado" || \
    echo "   ⚠️  bootstrap-ocv.sh no encontrado en Config/"
fi

# ─── 4. Generar tarball del backup
echo ""
echo "📦 Creando tarball..."
cd "${BACKUP_ROOT}"
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" .
cd - > /dev/null

BACKUP_SIZE=$(ls -lh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | awk '{print $5}')
echo "   ✅ Tarball creado (${BACKUP_SIZE}): ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# ─── 5. Limpiar directorio temporal del backup
echo ""
echo "🧹 Limpiando directorio temporal..."
rm -rf "${BACKUP_ROOT}"

# ─── 5. Retención: borrar tarballs con más de 30 días (LOG_RETENTION_DAYS) ───
RETENTION_DAYS="${LOG_RETENTION_DAYS:-30}"
echo ""
echo "🧹 Aplicando retención (${RETENTION_DAYS} días) en ${BACKUP_DIR}..."
OLD_TARBALLS=$(find "${BACKUP_DIR}" -maxdepth 1 -name 'opencode-*.tar.gz' -mtime +"${RETENTION_DAYS}" 2>/dev/null | wc -l)
if [ "${OLD_TARBALLS}" -gt 0 ]; then
    find "${BACKUP_DIR}" -maxdepth 1 -name 'opencode-*.tar.gz' -mtime +"${RETENTION_DAYS}" -delete 2>/dev/null || true
    echo "   🗑️  ${OLD_TARBALLS} tarballs antiguos eliminados (más de ${RETENTION_DAYS} días)"
else
    echo "   ✅ No hay tarballs antiguos que eliminar"
fi

# ─── 6. Poda diaria: conservar solo el ÚLTIMO tarball de cada día ───
echo "🗂️  Podando duplicados del mismo día (se conserva el último)..."
PODADOS=0
for f in "${BACKUP_DIR}"/opencode-*_*.tar.gz "${BACKUP_DIR}"/opencode-*-*.tar.gz; do
    [ -f "$f" ] || continue
    DAY=$(basename "$f" | grep -oE '[0-9]{8}' | head -1 || true)
    [ -n "$DAY" ] || continue
    LAST=$(find "${BACKUP_DIR}" -maxdepth 1 -name "opencode-*-${DAY}-*.tar.gz" 2>/dev/null | sort | tail -1)
    if [ -n "$LAST" ] && [ "$f" != "$LAST" ]; then
        rm -f "$f"
        PODADOS=$((PODADOS+1))
    fi
done
echo "   🗑️  ${PODADOS} duplicados del mismo día eliminados"

echo ""
echo "✅ Backup completado!"
echo ""
echo "Ubicación: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
echo "Para restaurar:"
echo "  1. tar -xzf ${CONFIG_BACKUP}/${BACKUP_NAME}.tar.gz -C /tmp/restore-opencode"
echo "  2. bash /tmp/restore-opencode/*-restore.sh"
echo ""
