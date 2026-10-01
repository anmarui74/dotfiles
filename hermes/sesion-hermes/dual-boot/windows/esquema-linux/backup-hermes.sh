#!/usr/bin/env bash
# backup-hermes.sh — Backup de Hermes Agent (esquema equivalente al de OpenCode)
# Genera tarball con restore.sh dentro; respaldo canónico en sesion-hermes/.
# Puntos del esquema (ver ~/Config/hermes/AGENTS.md):
#   - ~/.hermes/ es la configuración ACTIVA
#   - ~/Config/hermes/ es la copia de SEGURIDAD (instalación desde limpio)
#   - ~/Config/hermes/backups/hermes/ → tarballs hermes-backup-*.tar.gz
#   - ~/Config/hermes/sesion-hermes/ → respaldo canónico + instalador desde limpio
#   - Credenciales (.env, auth.json) dentro del tarball con permisos 600
#   - Copia saneada en ~/Documentos/dotfiles/hermes/ SIN claves de API
set -euo pipefail

HERMES_ACTIVO="${HERMES_HOME:-$HOME/.hermes}"
BACKUP_BASE="$HOME/Config/hermes"
BACKUP_DIR="$BACKUP_BASE/backups/hermes"
SESION_DIR="$BACKUP_BASE/sesion-hermes"
DOTFILES_DIR="$HOME/Documentos/dotfiles"
DOTFILES_HERMES="$DOTFILES_DIR/hermes"
DATE="$(date +%Y%m%d-%H%M%S)"
NAME="hermes-backup-${DATE}"
ROOT="${BACKUP_DIR}/${NAME}"
RETENTION_DAYS="${LOG_RETENTION_DAYS:-30}"

echo "=== Backup Hermes Agent - $(date '+%d/%m/%Y %H:%M') ==="

# ─── 0. VERIFICACIÓN OBLIGATORIA (si falla, se ABORTA el backup) ───
if [ -f "$BACKUP_BASE/check-setup-completo.sh" ]; then
    echo "🔍 Verificando setup (check-setup-completo.sh)..."
    if bash "$BACKUP_BASE/check-setup-completo.sh"; then
        echo "✅ Setup verificado. Continuando backup..."
    else
        echo ""
        echo "❌❌❌ VERIFICACIÓN DEL SETUP FALLIDA ❌❌❌"
        echo "   El esquema de backup no está correcto/completo."
        echo "   Corrige el setup ANTES del backup (ver ~/Config/hermes/AGENTS.md)."
        echo "   Backup ABORTADO para no guardar un setup defectuoso."
        exit 1
    fi
else
    echo "⚠️  check-setup-completo.sh no encontrado en ${BACKUP_BASE}"
fi

mkdir -p "${BACKUP_DIR}" "${ROOT}"
chmod 700 "${BACKUP_DIR}" 2>/dev/null || true

# ─── 1. Refrescar respaldo canónico (sesion-hermes) ───
echo "🔄 Refrescando respaldo canónico en sesion-hermes/..."
mkdir -p "${SESION_DIR}"
chmod 700 "${SESION_DIR}" 2>/dev/null || true
for f in config.yaml .env auth.json SOUL.md; do
    if [ -f "${HERMES_ACTIVO}/${f}" ]; then
        cp -p "${HERMES_ACTIVO}/${f}" "${SESION_DIR}/${f}"
    fi
done
for s in backup-hermes.sh sync-hermes.sh check-setup-completo.sh bootstrap-hermes.sh; do
    if [ -f "${BACKUP_BASE}/${s}" ]; then
        cp -p "${BACKUP_BASE}/${s}" "${SESION_DIR}/${s}"
    fi
done
# Scripts del esquema dual boot (Linux ↔ Windows)
if [ -d "${BACKUP_BASE}/dual-boot" ]; then
    rsync -a --delete "${BACKUP_BASE}/dual-boot/" "${SESION_DIR}/dual-boot/"
fi
find "${SESION_DIR}" -maxdepth 1 -type f \( -name '.env' -o -name 'auth.json' \) -exec chmod 600 {} + 2>/dev/null || true

