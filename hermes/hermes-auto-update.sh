#!/usr/bin/env bash
# Actualización automática de Hermes (source install, canal stable).
#
# Lo lanza hermes-auto-update.timer en su PROPIA unidad systemd, no dentro del cgroup del
# gateway: así sobrevive al reinicio que la actualización provoca en el gateway (la doc lo
# exige para cualquier update hijo del gateway; una unidad aparte se libra del KillMode).
#
# Secuencia:
#   1. `hermes update --check` (solo lectura). Si ya está en la última release, sale sin
#      tocar nada: no se reinicia el gateway sin motivo.
#   2. `hermes update --yes`: snapshot previo (updates.pre_update_backup), autostash de los
#      parches locales de voz y reinicio del fleet con drain-first.
#   3. Vuelve a negar la telemetría si una migración de config la hubiese reactivado.
#   4. Avisa por Telegram (mismo bot que hermes-ready-notify) con el resultado.
#
# Uso:  hermes-auto-update.sh [--dry-run]
# Log:  ~/Config/hermes/logs/auto-update.log   (y journalctl --user -u hermes-auto-update)
set -uo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
ENV_FILE="$HERMES_HOME/.env"
LOG="$HOME/Config/hermes/logs/auto-update.log"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

mkdir -p "$(dirname "$LOG")"
log() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG" >&2; }

_strip() {
  tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                  -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

tg() { # tg "mensaje"
  local tok chat code
  tok=$(grep -m1 -E '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- | _strip)
  chat=$(grep -m1 -E '^TELEGRAM_HOME_CHANNEL=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- | _strip)
  if [ -z "$tok" ] || [ -z "$chat" ]; then
    log "aviso Telegram omitido: faltan credenciales en $ENV_FILE"
    return 0
  fi
  if [ "$DRY_RUN" = 1 ]; then log "[dry-run] Telegram: $1"; return 0; fi
  code=$(curl -sS --max-time 20 -o /dev/null -w '%{http_code}' \
          --data-urlencode "chat_id=$chat" --data-urlencode "text=$1" \
          "https://api.telegram.org/bot$tok/sendMessage" 2>/dev/null) || code="error"
  [ "$code" = "200" ] || log "aviso Telegram devolvió $code"
}

# --- 1. ¿Hay algo nuevo? ---------------------------------------------------
version_antes=$(hermes --version 2>/dev/null | head -1)
log "--- comprobación (versión actual: ${version_antes:-desconocida}) ---"

check_out=$(timeout 300 hermes update --check 2>&1) || true
if printf '%s' "$check_out" | grep -qi "up to date"; then
  log "sin novedades: $(printf '%s' "$check_out" | grep -i 'up to date' | tail -1)"
  exit 0
fi
log "actualización disponible: $(printf '%s' "$check_out" | grep -iE 'latest release|available' | tail -1)"

if [ "$DRY_RUN" = 1 ]; then
  log "[dry-run] aquí se lanzaría: hermes update --yes"
  exit 0
fi

# --- 2. Actualizar --------------------------------------------------------
log "lanzando hermes update --yes"
timeout 1500 hermes update --yes >>"$LOG" 2>&1
rc=$?
version_despues=$(hermes --version 2>/dev/null | head -1)

# --- 3. Telemetría: negarla siempre ---------------------------------------
for clave in send enabled; do
  valor=$(hermes config get "telemetry.shared_metrics.$clave" 2>/dev/null | tail -1)
  if [ "$valor" != "false" ]; then
    hermes config set "telemetry.shared_metrics.$clave" false >>"$LOG" 2>&1 \
      && log "telemetría reactivada por la migración: '$clave' vuelto a false"
  fi
done

# --- 4. Resultado ---------------------------------------------------------
if [ "$rc" -eq 0 ]; then
  log "actualización OK: ${version_antes:-?} -> ${version_despues:-?}"
  tg "🔄 Hermes actualizado en Linux
${version_antes:-?}
→ ${version_despues:-?}
Telemetría: desactivada"
else
  log "ERROR: hermes update salió con código $rc (ver $LOG)"
  tg "⚠️ La actualización automática de Hermes en Linux falló (código $rc).
Versión: ${version_antes:-?}
Log: ~/Config/hermes/logs/auto-update.log"
fi
exit "$rc"
