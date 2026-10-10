#!/usr/bin/env bash
# backup-hermes.sh — Backup de Hermes Agent (configuración, datos, skills y credenciales)
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
for s in backup-hermes.sh sync-hermes.sh check-setup-completo.sh bootstrap-hermes.sh \
         hermes-modelos-viables.sh hermes-modelos-viables.py hermes-parche-ctrlq.sh \
         lm-studio-watchdog.sh hermes-nvidia-aliases.sh hermes-nvidia-aliases.py \
         hermes-auditoria-manual.sh hermes-auditoria-manual.py \
         lm-studio-gui.sh lm-studio-gui-run.sh; do
    if [ -f "${BACKUP_BASE}/${s}" ]; then
        cp -p "${BACKUP_BASE}/${s}" "${SESION_DIR}/${s}"
    fi
done
# Documento de reglas del esquema (vive en la raíz de Config/hermes, no en ~/.hermes)
if [ -f "${BACKUP_BASE}/AGENTS.md" ]; then
    cp -p "${BACKUP_BASE}/AGENTS.md" "${SESION_DIR}/AGENTS.md"
fi
# Copia de respaldo legible de la documentación de configuración
# (documentos/ = copias; el original de cada uno sigue en su ruta de siempre)
DOCS_DIR="${BACKUP_BASE}/documentos"
mkdir -p "${DOCS_DIR}"
for f in AGENTS.md SISTEMA-CACHYOS.md; do
    if [ -f "${BACKUP_BASE}/${f}" ]; then
        cp -p "${BACKUP_BASE}/${f}" "${DOCS_DIR}/${f}"
    fi
done
if [ -f "${HERMES_ACTIVO}/SOUL.md" ]; then
    cp -p "${HERMES_ACTIVO}/SOUL.md" "${DOCS_DIR}/SOUL.md"
fi
if [ -d "${BACKUP_BASE}/dual-boot/windows" ]; then
    mkdir -p "${DOCS_DIR}/dual-boot"
    rsync -a --delete --include='*/' --include='*.md' --exclude='*' \
          "${BACKUP_BASE}/dual-boot/windows/" "${DOCS_DIR}/dual-boot/"
fi
echo "   📄 documentos/ actualizado (copia de la documentación de configuración)"
# Scripts del esquema dual boot (Linux ↔ Windows)
if [ -d "${BACKUP_BASE}/dual-boot" ]; then
    rsync -a --delete "${BACKUP_BASE}/dual-boot/" "${SESION_DIR}/dual-boot/"
fi
# Herramientas del esquema: parches locales del CLI y unidades systemd de usuario propias
for d in parches units; do
    if [ -d "${BACKUP_BASE}/${d}" ]; then
        rsync -a --delete "${BACKUP_BASE}/${d}/" "${SESION_DIR}/${d}/"
    fi
done
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
for x in kokoro-tts whisper-stt whisper-cli speak-kokoro speak-kokoro-gpu hermes-voz \
         hermes-ready-notify.sh; do
    if [ -f "$HOME/.local/bin/${x}" ]; then
        cp -p "$HOME/.local/bin/${x}" "${ROOT}/extras/bin/${x}"
        cp -p "$HOME/.local/bin/${x}" "${SESION_DIR}/extras/bin/${x}"
        EXTRAS=$((EXTRAS+1))
    fi
done
echo "   ✅ ${EXTRAS} scripts de ~/.local/bin incluidos (tarball + sesion-hermes)"

# ─── 5b. Herramientas del esquema (parche del CLI, unidades, utilidades) ───
# En el tarball van bajo esquema/ para que una restauración pueda reponer el parche
# local del CLI, las unidades systemd de usuario y los atajos de ~/.local/bin sin
# depender de que ~/Config/hermes siga existiendo.
mkdir -p "${ROOT}/esquema"
for s in backup-hermes.sh sync-hermes.sh check-setup-completo.sh bootstrap-hermes.sh \
         setup-hermes-completo.sh \
         hermes-parche-ctrlq.sh lm-studio-watchdog.sh hermes-nvidia-aliases.sh \
         hermes-nvidia-aliases.py hermes-modelos-viables.sh hermes-modelos-viables.py \
         hermes-auditoria-manual.sh hermes-auditoria-manual.py \
         lm-studio-gui.sh lm-studio-gui-run.sh instalar-stack-voz.sh \
         AGENTS.md; do
    if [ -f "${BACKUP_BASE}/${s}" ]; then
        cp -p "${BACKUP_BASE}/${s}" "${ROOT}/esquema/${s}"
    fi
done
# dual-boot va al tarball para que una restauración con SOLO el tarball reponga
# también sus unidades y scripts (el restore.sh enlaza ~/.local/bin/hermes-dual-sync).
for d in parches units dual-boot; do
    if [ -d "${BACKUP_BASE}/${d}" ]; then
        rsync -a "${BACKUP_BASE}/${d}/" "${ROOT}/esquema/${d}/"
    fi
