#!/usr/bin/env bash
# backup-opencode.sh — Respalda toda la configuración personalizada de OpenCode
# Uso: bash ~/Config/opencode/backup-opencode.sh
# El backup incluye restore.sh (autónomo) que instala dependencias, descarga
# modelos whisper, restaura configuración, plugin, speak y estado.

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

# Copiar prompts personalizados (importante para que el agente lea AGENTS.md)
if [ -d "$HOME_DIR/.config/opencode/prompts" ]; then
    echo ">>> Copiando prompts personalizados..."
    mkdir -p "$TMPDIR/prompts"
    cp -r "$HOME_DIR/.config/opencode/prompts/"* "$TMPDIR/prompts/" 2>/dev/null || true
fi

# Copiar commands personalizados
if [ -d "$HOME_DIR/.config/opencode/commands" ]; then
    echo ">>> Copiando commands personalizados..."
    mkdir -p "$TMPDIR/commands"
    cp -r "$HOME_DIR/.config/opencode/commands/"* "$TMPDIR/commands/" 2>/dev/null || true
fi

# Copiar state/kv.json para mantener estado TTS y otros
if [ -f "$HOME_DIR/.local/state/opencode/kv.json" ]; then
    echo ">>> Copiando kv.json (estado)..."
    mkdir -p "$TMPDIR/state"
    cp "$HOME_DIR/.local/state/opencode/kv.json" "$TMPDIR/state/kv.json"
fi

# Crear script de restauración (autónomo: no depende de ningún otro script)
cat > "$TMPDIR/restore.sh" << 'RESTORE'
#!/usr/bin/env bash
# restore.sh — Restauración completa y autónoma de OpenCode con voz
# Uso: bash restore.sh
# NO requiere scripts externos. Instala dependencias, descarga modelos,
# restaura configuración, plugin, speak, .zshrc y estado.

set -euo pipefail

# Colores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }

HOME_DIR="$HOME"
BACKUP_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_BIN="$HOME_DIR/.local/bin"
OC_CONFIG="$HOME_DIR/.config/opencode"
PLUGIN_DIR="$OC_CONFIG/opencode-voice-modified"
SHARE_DIR="$HOME_DIR/.local/share"
WHISPER_DIR="$SHARE_DIR/whisper-cpp"

echo "=============================================="
echo "  Restauración completa de OpenCode con Voz"
echo "=============================================="
echo ""

# ---- 1. Dependencias del sistema ----
echo "--- 1/13: Dependencias del sistema ---"
sudo apt-get update -qq
sudo apt-get install -y -qq \
  sox pulseaudio-utils whisper-cpp pipx nodejs npm 2>/dev/null || {
  warn "Algunos paquetes no disponibles, instalando los esenciales..."
  sudo apt-get install -y -qq sox pulseaudio-utils pipx nodejs npm 2>/dev/null || true
}
info "Dependencias del sistema instaladas"

# ---- 2. whisper-cli wrapper ----
echo "--- 2/13: whisper-cli wrapper ---"
mkdir -p "$LOCAL_BIN"
if [ ! -f "$LOCAL_BIN/whisper-cli" ]; then
  if [ -f "$BACKUP_DIR/whisper-cli" ]; then
    cp "$BACKUP_DIR/whisper-cli" "$LOCAL_BIN/"
    info "whisper-cli restaurado del backup"
  else
    cat > "$LOCAL_BIN/whisper-cli" << 'WHISPERWRAP'
#!/usr/bin/env bash
exec /usr/bin/whisper-cli -l es "$@"
WHISPERWRAP
    info "whisper-cli wrapper creado"
  fi
  chmod +x "$LOCAL_BIN/whisper-cli"
else
  info "whisper-cli ya existe"
fi

# ---- 3. edge-tts via pipx ----
echo "--- 3/13: edge-tts ---"
if pipx list 2>/dev/null | grep -q edge-tts; then
  info "edge-tts ya instalado via pipx"
else
  pipx install edge-tts >/dev/null 2>&1 && info "edge-tts instalado via pipx" || warn "pipx install edge-tts fallo, instalando con pip..."
  command -v edge-tts &>/dev/null || pip install edge-tts 2>/dev/null || warn "Instala edge-tts manualmente: pip install edge-tts"
fi

