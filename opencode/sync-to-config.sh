#!/bin/bash
# Sincronización rápida de configuración crítica a Config/opencode/sesion-opencode/
# Sigue la estructura de backup definida en AGENTS.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_BACKUP="/home/antonio/Config/opencode"
SESION_DIR="${CONFIG_BACKUP}/sesion-opencode"

echo "=== Sincronizando configuración ==="

mkdir -p "$SESION_DIR"

# Copiar archivos JSON críticos
echo "📋 Copiando configuraciones principales..."
cp "$SCRIPT_DIR/opencode.json" "$SESION_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/opencode-local.json" "$SESION_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/opencode-cloud.json" "$SESION_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/qwen-qwen3.5-9b.json" "$SESION_DIR/" 2>/dev/null || true

# Copiar scripts críticos
echo "📝 Copiando scripts..."
cp "$SCRIPT_DIR/backup-opencode.sh" "$SESION_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/init-opencode.sh" "$SESION_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/start-lmstudio.sh" "$SESION_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/sync-to-config.sh" "$SESION_DIR/" 2>/dev/null || true

# Generar tarball de respaldo con todo el contenido de sesion-opencode
echo "📦 Creando tarball optimizado..."
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="opencode-sync-${DATE}"

cd "$SESION_DIR"
tar -czf "${CONFIG_BACKUP}/${BACKUP_NAME}.tar.gz" . 2>/dev/null || true
cd - > /dev/null

echo ""
echo "✅ Sincronización completada"
echo "   Backup: ${CONFIG_BACKUP}/${BACKUP_NAME}.tar.gz"
echo "   Sesión: $SESION_DIR/"
ls -lh "${CONFIG_BACKUP}/${BACKUP_NAME}.tar.gz"
