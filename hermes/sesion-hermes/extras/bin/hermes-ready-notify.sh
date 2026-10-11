#!/usr/bin/env bash
# Avisa por Telegram cuando el gateway de Hermes está listo tras un arranque, e incluye:
#   - si hay actualización disponible (`hermes update --check`, solo lectura),
#   - qué ha dejado Windows en el canal del dual boot (última importación, notas nuevas y
#     encargos pendientes).
# Lo lanza hermes-ready-notify.service (oneshot) al iniciar el user manager (login/arranque).
set -uo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
ENV_FILE="$HERMES_HOME/.env"
LOG_FILE="$HERMES_HOME/logs/gateway.log"
UNIT="hermes-gateway.service"
TIMEOUT="${HERMES_READY_TIMEOUT:-180}"
DRY_RUN="${DRY_RUN:-0}"
# Disco compartido del dual boot y registro de arranque para el agente.
COMUN="${HERMES_COMUN:-/mnt/seagate/HermesSync}"
LOG_ARRANQUE="$HOME/Config/hermes/logs/arranque-linux.log"

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
  local text="$1" attempt code body mid esc
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] no se envia: $text"
    return 0
  fi
  # El texto va dentro de un valor entrecomillado del config de curl (-K -): hay que
  # escapar backslash, comillas y los saltos de línea (\n). Sin esto, curl lee las
  # líneas siguientes del mensaje como opciones suyas y aborta
  # ("config file option '🔄' is unknown").
  esc=${text//\\/\\\\}
  esc=${esc//\"/\\\"}
  esc=${esc//$'\n'/\\n}
  for attempt in 1 2 3; do
    # El token va por stdin (-K -) para que no aparezca en argv/ps.
    body=$(curl -sS --max-time 20 -K - -w '__HTTP__%{http_code}' <<EOF
url = "https://api.telegram.org/bot${TOKEN}/sendMessage"
data-urlencode = "chat_id=${CHAT_ID}"
data-urlencode = "text=${esc}"
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

# --- Espera a que haya red/DNS --------------------------------------------
# Al arrancar, el script puede adelantarse a la red: sin resolución de nombres
# `hermes update --check` falla y el aviso salía con "no he podido comprobar
# si hay actualización". Espera activa acotada (máx. 45 s).
for _ in $(seq 1 15); do
  if getent hosts api.telegram.org >/dev/null 2>&1 || getent hosts github.com >/dev/null 2>&1; then
    break
  fi
  sleep 3
done

# --- Comprobación de actualización (una vez por arranque) ------------------
# `hermes update --check` es de solo lectura: hace un git fetch y no toca nada.
hermes_bin=$(command -v hermes 2>/dev/null || true)
[ -n "$hermes_bin" ] || hermes_bin="$HERMES_HOME/hermes-agent/.hermes/bin/hermes"
update_line="⚠️ no he podido comprobar si hay actualización"
canal=""
if [ -x "$hermes_bin" ]; then
  chk=$(timeout 150 "$hermes_bin" update --check 2>&1 || true)
  canal=$(printf '%s\n' "$chk" | sed -n 's/.*Update channel: *//p' | tail -1)
  case "$chk" in
    *"No newer release"*|*"up to date"*)
      update_line="✅ al día${canal:+ (canal $canal)}" ;;
    *"Update available"*|*"behind"*)
      update_line="⬆️ HAY ACTUALIZACIÓN — $(printf '%s\n' "$chk" | grep -m1 -E 'Update available|commits behind|behind origin' | sed 's/^[[:space:]]*//')" ;;
    *)
      update_line="⚠️ no he podido comprobar si hay actualización" ;;
  esac
fi

# --- Canal del dual boot: qué ha dejado Windows ---------------------------
dual_line="⚠️ no encuentro el disco compartido ($COMUN)"
if [ -d "$COMUN" ]; then
  imp=$(sed -n 's/.*"ultimo_import_utc": *"\([^"]*\)".*/\1/p' "$HERMES_HOME/.dual-sync/estado.json" 2>/dev/null | head -1)
  [ -n "$imp" ] || imp="desconocida"
  marca="$HERMES_HOME/state/arranque-nota.size"
  nota="$COMUN/NOTA-PARA-LINUX.md"
  nota_txt="sin novedades en NOTA-PARA-LINUX.md"
  if [ -f "$nota" ]; then
    size=$(stat -c%s "$nota" 2>/dev/null || echo 0)
    prev=$(cat "$marca" 2>/dev/null || echo "")
    if [ "$size" != "$prev" ]; then
      ult=$(grep '^## ' "$nota" 2>/dev/null | tail -1 | sed 's/^## *//' | tr -d '\r')
      nota_txt="📨 NOTA NUEVA de Windows — ${ult:0:90}"
      mkdir -p "$(dirname "$marca")" 2>/dev/null || true
      printf '%s' "$size" > "$marca" 2>/dev/null || true
    fi
  fi
  # Encargos que el otro sistema haya dejado y no estén marcados como hechos.
  pend=0
  for f in "$COMUN"/linux/encargos/*.sh; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    grep -q "\"$b\"" "$HERMES_HOME/state/encargos-hechos.json" 2>/dev/null || pend=$((pend + 1))
  done
  dual_line="última importación: ${imp} · ${nota_txt} · encargos pendientes de Windows: ${pend}"
fi

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

# --- Registro de arranque (lo lee el agente; queda en el esquema) ---------
_registrar() {
  mkdir -p "$(dirname "$LOG_ARRANQUE")" 2>/dev/null || true
  {
    printf '%s  arranque: gateway listo\n' "$(date '+%F %T')"
    printf '%s  arranque: update -> %s\n' "$(date '+%F %T')" "$update_line"
    printf '%s  arranque: dual boot -> %s\n' "$(date '+%F %T')" "$dual_line"
  } >> "$LOG_ARRANQUE" 2>/dev/null || true
}

if [ "$ready" = "1" ]; then
  _registrar
  _send "✅ Hermes activo — gateway listo y Telegram conectado (arranque $(date +%H:%M)). Ya puedes escribirme.
🔄 Update: ${update_line}
🤝 Dual boot: ${dual_line}"
  exit $?
fi

if systemctl --user is-active --quiet "$UNIT"; then
  _send "⚠️ Hermes arranco pero Telegram no conecto en ${TIMEOUT}s. Revisa: journalctl --user -u hermes-gateway -n 50"
else
  _send "⚠️ Hermes no arranco: el servicio hermes-gateway no esta activo tras ${TIMEOUT}s. Revisa: systemctl --user status hermes-gateway"
fi
exit 1
