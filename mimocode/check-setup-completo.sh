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

if [ "$ERRORS" -eq 0 ]; then
    log "✅ Verificación completada sin errores"
    exit 0
else
    log "❌ Verificación con $ERRORS problema(s)"
    exit 1
fi
