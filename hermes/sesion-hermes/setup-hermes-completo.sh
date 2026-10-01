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
#       bash setup-hermes-completo.sh --sin-externos   (solo configuración+esquema:
#            no instala el stack de voz ni toca el dock; útil en equipos sin NVIDIA
#            o para probar el instalador sin descargas)
#       bash setup-hermes-completo.sh --con-modelos    (además descarga los ~21 GB de
#            modelos de LM Studio sin preguntar)
#
# ⚠️  ÚNICA COPIA EN DISCO: vive SOLO en ~/Config/hermes/sesion-hermes/.
#     En la raíz de ~/Config/hermes/ hay un enlace simbólico para tenerlo a mano.
set -euo pipefail

SIN_EXTERNOS=0
CON_MODELOS=0
for arg in "$@"; do
    case "$arg" in
        --sin-externos) SIN_EXTERNOS=1 ;;
        --con-modelos)  CON_MODELOS=1 ;;
    esac
done

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
# Dependencias del sistema que necesitan el stack de voz local y los modelos en LM Studio
# (no viajan en el tarball porque son paquetes del sistema, no configuración).
FALTAN_SISTEMA=""
for c in python3.13 cmake nvcc ffmpeg sox node lms; do
    if command -v "$c" >/dev/null 2>&1; then
        ok "$c disponible"
    else
        aviso "$c no encontrado"
        FALTAN_SISTEMA="${FALTAN_SISTEMA}${FALTAN_SISTEMA:+, }$c"
    fi
done
if [ -n "$FALTAN_SISTEMA" ]; then
    echo "   → faltan: ${FALTAN_SISTEMA}"
    echo "     instálalos antes de continuar (Arch/CachyOS):"
    echo "       sudo pacman -S --needed python313 cmake cuda ffmpeg sox nodejs"
    echo "       yay -S lmstudio-bin        # LM Studio (alias local/local-qwen35/local-gemma)"
fi
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
for x in kokoro-tts whisper-stt whisper-cli speak-kokoro speak-kokoro-gpu hermes-voz \
         hermes-ready-notify.sh; do
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
for s in backup-hermes.sh sync-hermes.sh check-setup-completo.sh bootstrap-hermes.sh \
         hermes-modelos-viables.sh hermes-modelos-viables.py hermes-parche-ctrlq.sh \
         lm-studio-watchdog.sh hermes-nvidia-aliases.sh hermes-nvidia-aliases.py \
         lm-studio-gui.sh lm-studio-gui-run.sh instalar-stack-voz.sh; do
    if [ -f "${SESION_DIR}/${s}" ]; then
        cp -p "${SESION_DIR}/${s}" "${BACKUP_BASE}/${s}"
        chmod +x "${BACKUP_BASE}/${s}"
    fi
done
# Documento de reglas del esquema (no es ejecutable)
if [ -f "${SESION_DIR}/AGENTS.md" ]; then
    cp -p "${SESION_DIR}/AGENTS.md" "${BACKUP_BASE}/AGENTS.md"
    chmod 644 "${BACKUP_BASE}/AGENTS.md" 2>/dev/null || true
fi
# Parches locales del CLI y unidades systemd propias
for d in parches units; do
    if [ -d "${SESION_DIR}/${d}" ]; then
        rsync -a "${SESION_DIR}/${d}/" "${BACKUP_BASE}/${d}/"
    fi
done

# Esquema de dual boot (Linux ↔ Windows) y su atajo en ~/.local/bin
# Fuente: sesion-hermes/ si está (respaldo canónico) o, si solo hay tarball, el
# dual-boot que el restore.sh ya ha repuesto en ${BACKUP_BASE}/dual-boot.
FUENTE_DUAL="${BACKUP_BASE}/dual-boot"
if [ -d "${SESION_DIR}/dual-boot" ]; then FUENTE_DUAL="${SESION_DIR}/dual-boot"; fi
if [ -d "${FUENTE_DUAL}" ]; then
    mkdir -p "${BACKUP_BASE}/dual-boot"
    rsync -a "${FUENTE_DUAL}/" "${BACKUP_BASE}/dual-boot/"
    chmod +x "${BACKUP_BASE}/dual-boot/"*.sh 2>/dev/null || true
    mkdir -p "$LOCAL_BIN"
    if [ -f "${BACKUP_BASE}/dual-boot/hermes-dual-sync.sh" ]; then
        ln -sfn "${BACKUP_BASE}/dual-boot/hermes-dual-sync.sh" "$LOCAL_BIN/hermes-dual-sync"
    fi
    # Atajo del comprobador de modelos viables (LM Studio + NVIDIA)
    if [ -f "${BACKUP_BASE}/hermes-modelos-viables.sh" ]; then
        ln -sfn "${BACKUP_BASE}/hermes-modelos-viables.sh" "$LOCAL_BIN/hermes-modelos-viables"
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