# ─── 2. Archivos sueltos de configuración ───
echo "📦 Copiando configuración desde ${HERMES_ACTIVO}/..."
for f in config.yaml SOUL.md install_id channel_directory.json shell-hooks-allowlist.json; do
    if [ -f "${HERMES_ACTIVO}/${f}" ]; then
        cp -p "${HERMES_ACTIVO}/${f}" "${ROOT}/${f}"
    fi
done

# ─── 3. Directorios de datos (whitelist: solo datos/config, nunca binarios) ───
# Excluido a propósito: cache/, installs/, tools/, hermes-agent/ (clon git, ~3 GB),
# state.db + sessions/ (histórico de conversaciones), logs/, imagen y audio cache,
# runtime/, sandboxes/, terminal-sessions/, clones temporales.
for d in skills plugins memories hooks agent-hooks skins tui-widgets desktop-plugins pets; do
    if [ -d "${HERMES_ACTIVO}/${d}" ]; then
        rsync -a --delete --exclude='*.lock' --exclude='*.sock' --exclude='*.pid' \
              --exclude='__pycache__/' --exclude='*.pyc' \
              "${HERMES_ACTIVO}/${d}/" "${ROOT}/${d}/"
    fi
done

# Credencial del Portal Nous (access/refresh token) — se respalda, pero NO va a dotfiles
if [ -d "${HERMES_ACTIVO}/shared" ]; then
    rsync -a --exclude='*.lock' "${HERMES_ACTIVO}/shared/" "${ROOT}/shared/"
    echo "   ✅ shared/ (auth del Portal Nous) incluido"
fi

# Trabajos programados (sin la BD de ejecuciones, que es runtime)
if [ -d "${HERMES_ACTIVO}/cron" ]; then
    rsync -a --delete --exclude='executions.db' --exclude='*.lock' --exclude='*.sock' \
          --exclude='ticker_*' "${HERMES_ACTIVO}/cron/" "${ROOT}/cron/"
fi

# Tablero kanban (datos, no runtime): copia consistente si hay sqlite3
if [ -f "${HERMES_ACTIVO}/kanban.db" ]; then
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "${HERMES_ACTIVO}/kanban.db" ".backup '${ROOT}/kanban.db'"
    else
        cp -p "${HERMES_ACTIVO}/kanban.db" "${ROOT}/kanban.db"
    fi
    echo "   ✅ kanban.db incluido"
fi

# ─── 4. Credenciales (auth.json + .env) — van SOLO en el tarball, permisos 600 ───
mkdir -p "${ROOT}/credenciales"
chmod 700 "${ROOT}/credenciales"
for c in .env auth.json; do
    if [ -f "${HERMES_ACTIVO}/${c}" ]; then
        cp -p "${HERMES_ACTIVO}/${c}" "${ROOT}/credenciales/${c}"
        chmod 600 "${ROOT}/credenciales/${c}"
        echo "   ✅ credenciales/${c} incluido"
    else
        echo "   ⚠️  ${HERMES_ACTIVO}/${c} no encontrado"
    fi
done

# ─── 5. Extras fuera de ~/.hermes (stack de voz local) ───
mkdir -p "${ROOT}/extras/bin" "${SESION_DIR}/extras/bin"
EXTRAS=0
for x in kokoro-tts whisper-stt whisper-cli speak-kokoro speak-kokoro-gpu hermes-voz; do
    if [ -f "$HOME/.local/bin/${x}" ]; then
        cp -p "$HOME/.local/bin/${x}" "${ROOT}/extras/bin/${x}"
        cp -p "$HOME/.local/bin/${x}" "${SESION_DIR}/extras/bin/${x}"
        EXTRAS=$((EXTRAS+1))
    fi
done
echo "   ✅ ${EXTRAS} scripts de ~/.local/bin incluidos (tarball + sesion-hermes)"

# ─── 6. INFO.txt (trazabilidad del contenido y de la versión) ───
{
    echo "Backup: ${NAME}"
    echo "Fecha:  $(date '+%d/%m/%Y %H:%M:%S')"
    echo "HERMES_HOME: ${HERMES_ACTIVO}"
    hermes --version 2>/dev/null | head -3 || true
    echo ""
    echo "Contenido (nivel raíz):"
    ( cd "${ROOT}" && find . -maxdepth 1 -mindepth 1 | sort )
} > "${ROOT}/INFO.txt"

