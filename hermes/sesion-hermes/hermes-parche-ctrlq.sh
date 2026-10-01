#!/usr/bin/env bash
# hermes-parche-ctrlq.sh — estado / aplicar / revertir el parche local del CLI de Hermes.
#
# El parche (parches/ctrl-q-corta-audio.patch) toca DOS ficheros y hace tres cosas:
#   1. Ctrl+Q y Ctrl+C cortan la reproducción de audio en curso (el CLI de serie no lo hacía).
#   2. Ctrl+Q deja de interrumpir el turno: SOLO calla la locución. Interrumpir sigue siendo Ctrl+C.
#   3. tools/voice_mode.py: un corte deliberado ya no reintenta la cadena de reproductores
#      (tras matar ffplay, aplay volvía a arrancar la MISMA frase desde el principio: se oía un
#      chasquido y parecía que la tecla no callaba la voz; hacía falta pulsar dos veces).
# Prueba funcional del reparto de teclas: scripts/test-ctrlq-solo-tts.py de la skill
# hermes-voz-local-gpu (hay que reiniciar Hermes para que el cambio entre en una sesión nueva).
#
# Por qué existe este script: `hermes update` autostashea los cambios locales y los
# restaura después, pero un conflicto con el código nuevo puede dejarlos aparcados.
# Tras una actualización: `hermes-parche-ctrlq.sh estado` y, si hace falta, `aplicar`.
#
# Uso:
#   hermes-parche-ctrlq.sh            # estado (por defecto)
#   hermes-parche-ctrlq.sh estado     # 0 = aplicado, 1 = sin aplicar, 2 = conflicto
#   hermes-parche-ctrlq.sh aplicar
#   hermes-parche-ctrlq.sh revertir
set -euo pipefail

REPO="${HERMES_REPO:-$HOME/.hermes/hermes-agent}"
PARCHE="${HERMES_PARCHE:-$HOME/Config/hermes/parches/ctrl-q-corta-audio.patch}"
FICHERO="hermes_cli/cli_tui_mixin.py tools/voice_mode.py"

LOG_DIR="${HERMES_PARCHE_LOG_DIR:-$HOME/Config/hermes/logs}"
log() {
    # En una instalación desde limpio el directorio logs/ no existe (va excluido del tarball):
    # sin crearlo, el parche se aplicaba pero el script salía con error y parecía un fallo.
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_DIR/parches.log" 2>/dev/null || true
}

if [[ ! -f "$PARCHE" ]]; then
    echo "❌ No encuentro el parche: $PARCHE" >&2
    exit 2
fi
if [[ ! -d "$REPO/.git" ]]; then
    echo "❌ No encuentro el repo de Hermes: $REPO" >&2
    exit 2
fi

esta_aplicado() { git -C "$REPO" apply --reverse --check "$PARCHE" 2>/dev/null; }
se_puede_aplicar() { git -C "$REPO" apply --check "$PARCHE" 2>/dev/null; }

case "${1:-estado}" in
    estado)
        if esta_aplicado; then
            echo "✅ Parche aplicado ($FICHERO)"; exit 0
        elif se_puede_aplicar; then
            echo "⚠️  Parche SIN aplicar ($FICHERO)"; exit 1
        else
            echo "⛔ No sé si está aplicado: el fichero ha cambiado respecto al parche" >&2
            exit 2
        fi
        ;;
    aplicar)
        if esta_aplicado; then
            echo "✅ Ya estaba aplicado; no hago nada"
            exit 0
        fi
        if ! se_puede_aplicar; then
            echo "⛔ El parche no aplica limpio (el código aguas arriba cambió). Revisar $FICHERO" >&2
            exit 2
        fi
        git -C "$REPO" apply "$PARCHE"
        echo "✅ Parche aplicado ($FICHERO)"
        log "aplicado $PARCHE"
        ;;
    revertir)
        if ! esta_aplicado; then
            echo "ℹ️  No estaba aplicado; no hago nada"
            exit 0
        fi
        git -C "$REPO" apply --reverse "$PARCHE"
        echo "✅ Parche revertido ($FICHERO)"
        log "revertido $PARCHE"
        ;;
    *)
        echo "Uso: $(basename "$0") [estado|aplicar|revertir]" >&2
        exit 2
        ;;
esac