# ─── PASO 5b. Herramientas propias: atajos, unidades systemd y parche del CLI ───
paso "PASO 5b: atajos, unidades systemd y parche del CLI"
mkdir -p "$LOCAL_BIN"
ATAJOS=0
for par in "hermes-dual-sync:dual-boot/hermes-dual-sync.sh" \
           "hermes-modelos-viables:hermes-modelos-viables.sh" \
           "hermes-nvidia-aliases:hermes-nvidia-aliases.sh" \
           "hermes-parche-ctrlq:hermes-parche-ctrlq.sh" \
           "lm-studio-watchdog:lm-studio-watchdog.sh" \
           "lm-studio-gui:lm-studio-gui.sh" \
           "lm-studio-gui-run:lm-studio-gui-run.sh"; do
    enlace="${par%%:*}"; destino="${par#*:}"
    if [ -f "${BACKUP_BASE}/${destino}" ]; then
        ln -sfn "${BACKUP_BASE}/${destino}" "$LOCAL_BIN/${enlace}"
        ATAJOS=$((ATAJOS+1))
    fi
done
if [ "$ATAJOS" -gt 0 ]; then
    ok "${ATAJOS} atajos en $LOCAL_BIN"
else
    aviso "sin atajos que crear (¿faltan los scripts en ${BACKUP_BASE}?)"
fi

# Unidades systemd de usuario propias: backup periódico, LM Studio (app + vigilante),
# alias NVIDIA y aviso de arranque por Telegram.
if [ -d "${BACKUP_BASE}/units" ]; then
    mkdir -p "$HOME/.config/systemd/user"
    cp -f "${BACKUP_BASE}/units/"*.service "${BACKUP_BASE}/units/"*.timer \
          "${BACKUP_BASE}/units/"*.path "$HOME/.config/systemd/user/" 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    for u in hermes-sync.timer hermes-ready-notify.service lm-studio-app.service \
             lm-studio-watchdog.timer hermes-nvidia-aliases.path; do
        if systemctl --user enable --now "$u" >/dev/null 2>&1; then
            ok "unidad habilitada: $u"
        else
            aviso "no pude habilitar $u (¿existe en este equipo? revisa: systemctl --user status $u)"
        fi
    done
else
    aviso "sin unidades en ${BACKUP_BASE}/units/ (no se habilitan servicios propios)"
fi

# Parche local del CLI: Ctrl+Q corta la locución sin interrumpir el turno (Ctrl+C sí interrumpe)
if [ -x "$LOCAL_BIN/hermes-parche-ctrlq" ]; then
    if [ -d "${HERMES_ACTIVO}/hermes-agent/.git" ]; then
        if "$LOCAL_BIN/hermes-parche-ctrlq" aplicar >/dev/null 2>&1; then
            ok "parche Ctrl+Q aplicado (reinicia Hermes: no entra en sesiones ya abiertas)"
        else
            aviso "el parche Ctrl+Q no aplica limpio: revisa 'hermes-parche-ctrlq estado'"
        fi
    else
        aviso "parche Ctrl+Q pendiente: no hay repo de Hermes en ${HERMES_ACTIVO}/hermes-agent"
    fi
else
    aviso "falta el atajo hermes-parche-ctrlq: el parche Ctrl+Q no se aplica"
fi

# ─── PASO 5c. Dependencias externas: stack de voz local y modelos de LM Studio ───
if [ "$SIN_EXTERNOS" -eq 1 ]; then
    aviso "stack de voz y LM Studio omitidos (--sin-externos)"
else
    # El tarball lleva los scripts adaptadores (kokoro-tts, whisper-stt…), pero no sus
    # dependencias (~1,5 GB): venv de Kokoro + modelos y whisper.cpp con CUDA + modelo.