# ─── 7. Generar restore.sh dentro del backup ───
echo "🔧 Creando restore.sh..."
cat > "${ROOT}/${NAME}-restore.sh" << 'RESTORE_EOF'
#!/usr/bin/env bash
# Restaurar Hermes Agent desde backup - generado por backup-hermes.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}"
DEST_HOME="${HERMES_HOME:-$HOME/.hermes}"
LOCAL_BIN="$HOME/.local/bin"

echo "=== Restaurando Hermes Agent ==="
echo "Fuente:  $SOURCE_DIR"
echo "Destino: $DEST_HOME"
echo ""

if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ ERROR: directorio de backup no encontrado: $SOURCE_DIR"
    exit 1
fi

mkdir -p "$DEST_HOME"

# Configuración y datos (excluyendo el propio restore.sh, el instalador y las credenciales)
rsync -a --exclude='*-restore.sh' --exclude='setup-hermes-completo.sh' \
      --exclude='credenciales/' --exclude='extras/' --exclude='INFO.txt' \
      "$SOURCE_DIR/" "$DEST_HOME/."

# Credenciales a su ubicación original, con permisos 600
if [ -f "${SOURCE_DIR}/credenciales/.env" ]; then
    cp "${SOURCE_DIR}/credenciales/.env" "$DEST_HOME/.env"
    chmod 600 "$DEST_HOME/.env"
    echo "✅ .env restaurado en $DEST_HOME/"
fi
if [ -f "${SOURCE_DIR}/credenciales/auth.json" ]; then
    cp "${SOURCE_DIR}/credenciales/auth.json" "$DEST_HOME/auth.json"
    chmod 600 "$DEST_HOME/auth.json"
    echo "✅ auth.json restaurado en $DEST_HOME/"
fi

# Scripts extra (voz local) a ~/.local/bin
if [ -d "${SOURCE_DIR}/extras/bin" ]; then
    mkdir -p "$LOCAL_BIN"
    cp -f "${SOURCE_DIR}/extras/bin/"* "$LOCAL_BIN/" 2>/dev/null || true
    chmod +x "$LOCAL_BIN/"* 2>/dev/null || true
    echo "✅ Scripts de voz restaurados en $LOCAL_BIN/"
fi

echo ""
echo "🔎 Verificando archivos críticos..."
FALTA=0
for f in config.yaml .env auth.json SOUL.md memories/MEMORY.md; do
    if [ -e "$DEST_HOME/$f" ]; then
        echo "   ✅ $f"
    else
        echo "   ⚠️  falta $f"
        FALTA=1
    fi
done

echo ""
if [ "$FALTA" -eq 0 ]; then
    echo "✅ Restauración completada en $DEST_HOME"
    echo "   Siguiente paso: 'hermes doctor' para validar el entorno."
else
    echo "⚠️  Restauración incompleta: revisa los avisos de arriba."
fi
RESTORE_EOF

chmod +x "${ROOT}/${NAME}-restore.sh"
echo "   ✅ restore.sh creado"

# ─── 8. Copiar el instalador desde limpio (única copia en disco: sesion-hermes/) ───
if [ -f "${SESION_DIR}/setup-hermes-completo.sh" ]; then
    cp "${SESION_DIR}/setup-hermes-completo.sh" "${ROOT}/setup-hermes-completo.sh"
    echo "   ✅ setup-hermes-completo.sh incluido"
else
    echo "   ⚠️  setup-hermes-completo.sh no encontrado en sesion-hermes/"
fi

# ─── 9. Tarball (umask 077 + 600: dentro van las credenciales en claro) ───
echo ""
echo "📦 Creando tarball..."
( cd "${ROOT}" && umask 077 && tar -czf "${BACKUP_DIR}/${NAME}.tar.gz" . )
chmod 600 "${BACKUP_DIR}/${NAME}.tar.gz" 2>/dev/null || true
BACKUP_SIZE="$(du -h "${BACKUP_DIR}/${NAME}.tar.gz" | cut -f1)"
echo "   ✅ Tarball creado (${BACKUP_SIZE}): ${BACKUP_DIR}/${NAME}.tar.gz"

