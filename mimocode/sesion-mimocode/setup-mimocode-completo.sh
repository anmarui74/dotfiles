#!/usr/bin/env bash
# ============================================================
# setup-mimocode-completo.sh — INSTALACIÓN AUTÓNOMA DESDE CERO
# ============================================================
# Deja MiMoCode EXACTAMENTE igual que la instalación activa de
# Antonio, partiendo de un sistema limpio.
#
# Fuente de la configuración: ./config/  (copia canónica que
# mantiene `sync-mimocode.sh` idéntica a ~/.config/mimocode/).
# Esa carpeta viaja junto a este script dentro de sesion-mimocode/
# y dentro del tarball, así que el conjunto es autosuficiente.
#
# ⚠️ NO se embebe la config (mimocode.jsonc, AGENTS.md, tui.json…)
#    a propósito: duplicarla reintroduciría el desfase que ya nos
#    mordió (2 lanzadores desfasados un mes). Lo que SÍ se embebe
#    (lanzadores, timer, scripts de backup) lo verifica
#    automáticamente check-setup-completo.sh.
#
# Pasos: 0) dependencias  1) binario  2) directorios  3) config
#        4) credenciales  5) lanzadores  6) zsh  7) timer
#        8) npm  9) estructura Config  10) LM Studio  11) LSPs
#        12) voz  13) verificación final
#
# Referencia del patrón: ~/Config/opencode/sesion-opencode/setup-opencode-completo.sh
# ============================================================
set -uo pipefail

