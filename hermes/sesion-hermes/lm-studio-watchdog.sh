#!/usr/bin/env bash
# lm-studio-watchdog.sh — vigila el servidor local de LM Studio y reinicia la app si se queda mudo.
#
# Por qué existe: el servidor HTTP de la app de LM Studio puede quedarse *mudo* (acepta
# conexiones en el 1234 pero no contesta a nada). Como la propia interfaz saca su lista de
# modelos de ese servidor, el síntoma visible es «LM Studio no muestra ningún modelo»,
# aunque los ficheros y el índice estén bien. Restart=on-failure no lo cubre: el proceso
# sigue vivo. Este vigilante lo detecta y reinicia la unidad.
#
# Uso normal: lo dispara lm-studio-watchdog.timer cada 5 minutos.
#   systemctl --user list-timers lm-studio-watchdog.timer
#   systemctl --user start lm-studio-watchdog.service      # comprobar ahora mismo
#   tail -20 ~/Config/hermes/logs/lm-studio-watchdog.log
#
# Variables (para pruebas; los valores por defecto son los de producción):
#   LM_STUDIO_UNIT            unidad a reiniciar (lm-studio-app.service)
#   LM_STUDIO_PROBE           URL a sondear (http://127.0.0.1:1234/v1/models)
#   LM_STUDIO_PROBE_TIMEOUT   segundos de espera por intento (5)
#   LM_STUDIO_FAILS           fallos consecutivos antes de reiniciar (2)
#   LM_STUDIO_STATE           fichero contador de fallos
#   LM_STUDIO_WATCHDOG_LOG    log (por defecto ~/Config/hermes/logs/lm-studio-watchdog.log)
#   LM_STUDIO_DRY=1           no reinicia: solo registra lo que haría
set -uo pipefail

UNIDAD="${LM_STUDIO_UNIT:-lm-studio-app.service}"
URL="${LM_STUDIO_PROBE:-http://127.0.0.1:1234/v1/models}"
TIMEOUT="${LM_STUDIO_PROBE_TIMEOUT:-5}"
UMBRAL="${LM_STUDIO_FAILS:-2}"
ESTADO="${LM_STUDIO_STATE:-$HOME/.hermes/state/lm-studio-watchdog.fallos}"
LOG="${LM_STUDIO_WATCHDOG_LOG:-$HOME/Config/hermes/logs/lm-studio-watchdog.log}"
SECO="${LM_STUDIO_DRY:-0}"

mkdir -p "$(dirname "$LOG")" "$(dirname "$ESTADO")" 2>/dev/null || true

log() { printf '[%s] %s\n' "$(date '+%d/%m/%Y %H:%M:%S')" "$*" >> "$LOG"; }

# Si la unidad no está activa, Antonio la ha parado a propósito (p. ej. para usar el daemon
# llmster): no se toca nada, solo se deja constancia.
estado_unidad=$(systemctl --user is-active "$UNIDAD" 2>/dev/null || true)
case "$estado_unidad" in
    active|activating|reloading) ;;
    *)
        log "unidad $UNIDAD en estado '$estado_unidad': no se toca (parada a propósito)"
        rm -f "$ESTADO" 2>/dev/null || true
        exit 0
        ;;
esac

codigo=$(curl -s -m "$TIMEOUT" -o /dev/null -w '%{http_code}' "$URL" 2>/dev/null || true)
codigo="${codigo:-000}"

if [ "$codigo" = "200" ]; then
    if [ -f "$ESTADO" ]; then
        rm -f "$ESTADO"
        log "recuperado: $URL vuelve a responder 200"
    fi
    exit 0
fi

fallos=$(cat "$ESTADO" 2>/dev/null || echo 0)
case "$fallos" in ''|*[!0-9]*) fallos=0 ;; esac
fallos=$((fallos + 1))
echo "$fallos" > "$ESTADO" 2>/dev/null || true
log "sin respuesta en $URL (HTTP ${codigo:-000}), fallo ${fallos}/${UMBRAL}"

if [ "$fallos" -ge "$UMBRAL" ]; then
    if [ "$SECO" = "1" ]; then
        log "DRY: reiniciaría $UNIDAD (no se hace nada)"
        exit 0
    fi
    log "reiniciando $UNIDAD"
    if systemctl --user restart "$UNIDAD" >>"$LOG" 2>&1; then
        rm -f "$ESTADO"
        log "reinicio de $UNIDAD lanzado"
    else
        log "ERROR: el reinicio de $UNIDAD ha fallado"
    fi
fi
exit 0
