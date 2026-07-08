#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }

MODEL="${WHISPER_MODEL:-small}"
MODEL_DIR="${HOME}/.local/share/whisper-cpp"
MODEL_FILE="${MODEL_DIR}/ggml-${MODEL}.bin"
TUI_CONFIG="${HOME}/.config/opencode/tui.json"
WRAPPER="${HOME}/.local/bin/whisper-cli"

info "Instalando dependencias del sistema..."
sudo pacman -S --needed --noconfirm whisper-cpp-vulkan sox

info "Instalando plugin opencode-voice..."
sudo npm install -g @renjfk/opencode-voice

info "Configurando tui.json..."
mkdir -p "$(dirname "$TUI_CONFIG")"
cat > "$TUI_CONFIG" << 'EOF'
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "session_rename": "none"
  },
  "plugin": [
    "@renjfk/opencode-voice"
  ]
}
EOF

info "Descargando modelo Whisper ($MODEL)..."
mkdir -p "$MODEL_DIR"
if [ ! -f "$MODEL_FILE" ]; then
  curl -fsSL "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${MODEL}.bin" -o "$MODEL_FILE"
fi

info "Creando wrapper whisper-cli (GPU + español)..."
mkdir -p "${HOME}/.local/bin"
cat > "$WRAPPER" << 'EOF'
#!/usr/bin/env bash
exec /usr/bin/whisper-cli -l es "$@"
EOF
chmod +x "$WRAPPER"

info "Creando wrapper sox (buffer mínimo para no perder audio)..."
cat > "${HOME}/.local/bin/sox" << 'EOF'
#!/usr/bin/env bash
PULSE_LATENCY_MSEC=50 exec /usr/bin/sox "$@"
EOF
chmod +x "${HOME}/.local/bin/sox"

info "Parcheando plugin (silencio 10s, SIGINT, timeout 5s)..."
sudo sed -i 's/"silence", "1", "[0-9.]*", "1%"/"silence", "1", "10.0", "1%"/' /usr/lib/node_modules/@renjfk/opencode-voice/lib/stt.js
sudo sed -i 's/timeoutMs = 2000/timeoutMs = 5000/' /usr/lib/node_modules/@renjfk/opencode-voice/lib/stt.js

info "Limpiando caché del plugin..."
rm -rf ~/.cache/opencode/packages/@renjfk/

ok "Instalación completada"
echo
echo -e "${CYAN}──────────────────────────────────────${NC}"
echo -e "  ${GREEN}Ctrl+R${NC}     = grabar / detener"
echo -e "  ${GREEN}Ctrl+X luego R${NC} = grabar y enviar"
echo -e "  ${GREEN}/stt-record${NC}  = comando alternativo"
echo -e "${CYAN}──────────────────────────────────────${NC}"
echo

info "Abriendo opencode en kitty..."
kitty --title opencode -e env PATH="${HOME}/.local/bin:$PATH" opencode &

wait
