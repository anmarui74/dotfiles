#!/usr/bin/env bash
# backup-mimocode.sh - Backup completo de la config de MiMoCode
# Incluye: config activa (~/.config/mimocode), credenciales (auth.json),
# instalador (sesion-mimocode), backup-mimocode.sh y restore.sh autogenerado.
set -euo pipefail

DATE=$(date +%Y%m%d-%H%M%S)
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
  # La guarda evita que ese sync regenere a su vez el tarball: si este backup se ha
  # lanzado a mano, el sync no debe disparar un segundo backup (bucle/doble trabajo).
  MIMOCODE_LLAMADO_POR_BACKUP=1 bash "$SRC_CONFIG/sync-mimocode.sh" --quiet
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

# 1b. Grafo de memoria (MCP memory): copia fechada local de rotación.
# El grafo ya viaja en config.tar.gz (data/memory/) y en la copia estable
# sesion-mimocode/config/data/memory/ (esa es la que va a dotfiles vía sync).
# Ésta es el histórico LOCAL de rotación y NUNCA se vuelca a dotfiles: si no,
# acumularía cientos de duplicados versionados en el repo (pasó en OpenCode
# con 179 ficheros mcp-memory-backup-*.jsonl).
MEMORY_SRC="$SRC_CONFIG/data/memory/memory.jsonl"
if [ -f "$MEMORY_SRC" ]; then
  info "Respaldando grafo de memoria (copia fechada local)..."
  mkdir -p "$HOME/Config/mimocode/backups"
  MEMORY_DATE=$(date +%Y%m%d-%H%M%S)
  cp "$MEMORY_SRC" "$HOME/Config/mimocode/backups/mimocode-memory-backup-${MEMORY_DATE}.jsonl"
fi

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

# 7. Retención: tarballs y copias del grafo (LOG_RETENTION_DAYS, por defecto 30 días)
RETENTION_DAYS="${LOG_RETENTION_DAYS:-30}"
info "Aplicando retención (${RETENTION_DAYS} días)..."
find "$DEST" -maxdepth 1 -name 'mimocode-backup-*.tar.gz' -type f \
  -mtime +"${RETENTION_DAYS}" -delete 2>/dev/null || true
find "$HOME/Config/mimocode/backups" -maxdepth 1 -name 'mimocode-memory-backup-*.jsonl' \
  -mtime +"${RETENTION_DAYS}" -delete 2>/dev/null || true

# 7b. Poda diaria: conservar solo el ÚLTIMO tarball de cada día
# OJO con el patrón: los tarballs se llaman mimocode-backup-<YYYYMMDD>-<HHMMSS>.tar.gz,
# así que localizables con "mimocode-backup-${DAY}-*". NO vale copiar el patrón de
# backup-opencode.sh ("opencode-*-${DAY}-*"), donde el * casa el literal "backup" del
# nombre; aquí el prefijo literal ya consume ese guion y el find no casaría con nada
# (la poda no borraba nunca y los tarballs se acumulaban).
PODADOS=0
for f in "$DEST"/mimocode-backup-*.tar.gz; do
  [ -f "$f" ] || continue
  DAY=$(basename "$f" | grep -oE '[0-9]{8}' | head -1 || true)
  [ -n "$DAY" ] || continue
  LAST=$(find "$DEST" -maxdepth 1 -name "mimocode-backup-${DAY}-*.tar.gz" 2>/dev/null | sort | tail -1)
  if [ -n "$LAST" ] && [ "$f" != "$LAST" ]; then
    rm -f "$f"
    PODADOS=$((PODADOS+1))
  fi
done
if [ "$PODADOS" -gt 0 ]; then
  info "Poda diaria: $PODADOS tarballs duplicados del mismo día eliminados"
fi

# 7c. Poda diaria de las copias fechadas del grafo: conservar solo la ÚLTIMA de cada día.
# Desde el 10/10/2026 el sync regenera el backup cada 30 min, así que sin esta poda se
# acumularían ~48 copias diarias del mismo grafo (~5 MB/día, ~150 MB a los 30 días de
# retención). La granularidad fina por debajo del día no se pierde "de más": los tarballs
# también se podan a uno por día.
GRAFO_DIR="$HOME/Config/mimocode/backups"
PODADOS_G=0
for f in "$GRAFO_DIR"/mimocode-memory-backup-*.jsonl; do
  [ -f "$f" ] || continue
  DAY=$(basename "$f" | grep -oE '[0-9]{8}' | head -1 || true)
  [ -n "$DAY" ] || continue
  LAST=$(find "$GRAFO_DIR" -maxdepth 1 -name "mimocode-memory-backup-${DAY}-*.jsonl" 2>/dev/null | sort | tail -1)
  if [ -n "$LAST" ] && [ "$f" != "$LAST" ]; then
    rm -f "$f"
    PODADOS_G=$((PODADOS_G+1))
  fi
done
if [ "$PODADOS_G" -gt 0 ]; then
  info "Poda diaria del grafo: $PODADOS_G copias duplicadas del mismo día eliminadas"
fi

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
    --exclude 'backups/' \
    --exclude 'node_modules' \
    --exclude '*.bak*' \
    --exclude '.env' --exclude '*.env' \
    --exclude 'auth.json' \
    --exclude 'credenciales/' \
    --exclude '*.tar.gz' \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    --exclude 'data/*.log' \
    --exclude 'mimocode-memory-backup-*.jsonl' \
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
