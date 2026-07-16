#!/usr/bin/env bash
# backup-opencode.sh — Respalda toda la configuración personalizada de OpenCode
# Uso: bash ~/Config/opencode/backup-opencode.sh
# Genera: ~/Config/opencode/backups/opencode-config-AAAAMMDD-HHMMSS.tar.gz
#         ~/Config/opencode/backups/restore.sh (script de restauración)

set -euo pipefail

HOME_DIR="$HOME"
CONFIG_DIR="$HOME_DIR/Config/opencode"
BACKUP_DIR="$CONFIG_DIR/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="opencode-config-${TIMESTAMP}.tar.gz"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"
TMPDIR=$(mktemp -d)

mkdir -p "$BACKUP_DIR"

echo "=============================================="
echo "  Respaldo de configuración de OpenCode"
echo "=============================================="
echo ""

# ---- 1. Re-generar setup-voz.sh con el código actual ----
echo ">>> Actualizando setup-voz.sh..."

# Copiar stt.js, tts.js, index.js actuales
mkdir -p "$TMPDIR/plugin/lib"
cp "$HOME_DIR/.config/opencode/opencode-voice-modified/lib/stt.js" "$TMPDIR/plugin/lib/stt.js"
cp "$HOME_DIR/.config/opencode/opencode-voice-modified/lib/tts.js" "$TMPDIR/plugin/lib/tts.js"
cp "$HOME_DIR/.config/opencode/opencode-voice-modified/index.js" "$TMPDIR/plugin/index.js"
cp "$HOME_DIR/.config/opencode/opencode-voice-modified/lib/session.js" "$TMPDIR/plugin/lib/session.js"
cp "$HOME_DIR/.config/opencode/opencode-voice-modified/lib/logger.js" "$TMPDIR/plugin/lib/logger.js"
cp "$HOME_DIR/.config/opencode/opencode-voice-modified/lib/llm-client.js" "$TMPDIR/plugin/lib/llm-client.js"

# Copiar speak script
cp "$HOME_DIR/.local/bin/speak" "$TMPDIR/speak"

# Copiar whisper wrapper
cp "$HOME_DIR/.local/bin/whisper-cli" "$TMPDIR/whisper-cli"

# Extraer función ocv y PATH de .zshrc
grep -A2 "^function ocv" "$HOME_DIR/.zshrc" > "$TMPDIR/zshrc-ocv.txt" 2>/dev/null || true
grep 'PATH.*\.local/bin' "$HOME_DIR/.zshrc" | head -1 > "$TMPDIR/zshrc-path.txt" 2>/dev/null || true

# Copiar archivos de configuración de opencode
cp "$HOME_DIR/.config/opencode/opencode.json" "$TMPDIR/opencode.json"
cp "$HOME_DIR/.config/opencode/opencode.jsonc" "$TMPDIR/opencode.jsonc" 2>/dev/null || true
cp "$HOME_DIR/.config/opencode/tui.json" "$TMPDIR/tui.json"
cp "$HOME_DIR/.config/opencode/AGENTS.md" "$TMPDIR/AGENTS.md"
cp "$HOME_DIR/.config/opencode/ollama-proxy.py" "$TMPDIR/ollama-proxy.py" 2>/dev/null || true
cp "$HOME_DIR/.config/opencode/litellm-config.yaml" "$TMPDIR/litellm-config.yaml" 2>/dev/null || true

# Crear script de restauración
cat > "$TMPDIR/restore.sh" << 'RESTORE'
#!/usr/bin/env bash
# restore.sh — Restaura configuración de OpenCode desde este respaldo
# Uso: bash restore.sh

set -euo pipefail

echo "=============================================="
echo "  Restaurando configuración de OpenCode..."
echo "=============================================="

HOME_DIR="$HOME"
BACKUP_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. Configuración principal
echo ">>> Copiando opencode.json..."
mkdir -p "$HOME_DIR/.config/opencode"
cp "$BACKUP_DIR/opencode.json" "$HOME_DIR/.config/opencode/"

if [ -f "$BACKUP_DIR/opencode.jsonc" ]; then
    cp "$BACKUP_DIR/opencode.jsonc" "$HOME_DIR/.config/opencode/"
fi

cp "$BACKUP_DIR/tui.json" "$HOME_DIR/.config/opencode/"
cp "$BACKUP_DIR/AGENTS.md" "$HOME_DIR/.config/opencode/"

# 2. Proxy
if [ -f "$BACKUP_DIR/ollama-proxy.py" ]; then
    echo ">>> Copiando ollama-proxy.py..."
    cp "$BACKUP_DIR/ollama-proxy.py" "$HOME_DIR/.config/opencode/"
