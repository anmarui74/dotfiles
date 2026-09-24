#!/usr/bin/env bash
set -euo pipefail

# Instalación automática de rclone + dependencias en Arch Linux
if ! command -v rclone >/dev/null 2>&1; then
  echo "rclone no encontrado. Instalando rclone y fuse3..."
  sudo pacman -S --noconfirm rclone fuse3
else
  echo "rclone ya está instalado."
fi

if ! command -v fusermount3 >/dev/null 2>&1; then
  echo "fuse3 no encontrado. Instalando fuse3..."
  sudo pacman -S --noconfirm fuse3
else
  echo "fuse3 ya está instalado."
fi

# Comprobar y activar user_allow_other en /etc/fuse.conf
if ! grep -qE '^[[:space:]]*user_allow_other' /etc/fuse.conf; then
  echo "Activando user_allow_other en /etc/fuse.conf..."
  sudo bash -c 'sed -i "s/^#\s*\(user_allow_other\)/\1/" /etc/fuse.conf'
else
  echo "user_allow_other ya está activo en /etc/fuse.conf"
fi

BACKUP_DIR="$HOME/Config/rclone"
CONFIG_DIR="$HOME/.config/rclone"
CONFIG_FILE="$CONFIG_DIR/rclone.conf"
MOUNT_DIR="$HOME/GoogleDrive"

CLIENT_ID="682740452054-tfg0mm3pnlmk0qblj7q1crveg5nb228r.apps.googleusercontent.com"
CLIENT_SECRET="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"

mkdir -p "$BACKUP_DIR" "$CONFIG_DIR" "$MOUNT_DIR"

# Restauración automática desde el backup más reciente
latest_backup=$(ls -t "$BACKUP_DIR"/rclone.conf.* 2>/dev/null | head -n1 || true)
if [ -n "$latest_backup" ] && [ ! -f "$CONFIG_FILE" ]; then
  cp "$latest_backup" "$CONFIG_FILE"
  echo "Restaurado $CONFIG_FILE desde $latest_backup"
fi

timestamp=$(date +%Y%m%d_%H%M%S)
if [ -f "$CONFIG_FILE" ]; then
  cp "$CONFIG_FILE" "$BACKUP_DIR/rclone.conf.$timestamp"
  cp "$CONFIG_FILE" "$BACKUP_DIR/rclone.conf"
  echo "Backup creado: $BACKUP_DIR/rclone.conf.$timestamp"
  echo "Copia estática actualizada: $BACKUP_DIR/rclone.conf"
fi

# Asegurar que el remote gdrive exista con tus credenciales
if rclone listremotes | grep -q "^gdrive:"; then
  rclone config update gdrive client_id "$CLIENT_ID" client_secret "$CLIENT_SECRET"
else
  rclone config create gdrive drive client_id "$CLIENT_ID" client_secret "$CLIENT_SECRET"
fi

# Servicio systemd usuario
SERVICE_FILE="$HOME/.config/systemd/user/rclone-gdrive.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Rclone Google Drive mount
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount gdrive: $MOUNT_DIR --vfs-cache-mode writes --allow-other --umask 002 --uid 1000 --gid 1000
ExecStop=/usr/bin/fusermount3 -uz $MOUNT_DIR
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now rclone-gdrive.service

# Backup semanal automático
BACKUP_SCRIPT="$BACKUP_DIR/backup-rclone-weekly.sh"
cat > "$BACKUP_SCRIPT" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR="$HOME/Config/rclone"
CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
mkdir -p "$BACKUP_DIR"
if [ -f "$CONFIG_FILE" ]; then
  ts=$(date +%Y%m%d_%H%M%S)
  cp "$CONFIG_FILE" "$BACKUP_DIR/rclone.conf.$ts"
  cp "$CONFIG_FILE" "$BACKUP_DIR/rclone.conf"
  echo "Backup rclone.conf -> $BACKUP_DIR/rclone.conf.$ts"
fi
find "$BACKUP_DIR" -maxdepth 1 -name 'rclone.conf.[0-9]*' -type f -mtime +30 -delete
echo "Backups antiguos >30 días eliminados"
EOS
chmod +x "$BACKUP_SCRIPT"

cat > "$HOME/.config/systemd/user/rclone-backup.service" <<EOF
[Unit]
Description=Weekly backup of rclone.conf
[Service]
Type=oneshot
ExecStart=$BACKUP_SCRIPT
EOF

cat > "$HOME/.config/systemd/user/rclone-backup.timer" <<'EOF'
[Unit]
Description=Weekly rclone.conf backup timer
[Timer]
OnCalendar=Sun 03:00:00
Persistent=true
[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now rclone-backup.timer

echo "Rclone configurado y montado en $MOUNT_DIR"
echo "Backups en $BACKUP_DIR"
echo "Backup semanal automático activado"
