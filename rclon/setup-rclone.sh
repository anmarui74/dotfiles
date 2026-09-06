#!/usr/bin/env bash
set -euo pipefail

# Instalación automática de rclone en Arch Linux
if ! command -v rclone >/dev/null 2>&1; then
  echo "rclone no encontrado. Instalando..."
  sudo pacman -S --noconfirm rclone
fi

BACKUP_DIR="$HOME/Config/rclon"
CONFIG_DIR="$HOME/.config/rclone"
CONFIG_FILE="$CONFIG_DIR/rclone.conf"
MOUNT_DIR="$HOME/GoogleDrive"

CLIENT_ID=
CLIENT_SECRET=

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
cat >"$SERVICE_FILE" <<'EOF'
[Unit]
Description=Rclone Google Drive mount
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount gdrive: /home/antonio/GoogleDrive --vfs-cache-mode writes --allow-other --umask 002 --uid 1000 --gid 1000
ExecStop=/bin/fusermount -uz /home/antonio/GoogleDrive
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now rclone-gdrive.service

# Backup semanal automático
BACKUP_SCRIPT="$BACKUP_DIR/backup-rclone-weekly.sh"
cat >"$BACKUP_SCRIPT" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR="$HOME/Config/rclon"
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

cat >"$HOME/.config/systemd/user/rclone-backup.service" <<'EOF'
[Unit]
Description=Weekly backup of rclone.conf
[Service]
Type=oneshot
ExecStart=/home/antonio/Config/rclon/backup-rclone-weekly.sh
EOF

cat >"$HOME/.config/systemd/user/rclone-backup.timer" <<'EOF'
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
