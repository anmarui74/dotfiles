#!/usr/bin/env bash
# check-setup-completo.sh — Verificación automática del esquema de backup de Hermes
# Se ejecuta SIEMPRE al inicio de backup-hermes.sh: si falla, el backup se ABORTA.
#
# Comprueba:
#   1. Sintaxis (bash -n) de todos los scripts del esquema
#   2. shellcheck (si está instalado; solo errores, no avisos)
#   3. Que existe el instalador desde limpio (sesion-hermes/setup-hermes-completo.sh)
#   4. Que existe todo lo que el backup necesita copiar (config.yaml, .env, auth.json, SOUL.md)
#   5. Permisos correctos de las credenciales (600)
set -uo pipefail

BACKUP_BASE="$HOME/Config/hermes"
SESION_DIR="${BACKUP_BASE}/sesion-hermes"
HERMES_ACTIVO="${HERMES_HOME:-$HOME/.hermes}"
ERRORES=0

ok()   { echo "   ✅ $*"; }
fail() { echo "   ❌ $*"; ERRORES=$((ERRORES+1)); }
warn() { echo "   ⚠️  $*"; }

echo "── 1. Sintaxis de los scripts ──"
for s in backup-hermes.sh sync-hermes.sh check-setup-completo.sh bootstrap-hermes.sh \
         instalar-stack-voz.sh hermes-auditoria-manual.sh; do
    if [ -f "${BACKUP_BASE}/${s}" ]; then
        if bash -n "${BACKUP_BASE}/${s}" 2>/dev/null; then
            ok "${s}"
        else
            fail "${s}: error de sintaxis (bash -n)"
        fi
    else
        fail "${s}: no existe en ${BACKUP_BASE}/"
    fi
done
if [ -f "${SESION_DIR}/setup-hermes-completo.sh" ]; then
    if bash -n "${SESION_DIR}/setup-hermes-completo.sh" 2>/dev/null; then
        ok "sesion-hermes/setup-hermes-completo.sh"
    else
        fail "sesion-hermes/setup-hermes-completo.sh: error de sintaxis"
    fi
else
    fail "sesion-hermes/setup-hermes-completo.sh: NO EXISTE (instalador desde limpio)"
fi

echo "── 2. shellcheck ──"
if command -v shellcheck >/dev/null 2>&1; then
    for s in "${BACKUP_BASE}"/backup-hermes.sh "${BACKUP_BASE}"/sync-hermes.sh \
             "${BACKUP_BASE}"/bootstrap-hermes.sh "${SESION_DIR}"/setup-hermes-completo.sh; do
        [ -f "$s" ] || continue
        if out="$(shellcheck -S error "$s" 2>&1)" && [ -z "$out" ]; then
            ok "$(basename "$s") sin errores"
        else
            fail "$(basename "$s"): $(echo "$out" | head -3 | tr '\n' ' ')"
        fi
    done
else
    warn "shellcheck no instalado: se omite esta comprobación"
fi

echo "── 3. Estructura del esquema ──"
for d in "${BACKUP_BASE}" "${BACKUP_BASE}/backups/hermes" "${SESION_DIR}"; do
    if [ -d "$d" ]; then ok "existe ${d/#$HOME/~}"; else warn "falta ${d/#$HOME/~} (se creará en el backup)"; fi
done
if [ -f "${BACKUP_BASE}/AGENTS.md" ]; then ok "AGENTS.md (reglas del esquema)"; else warn "sin AGENTS.md en ${BACKUP_BASE/#$HOME/~}"; fi

echo "── 4. Origen a respaldar (${HERMES_ACTIVO}) ──"
for f in config.yaml .env auth.json SOUL.md; do
    if [ -f "${HERMES_ACTIVO}/${f}" ]; then ok "${f}"; else fail "${f} no existe en ${HERMES_ACTIVO}"; fi
done
for d in skills memories; do
    if [ -d "${HERMES_ACTIVO}/${d}" ]; then ok "${d}/"; else fail "${d}/ no existe en ${HERMES_ACTIVO}"; fi
done

echo "── 5. Permisos de las credenciales ──"
for f in .env auth.json; do
    p="${HERMES_ACTIVO}/${f}"
    [ -f "$p" ] || continue
    perm="$(stat -c '%a' "$p")"
    if [ "$perm" = "600" ]; then ok "${f} (600)"; else warn "${f} tiene permisos ${perm} (recomendado 600)"; fi