VERDE='\033[0;32m'; AMARILLO='\033[1;33m'; ROJO='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${VERDE}[+]${NC} $1"; }
aviso() { echo -e "${AMARILLO}[!]${NC} $1"; }
error() { echo -e "${ROJO}[X]${NC} $1"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${ROOT_DIR}/config"
CONFIG_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"

HOME_DIR="${HOME}"
MIMO_BIN_DIR="${HOME_DIR}/.mimocode/bin"
MIMO_CONFIG_DIR="${HOME_DIR}/.config/mimocode"
MIMO_DATA_DIR="${HOME_DIR}/.local/share/mimocode"
LOCAL_BIN="${HOME_DIR}/.local/bin"
AUTH_DST="${MIMO_DATA_DIR}/auth.json"
OPENCODE_DIR="${HOME_DIR}/.config/opencode"

FALLOS=0

echo ""
echo "=============================================="
echo "  INSTALACIÓN DE MIMOCODE DESDE CERO"
echo "=============================================="
info "Fuente de configuración: ${CONFIG_SRC}"
info "Destino:                 ${MIMO_CONFIG_DIR}"
echo ""

# ═══════════════════════════════════════════════════════════
# PASO 0: Dependencias base
# ═══════════════════════════════════════════════════════════
echo "--- 0/13: Dependencias base ---"
FALTAN=()
for c in node npm python3 curl git; do
    command -v "$c" >/dev/null 2>&1 || FALTAN+=("$c")
done
if [ ${#FALTAN[@]} -gt 0 ]; then
    aviso "Faltan dependencias: ${FALTAN[*]}"
    if command -v pacman >/dev/null 2>&1; then
        info "Instalando con pacman (se pedirá contraseña)..."
        if sudo pacman -S --needed --noconfirm nodejs npm python curl git; then
            info "Dependencias instaladas"
        else
            error "Instalación parcial; revisa: ${FALTAN[*]}"
            FALLOS=$((FALLOS+1))
        fi
    else
        error "Instálalas manualmente y vuelve a ejecutar: ${FALTAN[*]}"
        exit 1
    fi
else
    info "Dependencias base OK (node, npm, python3, curl, git)"
fi

# ═══════════════════════════════════════════════════════════
# PASO 1: Binario mimo
# ═══════════════════════════════════════════════════════════
echo "--- 1/13: Binario mimo ---"
if [ -x "${MIMO_BIN_DIR}/mimo" ]; then
    info "Binario mimo ya presente (v$("${MIMO_BIN_DIR}/mimo" --version 2>/dev/null | head -1 || echo '?'))"
else
    aviso "Binario mimo no encontrado; instalando con el instalador oficial..."
    if curl -fsSL --max-time 120 https://mimo.xiaomi.com/install | bash; then
        if [ -x "${MIMO_BIN_DIR}/mimo" ]; then
            info "Binario mimo instalado (v$("${MIMO_BIN_DIR}/mimo" --version 2>/dev/null | head -1 || echo '?'))"
        else
            error "El instalador terminó pero no hay binario en ${MIMO_BIN_DIR}/mimo"
            FALLOS=$((FALLOS+1))
        fi
    else
        error "No se pudo instalar el binario. Ejecuta a mano:"
        error "  curl -fsSL https://mimo.xiaomi.com/install | bash"
        FALLOS=$((FALLOS+1))
    fi
fi

# ═══════════════════════════════════════════════════════════
# PASO 2: Estructura de directorios
# ═══════════════════════════════════════════════════════════
echo "--- 2/13: Creando directorios ---"
mkdir -p "${MIMO_CONFIG_DIR}" "${MIMO_CONFIG_DIR}/data/memory" \
         "${MIMO_DATA_DIR}" "${LOCAL_BIN}" \
         "${HOME_DIR}/.config/systemd/user" \
         "${CONFIG_ROOT}/backups/mimocode" "${CONFIG_ROOT}/documentacion" \
         "${CONFIG_ROOT}/sesion-mimocode"
info "Directorios creados"

# ═══════════════════════════════════════════════════════════
# PASO 3: Restaurar la configuración
# ═══════════════════════════════════════════════════════════
echo "--- 3/13: Restaurando configuración ---"
if [ ! -d "${CONFIG_SRC}" ]; then
    error "No existe la configuración embebida en ${CONFIG_SRC}"
    exit 1
fi
if [ -f "${MIMO_CONFIG_DIR}/mimocode.jsonc" ]; then
    aviso "Ya existe una configuración activa; se sobrescribe con la canónica"
fi
cp -a "${CONFIG_SRC}/." "${MIMO_CONFIG_DIR}/"
# Limpiar restos que no deben llegar a la instalación activa
rm -f "${MIMO_CONFIG_DIR}"/data/*.log 2>/dev/null || true
chmod +x "${MIMO_CONFIG_DIR}/sync-mimocode.sh" 2>/dev/null || true
info "Configuración restaurada (mimocode.jsonc, profiles, tui.json, AGENTS.md, plugin de voz, memoria)"

# ═══════════════════════════════════════════════════════════
# PASO 4: Credenciales de proveedores (auth.json)
# ═══════════════════════════════════════════════════════════
# ⚠️ EMBEBIDAS A PROPÓSITO: así una instalación desde cero queda operativa con
#    la MISMA configuración actual (agentes cloud y nvidia funcionando) sin
#    pasos manuales de autenticación.
#    La copia de DOTFILES se sanea automáticamente en backup-mimocode.sh (paso 8):
#    las claves NUNCA salen hacia ~/Documentos/dotfiles/.
echo "--- 4/13: Credenciales (auth.json) ---"
mkdir -p "$(dirname "${AUTH_DST}")"
if [ -f "${AUTH_DST}" ]; then
    aviso "Ya existen credenciales en ${AUTH_DST}; se conservan las actuales"
    aviso "  (bórralas y vuelve a ejecutar para restaurar las embebidas)"
else
    cat > "${AUTH_DST}" <<'AUTHEOF'
{
  "opencode-go": {
    "type": "api",
    "key": "TU_CLAVE_AQUI"
  },
  "nvidia": {
    "type": "api",
    "key": "TU_CLAVE_AQUI"
  },
  "xiaomi": {
    "type": "api",
    "key": "TU_CLAVE_AQUI",
    "metadata": {
      "uid": "173093532",
      "base_url": "https://api.xiaomimimo.com/v1"
    }
  }
}
AUTHEOF
    chmod 600 "${AUTH_DST}"
    info "Credenciales restauradas en ${AUTH_DST} (chmod 600)"
fi

# ═══════════════════════════════════════════════════════════
# PASO 5: Lanzadores start-mimo*.sh
# ═══════════════════════════════════════════════════════════
# ⚠️ EMBEBIDOS: si editas un lanzador activo, replícalo aquí
#    (check-setup-completo.sh lo detecta y aborta el backup).
echo "--- 5/13: Lanzadores ---"
mkdir -p "${LOCAL_BIN}"

cat > "${LOCAL_BIN}/start-mimo.sh" <<'EOS'
#!/usr/bin/env bash
# start-mimo.sh - Carga LM Studio + modelo Qwen3.8-9B + proxy (infra propia de MiMoCode), luego abre MiMoCode
# Si SKIP_LMSTUDIO=1, NO carga el modelo local en VRAM.
set -e

# Telemetría desactivada por privacidad (sobreescribible con MIMOCODE_ENABLE_ANALYSIS=true)
export MIMOCODE_ENABLE_ANALYSIS="${MIMOCODE_ENABLE_ANALYSIS:-false}"

VERDE='\033[0;32m'; AMARILLO='\033[1;33m'; ROJO='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${VERDE}[+]${NC} $1"; }
aviso() { echo -e "${AMARILLO}[!]${NC} $1"; }
error() { echo -e "${ROJO}[X]${NC} $1"; }

LMS_SCRIPT="/home/antonio/.config/mimocode/start-lmstudio.sh"
REAL_MIMO="${REAL_MIMO:-/home/antonio/.mimocode/bin/mimo}"

if [ -n "$SKIP_LMSTUDIO" ]; then
    aviso "SKIP_LMSTUDIO=1: NO se carga el modelo local en VRAM."
elif [ -x "$LMS_SCRIPT" ]; then
    info "Cargando LM Studio (modelo Qwen3.8-9B + proxy)..."
    bash "$LMS_SCRIPT" || { error "Falló al cargar LM Studio + modelo."; exit 1; }
    # Health-check puertos LM Studio y proxy
    for port in 1234 4001; do
        if ! curl -s --connect-timeout 5 http://localhost:$port >/dev/null 2>&1; then
            error "Health-check falló: puerto $port no responde."
            exit 1
        fi
    done
    info "Health-check LM Studio y proxy OK"
else
    aviso "start-lmstudio.sh no encontrado, usando start-lmstudio-server.sh"
    bash /home/antonio/.config/mimocode/start-lmstudio-server.sh || { error "Falló al iniciar LM Studio."; exit 1; }
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

LMS_SCRIPT="/home/antonio/.config/mimocode/start-lmstudio.sh"
REAL_MIMO="${REAL_MIMO:-/home/antonio/.mimocode/bin/mimo}"
export MIMOCODE_CONFIG_DIR="$HOME/.config/mimocode/profiles/local"

if [ -n "$SKIP_LMSTUDIO" ]; then
    aviso "SKIP_LMSTUDIO=1: NO se carga el modelo local en VRAM."
elif [ -x "$LMS_SCRIPT" ]; then
    info "Cargando LM Studio (modelo Qwen3.8-9B + proxy)..."
    bash "$LMS_SCRIPT" || { error "Falló al cargar LM Studio + modelo."; exit 1; }
    for port in 1234 4001; do
        if ! curl -s --connect-timeout 5 http://localhost:$port >/dev/null 2>&1; then
            error "Health-check falló: puerto $port no responde."
            exit 1
        fi
    done
    info "Health-check LM Studio y proxy OK"
else
    aviso "start-lmstudio.sh no encontrado, usando start-lmstudio-server.sh"
    bash /home/antonio/.config/mimocode/start-lmstudio-server.sh || { error "Falló al iniciar LM Studio."; exit 1; }
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
info "3 lanzadores creados en ${LOCAL_BIN}"

# ═══════════════════════════════════════════════════════════
# PASO 6: Funciones ZSH
# ═══════════════════════════════════════════════════════════
echo "--- 6/13: Funciones ZSH ---"
ZSHRC="${HOME_DIR}/.zshrc"
if grep -q "function mimo()" "${ZSHRC}" 2>/dev/null; then
    info "Las funciones ZSH mimo* ya existen"
else
    cat >> "${ZSHRC}" <<'EOS'

# MiMoCode launchers
function mimo() { /home/antonio/.local/bin/start-mimo.sh "$@"; }
function mimo-local() { /home/antonio/.local/bin/start-mimo-local.sh "$@"; }
function mimo-cloud() { /home/antonio/.local/bin/start-mimo-cloud.sh "$@"; }
# La VOZ no necesita funciones propias: el plugin vive en tui.json (unico, sin variante
# por perfil) -> se carga en los 3 lanzamientos y basta con /voice en la TUI.
EOS
    info "Funciones ZSH añadidas a ${ZSHRC}"
fi

# Asegurar que ~/.mimocode/bin está en el PATH
if ! grep -q '.mimocode/bin' "${ZSHRC}" 2>/dev/null; then
    echo 'export PATH="$HOME/.mimocode/bin:$PATH"' >> "${ZSHRC}"
    info "PATH de mimocode añadido a ${ZSHRC}"
else
    info "PATH de mimocode ya presente en ${ZSHRC}"
fi

# ═══════════════════════════════════════════════════════════
# PASO 7: Timer systemd de sincronización
# ═══════════════════════════════════════════════════════════
echo "--- 7/13: Timer systemd ---"
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
    info "Timer mimocode-sync activado (cada 30 min)"
else
    aviso "systemd no disponible; el timer de sincronización no se ha activado"
fi

# ═══════════════════════════════════════════════════════════
# PASO 8: Dependencias npm (plugin de voz y de servidor)
# ═══════════════════════════════════════════════════════════
echo "--- 8/13: Dependencias npm ---"
if [ -f "${MIMO_CONFIG_DIR}/package.json" ]; then
    ( cd "${MIMO_CONFIG_DIR}" && npm install --no-audit --no-fund 2>/dev/null ) \
        && info "Dependencias npm instaladas en ${MIMO_CONFIG_DIR}" \
        || aviso "Falló npm install; ejecútalo a mano: cd ${MIMO_CONFIG_DIR} && npm install"
else
    aviso "No hay package.json en ${MIMO_CONFIG_DIR}; se omite npm install"
fi

# ═══════════════════════════════════════════════════════════
# PASO 9: Estructura de ~/Config/mimocode + scripts de backup
# ═══════════════════════════════════════════════════════════
# ⚠️ EMBEBIDOS: si editas el script de backup o el de verificación,
#    replícalos aquí (check-setup-completo.sh compara estos heredocs).
echo "--- 9/13: Estructura de Config + scripts de backup ---"

cat > "${CONFIG_ROOT}/backup-mimocode.sh" <<'BKUEOF'
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
BKUEOF
chmod +x "${CONFIG_ROOT}/backup-mimocode.sh"
info "backup-mimocode.sh instalado"

cat > "${CONFIG_ROOT}/check-setup-completo.sh" <<'CHKEOF'
#!/usr/bin/env bash
# ============================================================
# check-setup-completo.sh — Verificación del instalador y de la
# copia canónica de MiMoCode.
#
# Comprueba que:
#  1. Existe la copia canónica de la config (sesion-mimocode/config)
#  2. Existe el instalador y tiene sintaxis válida (bash -n)
#  3. La copia canónica == config activa (~/.config/mimocode)
#  4. Existen los lanzadores start-mimo*.sh
#  5. Las funciones ZSH mimo* están definidas
#  6. Los heredocs embebidos en el instalador (lanzadores, timer systemd, scripts
#     de backup/verificación, credenciales e infraestructura LM Studio) coinciden
#     con los ficheros activos
#
# Se ejecuta automáticamente desde backup-mimocode.sh. Si hay
# errores, el backup se ABORTA.
# ============================================================
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANON="${ROOT_DIR}/sesion-mimocode/config"
SETUP="${ROOT_DIR}/sesion-mimocode/setup-mimocode-completo.sh"
ACTIVO="$HOME/.config/mimocode"
LOG="$ACTIVO/data/setup-check.log"

ERRORS=0

mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" | tee -a "$LOG"; }

log "═══════════ VERIFICACIÓN SETUP MIMOCODE ═══════════"

# 1. Copia canónica
if [ -d "$CANON" ]; then
    log "✅ Copia canónica: $CANON"
else
    log "❌ ERROR: No existe $CANON"
    ERRORS=$((ERRORS+1))
fi

# 2. Instalador
if [ -f "$SETUP" ]; then
    log "✅ Instalador encontrado ($(wc -l < "$SETUP") líneas)"
    if bash -n "$SETUP" 2>/dev/null; then
        log "✅ Sintaxis del instalador válida (bash -n)"
    else
        log "❌ ERROR: Sintaxis inválida en el instalador"
        ERRORS=$((ERRORS+1))
    fi
else
    log "❌ ERROR: No existe $SETUP"
    ERRORS=$((ERRORS+1))
fi

# 3. Copia canónica == config activa (excluye node_modules, .bak y logs)
if [ -d "$CANON" ] && [ -d "$ACTIVO" ]; then
    DIFF=$(diff -rq \
        --exclude 'node_modules' \
        --exclude '*.bak*' \
        --exclude 'sync.log' \
        --exclude 'setup-check.log' \
        "$ACTIVO" "$CANON" 2>&1 || true)
    if [ -z "$DIFF" ]; then
        log "✅ Copia canónica == config activa"
    else
        log "❌ ERROR: La copia canónica difiere de la config activa:"
        echo "$DIFF" | sed 's/^/      /' | tee -a "$LOG"
        log "   → Ejecuta: bash ~/.config/mimocode/sync-mimocode.sh"
        ERRORS=$((ERRORS+1))
    fi
fi

# 4. Lanzadores
for l in start-mimo.sh start-mimo-local.sh start-mimo-cloud.sh; do
    if [ -x "$HOME/.local/bin/$l" ]; then
        log "✅ Lanzador $l"
    else
        log "❌ ERROR: Falta el lanzador $l"
        ERRORS=$((ERRORS+1))
    fi
done

# 5. Funciones ZSH
if grep -q "function mimo()" "$HOME/.zshrc" 2>/dev/null; then
    log "✅ Funciones ZSH mimo*"
else
    log "⚠️  Faltan las funciones ZSH mimo* en ~/.zshrc"
    ERRORS=$((ERRORS+1))
fi

# 6. Heredocs embebidos en el instalador == ficheros activos
if [ -f "$SETUP" ]; then
    HEREDOCS=$(python3 - "$SETUP" <<'PYEOF'
import re, os, sys
setup = sys.argv[1]
H = os.path.expanduser('~')
CFG = f'{H}/Config/mimocode'
mapa = {
    '${LOCAL_BIN}/start-mimo.sh':       f'{H}/.local/bin/start-mimo.sh',
    '${LOCAL_BIN}/start-mimo-local.sh': f'{H}/.local/bin/start-mimo-local.sh',
    '${LOCAL_BIN}/start-mimo-cloud.sh': f'{H}/.local/bin/start-mimo-cloud.sh',
    '${HOME_DIR}/.config/systemd/user/mimocode-sync.service': f'{H}/.config/systemd/user/mimocode-sync.service',
    '${HOME_DIR}/.config/systemd/user/mimocode-sync.timer':   f'{H}/.config/systemd/user/mimocode-sync.timer',
    '${CONFIG_ROOT}/backup-mimocode.sh':      f'{CFG}/backup-mimocode.sh',
    '${CONFIG_ROOT}/check-setup-completo.sh': f'{CFG}/check-setup-completo.sh',
    '${AUTH_DST}':                            f'{H}/.local/share/mimocode/auth.json',
    '${MIMO_CONFIG_DIR}/start-lmstudio.sh':        f'{H}/.config/mimocode/start-lmstudio.sh',
    '${MIMO_CONFIG_DIR}/start-lmstudio-server.sh': f'{H}/.config/mimocode/start-lmstudio-server.sh',
    '${MIMO_CONFIG_DIR}/lmstudio-proxy.py':        f'{H}/.config/mimocode/lmstudio-proxy.py',
}
src = open(setup).read()
pat = re.compile(r'cat > "([^"]+)" <<\'([A-Z_]+)\'\n(.*?)\n\2\n', re.S)
for dest, delim, contenido in pat.findall(src):
    real = mapa.get(dest)
    if not real or not os.path.exists(real):
        continue
    nombre = os.path.basename(real)
    if open(real).read().strip('\n') == contenido.strip('\n'):
        print(f'OK|{nombre}')
    else:
        print(f'BAD|{nombre}')
PYEOF
)
    while IFS='|' read -r estado nombre; do
        [ -z "$nombre" ] && continue
        if [ "$estado" = "OK" ]; then
            log "✅ Heredoc $nombre == activo"
        else
            log "❌ ERROR: $nombre DIFIERE de lo embebido en el instalador"
            ERRORS=$((ERRORS+1))
        fi
    done <<< "$HEREDOCS"
fi

if [ "$ERRORS" -eq 0 ]; then
    log "✅ Verificación completada sin errores"
    exit 0
else
    log "❌ Verificación con $ERRORS problema(s)"
    exit 1
fi
CHKEOF
chmod +x "${CONFIG_ROOT}/check-setup-completo.sh"
info "check-setup-completo.sh instalado"

# AGENTS.md en la raíz de Config (copia de la config activa)
if [ -f "${MIMO_CONFIG_DIR}/AGENTS.md" ]; then
    cp "${MIMO_CONFIG_DIR}/AGENTS.md" "${CONFIG_ROOT}/AGENTS.md"
    info "AGENTS.md copiado a ${CONFIG_ROOT}/"
fi

# Enlace simbólico de acceso directo al instalador
ln -sfn "sesion-mimocode/setup-mimocode-completo.sh" "${CONFIG_ROOT}/setup-mimocode-completo.sh"
info "Enlace ${CONFIG_ROOT}/setup-mimocode-completo.sh → sesion-mimocode/setup-mimocode-completo.sh"

# ═══════════════════════════════════════════════════════════
# PASO 10: Infraestructura LM Studio PROPIA de MiMoCode
# ═══════════════════════════════════════════════════════════
# MiMoCode es AUTÓNOMO: NO depende de ~/.config/opencode/. Instala su propia copia
# de los scripts de LM Studio y del proxy, con las rutas ya adaptadas a mimocode.
# ⚠️ EMBEBIDOS: si editas el original en ~/.config/mimocode/, replícalo aquí.
echo "--- 10/13: Infraestructura LM Studio (propia) ---"

cat > "${MIMO_CONFIG_DIR}/start-lmstudio.sh" <<'LMSEOF'
#!/usr/bin/env bash
# start-lmstudio.sh - Qwen3.8-9B Q6_K + RTX 4070 Ti SUPER (80k contexto)
set -euo pipefail

LMSTUDIO="/home/antonio/.lmstudio/bin/lms"
MODEL_ID="qwen3.8-9b"
CONTEXTO=81920
PORT_LM=1234
PORT_PROXY=4001

echo "╔════════════════════════════════════════════════════╗"
echo "║  Qwen3.8-9B Q6_K - 80k contexto                  ║"
echo "║  RTX 4070 Ti SUPER 16GB + Ryzen 9 7900 Zen4      ║"
echo "╚════════════════════════════════════════════════════╝"

# Verificar binario
if [ ! -f "$LMSTUDIO" ]; then
    echo "❌ Binario no encontrado: $LMSTUDIO"
    exit 1
fi

# Iniciar servidor LM Studio si no está corriendo
if ! curl -s http://localhost:$PORT_LM/v1/models >/dev/null 2>&1; then
    echo "▶️  Arrancando LM Studio server..."
    "$LMSTUDIO" server start >/dev/null 2>&1
    sleep 3
fi
echo "✅ LM Studio activo puerto ${PORT_LM}"

# Comprobar si el modelo ya está cargado
if "$LMSTUDIO" ps 2>/dev/null | grep -q "$MODEL_ID"; then
    echo "✅ Modelo $MODEL_ID ya está cargado en VRAM, se omite recarga"
else
    echo "▶️  Liberando VRAM..."
    "$LMSTUDIO" unload --all >/dev/null 2>&1 || true
    sleep 2

    # Cargar Q6_K con 80k contexto
    echo "▶️  Cargando Qwen3.8-9B Q6_K con ${CONTEXTO} tokens de contexto..."
    if ! "$LMSTUDIO" load "$MODEL_ID" -c "$CONTEXTO" -y >/dev/null 2>&1; then
        echo "⚠️  Carga directa falló, intentando sin contexto específico..."
        "$LMSTUDIO" load "$MODEL_ID" -y >/dev/null 2>&1
    fi
    sleep 2
fi

CONTEXTO_REAL=$("$LMSTUDIO" ps 2>/dev/null | awk -v m="$MODEL_ID" '
  NR==1 { for (i=1; i<=NF; i++) if ($i == "CONTEXT") c=i }
  $0 ~ m && c { print $c; exit }')
echo "✅ Modelo cargado: ${CONTEXTO_REAL:-desconocido} tokens de contexto"

VRAM_USO=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
echo "✅ VRAM usado: ${VRAM_USO} MB / 16376 MB"

# Matar proxies zombies y arrancar uno limpio
if pgrep -f "lmstudio-proxy" >/dev/null 2>&1; then
    pkill -f "lmstudio-proxy" 2>/dev/null || true
    sleep 1
fi
echo "▶️  Iniciando proxy en puerto ${PORT_PROXY}..."
setsid python3 /home/antonio/.config/mimocode/lmstudio-proxy.py "$PORT_PROXY" < /dev/null > /tmp/lms-proxy.log 2>&1 &
sleep 2
echo "✅ Proxy activo en http://localhost:${PORT_PROXY}"

echo ""
echo "════════════════════════════════════════════════════"
echo "  Sistema listo para usar!"
echo "  API: http://localhost:${PORT_PROXY}/v1/chat/completions"
echo "  Modelo: $MODEL_ID"
echo "  Contexto: ${CONTEXTO} tokens"
echo "  Tokens/s: incluido en cada respuesta"
echo "════════════════════════════════════════════════════"
LMSEOF
chmod +x "${MIMO_CONFIG_DIR}/start-lmstudio.sh"

cat > "${MIMO_CONFIG_DIR}/start-lmstudio-server.sh" <<'LMSSRVEOF'
#!/usr/bin/env bash
# start-lmstudio-server.sh - Solo servidor LM Studio sin cargar modelo en VRAM
set -euo pipefail

LMSTUDIO="/home/antonio/.lmstudio/bin/lms"
PORT_LM=1234
PORT_PROXY=4001

echo "╔════════════════════════════════════════════════════╗"
echo "║  LM Studio Server (sin modelo cargado en VRAM)   ║"
echo "║  Esperando carga manual desde OpenCode/OCV       ║"
echo "╚════════════════════════════════════════════════════╝"

# Verificar binario
if [ ! -f "$LMSTUDIO" ]; then
    echo "❌ Binario no encontrado: $LMSTUDIO"
    exit 1
fi

# Descargar y cargar modelos previos para liberar VRAM
echo "▶️  Descargando modelos previos..."
"$LMSTUDIO" download --all >/dev/null 2>&1 || true

# Liberar TODOS los modelos cargados
echo "▶️  Liberando VRAM..."
"$LMSTUDIO" unload --all >/dev/null 2>&1 || true
sleep 2

# Verificar estado antes de iniciar servidor
MODELS_BEFORE=$("$LMSTUDIO" ps 2>/dev/null || echo "")
if [ -n "$MODELS_BEFORE" ]; then
    echo "⚠️  Advertencia: Hay modelos cargados:"
    echo "$MODELS_BEFORE" | grep -v "^$" | head -3
fi

# Iniciar servidor LM Studio si no está corriendo
echo "▶️  Verificando servidor LM Studio..."
if curl -s http://localhost:$PORT_LM/v1/models >/dev/null 2>&1; then
    echo "✅ LM Studio ya está corriendo en puerto ${PORT_LM}"
else
    echo "▶️  Arrancando LM Studio server..."
    "$LMSTUDIO" server start >/dev/null 2>&1
    sleep 3
    
    # Verificar que el servidor responde
    if ! curl -s http://localhost:$PORT_LM/v1/models >/dev/null 2>&1; then
        echo "❌ Falló al iniciar LM Studio. Asegúrate de que la GUI esté abierta o usa: lms server start"
        exit 1
    fi
fi

# Verificar estado final (debería estar vacío)
MODELS_AFTER=$("$LMSTUDIO" ps 2>/dev/null || echo "")
echo "✅ LM Studio activo en puerto ${PORT_LM}"

if [ -n "$MODELS_AFTER" ] && ! echo "$MODELS_AFTER" | grep -q "^$"; then
    VRAM_USO=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
    echo "⚠️  Advertencia: Modelo cargado (debería estar vacío):"
    echo "$MODELS_AFTER" | grep -v "^$" | head -3
    echo "   VRAM usada: ${VRAM_USO} MB"
else
    VRAM_USO=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
    echo "✅ VRAM libre: ${VRAM_USO} MB / 16376 MB"
fi

# Matar proxies zombies y arrancar uno limpio
echo "▶️  Iniciando proxy en puerto ${PORT_PROXY}..."
if pgrep -f "lmstudio-proxy" >/dev/null 2>&1; then
    pkill -f "lmstudio-proxy" 2>/dev/null || true
    sleep 1
fi

setsid python3 /home/antonio/.config/mimocode/lmstudio-proxy.py "$PORT_PROXY" < /dev/null > /tmp/lms-proxy.log 2>&1 &
sleep 2
echo "✅ Proxy activo en http://localhost:${PORT_PROXY}"

echo ""
echo "════════════════════════════════════════════════════"
echo "  Servidor listo! Modelo NO cargado en VRAM."
echo "  Carga automática cuando uses: mimo o mimo-local"
echo "  API: http://localhost:${PORT_PROXY}/v1/chat/completions"
echo "════════════════════════════════════════════════════"
LMSSRVEOF
chmod +x "${MIMO_CONFIG_DIR}/start-lmstudio-server.sh"

cat > "${MIMO_CONFIG_DIR}/lmstudio-proxy.py" <<'LMPROXYEOF'
#!/usr/bin/env python3
"""Proxy OpenCode ↔ LM Studio - VERSIÓN QUE FUNCIONA + MÉTRICAS
Reenvía peticiones a LM Studio (localhost:1234). Además:
- Registra métricas por request (tiempo, tokens, tok/s) en METRICS_EXPORT_PATH
- Inyecta `stats.tokens_per_second` en respuestas no-streaming
"""
import json
import os
import re
import threading
import time
import urllib.request
import http.server
import sys

LM = "http://localhost:1234"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4001

CONFIG_DIR = os.path.dirname(os.path.abspath(__file__))
METRICS_LOCK = threading.Lock()
MAX_RECORDS = 500


def load_env(path):
    """Carga variables KEY=VALUE de un .env simple (para METRICS)."""
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                k = k.strip()
                v = v.strip().strip('"').strip("'")
                if k:
                    os.environ.setdefault(k, v)
    except OSError:
        pass


load_env(os.path.join(CONFIG_DIR, ".env"))


def env_bool(name, default):
    val = os.environ.get(name)
    if val is None:
        return default
    return val.strip().lower() in ("1", "true", "yes", "on")


ENABLE_METRICS = env_bool("ENABLE_METRICS", True)
METRICS_PATH = os.environ.get("METRICS_EXPORT_PATH") or os.path.join(CONFIG_DIR, "data", "metrics.json")


def record_metric(model, prompt_tokens, completion_tokens, elapsed_s, stream):
    if not ENABLE_METRICS:
        return
    tps = (completion_tokens / elapsed_s) if elapsed_s > 0 else 0
    entry = {
        "ts": time.time(),
        "time": time.strftime("%d/%m/%Y %H:%M:%S"),
        "model": model,
        "stream": bool(stream),
        "elapsed_s": round(elapsed_s, 3),
        "prompt_tokens": int(prompt_tokens or 0),
        "completion_tokens": int(completion_tokens or 0),
        "tokens_per_second": round(tps, 2),
    }
    try:
        with METRICS_LOCK:
            data = {"updated_at": entry["time"], "count": 0, "records": []}
            try:
                with open(METRICS_PATH) as f:
                    loaded = json.load(f)
                if isinstance(loaded, dict):
                    data = loaded
            except (OSError, ValueError):
                pass
            records = data.get("records", [])
            if not isinstance(records, list):
                records = []
            records.append(entry)
            data["records"] = records[-MAX_RECORDS:]
            data["count"] = len(data["records"])
            data["updated_at"] = entry["time"]
            os.makedirs(os.path.dirname(METRICS_PATH), exist_ok=True)
            with open(METRICS_PATH, "w") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
    except OSError:
        pass


def parse_sse_usage(buf):
    """Extrae el usage (tokens) del último chunk data: {...} de un buffer SSE.
    Si el servidor no reporta usage (LM Studio), estima tokens = chars / 4."""
    if not buf:
        return None
    try:
        text = buf.decode("utf-8", errors="ignore")
    except Exception:
        return None
    usage = None
    chars = 0
    for m in re.finditer(r'data:\s*(\{.*?\})\s*\n', text, re.DOTALL):
        try:
            obj = json.loads(m.group(1))
        except ValueError:
            continue
        if not isinstance(obj, dict):
            continue
        if isinstance(obj.get("usage"), dict):
            usage = obj["usage"]
        try:
            delta = obj.get("choices", [{}])[0].get("delta", {})
            chars += len(delta.get("content") or "") + len(delta.get("reasoning_content") or "")
        except Exception:
            pass
    if usage is not None:
        return usage
    estimated = {"prompt_tokens": 0, "completion_tokens": max(1, round(chars / 4))}
    return estimated


class Proxy(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, format, *args):
        pass

    def do_GET(self):
        try:
            r = urllib.request.urlopen(urllib.request.Request(f"{LM}{self.path}"), timeout=5)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(r.read())
        except Exception:
            self.send_error(502)

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        body = json.loads(raw)
        model = body.get("model", "")
        if model.startswith("lmstudio/"):
            body["model"] = model[len("lmstudio/"):]

        msgs = body.get('messages', [])
        if not any(m.get('role') == 'user' for m in msgs):
            body['messages'].append({'role': 'user', 'content': '(cont.)'})

        start = time.time()
        try:
            r = urllib.request.urlopen(urllib.request.Request(
                f"{LM}{self.path}", data=json.dumps(body).encode(),
                headers={"Content-Type": "application/json"}), timeout=300)

            is_stream = body.get("stream", False)
            if is_stream:
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Cache-Control", "no-cache")
                self.end_headers()
                buf = b""
                while True:
                    chunk = r.read(65536)
                    if not chunk:
                        break
                    buf += chunk
                    self.wfile.write(chunk)
                    self.wfile.flush()
                elapsed = time.time() - start
                usage = parse_sse_usage(buf)
                if usage:
                    record_metric(model, usage.get("prompt_tokens"), usage.get("completion_tokens"), elapsed, True)
            else:
                resp = r.read()
                elapsed = time.time() - start
                try:
                    obj = json.loads(resp)
                    usage = obj.get("usage") or {}
                    tps = None
                    if elapsed > 0 and usage.get("completion_tokens"):
                        tps = round(usage["completion_tokens"] / elapsed, 2)
                    obj["stats"] = {"tokens_per_second": tps}
                    resp = json.dumps(obj).encode()
                    record_metric(model, usage.get("prompt_tokens"), usage.get("completion_tokens"), elapsed, False)
                except ValueError:
                    pass
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(resp)
        except Exception as e:
            self.send_error(502, str(e)[:200])


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Proxy).serve_forever()
LMPROXYEOF
mkdir -p "${MIMO_CONFIG_DIR}/data"
info "Infraestructura LM Studio instalada (start-lmstudio.sh, server y proxy)"

# El proxy es autocontenido: escribe las métricas en ${MIMO_CONFIG_DIR}/data/metrics.json
# y lee un .env de su propio directorio si existe. NO necesita claves de API.
# ─── LM Studio: instalar si falta ───
LMS_BIN="${HOME_DIR}/.lmstudio/bin/lms"
if command -v lms >/dev/null 2>&1; then
    LMS_CMD="lms"
    info "LM Studio CLI ya instalado (en el PATH)"
elif [ -x "$LMS_BIN" ]; then
    LMS_CMD="$LMS_BIN"
    info "LM Studio CLI ya instalado en $LMS_BIN"
else
    aviso "LM Studio no encontrado; instalándolo (puede tardar varios minutos)..."
    if curl -fsSL https://lmstudio.ai/install.sh | bash -s latest --yes; then
        LMS_CMD="$LMS_BIN"
        info "LM Studio instalado"
    else
        aviso "Fallo al instalar LM Studio. Instálalo a mano: https://lmstudio.ai/"
    fi
fi

# ─── Modelos: descargar de Hugging Face los que falten ───
# Ambos son GGUF en cuantización Q6_K (~7,5 GB cada uno):
#   qwen3.8-9b ← https://huggingface.co/empero-ai/Qwen3.8-9B-Distill-GGUF  (modelo principal)
#   qwen3.5-9b ← https://huggingface.co/unsloth/Qwen3.5-9B-GGUF
# En LM Studio quedan como "qwen3.8-9b" y "qwen3.5-9b".
MODELOS=(
  "qwen3.8-9b|empero-ai/Qwen3.8-9B-Distill-GGUF@Q6_K"
  "qwen3.5-9b|unsloth/Qwen3.5-9B-GGUF@Q6_K"
)
if [ -n "${LMS_CMD:-}" ]; then
    for entrada in "${MODELOS[@]}"; do
        clave="${entrada%%|*}"
        repo="${entrada##*|}"
        if "$LMS_CMD" ls 2>/dev/null | grep -q "$clave"; then
            info "Modelo $clave ya disponible en LM Studio"
        else
            aviso "Descargando $repo (~7,5 GB). Puede tardar bastante..."
            if "$LMS_CMD" get "$repo" --yes; then
                info "Modelo $clave descargado"
            else
                aviso "Fallo al descargar $clave. Hazlo a mano:"
                aviso "  lms get $repo --yes"
            fi
        fi
    done
else
    aviso "Sin LM Studio no se puede descargar el modelo."
    aviso "Los perfiles 'mimo' y 'mimo-local' lo necesitan. Puedes arrancar con"
    aviso "SKIP_LMSTUDIO=1 para usarlos sin modelo local (los perfiles cloud van igual)."
fi

# ═══════════════════════════════════════════════════════════
# PASO 11: Servidores LSP
# ═══════════════════════════════════════════════════════════
echo "--- 11/13: Servidores LSP ---"
npm config set prefix "$HOME/.npm-global" >/dev/null 2>&1 || true

if ! command -v basedpyright-langserver >/dev/null 2>&1 && [ ! -x "${HOME_DIR}/.local/bin/basedpyright-langserver" ]; then
    pipx install basedpyright >/dev/null 2>&1 \
        && info "basedpyright instalado" \
        || aviso "Fallo basedpyright (instala: pipx install basedpyright)"
else
    info "basedpyright ya instalado"
fi

for pkg in "typescript-language-server typescript" "vscode-langservers-extracted" \
           "yaml-language-server" "bash-language-server"; do
    bin=$(echo "$pkg" | awk '{print $1}')
    if ! command -v "$bin" >/dev/null 2>&1 && [ ! -x "${HOME_DIR}/.npm-global/bin/$bin" ]; then
        npm install -g $pkg >/dev/null 2>&1 \
            && info "$bin instalado" \
            || aviso "Fallo $bin (instala: npm i -g $pkg)"
    else
        info "$bin ya instalado"
    fi
done

for b in clangd marksman; do
    if command -v "$b" >/dev/null 2>&1; then
        info "$b presente"
    else
        aviso "$b no encontrado (instálalo con tu gestor de paquetes)"
    fi
done
if [ -x "${HOME_DIR}/go/bin/gopls" ] || command -v gopls >/dev/null 2>&1; then
    info "gopls presente"
else
    aviso "gopls no encontrado (go install golang.org/x/tools/gopls@latest)"
fi
if [ -x "${HOME_DIR}/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rust-analyzer" ]; then
    info "rust-analyzer presente"
else
    aviso "rust-analyzer no encontrado (rustup component add rust-analyzer)"
fi

# ═══════════════════════════════════════════════════════════
# PASO 12: Dependencias de voz (STT/TTS)
# ═══════════════════════════════════════════════════════════
echo "--- 12/13: Dependencias de voz ---"
for c in sox whisper-cli speak-kokoro-gpu; do
    if command -v "$c" >/dev/null 2>&1 || [ -x "${LOCAL_BIN}/${c}" ]; then
        info "$c presente"
    else
        aviso "$c no encontrado → /voice y el TTS no funcionarán hasta instalarlo"
    fi
done

# ═══════════════════════════════════════════════════════════
# PASO 13: Verificación final
# ═══════════════════════════════════════════════════════════
echo ""
echo "--- 13/13: Verificación final ---"
if bash "${CONFIG_ROOT}/check-setup-completo.sh"; then
    info "Verificación del setup: OK"
else
    aviso "La verificación reportó incidencias (revisa arriba)"
    FALLOS=$((FALLOS+1))
fi

# Sincronizar la copia canónica para dejarla coherente
bash "${MIMO_CONFIG_DIR}/sync-mimocode.sh" >/dev/null 2>&1 || true

echo ""
echo "=============================================="
if [ "$FALLOS" -eq 0 ]; then
    echo -e "${VERDE}  INSTALACIÓN COMPLETA SIN INCIDENCIAS${NC}"
else
    echo -e "${AMARILLO}  INSTALACIÓN COMPLETADA CON ${FALLOS} AVISO(S)${NC}"
fi
echo "=============================================="
echo ""
echo "Para iniciar MiMoCode:"
echo "  mimo          # global (agente nvidia)"
echo "  mimo-local    # perfil local (Qwen)"
echo "  mimo-cloud    # perfil cloud (sin LM Studio)"
echo ""
echo "Configuración en: ${MIMO_CONFIG_DIR}"
echo "Copia canónica:   ${CONFIG_ROOT}/sesion-mimocode/config"
echo "Backup:           bash ${CONFIG_ROOT}/backup-mimocode.sh"
echo ""
echo "Atajos de voz en la TUI:  Ctrl+R (STT)  ·  Ctrl+Q (parar TTS)  ·  /voice"
echo ""
