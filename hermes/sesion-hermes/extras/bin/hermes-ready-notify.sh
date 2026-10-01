#!/usr/bin/env bash
# Avisa por Telegram cuando el gateway de Hermes está listo tras un arranque.
# Lo lanza hermes-ready-notify.service (oneshot) al iniciar el user manager.
set -uo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
ENV_FILE="$HERMES_HOME/.env"
LOG_FILE="$HERMES_HOME/logs/gateway.log"
UNIT="hermes-gateway.service"
TIMEOUT="${HERMES_READY_TIMEOUT:-180}"
DRY_RUN="${DRY_RUN:-0}"

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }

# --- Credenciales ---------------------------------------------------------
_strip() {
  tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                  -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}
TOKEN=$(grep -m1 -E '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- | _strip)
CHAT_ID=$(grep -m1 -E '^TELEGRAM_HOME_CHANNEL=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- | _strip)

if [ -z "$TOKEN" ] || [ -z "$CHAT_ID" ]; then
  log "ERROR: faltan TELEGRAM_BOT_TOKEN o TELEGRAM_HOME_CHANNEL en $ENV_FILE"
  exit 1
fi

# --- No duplicar el aviso nativo de Hermes --------------------------------
# En reinicios planificados (/restart o actualizacion) el propio gateway ya
# envia su notificacion via ~/.hermes/.restart_notify.json / .restart_pending.json
for marker in "$HERMES_HOME/.restart_pending.json" "$HERMES_HOME/.restart_notify.json"; do
  if [ -e "$marker" ]; then
    log "marcador nativo presente ($marker): el gateway avisa por su cuenta"
    exit 0
  fi
done

# --- Envio ----------------------------------------------------------------
_send() {
  local text="$1" attempt code body mid
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] no se envia: $text"
    return 0
  fi
  for attempt in 1 2 3; do
    # El token va por stdin (-K -) para que no aparezca en argv/ps.
    body=$(curl -sS --max-time 20 -K - -w '__HTTP__%{http_code}' <<EOF
url = "https://api.telegram.org/bot${TOKEN}/sendMessage"
data-urlencode = "chat_id=${CHAT_ID}"
data-urlencode = "text=${text}"
EOF
) || body=""
    code="${body##*__HTTP__}"
    body="${body%__HTTP__*}"
    # Telegram puede contestar 200 con ok:false: hay que mirar el cuerpo, no solo el codigo.
    if printf '%s' "$body" | grep -qE '"ok"[[:space:]]*:[[:space:]]*true'; then
      mid=$(printf '%s' "$body" | sed -n 's/.*"message_id":[[:space:]]*\([0-9]*\).*/\1/p')
      log "mensaje enviado a telegram:$CHAT_ID (http $code, message_id=${mid:-?})"
      return 0
    fi
    log "intento $attempt fallido (http ${code:-sin respuesta}): $(printf '%s' "$body" | head -c 200)"
    [ "$attempt" -lt 3 ] && sleep 2
  done
  return 1
}

# --- Espera a que el gateway este realmente listo -------------------------
# "Listo" = servicio active Y adaptador de Telegram conectado despues de
# arrancar el servicio (no basta con que el proceso exista).
deadline=$(( $(date +%s) + TIMEOUT ))
t0=$(date +%s)
ready=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  if systemctl --user is-active --quiet "$UNIT"; then
    svc_start=$(systemctl --user show -p ActiveEnterTimestamp --value "$UNIT" 2>/dev/null)
    svc_epoch=$(LC_ALL=C date -d "$svc_start" +%s 2>/dev/null) || svc_epoch=0
    # Fallback si systemd devolviera una fecha no parseable: basta con que la
    # conexion sea reciente respecto al inicio de este script.
    [ "$svc_epoch" -gt 0 ] || svc_epoch=$(( t0 - 120 ))
    last_seen=$(tail -n 400 "$LOG_FILE" 2>/dev/null \
      | grep -E 'Connected to Telegram \(polling mode\)|telegram connected' \
      | tail -1 | awk '{print $1" "$2}')
    if [ -n "$last_seen" ]; then
      seen_epoch=$(LC_ALL=C date -d "${last_seen/,/.}" +%s 2>/dev/null) || seen_epoch=0
      if [ "$seen_epoch" -ge "$svc_epoch" ] && [ "$seen_epoch" -gt 0 ]; then
        ready=1
        break
      fi
    fi
  fi
  sleep 3
done

if [ "$ready" = "1" ]; then
  _send "✅ Hermes activo — gateway listo y Telegram conectado (arranque $(date +%H:%M)). Ya puedes escribirme."
  exit $?
fi

if systemctl --user is-active --quiet "$UNIT"; then
  _send "⚠️ Hermes arranco pero Telegram no conecto en ${TIMEOUT}s. Revisa: journalctl --user -u hermes-gateway -n 50"
else
  _send "⚠️ Hermes no arranco: el servicio hermes-gateway no esta activo tras ${TIMEOUT}s. Revisa: systemctl --user status hermes-gateway"
fi
exit 1
