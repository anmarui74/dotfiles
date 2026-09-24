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
chmod 700 "$DEST" 2>/dev/null || true

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

# 6. Tarball final (permisos 600: dentro va credenciales/auth.json con claves en claro)
info "Creando tarball..."
( umask 077; tar -czf "$DEST/mimocode-backup-${DATE}.tar.gz" -C "$STAGE" \
  config.tar.gz setup.tar.gz credenciales scripts restore.sh )
chmod 600 "$DEST/mimocode-backup-${DATE}.tar.gz" 2>/dev/null || true

# 7. Retencion: 30 dias
find "$DEST" -name 'mimocode-backup-*.tar.gz' -type f -mtime +30 -delete

# 8. Copia en dotfiles (SIN claves de API)
# Vuelca la copia canónica al repo de dotfiles EXCLUYENDO cualquier archivo con
# claves de API (tarballs con credenciales/auth.json, .env, auth.json, credenciales/).
DOTFILES_MIMO="$HOME/Documentos/dotfiles/mimocode"
if [ -d "$HOME/Documentos/dotfiles" ]; then
  info "Sincronizando copia en dotfiles (SIN claves de API)..."
  mkdir -p "$DOTFILES_MIMO"
  # --delete-excluded es IMPRESCINDIBLE: con solo --delete, los ficheros que
  # están en la lista de exclusión (node_modules, *.bak*, .env, credenciales/)
  # NO se purgan del destino, porque quedan fuera de la transferencia. Sin él,
  # cada backup acumulaba restos de copias anteriores (se detectaron 171 MB de
  # node_modules huérfanos el 22/09/2026).
  rsync -a --delete --delete-excluded \
    --exclude 'backups/mimocode/' \
    --exclude 'node_modules' \
    --exclude '*.bak*' \
    --exclude '.env' --exclude '*.env' \
    --exclude 'auth.json' \
    --exclude 'credenciales/' \
    "$HOME/Config/mimocode/" "$DOTFILES_MIMO/"

  # Eliminar cualquier resto con credenciales que pudiera haber quedado
  find "$DOTFILES_MIMO" -name '*.tar.gz' -delete 2>/dev/null || true
  find "$DOTFILES_MIMO" \( -name '.env' -o -name 'auth.json' \) -delete 2>/dev/null || true
  rm -rf "$DOTFILES_MIMO/credenciales" 2>/dev/null || true

  # Saneado del INSTALADOR en dotfiles. El instalador canónico EMBEBE auth.json con las
  # claves reales a propósito (para que una instalación desde cero quede operativa con la
  # misma config). La copia de dotfiles NUNCA debe llevar claves → se sustituyen por un
  # placeholder SOLO aquí.
  # ⚠️ NO sanear el instalador canónico (~/Config/mimocode/sesion-mimocode/): si no, una
  #    instalación desde cero no restauraría las credenciales.
  SETUP_DOTFILES="$DOTFILES_MIMO/sesion-mimocode/setup-mimocode-completo.sh"
  if [ -f "$SETUP_DOTFILES" ]; then
    sed -i -E 's/("key"[[:space:]]*:[[:space:]]*")[^"]*(")/\1TU_CLAVE_AQUI\2/g' "$SETUP_DOTFILES"
    info "Instalador saneado en dotfiles (claves → TU_CLAVE_AQUI)"
  fi

  # Verificación: la copia de dotfiles no debe contener claves.
  # El patrón exige un límite de palabra antes de "sk-" y claves largas, para NO dar
  # falsos positivos con palabras como "task-<hash>", "disk-encryption-keyvault" o los
  # ejemplos documentales tipo "sk-1234567890abcdef" que viven en el grafo de memoria.
  if grep -rIlP --exclude='*.md' --exclude-dir=node_modules \
       '(nvapi-|oc_sk_)[A-Za-z0-9_-]{15,}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{25,}|AEMET_API_KEY=[A-Za-z0-9]{15,}' \
       "$DOTFILES_MIMO" 2>/dev/null | grep -q .; then
    aviso "⚠️  Posibles claves en la copia de dotfiles. Revisar antes de commitear."
  else
    info "✅ Copia en dotfiles libre de claves de API"
  fi
fi

echo ""
info "Backup creado: $DEST/mimocode-backup-${DATE}.tar.gz"
size=$(stat -c %s "$DEST/mimocode-backup-${DATE}.tar.gz")
echo "    Tamano: $(numfmt --to=iec "$size" 2>/dev/null || echo "$size bytes")"
echo "    Contenido:"
tar -tzf "$DEST/mimocode-backup-${DATE}.tar.gz" | sed 's/^/      /'