done
echo "   ✅ esquema/ incluido (parche Ctrl+Q, unidades systemd, utilidades, dual-boot)"

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

# Configuración y datos (excluyendo el propio restore.sh, el instalador, las credenciales
# y esquema/, que va a ~/Config/hermes y se repone más abajo)
rsync -a --exclude='*-restore.sh' --exclude='setup-hermes-completo.sh' \
      --exclude='credenciales/' --exclude='extras/' --exclude='INFO.txt' \
      --exclude='esquema/' \
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

# Herramientas del esquema (esquema/ del tarball): parche local del CLI, unidades systemd
# de usuario y atajos. Sin esto, la restauración dejaría Hermes sin Ctrl+Q y sin sus
# servicios propios (LM Studio, alias NVIDIA, backup, aviso de arranque).
BASE_ESQUEMA="$HOME/Config/hermes"
if [ -d "${SOURCE_DIR}/esquema" ]; then
    mkdir -p "$BASE_ESQUEMA" "$LOCAL_BIN"
    rsync -a "${SOURCE_DIR}/esquema/" "$BASE_ESQUEMA/"
    chmod +x "$BASE_ESQUEMA"/*.sh 2>/dev/null || true
    ln -sfn "$BASE_ESQUEMA/dual-boot/hermes-dual-sync.sh" "$LOCAL_BIN/hermes-dual-sync"
    ln -sfn "$BASE_ESQUEMA/hermes-modelos-viables.sh" "$LOCAL_BIN/hermes-modelos-viables"
    ln -sfn "$BASE_ESQUEMA/hermes-auditoria-manual.sh" "$LOCAL_BIN/hermes-auditoria-manual"
    ln -sfn "$BASE_ESQUEMA/hermes-nvidia-aliases.sh" "$LOCAL_BIN/hermes-nvidia-aliases"
    ln -sfn "$BASE_ESQUEMA/hermes-parche-ctrlq.sh" "$LOCAL_BIN/hermes-parche-ctrlq"
    ln -sfn "$BASE_ESQUEMA/lm-studio-watchdog.sh" "$LOCAL_BIN/lm-studio-watchdog"
    ln -sfn "$BASE_ESQUEMA/lm-studio-gui.sh" "$LOCAL_BIN/lm-studio-gui"
    ln -sfn "$BASE_ESQUEMA/lm-studio-gui-run.sh" "$LOCAL_BIN/lm-studio-gui-run"
    echo "✅ Esquema restaurado en $BASE_ESQUEMA (atajos en $LOCAL_BIN)"

    if [ -d "${BASE_ESQUEMA}/units" ]; then
        mkdir -p "$HOME/.config/systemd/user"
        cp -f "${BASE_ESQUEMA}/units/"*.service "${BASE_ESQUEMA}/units/"*.timer \
              "${BASE_ESQUEMA}/units/"*.path "$HOME/.config/systemd/user/" 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
        echo "✅ Unidades systemd de usuario copiadas (revisa con: systemctl --user list-unit-files 'hermes*' 'lm-studio*')"
    fi

    # Parche local del CLI: Ctrl+Q corta la locución sin interrumpir el turno
    if [ -x "$LOCAL_BIN/hermes-parche-ctrlq" ] && [ -d "$DEST_HOME/hermes-agent/.git" ]; then
        if "$LOCAL_BIN/hermes-parche-ctrlq" aplicar; then
            echo "✅ Parche Ctrl+Q aplicado"
        else
            echo "⚠️  No se pudo aplicar el parche Ctrl+Q: revisa '$LOCAL_BIN/hermes-parche-ctrlq estado'"
        fi
    else
        echo "⚠️  Parche Ctrl+Q sin aplicar (falta el repo en $DEST_HOME/hermes-agent o el aplicador)"
    fi
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
echo "🔎 Comprobando el parche del CLI..."
if [ -x "$LOCAL_BIN/hermes-parche-ctrlq" ]; then
    "$LOCAL_BIN/hermes-parche-ctrlq" estado || true
fi

echo ""
if [ "$FALTA" -eq 0 ]; then
    echo "✅ Restauración completada en $DEST_HOME"
    echo "   1. 'hermes doctor' para validar el entorno."
    echo "   2. Reinicia Hermes: el parche de Ctrl+Q no entra en sesiones ya abiertas."
    echo "   3. Habilita los servicios que necesites:"
    echo "      systemctl --user enable --now hermes-sync.timer lm-studio-watchdog.timer hermes-nvidia-aliases.path"
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
      --exclude='logs/' \
      --exclude='SISTEMA-CACHYOS.md' \
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
