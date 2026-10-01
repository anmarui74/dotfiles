#!/usr/bin/env bash
# setup-hermes-completo.sh — INSTALACIÓN DE HERMES DESDE LIMPIO
#
# Rehace el entorno de Hermes de Antonio desde cero: instala Hermes Agent,
# restaura la configuración (config.yaml, .env, auth.json, SOUL.md), los datos
# (skills, memories, cron, plugins, kanban) y los scripts del stack de voz local.
#
# Fuentes de restauración, en orden de preferencia:
#   1. Último tarball de ~/Config/hermes/backups/hermes/hermes-backup-*.tar.gz
#   2. Respaldo canónico ~/Config/hermes/sesion-hermes/ (si no hay tarball)
#
# Uso:  bash ~/Config/hermes/setup-hermes-completo.sh
#       bash ~/Config/hermes/sesion-hermes/setup-hermes-completo.sh
#
# ⚠️  ÚNICA COPIA EN DISCO: vive SOLO en ~/Config/hermes/sesion-hermes/.
#     En la raíz de ~/Config/hermes/ hay un enlace simbólico para tenerlo a mano.
set -euo pipefail

HERMES_ACTIVO="${HERMES_HOME:-$HOME/.hermes}"
BACKUP_BASE="$HOME/Config/hermes"
SESION_DIR="${BACKUP_BASE}/sesion-hermes"
BACKUP_DIR="${BACKUP_BASE}/backups/hermes"
LOCAL_BIN="$HOME/.local/bin"
TMP_RESTORE="/tmp/restore-hermes-setup"
FALLOS=0

paso()  { echo ""; echo "── $* ─────────────────────────────────────"; }
ok()    { echo "   ✅ $*"; }
aviso() { echo "   ⚠️  $*"; }
mal()   { echo "   ❌ $*"; FALLOS=$((FALLOS+1)); }

echo "==============================================="
echo " INSTALACIÓN DE HERMES DESDE LIMPIO (Antonio)"
echo " Fecha: $(date '+%d/%m/%Y %H:%M')"
echo "==============================================="

# ─── PASO 1. Comprobar el sistema ───
paso "PASO 1: comprobación del sistema"
for c in bash tar rsync curl sqlite3; do
    if command -v "$c" >/dev/null 2>&1; then ok "$c disponible"; else aviso "$c no encontrado (puede ser necesario)"; fi
done
if command -v hermes >/dev/null 2>&1; then
    ok "Hermes ya instalado: $(hermes --version 2>/dev/null | head -1)"
else
    aviso "Hermes no está instalado todavía"
fi

# ─── PASO 2. Instalar Hermes Agent si falta ───
paso "PASO 2: instalación de Hermes Agent"
if command -v hermes >/dev/null 2>&1; then
    ok "Se omite la instalación (ya está presente)"
    echo "   Para forzar la actualización: hermes update"
else
    echo "   Instalando con el instalador oficial..."
    if curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash; then
        ok "Hermes instalado"
    else
        mal "Fallo al instalar Hermes: instálalo a mano y vuelve a ejecutar este script"
        echo ""
        echo "❌ Instalación abortada."
        exit 1
    fi
fi

# ─── PASO 3. Localizar la fuente de restauración ───
paso "PASO 3: localización de la copia de seguridad"
TARBALL=""
if [ -d "$BACKUP_DIR" ]; then
    TARBALL="$(find "$BACKUP_DIR" -maxdepth 1 -name 'hermes-backup-*.tar.gz' 2>/dev/null | sort | tail -1)"
fi

if [ -n "$TARBALL" ] && [ -f "$TARBALL" ]; then
    ok "Tarball encontrado: $TARBALL ($(du -h "$TARBALL" | cut -f1))"
else
    aviso "No hay tarball en $BACKUP_DIR"
    if [ -d "$SESION_DIR" ]; then
        aviso "Se restaurará solo el respaldo canónico de sesion-hermes/"
    else
        mal "No hay NINGUNA copia de seguridad en $BACKUP_BASE. Nada que restaurar."
        echo ""
        echo "❌ Abortado: no hay fuentes de restauración."
        exit 1
    fi
fi

