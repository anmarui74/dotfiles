#!/usr/bin/env bash
# backup-mimocode.sh - Backup completo de la config de MiMoCode
# Incluye: config activa (~/.config/mimocode), credenciales (auth.json),
# instalador (sesion-mimocode), backup-mimocode.sh y restore.sh autogenerado.
set -euo pipefail

DATE=$(date +%Y%m%d-%H%M)
SRC_CONFIG="$HOME/.config/mimocode"
SRC_SETUP="$HOME/Config/mimocode/sesion-mimocode"
AUTH_SRC="$HOME/.local/share/mimocode/auth.json"
DEST="$HOME/Config/mimocode/backups/mimocode"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

info()  { echo -e "\033[0;32m[+]\033[0m $1"; }
aviso() { echo -e "\033[1;33m[!]\033[0m $1"; }
error() { echo -e "\033[0;31m[X]\033[0m $1"; }

[ -d "$SRC_CONFIG" ] || { error "No existe $SRC_CONFIG"; exit 1; }
mkdir -p "$DEST" "$STAGE/credenciales" "$STAGE/scripts"

# 0. Sincronizar la copia canónica y verificar el setup (aborta si falla)
if [ -x "$SRC_CONFIG/sync-mimocode.sh" ]; then
  info "Sincronizando copia canónica..."
  bash "$SRC_CONFIG/sync-mimocode.sh" --quiet
fi
if [ -f "$HOME/Config/mimocode/check-setup-completo.sh" ]; then
  info "Verificando setup..."
  if ! bash "$HOME/Config/mimocode/check-setup-completo.sh"; then
    error "La verificación del setup ha fallado. Backup ABORTADO."
    exit 1
  fi
fi

# 1. Config activa (sin node_modules ni backups .bak)
info "Empaquetando config activa..."
tar -czf "$STAGE/config.tar.gz" -C "$HOME/.config" \
  --exclude='*/node_modules' --exclude='*/node_modules/*' \
  --exclude='mimocode/*.bak*' --exclude='mimocode/profiles/*/*.bak*' \
  mimocode

# 2. Instalador completo (setup), sin node_modules
if [ -d "$SRC_SETUP" ]; then
  info "Empaquetando instalador (sesion-mimocode)..."
  tar -czf "$STAGE/setup.tar.gz" -C "$SRC_SETUP" \
    --exclude='*/node_modules' --exclude='*/node_modules/*' \
    --exclude='*.bak*' \
    .
else
  aviso "No existe $SRC_SETUP; el tarball no incluye el instalador."
fi

# 3. Credenciales (claves de proveedores)
if [ -f "$AUTH_SRC" ]; then
  info "Incluyendo credenciales (auth.json)..."
  install -m 600 "$AUTH_SRC" "$STAGE/credenciales/auth.json"
else
  aviso "No existe $AUTH_SRC; el backup NO incluye credenciales."
fi

# 4. Copia de los scripts auxiliares
cp "$0" "$STAGE/scripts/backup-mimocode.sh"
cp "$HOME/Config/mimocode/check-setup-completo.sh" "$STAGE/scripts/check-setup-completo.sh" 2>/dev/null || true

# 5. restore.sh autogenerado
cat > "$STAGE/restore.sh" <<'EOF'
#!/usr/bin/env bash
# restore.sh - Restaura la config de MiMoCode desde este tarball
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[+] Restaurando config en ~/.config/mimocode ..."
tar -xzf "$HERE/config.tar.gz" -C "$HOME/.config"

if [ -f "$HERE/credenciales/auth.json" ]; then
  echo "[+] Restaurando credenciales en ~/.local/share/mimocode/auth.json ..."
  mkdir -p "$HOME/.local/share/mimocode"
  install -m 600 "$HERE/credenciales/auth.json" "$HOME/.local/share/mimocode/auth.json"
fi

if [ -f "$HERE/setup.tar.gz" ] && [ -s "$HERE/setup.tar.gz" ]; then
  echo "[+] Restaurando instalador en ~/Config/mimocode/sesion-mimocode ..."
  mkdir -p "$HOME/Config/mimocode/sesion-mimocode"
  tar -xzf "$HERE/setup.tar.gz" -C "$HOME/Config/mimocode/sesion-mimocode"
fi

if [ -f "$HERE/scripts/backup-mimocode.sh" ]; then
  echo "[+] Restaurando backup-mimocode.sh ..."
  cp "$HERE/scripts/backup-mimocode.sh" "$HOME/Config/mimocode/backup-mimocode.sh"
  chmod +x "$HOME/Config/mimocode/backup-mimocode.sh"
fi

if [ -f "$HERE/scripts/check-setup-completo.sh" ]; then
  echo "[+] Restaurando check-setup-completo.sh ..."
  cp "$HERE/scripts/check-setup-completo.sh" "$HOME/Config/mimocode/check-setup-completo.sh"
  chmod +x "$HOME/Config/mimocode/check-setup-completo.sh"
fi

echo "[+] Restauracion completada."
echo "    Reinstalacion desde cero: bash ~/Config/mimocode/sesion-mimocode/setup-mimocode-completo.sh"
echo "    Si un plugin necesita dependencias: cd ~/.config/mimocode && npm install"
EOF
chmod +x "$STAGE/restore.sh"

# 6. Tarball final
info "Creando tarball..."
tar -czf "$DEST/mimocode-backup-${DATE}.tar.gz" -C "$STAGE" \
  config.tar.gz setup.tar.gz credenciales scripts restore.sh

# 7. Retencion: 30 dias
find "$DEST" -name 'mimocode-backup-*.tar.gz' -type f -mtime +30 -delete

echo ""
info "Backup creado: $DEST/mimocode-backup-${DATE}.tar.gz"
size=$(stat -c %s "$DEST/mimocode-backup-${DATE}.tar.gz")
echo "    Tamano: $(numfmt --to=iec "$size" 2>/dev/null || echo "$size bytes")"
echo "    Contenido:"
tar -tzf "$DEST/mimocode-backup-${DATE}.tar.gz" | sed 's/^/      /'