fi

# 3. Plugin de voz
echo ">>> Restaurando plugin opencode-voice..."
PLUGIN_DIR="$HOME_DIR/.config/opencode/opencode-voice-modified"
rm -rf "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR/lib"
cp "$BACKUP_DIR/plugin/index.js" "$PLUGIN_DIR/"
cp "$BACKUP_DIR/plugin/lib/stt.js" "$PLUGIN_DIR/lib/"
cp "$BACKUP_DIR/plugin/lib/tts.js" "$PLUGIN_DIR/lib/"
cp "$BACKUP_DIR/plugin/lib/session.js" "$PLUGIN_DIR/lib/"
cp "$BACKUP_DIR/plugin/lib/logger.js" "$PLUGIN_DIR/lib/"
cp "$BACKUP_DIR/plugin/lib/llm-client.js" "$PLUGIN_DIR/lib/"

# Copiar package.json del original si existe
if [ -d "/usr/lib/node_modules/@renjfk/opencode-voice" ]; then
    cp "/usr/lib/node_modules/@renjfk/opencode-voice/package.json" "$PLUGIN_DIR/"
    cp "/usr/lib/node_modules/@renjfk/opencode-voice/LICENSE" "$PLUGIN_DIR/" 2>/dev/null || true
fi

# 4. speak script
echo ">>> Instalando speak..."
mkdir -p "$HOME_DIR/.local/bin"
cp "$BACKUP_DIR/speak" "$HOME_DIR/.local/bin/"
chmod +x "$HOME_DIR/.local/bin/speak"

# 5. whisper wrapper
if [ -f "$BACKUP_DIR/whisper-cli" ]; then
    echo ">>> Instalando whisper-cli..."
    cp "$BACKUP_DIR/whisper-cli" "$HOME_DIR/.local/bin/"
    chmod +x "$HOME_DIR/.local/bin/whisper-cli"
fi

# 6. Añadir función ocv y PATH a .zshrc
if [ -f "$BACKUP_DIR/zshrc-ocv.txt" ] && [ -s "$BACKUP_DIR/zshrc-ocv.txt" ]; then
    if ! grep -q "function ocv" "$HOME_DIR/.zshrc" 2>/dev/null; then
        echo "" >> "$HOME_DIR/.zshrc"
        echo "# OCV - OpenCode con voz" >> "$HOME_DIR/.zshrc"
        cat "$BACKUP_DIR/zshrc-ocv.txt" >> "$HOME_DIR/.zshrc"
        echo ">>> función ocv añadida a .zshrc"
    else
        echo ">>> función ocv ya existe en .zshrc"
    fi
fi

if [ -f "$BACKUP_DIR/zshrc-path.txt" ] && [ -s "$BACKUP_DIR/zshrc-path.txt" ]; then
    if ! grep -q '\.local/bin' "$HOME_DIR/.zshrc" 2>/dev/null; then
        cat "$BACKUP_DIR/zshrc-path.txt" >> "$HOME_DIR/.zshrc"
        echo ">>> PATH añadido a .zshrc"
    fi
fi

echo ""
echo "=============================================="
echo "  Restauración completada"
echo "=============================================="
echo "Recarga: source ~/.zshrc"
echo "Luego ejecuta: ocv"
RESTORE
chmod +x "$TMPDIR/restore.sh"

# Crear el tarball
cd "$TMPDIR"
tar czf "$BACKUP_PATH" . 2>/dev/null
cd "$HOME_DIR"

# Limpiar
rm -rf "$TMPDIR"

echo ">>> Respaldo creado: $BACKUP_PATH"
echo ">>> Tamaño: $(du -h "$BACKUP_PATH" | cut -f1)"
echo ""

# ---- Crear/actualizar enlace al último backup ----
ln -sf "$BACKUP_PATH" "$BACKUP_DIR/opencode-config-latest.tar.gz" 2>/dev/null || true

echo "=============================================="
echo "  Respaldo completado"
echo "=============================================="
echo ""
echo "Para restaurar en un sistema limpio:"
echo "  1. Instalar OpenCode, Ollama, sox, edge-tts, whisper-cpp"
echo "  2. cd ~/Config/opencode/backups"
echo "  3. tar xzf opencode-config-latest.tar.gz"
echo "  4. bash restore.sh"
echo ""
echo "O usa el setup-voz.sh para la parte de voz:"
echo "  bash ~/Config/opencode/setup-voz.sh"
