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

# Limpieza de backups antiguos >30 días
find "$BACKUP_DIR" -maxdepth 1 -name 'rclone.conf.[0-9]*' -type f -mtime +30 -delete
echo "Backups antiguos >30 días eliminados"
