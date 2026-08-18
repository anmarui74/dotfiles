#!/bin/bash
# Instalador de backup-rs para Arch Linux
# Uso: sudo ./install.sh

set -euo pipefail

readonly INSTALL_DIR="/usr/local/bin"
readonly SERVICE_DIR="/etc/systemd/system"
readonly CONFIG_DIR="/home/antonio/.config/backup-rs"
readonly MOUNT_POINT="/run/media/antonio/CRUCIAL"
readonly SSD_LABEL="CRUCIAL"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERR]${NC} $*"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_err "Este script debe ejecutarse como root (sudo)"
        exit 1
    fi
}

check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_warn "No estás en Arch Linux, continuando de todos modos..."
    fi
}

install_rust() {
    if ! command -v cargo &> /dev/null; then
        log_info "Instalando Rust..."
        pacman -S --needed --noconfirm rust
    else
        log_ok "Rust ya instalado: $(cargo --version)"
    fi
}

build_project() {
    local bin="/home/antonio/backup-rs/target/release/backup"
    if [[ -f "$bin" && -x "$bin" ]]; then
        log_ok "Binario ya compilado: $bin"
        return 0
    fi

    log_info "Compilando backup-rs en modo release (como antonio)..."
    cd /home/antonio/backup-rs
    su antonio -c "cargo build --release"
    log_ok "Compilación completada"
}

install_binary() {
    log_info "Instalando binario en $INSTALL_DIR..."
    install -Dm755 /home/antonio/backup-rs/target/release/backup "$INSTALL_DIR/backup"
    log_ok "Binario instalado: $(backup --version)"
}

setup_ssd_mount() {
    log_info "Configurando acceso al disco Crucial..."

    # Verificar que existe la partición
    if ! blkid -L "$SSD_LABEL" &> /dev/null; then
        log_err "No se encuentra partición con etiqueta '$SSD_LABEL'"
        log_info "Verifica que el SSD esté conectado y formateado con: sudo blkid"
        exit 1
    fi

    local device=$(blkid -L "$SSD_LABEL")
    log_info "Dispositivo encontrado: $device"

    # Crear directorio Backup (si el disco está montado)
    if mountpoint -q "$MOUNT_POINT" || [ -d "$MOUNT_POINT" ]; then
        mkdir -p "$MOUNT_POINT/Backup" 2>/dev/null || true
    fi

    # Crear regla polkit para que Nautilus monte/desmonte SOLO el Crucial sin contraseña
    cat > /etc/polkit-1/rules.d/50-antonio-crucial.rules << 'POLKIT'
// Permitir a antonio montar/desmontar SOLO el disco Crucial (/dev/sda1) sin autenticación.
// NO se incluye el SEAGATE: ese disco debe montarse con privilegios (sudo).
polkit.addRule(function(action, subject) {
    if (subject.user == "antonio") {
        var dev = "";
        try { dev = action.lookup("device"); } catch (e) {}
        var isCrucial = (dev && (dev.indexOf("/dev/sda1") !== -1 || dev.indexOf("a78a8d29-6938-44c6-906e-8b41c6982e31") !== -1));
        if (isCrucial) {
            if (action.id == "org.freedesktop.udisks2.filesystem-mount" ||
                action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
                action.id == "org.freedesktop.udisks2.filesystem-mount-other-seat" ||
                action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
                action.id == "org.freedesktop.udisks2.filesystem-unmount-system" ||
                action.id == "org.freedesktop.udisks2.filesystem-unmount") {
                return polkit.Result.YES;
            }
        }
    }
});
POLKIT
    log_ok "Regla polkit creada: solo el Crucial se monta/desmonta sin contraseña en Nautilus"
}

create_config() {
    log_info "Creando configuración por defecto..."
    sudo -u antonio mkdir -p "$CONFIG_DIR"

    if [[ ! -f "$CONFIG_DIR/config.toml" ]]; then
        sudo -u antonio cp /home/antonio/backup-rs/config.example.toml "$CONFIG_DIR/config.toml"
        log_ok "Configuración creada en $CONFIG_DIR/config.toml"
    else
        log_ok "Configuración ya existe"
    fi
}

install_systemd_service() {
    log_info "Instalando servicio systemd..."

    cat > "$SERVICE_DIR/backup-rs.service" << 'EOF'
[Unit]
Description=Backup automático versionado (backup-rs)
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=antonio
Group=antonio
Environment=HOME=/home/antonio
WorkingDirectory=/home/antonio
ExecStart=/usr/local/bin/backup run
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=backup-rs

# Corre como antonio (el Crucial se monta sin privilegios). El SEAGATE (root)
# se omite en el daemon; se sincroniza con "backup once"/"backup mirror".
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    # El servicio se CREA pero NO se habilita: el uso principal es manual
    # (backup once/backup mirror). Si se quiere vigilancia automática:
    #   sudo systemctl enable --now backup-rs
    log_ok "Servicio systemd creado (NO habilitado). Para vigilancia automática: sudo systemctl enable --now backup-rs"
}

setup_bash_completion() {
    log_info "Configurando autocompletado bash..."
    backup --generate-complete-script bash > /usr/share/bash-completion/completions/backup 2>/dev/null || true
    log_ok "Autocompletado configurado"
}

print_summary() {
    echo
    log_ok "╔═══════════════════════════════════════════════════════════╗"
    log_ok "║  backup-rs instalado correctamente                        ║"
    log_ok "╚═══════════════════════════════════════════════════════════╝"
    echo
    echo "📋 Comandos disponibles:"
    echo "   backup init          # Crear configuración"
    echo "   backup once          # Backup único"
    echo "   backup run           # Backup + watching continuo (daemon)"
    echo "   backup mirror        # Sincronizar espejos planos (machacar)"
    echo "   backup status        # Ver estado y versiones"
    echo "   backup list          # Listar todas las versiones"
    echo "   backup restore <ver> # Restaurar versión"
    echo
    echo "🔧 Servicios systemd:"
    echo "   sudo systemctl start backup-rs      # Iniciar daemon"
    echo "   sudo systemctl status backup-rs     # Ver estado"
    echo "   sudo systemctl stop backup-rs       # Detener daemon"
    echo "   journalctl -u backup-rs -f          # Ver logs en vivo"
    echo
    echo "💾 SSD Crucial montado en: $MOUNT_POINT"
    echo "📁 Backups en: $MOUNT_POINT/Backup"
    echo "⚙️  Configuración: $CONFIG_DIR/config.toml"
    echo
    log_info "Para iniciar ahora: sudo systemctl start backup-rs"
}

main() {
    check_root
    check_arch
    install_rust
    build_project
    install_binary
    setup_ssd_mount
    create_config
    install_systemd_service
    setup_bash_completion
    print_summary
}

main "$@"