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
