#!/bin/bash
# Instalador de backup-rs para Arch Linux
# Uso: sudo ./install.sh
#
# Nota: este script se ejecuta con sudo (no pkexec) porque copia binarios a
# /usr/local/bin y escribe en /etc/fstab, /etc/polkit y /etc/systemd.
# La NUBE MyCloud NO requiere root en uso diario (montaje con fstab `users`).

set -euo pipefail

# Ruta del proyecto (se detecta automáticamente si se invoca desde el repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

readonly INSTALL_DIR="/usr/local/bin"
readonly SERVICE_DIR="/etc/systemd/system"
readonly CONFIG_DIR="/home/antonio/.config/backup-rs"
readonly MOUNT_POINT="/run/media/antonio/CRUCIAL"
readonly SSD_LABEL="CRUCIAL"

# Nube MyCloud (WD): host y shares
readonly CLOUD_HOST="mycloud-eudvfr.local"
readonly CLOUD_SHARE_ANTONIO="antonio"
readonly CLOUD_SHARE_PUBLIC="public"
readonly CLOUD_MOUNT_ANTONIO="/home/antonio/MyCloud/antonio"
readonly CLOUD_MOUNT_PUBLIC="/home/antonio/MyCloud/public"
readonly CLOUD_CREDENTIALS="$CONFIG_DIR/smb-antonio.credentials"
readonly CLOUD_FSTAB_TAG="MyCloud WD"

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
    local bin="$PROJECT_DIR/target/release/backup"
    if [[ -f "$bin" && -x "$bin" ]]; then
        log_ok "Binario ya compilado: $bin"
        return 0
    fi

    log_info "Compilando backup-rs en modo release (como antonio)..."
    chown -R antonio:antonio "$PROJECT_DIR" 2>/dev/null || true
    su antonio -c "cd '$PROJECT_DIR' && cargo build --release"
    log_ok "Compilación completada"
}

install_binary() {
    log_info "Instalando binario en $INSTALL_DIR..."
    install -Dm755 "$PROJECT_DIR/target/release/backup" "$INSTALL_DIR/backup"
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

# Configura el montaje de la NUBE MyCloud en fstab con opciones `users` +
# `x-systemd.automount`: se monta/desmonta SIN root y se activa al acceder.
# También crea el archivo de credenciales del share privado (si aplica).
setup_cloud_mount() {
    log_info "Configurando montaje de la nube MyCloud ($CLOUD_HOST)..."

    # Directorios de montaje (propiedad de antonio)
    sudo -u antonio mkdir -p "$CLOUD_MOUNT_ANTONIO" "$CLOUD_MOUNT_PUBLIC"
    log_ok "Puntos de montaje creados: $CLOUD_MOUNT_ANTONIO, $CLOUD_MOUNT_PUBLIC"

    # Archivo de credenciales del share privado (si el usuario lo desea)
    if [[ ! -f "$CLOUD_CREDENTIALS" ]]; then
        echo
        echo "El share privado '${CLOUD_SHARE_ANTONIO}' de la nube requiere usuario/contraseña."
        read -r -p "¿Quieres crear el archivo de credenciales ahora? [s/N] " -n 1 resp
        echo
        if [[ "$resp" =~ [sS] ]]; then
            read -r -p "Usuario del share (por defecto ${CLOUD_SHARE_ANTONIO}): " cifs_user
            read -r -s -p "Contraseña del share: " cifs_pass
            echo
            sudo -u antonio mkdir -p "$CONFIG_DIR"
            printf 'username=%s\npassword=%s\ndomain=WORKGROUP\n' "${cifs_user:-$CLOUD_SHARE_ANTONIO}" "$cifs_pass" \
                > "$CLOUD_CREDENTIALS"
            chmod 600 "$CLOUD_CREDENTIALS"
            log_ok "Credenciales guardadas en $CLOUD_CREDENTIALS (permisos 600)"
        else
            log_warn "Sin credenciales guardadas: el share privado deberá montarse manualmente."
        fi
    else
        log_ok "Credenciales ya existen: $CLOUD_CREDENTIALS"
    fi

    # Entradas de fstab (idempotente: no duplicar si ya existen)
    local fstab_marker="# $CLOUD_FSTAB_TAG"
    if grep -qF "$fstab_marker" /etc/fstab; then
        log_ok "fstab ya contiene la configuración de la nube MyCloud"
    else
        cat >> /etc/fstab << EOF

$fstab_marker
//$CLOUD_HOST/$CLOUD_SHARE_ANTONIO $CLOUD_MOUNT_ANTONIO cifs credentials=$CLOUD_CREDENTIALS,uid=1000,gid=1000,file_mode=0664,dir_mode=0775,iocharset=utf8,vers=3.0,noauto,x-systemd.automount,nofail,users,_netdev 0 0
//$CLOUD_HOST/$CLOUD_SHARE_PUBLIC $CLOUD_MOUNT_PUBLIC cifs guest,uid=1000,gid=1000,file_mode=0664,dir_mode=0775,iocharset=utf8,vers=3.0,noauto,x-systemd.automount,nofail,users,_netdev 0 0
EOF
        log_ok "Entradas de la nube MyCloud añadidas a /etc/fstab"
    fi

    # Recargar systemd y activar los automounts
    systemctl daemon-reload
    systemctl start "home-antonio-MyCloud-${CLOUD_SHARE_ANTONIO}.automount" \
                     "home-antonio-MyCloud-${CLOUD_SHARE_PUBLIC}.automount" 2>/dev/null || true
    log_ok "Automounts de la nube activados (se montan al acceder a las rutas)"
}

create_config() {
    log_info "Creando configuración por defecto..."
    sudo -u antonio mkdir -p "$CONFIG_DIR"

    if [[ ! -f "$CONFIG_DIR/config.toml" ]]; then
        sudo -u antonio cp "$PROJECT_DIR/config.example.toml" "$CONFIG_DIR/config.toml"
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
    echo "☁️  Nube MyCloud:"
    echo "   ${CLOUD_SHARE_ANTONIO}: $CLOUD_MOUNT_ANTONIO/Linux"
    echo "   ${CLOUD_SHARE_PUBLIC}: $CLOUD_MOUNT_PUBLIC/Linux"
    echo "   (montaje sin root: fstab users + automount; credenciales en $CLOUD_CREDENTIALS)"
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
    setup_cloud_mount
    create_config
    install_systemd_service
    setup_bash_completion
    print_summary
}

main "$@"