paso "PASO 5c: stack de voz local y modelos de LM Studio"
    if [ -x "${BACKUP_BASE}/instalar-stack-voz.sh" ]; then
        if bash "${BACKUP_BASE}/instalar-stack-voz.sh" --comprobar >/dev/null 2>&1; then
            ok "stack de voz local completo (Kokoro TTS + whisper.cpp)"
        else
            echo "   Faltan componentes del stack de voz: instalando (~1,5 GB y compilación CUDA; puede tardar)..."
            if bash "${BACKUP_BASE}/instalar-stack-voz.sh"; then
                ok "stack de voz instalado"
            else
                aviso "el stack de voz quedó incompleto: repite 'bash ${BACKUP_BASE}/instalar-stack-voz.sh'"
            fi
        fi
    else
        aviso "falta ${BACKUP_BASE}/instalar-stack-voz.sh: sin él, kokoro-tts/whisper-stt no funcionarán"
    fi

    # ── LM Studio: app (AUR), ajuste de contexto y modelos de los alias locales ──
    # Nada de esto cabe en el tarball: la app es un paquete AUR, los modelos ocupan ~21 GB
    # y defaultContextLength vive en ~/.lmstudio/settings.json (config de LM Studio).
    MODELOS_LM=("qwen3.8-9b@q6_k" "qwen3.5-9b@q6_k" "google/gemma-4-e4b@q4_k_m")

    # 1) La app
    if ! command -v lms >/dev/null 2>&1; then
        HELPER=""
        if command -v yay >/dev/null 2>&1; then HELPER="$(command -v yay)"
        elif command -v paru >/dev/null 2>&1; then HELPER="$(command -v paru)"; fi
        if [ -n "$HELPER" ]; then
            echo "   Instalando LM Studio desde AUR con $(basename "$HELPER")..."
            if "$HELPER" -S --noconfirm --needed lmstudio-bin; then
                ok "LM Studio instalado (lmstudio-bin)"
            else
                aviso "no se pudo instalar lmstudio-bin: hazlo a mano ('yay -S lmstudio-bin')"
            fi
        else
            aviso "LM Studio no instalado y sin helper AUR: instálalo con 'yay -S lmstudio-bin'"
        fi
    else
        ok "LM Studio instalado (lms en PATH)"
    fi

    # 2) Ventana de contexto por defecto >= 64k. Con el valor de fábrica (8192) Hermes
    #    rechaza el modelo local como principal y la cadena de respaldo cae al escalón previo.
    SET_LM="$HOME/.lmstudio/settings.json"
    if [ -f "$SET_LM" ]; then
        CONTEXTO="$(python3 -c "import json,sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception:
    print(0); raise SystemExit
v = d.get('defaultContextLength')
print((v.get('value') if isinstance(v, dict) else v) or 0)" "$SET_LM" 2>/dev/null || echo 0)"
        if [ "${CONTEXTO:-0}" -lt 65536 ] 2>/dev/null; then
            cp -p "$SET_LM" "$SET_LM.bak-$(date +%Y%m%d-%H%M%S)"
            if python3 -c "import json,sys
p = sys.argv[1]
d = json.load(open(p, encoding='utf-8'))
d['defaultContextLength'] = {'type': 'custom', 'value': 81920}
json.dump(d, open(p, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)" "$SET_LM"; then
                aviso "defaultContextLength ajustado a 81920 (reinicia LM Studio para que lo tome)"
            else
                aviso "no pude ajustar defaultContextLength en $SET_LM"
            fi
        else
            ok "defaultContextLength = ${CONTEXTO} (>= 65536)"
        fi
    else
        aviso "sin ~/.lmstudio/settings.json: arranca LM Studio una vez y repite este paso"
    fi

    # 3) Modelos de los alias locales (solo si faltan; con --con-modelos o confirmación)
    if command -v lms >/dev/null 2>&1; then
        FALTAN_LM=()
        LISTA_LM="$(lms ls 2>/dev/null || true)"
        for m in "${MODELOS_LM[@]}"; do
            nombre="${m%@*}"
            if printf '%s' "$LISTA_LM" | grep -qi -- "$nombre"; then
                ok "modelo ${nombre} presente"
            else
                FALTAN_LM+=("$m")
            fi
        done
        if [ "${#FALTAN_LM[@]}" -gt 0 ]; then
            DESCARGAR=0
            if [ "$CON_MODELOS" -eq 1 ]; then
                DESCARGAR=1
            elif [ -t 0 ]; then
                printf '   Faltan %d modelo(s) (~21 GB). ¿Descargarlos ahora? [s/N] ' "${#FALTAN_LM[@]}"
                read -r RESPUESTA_LM || RESPUESTA_LM=""
                case "$RESPUESTA_LM" in [sSyY]*) DESCARGAR=1 ;; esac
            fi
            if [ "$DESCARGAR" -eq 1 ]; then
                for m in "${FALTAN_LM[@]}"; do
                    echo "   Descargando ${m}..."
                    if lms get "$m" -y || lms get "${m%@*}" -y; then
                        ok "descargado ${m}"
                    else
                        aviso "no pude descargar ${m}: hazlo con 'lms get ${m%@*}' o desde la app"
                    fi
                done
            else
                aviso "sin descargar ${#FALTAN_LM[@]} modelo(s): usa --con-modelos o 'lms get <modelo>'"
            fi
        fi
    fi