done
for f in "${SESION_DIR}/.env" "${SESION_DIR}/auth.json"; do
    [ -f "$f" ] || continue
    perm="$(stat -c '%a' "$f")"
    if [ "$perm" = "600" ]; then ok "sesion-hermes/$(basename "$f") (600)"; else fail "sesion-hermes/$(basename "$f") tiene permisos ${perm} (debe ser 600)"; fi
done

echo "── 6. Herramientas del esquema (parche, unidades systemd, atajos) ──"
for f in hermes-parche-ctrlq.sh lm-studio-watchdog.sh hermes-nvidia-aliases.sh \
         hermes-nvidia-aliases.py lm-studio-gui.sh lm-studio-gui-run.sh \
         hermes-auditoria-manual.sh hermes-auditoria-manual.py \
         instalar-stack-voz.sh \
         parches/ctrl-q-corta-audio.patch; do
    if [ -f "${BACKUP_BASE}/${f}" ]; then ok "${f}"; else fail "falta ${f} en ${BACKUP_BASE}/"; fi
done
for u in hermes-sync.timer hermes-sync.service hermes-ready-notify.service \
         lm-studio-app.service lm-studio-gui.service lm-studio-watchdog.timer \
         lm-studio-watchdog.service hermes-nvidia-aliases.path \
         hermes-nvidia-aliases.service; do
    if [ -f "${BACKUP_BASE}/units/${u}" ]; then ok "units/${u}"; else fail "falta units/${u} en ${BACKUP_BASE}/units/"; fi
done
for x in hermes-parche-ctrlq hermes-nvidia-aliases lm-studio-watchdog hermes-dual-sync \
         hermes-modelos-viables hermes-auditoria-manual lm-studio-gui lm-studio-gui-run; do
    if [ -e "$HOME/.local/bin/${x}" ]; then ok "atajo ~/.local/bin/${x}"; else fail "falta el atajo ~/.local/bin/${x}"; fi
done

echo "── 7. Parche local del CLI (Ctrl+Q corta la locución) ──"
if [ -x "$HOME/.local/bin/hermes-parche-ctrlq" ] && [ -d "${HERMES_ACTIVO}/hermes-agent/.git" ]; then
    if "$HOME/.local/bin/hermes-parche-ctrlq" estado >/dev/null 2>&1; then
        ok "parche Ctrl+Q aplicado"
    else
        warn "parche Ctrl+Q NO aplicado: ejecuta 'hermes-parche-ctrlq aplicar' (típico tras un 'hermes update')"
    fi
else
    warn "no puedo comprobar el parche Ctrl+Q (falta el repo en ${HERMES_ACTIVO}/hermes-agent o el aplicador)"
fi

echo "── 8. Requisitos externos al tarball (solo aviso: no bloquean el backup) ──"
# Estas piezas no viajan en el tarball (peso en disco), pero sin ellas la config
# restaurada no funciona del todo. Se reponen con instalar-stack-voz.sh y con
# los paquetes del sistema; aquí solo se comprueba que estén.
if [ -x "${BACKUP_BASE}/instalar-stack-voz.sh" ]; then
    if bash "${BACKUP_BASE}/instalar-stack-voz.sh" --comprobar >/dev/null 2>&1; then
        ok "stack de voz local completo (Kokoro TTS + whisper.cpp)"
    else
        warn "stack de voz local incompleto: ejecuta 'bash ${BACKUP_BASE}/instalar-stack-voz.sh'"
    fi
fi
if command -v lms >/dev/null 2>&1; then
    ok "LM Studio instalado (lms en PATH)"
else
    warn "LM Studio no instalado: los alias local/local-qwen35/local-gemma no responderán ('yay -S lmstudio-bin')"
fi
if [ -d "$HOME/.lmstudio/models/lmstudio-community" ]; then
    ok "modelos de LM Studio presentes (~/.lmstudio/models)"
else
    warn "sin modelos en ~/.lmstudio/models: descárgalos con 'lms get <modelo>' (ver AGENTS.md)"
fi
if [ -f "$HOME/.local/share/applications/hermes.desktop" ]; then
    ok "entrada ancla de GNOME/X11 (hermes.desktop)"
else
    warn "sin ~/.local/share/applications/hermes.desktop: en GNOME con XWayland el dock puede mostrar dos iconos"
fi

echo ""
if [ "$ERRORES" -eq 0 ]; then
    echo "✅ VERIFICACIÓN CORRECTA (0 errores)"
    exit 0
else
    echo "❌ VERIFICACIÓN FALLIDA (${ERRORES} errores)"
    exit 1
fi