# ---- 4. Modelos whisper ----
echo "--- 4/13: Modelos whisper ---"
mkdir -p "$WHISPER_DIR"
download_model() {
  local name="$1"
  local file="$2"
  if [ -f "${WHISPER_DIR}/${file}" ]; then
    info "Modelo ${name} ya presente"
  else
    echo "Descargando modelo whisper: ${name}..."
    wget -q --show-progress "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${file}" -O "${WHISPER_DIR}/${file}" && info "Modelo ${name} descargado" || warn "Fallo al descargar ${name}"
  fi
}
download_model "large-v3-turbo-q5_0" "ggml-large-v3-turbo-q5_0.bin"
download_model "small" "ggml-small.bin"
download_model "base" "ggml-base.bin"

# ---- 5. Configuración principal ----
echo "--- 5/13: Configuración principal ---"
mkdir -p "$OC_CONFIG"
cp "$BACKUP_DIR/opencode.json" "$OC_CONFIG/"
[ -f "$BACKUP_DIR/opencode.jsonc" ] && cp "$BACKUP_DIR/opencode.jsonc" "$OC_CONFIG/"
cp "$BACKUP_DIR/tui.json" "$OC_CONFIG/"
cp "$BACKUP_DIR/AGENTS.md" "$OC_CONFIG/"
info "Archivos de configuración copiados"

# ---- 6. Prompts personalizados ----
echo "--- 6/13: Prompts ---"
if [ -d "$BACKUP_DIR/prompts" ]; then
  mkdir -p "$OC_CONFIG/prompts"
  cp -r "$BACKUP_DIR/prompts/"* "$OC_CONFIG/prompts/" 2>/dev/null || true
  info "Prompts restaurados"
else
  info "No hay prompts en el backup"
fi

# ---- 7. Commands personalizados ----
echo "--- 7/13: Commands ---"
if [ -d "$BACKUP_DIR/commands" ]; then
  mkdir -p "$OC_CONFIG/commands"
  cp -r "$BACKUP_DIR/commands/"* "$OC_CONFIG/commands/" 2>/dev/null || true
  info "Commands restaurados"
else
  info "No hay commands en el backup"
fi

# ---- 8. Proxy ----
echo "--- 8/13: Proxy Ollama ---"
if [ -f "$BACKUP_DIR/ollama-proxy.py" ]; then
  cp "$BACKUP_DIR/ollama-proxy.py" "$OC_CONFIG/"
  info "ollama-proxy.py copiado"
fi

# ---- 9. Plugin de voz ----
echo "--- 9/13: Plugin opencode-voice ---"
rm -rf "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR/lib"
cp "$BACKUP_DIR/plugin/index.js" "$PLUGIN_DIR/"
cp "$BACKUP_DIR/plugin/lib/stt.js" "$PLUGIN_DIR/lib/"
cp "$BACKUP_DIR/plugin/lib/tts.js" "$PLUGIN_DIR/lib/"
cp "$BACKUP_DIR/plugin/lib/session.js" "$PLUGIN_DIR/lib/"
cp "$BACKUP_DIR/plugin/lib/logger.js" "$PLUGIN_DIR/lib/"
cp "$BACKUP_DIR/plugin/lib/llm-client.js" "$PLUGIN_DIR/lib/"

# package.json del plugin (necesario para npm/yarn)
cat > "$PLUGIN_DIR/package.json" << 'PLUGPKG'
{
  "name": "@renjfk/opencode-voice",
  "version": "0.6.0",
  "description": "Speech-to-text and text-to-speech for OpenCode.",
  "license": "MIT",
  "type": "module",
  "main": "index.js",
  "exports": { ".": { "import": "./index.js" }, "./tui": { "import": "./index.js" } },
  "files": ["index.js", "lib"]
}
PLUGPKG
info "Plugin restaurado"

# ---- 10. speak script ----
echo "--- 10/13: speak script ---"
mkdir -p "$LOCAL_BIN"
cp "$BACKUP_DIR/speak" "$LOCAL_BIN/"
chmod +x "$LOCAL_BIN/speak"
info "speak instalado en $LOCAL_BIN/speak"

# ---- 11. Configurar .zshrc ----
echo "--- 11/13: .zshrc ---"
ZSHRC="$HOME_DIR/.zshrc"

# Función ocv: reemplazar si existe
if grep -q "function ocv" "$ZSHRC" 2>/dev/null; then
  awk '/^function ocv\(\) \{/{skip=1; next} skip && /^}/ {skip=0; next} !skip' "$ZSHRC" > "${ZSHRC}.tmp" && mv "${ZSHRC}.tmp" "$ZSHRC"