# ─── PASO 4. Extraer y restaurar el tarball ───
paso "PASO 4: restauración de configuración y datos"
mkdir -p "$HERMES_ACTIVO"
if [ -n "$TARBALL" ] && [ -f "$TARBALL" ]; then
    rm -rf "$TMP_RESTORE"
    mkdir -p "$TMP_RESTORE"
    if tar -xzf "$TARBALL" -C "$TMP_RESTORE"; then
        ok "Tarball extraído en $TMP_RESTORE"
    else
        mal "No se pudo extraer el tarball"
        exit 1
    fi

    RESTORE_SH="$(find "$TMP_RESTORE" -maxdepth 1 -name '*-restore.sh' | head -1)"
    if [ -n "$RESTORE_SH" ]; then
        echo "   Ejecutando $(basename "$RESTORE_SH")..."
        if HERMES_HOME="$HERMES_ACTIVO" bash "$RESTORE_SH"; then
            ok "Restauración del tarball completada"
        else
            mal "El restore.sh devolvió error"
        fi
    else
        # Sin restore.sh: copia directa del contenido
        if rsync -a --exclude='*-restore.sh' --exclude='credenciales/' --exclude='extras/' \
              --exclude='INFO.txt' --exclude='setup-hermes-completo.sh' \
              "$TMP_RESTORE/" "$HERMES_ACTIVO/."; then
            ok "Contenido copiado a $HERMES_ACTIVO"
        else
            mal "Fallo al copiar el contenido"
        fi
        for c in .env auth.json; do
            if [ -f "$TMP_RESTORE/credenciales/$c" ]; then
                cp "$TMP_RESTORE/credenciales/$c" "$HERMES_ACTIVO/$c"
                chmod 600 "$HERMES_ACTIVO/$c"
                ok "credenciales/$c restaurado"
            fi
        done
        if [ -d "$TMP_RESTORE/extras/bin" ]; then
            mkdir -p "$LOCAL_BIN"
            cp -f "$TMP_RESTORE/extras/bin/"* "$LOCAL_BIN/" 2>/dev/null || true
            chmod +x "$LOCAL_BIN/"* 2>/dev/null || true
            ok "scripts de voz restaurados en $LOCAL_BIN"
        fi
    fi
fi

# Complementar con el respaldo canónico (config.yaml, .env, auth.json, SOUL.md)
if [ -d "$SESION_DIR" ]; then
    for f in config.yaml .env auth.json SOUL.md; do
        if [ -f "${SESION_DIR}/${f}" ]; then
            cp -p "${SESION_DIR}/${f}" "${HERMES_ACTIVO}/${f}"
            ok "sesion-hermes/${f} → $HERMES_ACTIVO/"
        fi
    done
fi

# Permisos de credenciales
for f in .env auth.json; do
    [ -f "${HERMES_ACTIVO}/${f}" ] && chmod 600 "${HERMES_ACTIVO}/${f}"
done
mkdir -p "$SESION_DIR" && chmod 700 "$SESION_DIR" 2>/dev/null || true

# ─── PASO 5. Scripts extra del stack de voz ───
paso "PASO 5: scripts extra (~/.local/bin)"
mkdir -p "$LOCAL_BIN"
RESTAURADOS=0
for x in kokoro-tts whisper-stt whisper-cli speak-kokoro speak-kokoro-gpu hermes-voz; do
    if [ -f "${SESION_DIR}/extras/bin/${x}" ]; then
        cp -f "${SESION_DIR}/extras/bin/${x}" "$LOCAL_BIN/${x}"
        chmod +x "$LOCAL_BIN/${x}"
        RESTAURADOS=$((RESTAURADOS+1))
    fi
done
if [ "$RESTAURADOS" -gt 0 ]; then
    ok "${RESTAURADOS} scripts de voz restaurados desde sesion-hermes/extras/bin/"
else
    if [ -x "$LOCAL_BIN/kokoro-tts" ] && [ -x "$LOCAL_BIN/whisper-stt" ]; then
        ok "los scripts de voz ya están en $LOCAL_BIN"
    else
        aviso "sin scripts de voz ni copia en sesion-hermes/extras/bin/ (TTS/STT locales no funcionarán)"
    fi
fi

# Scripts del esquema de backup en su sitio
for s in backup-hermes.sh sync-hermes.sh check-setup-completo.sh bootstrap-hermes.sh; do
    if [ -f "${SESION_DIR}/${s}" ]; then
        cp -p "${SESION_DIR}/${s}" "${BACKUP_BASE}/${s}"
        chmod +x "${BACKUP_BASE}/${s}"
    fi
done