fi

# ─── PASO 5d. Entrada ancla del dock de GNOME en XWayland (temporal) ───
if [ "$SIN_EXTERNOS" -eq 1 ]; then
    aviso "entrada del dock omitida (--sin-externos)"
else
    # Con NVIDIA propietario la ventana corre en XWayland (WM_CLASS "hermes"/"Hermes") y el
    # dock muestra dos iconos si el .desktop no declara StartupWMClass=Hermes. El parche
    # upstream está en revisión (PR #129373); hasta que entre, se crea la entrada a mano.
paso "PASO 5d: entrada ancla del dock (GNOME + XWayland)"
    if command -v gsettings >/dev/null 2>&1; then
        if [ -e /proc/driver/nvidia/version ] && [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
            APPS="$HOME/.local/share/applications"
            mkdir -p "$APPS"
            if [ -f "$APPS/hermes.desktop" ]; then
                ok "entrada hermes.desktop ya presente"
            else
                cat > "$APPS/hermes.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Hermes
Comment=Hermes Agent (Nous Research)
Exec=${HOME}/.local/bin/hermes desktop --skip-build
Icon=hermes
Terminal=false
Categories=Development;Utility;
StartupWMClass=Hermes
EOF
                ok "creada ~/.local/share/applications/hermes.desktop (agrupa la ventana XWayland)"
            fi
            if [ -f "$APPS/com.nousresearch.hermes.desktop" ] && ! grep -q "NoDisplay=true" "$APPS/com.nousresearch.hermes.desktop"; then
                if grep -q "NoDisplay" "$APPS/com.nousresearch.hermes.desktop"; then
                    sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$APPS/com.nousresearch.hermes.desktop"
                else
                    printf '\nNoDisplay=true\n' >> "$APPS/com.nousresearch.hermes.desktop"
                fi
                ok "entrada por app-id ocultada (evita el segundo icono genérico)"
            fi
            ACTUAL="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || true)"
            case "$ACTUAL" in
                *"com.nousresearch.hermes.desktop"*)
                    NUEVO="$(printf '%s' "$ACTUAL" | sed "s/'com\.nousresearch\.hermes\.desktop'/'hermes.desktop'/")"
                    if gsettings set org.gnome.shell favorite-apps "$NUEVO" 2>/dev/null; then
                        ok "dock: ancla sustituida por hermes.desktop"
                    else
                        aviso "no pude actualizar el ancla del dock (hazlo a mano desde el dock)"
                    fi
                    ;;
                *"hermes.desktop"*) ok "dock: ya anclado hermes.desktop" ;;
                *) aviso "Hermes no está anclado en el dock (ánclalo desde la vista de aplicaciones)" ;;
            esac
        else
            ok "no aplica: sesión sin NVIDIA/XWayland (el dock no necesita la entrada ancla)"
        fi
    else
        aviso "sin gsettings (¿entorno no GNOME?): se omite el ajuste del dock"
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
echo -n "   Parche Ctrl+Q: "
if [ -x "$LOCAL_BIN/hermes-parche-ctrlq" ]; then
    "$LOCAL_BIN/hermes-parche-ctrlq" estado 2>/dev/null || echo "(pendiente)"
else
    echo "(sin aplicador)"
fi
echo "   Servicios propios: systemctl --user list-unit-files 'hermes*' 'lm-studio*'"
echo -n "   Stack de voz (Kokoro + whisper.cpp): "
if [ -x "${BACKUP_BASE}/instalar-stack-voz.sh" ] && bash "${BACKUP_BASE}/instalar-stack-voz.sh" --comprobar >/dev/null 2>&1; then
    echo "completo"
else
    echo "INCOMPLETO → bash ${BACKUP_BASE}/instalar-stack-voz.sh"
fi
echo -n "   LM Studio (alias local/local-qwen35/local-gemma): "
if command -v lms >/dev/null 2>&1; then echo "instalado"; else echo "NO instalado"; fi
echo -n "   Entrada del dock (XWayland): "
if [ -f "$HOME/.local/share/applications/hermes.desktop" ]; then echo "presente"; else echo "ausente (solo afecta a GNOME con NVIDIA)"; fi

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