fi
echo "" >> "$ZSHRC"
echo "# OCV - OpenCode con voz" >> "$ZSHRC"
echo 'function ocv() {' >> "$ZSHRC"
echo '    script -q -f -c "opencode $*" /dev/null 2>&1' >> "$ZSHRC"
echo '}' >> "$ZSHRC"
info "Función ocv añadida a .zshrc"

# PATH a ~/.local/bin (si no existe)
if ! grep -q '\.local/bin' "$ZSHRC" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
  info "PATH a .local/bin añadido a .zshrc"
else
  info "PATH a .local/bin ya existe en .zshrc"
fi

# ---- 12. npm dependencies ----
echo "--- 12/13: Dependencias npm ---"
cd "$OC_CONFIG"
if [ ! -f package.json ]; then
  cat > package.json << 'NPMDEPS'
{
  "dependencies": {
    "@opencode-ai/plugin": "1.17.13",
    "@renjfk/opencode-voice": "^0.6.0"
  }
}
NPMDEPS
  info "package.json creado en $OC_CONFIG"
fi
echo "Ejecutando npm install..."
npm install --no-audit --no-fund 2>/dev/null || npm install
info "Dependencias npm instaladas"

# ---- 13. kv.json (estado TTS) ----
echo "--- 13/13: Estado TTS (kv.json) ---"
if [ -f "$BACKUP_DIR/state/kv.json" ]; then
  mkdir -p "$HOME_DIR/.local/state/opencode"
  if [ -f "$HOME_DIR/.local/state/opencode/kv.json" ]; then
    BACKUP_TTS=$(python3 -c "import json; d=json.load(open('$BACKUP_DIR/state/kv.json')); print(d.get('tts.mode','on'))" 2>/dev/null || echo "on")
    python3 -c "
import json
with open('$HOME_DIR/.local/state/opencode/kv.json') as f: d=json.load(f)
d['tts.mode']='$BACKUP_TTS'
with open('$HOME_DIR/.local/state/opencode/kv.json','w') as f: json.dump(d,f)
" 2>/dev/null || cp "$BACKUP_DIR/state/kv.json" "$HOME_DIR/.local/state/opencode/kv.json"
    info "kv.json fusionado (tts.mode=$BACKUP_TTS)"
  else
    cp "$BACKUP_DIR/state/kv.json" "$HOME_DIR/.local/state/opencode/kv.json"
    info "kv.json restaurado"
  fi
else
  # Forzar TTS on aunque no haya backup
  mkdir -p "$HOME_DIR/.local/state/opencode"
  echo '{"tts.mode":"on"}' > "$HOME_DIR/.local/state/opencode/kv.json"
  info "kv.json creado con tts.mode=on"
fi

echo ""
echo "=============================================="
echo -e "${GREEN}  Restauración completada${NC}"
echo "=============================================="
echo ""
echo "Resumen:"
echo "  sox          $(command -v sox &>/dev/null && echo 'OK' || echo 'FALTA')"
echo "  edge-tts     $(command -v edge-tts &>/dev/null && echo 'OK' || echo 'FALTA')"
echo "  whisper-cli  $(command -v whisper-cli &>/dev/null && echo 'OK' || echo 'FALTA')"
echo "  speak        $(command -v speak &>/dev/null && echo 'OK' || echo 'FALTA')"
echo "  plugin       $( [ -f $PLUGIN_DIR/index.js ] && echo 'OK' || echo 'FALTA')"
echo ""
echo "Uso:"
echo "  source ~/.zshrc"
echo "  ocv                    → Inicia OpenCode con voz"
echo "  Ctrl+R                 → Grabar / Parar + transcribir + enviar"
echo "  <leader>v (Espacio+v)  → Activar/desactivar TTS automático"
echo "  <leader>s (Espacio+s)  → Leer última respuesta"
echo "  Escape                 → Parar reproducción"
echo ""
echo "Variables de entorno (opcional):"
echo "  SPEAK_VOICE=es-ES-AlvaroNeural"
echo "  SPEAK_RATE=+5%"
echo "  SPEAK_PITCH=+0Hz"
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
echo "  1. Instalar OpenCode y Ollama"
echo "  2. cd ~/Config/opencode/backups"
echo "  3. tar xzf opencode-config-latest.tar.gz"
echo "  4. bash restore.sh"
echo "  5. source ~/.zshrc"
echo "  6. ocv"