# ─── 10. Limpiar directorio temporal ───
rm -rf "${ROOT}"

# ─── 11. Retención: borrar tarballs de más de N días (LOG_RETENTION_DAYS, 30 por defecto) ───
echo ""
echo "🧹 Aplicando retención (${RETENTION_DAYS} días)..."
OLD="$(find "${BACKUP_DIR}" -maxdepth 1 -name 'hermes-*.tar.gz' -mtime +"${RETENTION_DAYS}" 2>/dev/null | wc -l)"
if [ "${OLD}" -gt 0 ]; then
    find "${BACKUP_DIR}" -maxdepth 1 -name 'hermes-*.tar.gz' -mtime +"${RETENTION_DAYS}" -delete 2>/dev/null || true
    echo "   🗑️  ${OLD} tarballs antiguos eliminados"
else
    echo "   ✅ No hay tarballs antiguos que eliminar"
fi

# ─── 12. Poda: conservar solo el ÚLTIMO tarball de cada día ───
PODADOS=0
for f in "${BACKUP_DIR}"/hermes-backup-*.tar.gz; do
    [ -f "$f" ] || continue
    DAY="$(basename "$f" | grep -oE '[0-9]{8}' | head -1 || true)"
    [ -n "$DAY" ] || continue
    LAST="$(find "${BACKUP_DIR}" -maxdepth 1 -name "hermes-backup-${DAY}-*.tar.gz" 2>/dev/null | sort | tail -1)"
    if [ -n "$LAST" ] && [ "$f" != "$LAST" ]; then
        rm -f "$f"
        PODADOS=$((PODADOS+1))
    fi
done
echo "   🗂️  ${PODADOS} duplicados del mismo día eliminados"

# ─── 13. Copia en dotfiles (SIN claves de API) ───
if [ -d "${DOTFILES_DIR}" ]; then
    echo ""
    echo "🔐 Sincronizando copia en dotfiles (SIN claves de API)..."
    mkdir -p "${DOTFILES_HERMES}"
    rsync -a --delete --delete-excluded \
      --exclude='backups/' \
      --exclude='credenciales/' \
      --exclude='shared/' \
      --exclude='.env' --exclude='*.env' \
      --exclude='auth.json' \
      --exclude='*.tar.gz' \
      --exclude='*-restore.sh' \
      --exclude='__pycache__/' --exclude='*.pyc' \
      --exclude='*.lock' \
      "${BACKUP_BASE}/" "${DOTFILES_HERMES}/"

    # Purgar cualquier resto con credenciales
    find "${DOTFILES_HERMES}" \( -name '*.tar.gz' -o -name '.env' -o -name 'auth.json' \) -delete 2>/dev/null || true
    rm -rf "${DOTFILES_HERMES}/credenciales" "${DOTFILES_HERMES}/shared" 2>/dev/null || true

    # Verificación: la copia de dotfiles NO debe contener ninguna clave
    if grep -rIlP --exclude='*.md' \
         '(nvapi-|oc_sk_)[A-Za-z0-9_-]{15,}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{25,}|AEMET_API_KEY=[A-Za-z0-9]{15,}|NVIDIA_API_KEY=[A-Za-z0-9_-]{15,}|OPENCODE_GO_API_KEY=[A-Za-z0-9_-]{15,}' \
         "${DOTFILES_HERMES}" 2>/dev/null | grep -q .; then
        echo "   ⚠️  ATENCIÓN: posibles claves en la copia de dotfiles. Revisar antes de commitear."
    else
        echo "   ✅ Copia en dotfiles libre de claves de API"
    fi
fi

echo ""
echo "✅ Backup completado."
echo "   Ubicación: ${BACKUP_DIR}/${NAME}.tar.gz"
echo "   Para restaurar:"
echo "     1. mkdir -p /tmp/restore-hermes && tar -xzf ${BACKUP_DIR}/${NAME}.tar.gz -C /tmp/restore-hermes"
echo "     2. bash /tmp/restore-hermes/${NAME}-restore.sh"