# Esquema de dual boot (Linux ↔ Windows) y su atajo en ~/.local/bin
if [ -d "${SESION_DIR}/dual-boot" ]; then
    mkdir -p "${BACKUP_BASE}/dual-boot"
    rsync -a "${SESION_DIR}/dual-boot/" "${BACKUP_BASE}/dual-boot/"
    chmod +x "${BACKUP_BASE}/dual-boot/"*.sh 2>/dev/null || true
    mkdir -p "$LOCAL_BIN"
    if [ -f "${BACKUP_BASE}/dual-boot/hermes-dual-sync.sh" ]; then
        ln -sfn "${BACKUP_BASE}/dual-boot/hermes-dual-sync.sh" "$LOCAL_BIN/hermes-dual-sync"
    fi
    ok "esquema de dual boot restaurado en ${BACKUP_BASE}/dual-boot/"

    # Unidades de usuario (publicar cada 10 min + importar al arrancar antes del gateway)
    if [ -d "${BACKUP_BASE}/dual-boot/systemd-user" ]; then
        mkdir -p "$HOME/.config/systemd/user"
        cp -f "${BACKUP_BASE}/dual-boot/systemd-user/"*.service \
              "${BACKUP_BASE}/dual-boot/systemd-user/"*.timer "$HOME/.config/systemd/user/" 2>/dev/null
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now hermes-dual-sync.timer 2>/dev/null || true
        systemctl --user enable hermes-dual-sync-import.service 2>/dev/null || true
        ok "unidades systemd de usuario del dual boot restauradas"
    fi

    # Hook de publicación al cerrar sesión (necesita entrada en la allowlist de hooks)
    HOOK="${HERMES_ACTIVO:-$HOME/.hermes}/agent-hooks/dual-sync-publicar.sh"
    if [ ! -f "$HOOK" ] && [ -f "${BACKUP_BASE}/dual-boot/hooks/dual-sync-publicar.sh" ]; then
        mkdir -p "$(dirname "$HOOK")"
        cp -p "${BACKUP_BASE}/dual-boot/hooks/dual-sync-publicar.sh" "$HOOK"
        chmod +x "$HOOK"
    fi
    if [ -f "$HOOK" ]; then
        ALLOW="${HERMES_ACTIVO:-$HOME/.hermes}/shell-hooks-allowlist.json"
        python3 - "$ALLOW" "$HOOK" <<'PY' 2>/dev/null || true
import json, os, sys, datetime
ruta, hook = sys.argv[1], sys.argv[2]
datos = {"approvals": []}
if os.path.exists(ruta):
    try:
        datos = json.load(open(ruta, encoding='utf-8'))
    except Exception:
        pass
if not any(a.get("command") == hook for a in datos.get("approvals", [])):
    datos.setdefault("approvals", []).append({
        "event": "on_session_end",
        "command": hook,
        "approved_at": datetime.datetime.now(datetime.timezone.utc).isoformat().replace('+00:00', 'Z'),
        "script_mtime_at_approval": datetime.datetime.fromtimestamp(
            os.path.getmtime(hook), datetime.timezone.utc).isoformat().replace('+00:00', 'Z'),
    })
    json.dump(datos, open(ruta, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
PY
        ok "hook de publicación del dual boot registrado"
    fi
fi

# ─── PASO 6. Verificación final ───
paso "PASO 6: verificación"
for f in config.yaml .env auth.json SOUL.md memories/MEMORY.md skills; do
    if [ -e "${HERMES_ACTIVO}/${f}" ]; then ok "$f"; else mal "falta $f en $HERMES_ACTIVO"; fi
done
if command -v hermes >/dev/null 2>&1; then
    echo ""
    echo "   Modelo configurado: $(hermes config get model.default 2>/dev/null || echo '(no legible)')"
    echo "   Perfil/HOME: ${HERMES_ACTIVO}"
fi

# ─── PASO 7. Limpieza ───
rm -rf "$TMP_RESTORE" 2>/dev/null || true

echo ""
echo "==============================================="
if [ "$FALLOS" -eq 0 ]; then
    echo " ✅ INSTALACIÓN COMPLETADA SIN FALLOS"
    echo ""
    echo " Siguientes pasos recomendados:"
    echo "   1. hermes doctor          → validar el entorno"
    echo "   2. hermes gateway start   → arrancar el gateway de mensajería"
    echo "   3. hermes sync status     → comprobar el sync de skills"
else
    echo " ⚠️  INSTALACIÓN COMPLETADA CON ${FALLOS} AVISOS/FALLOS"
    echo "    Revisa las líneas ❌ de arriba."
fi
echo "==============================================="
