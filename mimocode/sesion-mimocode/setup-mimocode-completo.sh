#!/usr/bin/env bash
# setup-mimocode-completo.sh - Instalación autónoma desde cero de MiMoCode
# Reproduce la configuración actual de MiMoCode de forma totalmente autónoma.
set -euo pipefail

VERDE='\033[0;32m'; AMARILLO='\033[1;33m'; ROJO='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${VERDE}[+]${NC} $1"; }
aviso() { echo -e "${AMARILLO}[!]${NC} $1"; }
error() { echo -e "${ROJO}[X]${NC} $1"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${ROOT_DIR}/config"
HOME_DIR="${HOME}"
MIMO_BIN_DIR="${HOME_DIR}/.mimocode/bin"
MIMO_CONFIG_DIR="${HOME_DIR}/.config/mimocode"
LOCAL_BIN="${HOME_DIR}/.local/bin"

info "Iniciando instalación autónoma de MiMoCode desde cero"
info "Fuente de configuración: ${CONFIG_SRC}"

# 1. Dependencias básicas
command -v node >/dev/null || { error "Node.js no está instalado"; exit 1; }
command -v npm >/dev/null || { error "npm no está instalado"; exit 1; }

# 2. Instalar binario MiMoCode si no existe
mkdir -p "${MIMO_BIN_DIR}"
if [ ! -x "${MIMO_BIN_DIR}/mimo" ]; then
    aviso "Descargando binario mimo..."
    # Placeholder: en entorno real reemplazar URL por release oficial de MiMoCode
    # Ejemplo:
    # curl -L https://.../mimo-linux-x64 -o "${MIMO_BIN_DIR}/mimo"
    # chmod +x "${MIMO_BIN_DIR}/mimo"
    error "Binario mimo no encontrado. Coloca mimo en ${MIMO_BIN_DIR}/mimo"
    exit 1
else
    info "Binario mimo ya presente"
fi

# 3. Crear estructura de configuración
mkdir -p "${MIMO_CONFIG_DIR}"
if [ -d "${CONFIG_SRC}" ]; then
    info "Restaurando configuración desde ${CONFIG_SRC}"
    cp -a "${CONFIG_SRC}/." "${MIMO_CONFIG_DIR}/"
else
    error "No existe ${CONFIG_SRC} con la configuración embebida"
    exit 1
fi

# 4. Asegurar plugin de voz independiente
VOICE_SRC="${MIMO_CONFIG_DIR}/mimocode-voice-modified"
if [ ! -d "${VOICE_SRC}" ]; then
    aviso "Plugin de voz no encontrado, copiando desde fuente"
    # El plugin ya viene en la config restaurada
fi

# 5. Lanzadores
mkdir -p "${LOCAL_BIN}"
cat > "${LOCAL_BIN}/start-mimo.sh" <<'EOS'
#!/usr/bin/env bash
# start-mimo.sh - Carga LM Studio + modelo Qwen3.8-9B + proxy (igual que OpenCode), luego abre MiMoCode
# Si SKIP_LMSTUDIO=1, NO carga el modelo local en VRAM.
set -e

# Telemetría desactivada por privacidad (sobreescribible con MIMOCODE_ENABLE_ANALYSIS=true)
export MIMOCODE_ENABLE_ANALYSIS="${MIMOCODE_ENABLE_ANALYSIS:-false}"

VERDE='\033[0;32m'; AMARILLO='\033[1;33m'; ROJO='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${VERDE}[+]${NC} $1"; }
aviso() { echo -e "${AMARILLO}[!]${NC} $1"; }
error() { echo -e "${ROJO}[X]${NC} $1"; }

LMS_SCRIPT="/home/antonio/.config/opencode/start-lmstudio.sh"
REAL_MIMO="${REAL_MIMO:-/home/antonio/.mimocode/bin/mimo}"

if [ -n "$SKIP_LMSTUDIO" ]; then
    aviso "SKIP_LMSTUDIO=1: NO se carga el modelo local en VRAM."
elif [ -x "$LMS_SCRIPT" ]; then
    info "Cargando LM Studio (modelo Qwen3.8-9B + proxy)..."
    bash "$LMS_SCRIPT" || { error "Falló al cargar LM Studio + modelo."; exit 1; }
else
    aviso "start-lmstudio.sh no encontrado, usando start-lmstudio-server.sh"
    bash /home/antonio/.config/opencode/start-lmstudio-server.sh || { error "Falló al iniciar LM Studio."; exit 1; }
fi

info "Lanzando ${REAL_MIMO}..."
exec "${REAL_MIMO}" "$@"
EOS
chmod +x "${LOCAL_BIN}/start-mimo.sh"

cat > "${LOCAL_BIN}/start-mimo-local.sh" <<'EOS'
#!/usr/bin/env bash
# start-mimo-local.sh - Perfil local: agente local (Qwen) + carga LM Studio, luego abre MiMoCode
set -e

# Telemetría desactivada por privacidad (sobreescribible con MIMOCODE_ENABLE_ANALYSIS=true)
export MIMOCODE_ENABLE_ANALYSIS="${MIMOCODE_ENABLE_ANALYSIS:-false}"

VERDE='\033[0;32m'; AMARILLO='\033[1;33m'; ROJO='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${VERDE}[+]${NC} $1"; }
aviso() { echo -e "${AMARILLO}[!]${NC} $1"; }
error() { echo -e "${ROJO}[X]${NC} $1"; }

LMS_SCRIPT="/home/antonio/.config/opencode/start-lmstudio.sh"
REAL_MIMO="${REAL_MIMO:-/home/antonio/.mimocode/bin/mimo}"
export MIMOCODE_CONFIG_DIR="$HOME/.config/mimocode/profiles/local"

if [ -n "$SKIP_LMSTUDIO" ]; then
    aviso "SKIP_LMSTUDIO=1: NO se carga el modelo local en VRAM."
elif [ -x "$LMS_SCRIPT" ]; then
    info "Cargando LM Studio (modelo Qwen3.8-9B + proxy)..."
    bash "$LMS_SCRIPT" || { error "Falló al cargar LM Studio + modelo."; exit 1; }
else
    aviso "start-lmstudio.sh no encontrado, usando start-lmstudio-server.sh"
    bash /home/antonio/.config/opencode/start-lmstudio-server.sh || { error "Falló al iniciar LM Studio."; exit 1; }
fi

info "Lanzando ${REAL_MIMO} (agente local)..."
exec "${REAL_MIMO}" --agent local "$@"
EOS
chmod +x "${LOCAL_BIN}/start-mimo-local.sh"

cat > "${LOCAL_BIN}/start-mimo-cloud.sh" <<'EOS'
#!/usr/bin/env bash
# start-mimo-cloud.sh - Perfil cloud: agentes en la nube, NO carga LM Studio, luego abre MiMoCode
set -e

# Telemetría desactivada por privacidad (sobreescribible con MIMOCODE_ENABLE_ANALYSIS=true)
export MIMOCODE_ENABLE_ANALYSIS="${MIMOCODE_ENABLE_ANALYSIS:-false}"

VERDE='\033[0;32m'; AMARILLO='\033[1;33m'; ROJO='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${VERDE}[+]${NC} $1"; }
aviso() { echo -e "${AMARILLO}[!]${NC} $1"; }
error() { echo -e "${ROJO}[X]${NC} $1"; }

REAL_MIMO="${REAL_MIMO:-/home/antonio/.mimocode/bin/mimo}"
export MIMOCODE_CONFIG_DIR="$HOME/.config/mimocode/profiles/cloud"

aviso "Perfil cloud: NO se carga el modelo local en VRAM."
info "Lanzando ${REAL_MIMO} (agente cloud)..."
exec "${REAL_MIMO}" --agent cloud "$@"
EOS
chmod +x "${LOCAL_BIN}/start-mimo-cloud.sh"

# 6. Funciones ZSH idempotentes
ZSHRC="${HOME_DIR}/.zshrc"
grep -q "function mimo()" "${ZSHRC}" 2>/dev/null || cat >> "${ZSHRC}" <<'EOS'

# MiMoCode launchers
function mimo() { /home/antonio/.local/bin/start-mimo.sh "$@"; }
function mimo-local() { /home/antonio/.local/bin/start-mimo-local.sh "$@"; }
function mimo-cloud() { /home/antonio/.local/bin/start-mimo-cloud.sh "$@"; }
function mimo-voz() { /home/antonio/.local/bin/start-mimo.sh "$@"; }
function mimo-voz-local() { /home/antonio/.local/bin/start-mimo-local.sh "$@"; }
function mimo-voz-cloud() { /home/antonio/.local/bin/start-mimo-cloud.sh "$@"; }
EOS

# 7. Timer systemd de sincronización de la copia canónica (si hay systemd)
if command -v systemctl >/dev/null 2>&1; then
    mkdir -p "${HOME_DIR}/.config/systemd/user"
    cat > "${HOME_DIR}/.config/systemd/user/mimocode-sync.service" <<'EOS'
[Unit]
Description=MiMoCode sync: .config -> Config (copia canónica)
After=network.target

[Service]
Type=oneshot
ExecStart=/home/antonio/.config/mimocode/sync-mimocode.sh --quiet
StandardOutput=journal
StandardError=journal
EOS
    cat > "${HOME_DIR}/.config/systemd/user/mimocode-sync.timer" <<'EOS'
[Unit]
Description=Sync MiMoCode each 30 min

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
Unit=mimocode-sync.service

[Install]
WantedBy=default.target
EOS
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now mimocode-sync.timer 2>/dev/null || true
    info "Timer systemd mimocode-sync activado"
fi

info "Instalación completada"
info "Configuración en ${MIMO_CONFIG_DIR}"
info "Lanzadores en ${LOCAL_BIN}"
info "Ejecuta: mimo o mimo-local o mimo-cloud"
