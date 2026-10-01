#!/usr/bin/env bash
#==============================================================================
# hermes-dual-sync.sh — Estado compartido de Hermes entre Linux y Windows
# (equipos en dual boot: nunca están encendidos a la vez)
#
# Uso:
#   hermes-dual-sync.sh auto              # importa si hay algo más nuevo y publica
#   hermes-dual-sync.sh import            # trae el estado del otro sistema
#   hermes-dual-sync.sh export            # publica el estado de este sistema
#   hermes-dual-sync.sh estado            # muestra el estado de la carpeta común
#   hermes-dual-sync.sh semilla           # genera la semilla de configuración (a petición; no se recrea sola)
#   hermes-dual-sync.sh listar-historico  # copias guardadas en el historial
#   hermes-dual-sync.sh restaurar <host> <epoch>
#
# Opciones: --quiet --forzar --semilla --reiniciar-gateway --sin-import
#
# Esquema: ~/Config/hermes/AGENTS.md (sección "Dual boot")
#==============================================================================

set -uo pipefail

HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"
CONF_FILE="$HOME/.config/hermes-dual-sync.conf"
ESTADO_LOCAL_DIR="$HERMES_HOME_DIR/.dual-sync"
ESTADO_LOCAL_JSON="$ESTADO_LOCAL_DIR/estado.json"
BACKUPS_LOCALES="$ESTADO_LOCAL_DIR/backups"
LOCK_FILE="$ESTADO_LOCAL_DIR/.sync.lock"
HOST_ACTUAL="$(hostname -s 2>/dev/null || echo linux)"

# --- Configuración por defecto (se sobreescribe con $CONF_FILE) --------------
COMUN_MONTADO="${COMUN_MONTADO:-}"          # p.ej. /mnt/seagate si ya está montado
PUNTO_MONTAJE="/mnt/seagate"                # destino fstab del disco compartido
UUID_DISCO="A472BB2A72BB005A"               # disco SEAGATE (NTFS)
SUBDIR="HermesSync"                         # carpeta dentro del disco
RETENCION=5                                 # copias históricas por host
DIAS_BACKUP_LOCAL=10                        # días de backups locales previos al import

# shellcheck disable=SC1090
[ -f "$CONF_FILE" ] && . "$CONF_FILE"

QUIET="no"; FORZAR="no"; CON_SEMILLA="no"; REINICIAR_GATEWAY="no"; SIN_IMPORT="no"
COMUN_FORZADO=""
SOLO_SI_CAMBIA="no"; ACCION=""
MARCA_PUBLICACION="$ESTADO_LOCAL_DIR/.ultima-publicacion"

#==============================================================================
# Utilidades
#==============================================================================
log()  { echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null; [ "$QUIET" = "no" ] && echo "$*"; return 0; }
avisar(){ [ "$QUIET" = "no" ] && echo "$*"; return 0; }
morir() { echo "ERROR: $*" >&2; [ -n "${LOG_FILE:-}" ] && echo "[$(date '+%d/%m/%Y %H:%M:%S')] ERROR: $*" >> "$LOG_FILE"; exit 1; }

json_get() {  # json_get <fichero> <clave>
    python3 - "$1" "$2" <<'PY' 2>/dev/null
import json,sys
try:
    with open(sys.argv[1], encoding='utf-8-sig') as fh:
        print(json.load(fh).get(sys.argv[2], ""))
except Exception:
    print("")
PY
}

#==============================================================================
# Carpeta común: localizar / montar / comprobar
#==============================================================================
montar_comun() {
    local mnt="" intento
    if [ -n "$COMUN_FORZADO" ]; then COMUN="$COMUN_FORZADO"; return 0; fi

    # El disco está en fstab con `x-systemd.automount`: el montaje real sólo ocurre
    # cuando alguien toca el punto de montaje.  Un `mount` suelto no sirve (sin
    # privilegios) y udisksctl necesita una sesión gráfica que en el arranque todavía
    # no existe, así que hay que forzar el acceso y darle unos segundos a systemd.
    # (Sin esto el import de arranque no veía el disco: montó a las 10:47:43 cuando el
    #  import había corrido a las 10:44:26 — y salía como éxito sin hacer nada.)
    for intento in $(seq 1 12); do
        mnt="$(findmnt -rn -S "UUID=$UUID_DISCO" -o TARGET 2>/dev/null | head -1)"
        [ -n "$mnt" ] && break
        if [ -d "$PUNTO_MONTAJE" ]; then
            ls "$PUNTO_MONTAJE" >/dev/null 2>&1 || true     # dispara el automount
            mnt="$(findmnt -rn -S "UUID=$UUID_DISCO" -o TARGET 2>/dev/null | head -1)"
            [ -n "$mnt" ] && break
        fi
        if [ "$intento" = "4" ] && command -v udisksctl >/dev/null 2>&1; then
            udisksctl mount -b "/dev/disk/by-uuid/$UUID_DISCO" >/dev/null 2>&1 || true
        fi
        sleep 1
    done
    [ -n "$mnt" ] || return 1
    COMUN="$mnt/$SUBDIR"
    return 0
}

preparar_comun() {
    if ! montar_comun; then
        if [ "$QUIET" = "si" ] || [ "$ACCION" = "auto" ]; then
            # Deja rastro en el journal aunque vaya con --quiet: antes salía en silencio
            # con éxito y un import de arranque que no encontraba el disco era
            # indistinguible de uno que sí se había hecho.
            echo "[$(date '+%d/%m/%Y %H:%M:%S')] AVISO dual-sync ($ACCION): el disco compartido (UUID=$UUID_DISCO) no está montado; no hay nada que sincronizar." >&2
            exit 0
        fi
        morir "no encuentro el disco compartido (UUID=$UUID_DISCO) montado. ¿Está conectado el disco SEAGATE?"
    fi
    mkdir -p "$COMUN" 2>/dev/null || morir "no puedo crear $COMUN (¿montaje en solo lectura? Si Windows se apagó con 'inicio rápido', el NTFS queda sucio)"
    mkdir -p "$COMUN/estado" "$COMUN/historial" "$COMUN/logs" 2>/dev/null || true
    if [ ! -f "$COMUN/.hermes-sync" ]; then
        printf 'protocolo=1\ncreado=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$COMUN/.hermes-sync" 2>/dev/null || true
    fi
    if [ ! -w "$COMUN/estado" ]; then
        ESCRIBIBLE="no"
    else
        ESCRIBIBLE="si"
    fi
    mkdir -p "$ESTADO_LOCAL_DIR" "$BACKUPS_LOCALES" 2>/dev/null || true
    LOG_FILE="$COMUN/logs/$HOST_ACTUAL.log"
}

#==============================================================================
# Estado local (marca de último import/export)
#==============================================================================
leer_local() {
    ULTIMO_IMPORT_EPOCH="$(json_get "$ESTADO_LOCAL_JSON" ultimo_import_epoch)"
    [ -z "$ULTIMO_IMPORT_EPOCH" ] && ULTIMO_IMPORT_EPOCH=0
}

guardar_local() {  # guardar_local <epoch>
    python3 - "$ESTADO_LOCAL_JSON" "$1" "$HOST_ACTUAL" <<'PY'
import json,sys,os,datetime
ruta, epoch, host = sys.argv[1], int(sys.argv[2]), sys.argv[3]
datos = {}
if os.path.exists(ruta):
    try:
        datos = json.load(open(ruta, encoding='utf-8'))
    except Exception:
        datos = {}
datos.update({
    "host": host,
    "ultimo_import_epoch": epoch,
    "ultimo_import_utc": datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ') if epoch else None,
})
os.makedirs(os.path.dirname(ruta), exist_ok=True)
tmp = ruta + '.tmp'
with open(tmp, 'w', encoding='utf-8') as fh:
    json.dump(datos, fh, indent=2, ensure_ascii=False)
os.replace(tmp, ruta)
PY
}

#==============================================================================
# Ficheros que viajan
#==============================================================================
ARBOLES=(sessions memories skills cron)
EXCL_ARBOLES=(--exclude='*.lock' --exclude='executions.db*' --exclude='ticker_heartbeat' --exclude='ticker_last_success' --exclude='output/')
FICHEROS=(state.db kanban.db SOUL.md)

#==============================================================================
# EXPORT: publicar el estado de este sistema en la carpeta común
#==============================================================================
hacer_export() {
    [ "$ESCRIBIBLE" = "si" ] || { avisar "⚠️  El disco compartido está en solo lectura: no publico nada."; return 1; }

    # Modo rápido (hook por turno): salir si nada ha cambiado desde la última publicación
    if [ "$SOLO_SI_CAMBIA" = "si" ] && [ -f "$MARCA_PUBLICACION" ]; then
        if [ -z "$(find "$HERMES_HOME_DIR/state.db" "$HERMES_HOME_DIR/memories" "$HERMES_HOME_DIR/skills" \
                     "$HERMES_HOME_DIR/cron" "$HERMES_HOME_DIR/kanban.db" "$HERMES_HOME_DIR/SOUL.md" \
                     -newer "$MARCA_PUBLICACION" -print -quit 2>/dev/null)" ]; then
            return 0
        fi
    fi

    # Nunca pisar algo más nuevo del otro sistema sin haberlo integrado antes
    remoto_epoch="$(json_get "$COMUN/estado/MANIFEST.json" publicado_epoch)"
    remoto_host="$(json_get "$COMUN/estado/MANIFEST.json" host)"
    if [ -n "$remoto_epoch" ] && [ "$remoto_epoch" != "0" ] && [ "$remoto_epoch" -gt "${ULTIMO_IMPORT_EPOCH:-0}" ] && [ "$remoto_host" != "$HOST_ACTUAL" ]; then
        if [ "$SIN_IMPORT" = "si" ]; then
            morir "hay estado más nuevo de '$remoto_host' sin integrar. Ejecuta 'import' primero."
        fi
        avisar "ℹ️  Hay estado más reciente de '$remoto_host' sin integrar: lo importo antes de publicar."
        if ! hacer_import; then
            # No se puede integrar (Hermes está en uso aquí). Se publica igualmente para no
            # bloquear el esquema; el estado del otro sistema queda archivado en el historial.
            avisar "⚠️  No he podido integrar lo de '$remoto_host' (Hermes en uso). Publico igualmente;"
            avisar "    su copia queda guardada en el historial: 'hermes-dual-sync listar-historico'"
        fi
    fi

    log "📤 Publicando estado de $HOST_ACTUAL en $COMUN/estado/"
    # 1) Archivar en el historial lo que hubiera publicado el otro sistema
    if [ -f "$COMUN/estado/state.db" ] && [ -n "$remoto_epoch" ] && [ "$remoto_host" != "$HOST_ACTUAL" ]; then
        mkdir -p "$COMUN/historial/$remoto_host"
        gzip -c "$COMUN/estado/state.db" > "$COMUN/historial/$remoto_host/${remoto_epoch}-state.db.gz" 2>/dev/null || true
        ( cd "$COMUN/estado" && tar -czf "$COMUN/historial/$remoto_host/${remoto_epoch}-resto.tar.gz" \
            --exclude='state.db' . 2>/dev/null ) || true
    fi

    # 2) state.db: copia consistente (incluye el WAL)
    tmp="$COMUN/estado/state.db.tmp"
    rm -f "$tmp"
    sqlite3 "$HERMES_HOME_DIR/state.db" ".backup '$tmp'" || morir "no pude copiar state.db"
    verifica="$(sqlite3 "$tmp" 'PRAGMA integrity_check;' 2>/dev/null | head -1)"
    [ "$verifica" = "ok" ] || { rm -f "$tmp"; morir "la copia de state.db no pasa integrity_check ($verifica)"; }
    mv -f "$tmp" "$COMUN/estado/state.db"

    # 3) Árboles y ficheros sueltos
    for d in "${ARBOLES[@]}"; do
        if [ -d "$HERMES_HOME_DIR/$d" ]; then
            mkdir -p "$COMUN/estado/$d"
            rsync -rt --delete --no-perms --no-owner --no-group --modify-window=2 \
                  "${EXCL_ARBOLES[@]}" "$HERMES_HOME_DIR/$d/" "$COMUN/estado/$d/" || avisar "⚠️  rsync falló en $d"
        fi
    done
    for f in "${FICHEROS[@]}"; do
        [ -f "$HERMES_HOME_DIR/$f" ] && cp -f "$HERMES_HOME_DIR/$f" "$COMUN/estado/$f"
    done

    # 4) Semilla de configuración (SOLO a petición: `semilla` o --semilla)
    #    Lleva claves en claro (.env, auth.json): si se regenerase sola al faltar,
    #    borrarla no serviría de nada — volvería a los pocos minutos al disco
    #    compartido.  Igual que el motor de Windows (`-Accion semilla`).
    if [ "$CON_SEMILLA" = "si" ]; then
        mkdir -p "$COMUN/semilla"
        for f in config.yaml .env auth.json SOUL.md; do
            [ -f "$HERMES_HOME_DIR/$f" ] && cp -f "$HERMES_HOME_DIR/$f" "$COMUN/semilla/$f"
        done
        chmod 600 "$COMUN/semilla/.env" "$COMUN/semilla/auth.json" 2>/dev/null || true
        log "🔑 Semilla de configuración disponible en $COMUN/semilla (solo para el primer arranque en Windows)"
    fi

    # 6) Utilidades del lado Windows (la carpeta común queda autosuficiente)
    if [ -d "$HOME/Config/hermes/dual-boot/windows" ] && [ "$ESCRIBIBLE" = "si" ]; then
        rsync -au "$HOME/Config/hermes/dual-boot/windows/" "$COMUN/windows/" 2>/dev/null \
            && log "🪟 Scripts de Windows al día en $COMUN/windows"
    fi

    # 7) Manifiesto
    sesiones="$(sqlite3 "$HERMES_HOME_DIR/state.db" 'SELECT COUNT(*) FROM sessions;' 2>/dev/null || echo 0)"
    mensajes="$(sqlite3 "$HERMES_HOME_DIR/state.db" 'SELECT COUNT(*) FROM messages;' 2>/dev/null || echo 0)"
    sha="$(sha256sum "$COMUN/estado/state.db" | awk '{print $1}')"
    version="$(hermes --version 2>/dev/null | head -1 | sed 's/^Hermes Agent //; s/ .*//')"
    python3 - "$COMUN/estado/MANIFEST.json" "$HOST_ACTUAL" "$sesiones" "$mensajes" "$sha" "$version" "$HERMES_HOME_DIR" <<'PY'
import json,sys,os,datetime,socket
ruta, host, sesiones, mensajes, sha, version, home = sys.argv[1:8]
ahora = datetime.datetime.now(datetime.timezone.utc)
datos = {
    "protocolo": 1,
    "host": host,
    "hostname": socket.gethostname(),
    "plataforma": "Linux",
    "publicado_utc": ahora.strftime('%Y-%m-%dT%H:%M:%SZ'),
    "publicado_epoch": int(ahora.timestamp()),
    "hermes_version": version,
    "hermes_home": home,
    "sesiones": int(sesiones or 0),
    "mensajes": int(mensajes or 0),
    "sha256_state_db": sha,
    "contenido": {"arboles": ["sessions","memories","skills","cron"], "ficheros": ["state.db","kanban.db","SOUL.md"]},
}
tmp = ruta + '.tmp'
with open(tmp, 'w', encoding='utf-8') as fh:
    json.dump(datos, fh, indent=2, ensure_ascii=False)
os.replace(tmp, ruta)
PY

    # 6) Podar historial antiguo por host
    for h in $(ls -1 "$COMUN/historial" 2>/dev/null); do
        ls -1t "$COMUN/historial/$h"/*-state.db.gz 2>/dev/null | tail -n +$((RETENCION+1)) | while read -r viejo; do rm -f "$viejo"; done
    done

    log "✅ Publicado: $sesiones sesiones / $mensajes mensajes (sha256 ${sha:0:12}…)"
    touch "$MARCA_PUBLICACION" 2>/dev/null || true
}

#==============================================================================
# IMPORT: traer el estado del otro sistema
#==============================================================================
hacer_import() {
    local man="$COMUN/estado/MANIFEST.json"
    [ -f "$man" ] || { avisar "ℹ️  Aún no hay nada publicado por el otro sistema."; return 0; }

    local r_epoch r_host r_sha r_sesiones
    r_epoch="$(json_get "$man" publicado_epoch)"; r_host="$(json_get "$man" host)"
    r_sha="$(json_get "$man" sha256_state_db)";  r_sesiones="$(json_get "$man" sesiones)"
    [ -z "$r_epoch" ] && morir "el MANIFEST de la carpeta común está ilegible."

    if [ "$r_host" = "$HOST_ACTUAL" ]; then
        avisar "ℹ️  Lo publicado en la carpeta común lo publicó este mismo equipo ($HOST_ACTUAL): nada que importar."
        return 0
    fi
    if [ "$r_epoch" -le "${ULTIMO_IMPORT_EPOCH:-0}" ] && [ "$FORZAR" = "no" ]; then
        avisar "ℹ️  Sin novedades de '$r_host' (última importación: $(date -d "@${ULTIMO_IMPORT_EPOCH:-0}" '+%d/%m/%Y %H:%M'))."
        return 0
    fi

    # ¿Está la base de datos en uso por el gateway/CLI de aquí?
    if command -v lsof >/dev/null 2>&1 && [ -n "$(lsof -t "$HERMES_HOME_DIR/state.db" 2>/dev/null)" ]; then
        if [ "$REINICIAR_GATEWAY" = "si" ] && systemctl --user stop hermes-gateway.service 2>/dev/null; then
            sleep 2
            if [ -n "$(lsof -t "$HERMES_HOME_DIR/state.db" 2>/dev/null)" ]; then
                systemctl --user start hermes-gateway.service 2>/dev/null || true
                morir "state.db sigue en uso: cierra las sesiones de Hermes y reintenta."
            fi
        else
            avisar "⚠️  Hermes está usando state.db en este equipo. Cierra el gateway y las sesiones (o usa --reiniciar-gateway) y reintenta el import."
            [ "$ACCION" = "auto" ] && avisar "    (la publicación se omite para no pisar el estado del otro sistema)"
            return 1
        fi
    fi

    # Verificar el sha256 y la integridad de la BD remota ANTES de tocar nada
    if [ -n "$r_sha" ]; then
        sha_real="$(sha256sum "$COMUN/estado/state.db" | awk '{print $1}')"
        [ "$sha_real" = "$r_sha" ] || morir "la copia de state.db de la carpeta común está corrupta (sha256 no coincide). Import abortado."
    fi
    int="$(sqlite3 "$COMUN/estado/state.db" 'PRAGMA integrity_check;' 2>/dev/null | head -1)"
    [ "$int" = "ok" ] || morir "state.db remota ilegible o dañada (integrity_check: ${int:-sin respuesta}). Import abortado."
    ses_remotas="$(sqlite3 "$COMUN/estado/state.db" 'SELECT COUNT(*) FROM sessions;' 2>/dev/null || echo '')"
    if [ -z "$ses_remotas" ]; then
        morir "state.db remota ilegible (no tiene tabla de sesiones). Import abortado."
    elif [ -n "$r_sesiones" ] && [ "$r_sesiones" != "0" ] && [ "$ses_remotas" != "$r_sesiones" ]; then
        morir "state.db remota tiene $ses_remotas sesiones pero el manifiesto declara $r_sesiones: copia incompleta. Import abortado."
    fi

    log "📥 Importando estado de '$r_host' publicado el $(date -d "@$r_epoch" '+%d/%m/%Y %H:%M') ($r_sesiones sesiones)"

    # Backup local por si hay que volver atrás
    mkdir -p "$BACKUPS_LOCALES/$r_epoch"
    sqlite3 "$HERMES_HOME_DIR/state.db" ".backup '$BACKUPS_LOCALES/$r_epoch/state.db'" 2>/dev/null || true
    for d in memories skills cron; do
        [ -d "$HERMES_HOME_DIR/$d" ] && rsync -rt --no-perms --no-owner --no-group --modify-window=2 "$HERMES_HOME_DIR/$d/" "$BACKUPS_LOCALES/$r_epoch/$d/" 2>/dev/null
    done
    [ -f "$HERMES_HOME_DIR/kanban.db" ] && cp -f "$HERMES_HOME_DIR/kanban.db" "$BACKUPS_LOCALES/$r_epoch/kanban.db" 2>/dev/null
    find "$BACKUPS_LOCALES" -maxdepth 1 -type d -mtime +"$DIAS_BACKUP_LOCAL" -exec rm -rf {} + 2>/dev/null || true

    # Sustituir state.db (y limpiar WAL/SHM del anterior)
    rm -f "$HERMES_HOME_DIR/state.db-wal" "$HERMES_HOME_DIR/state.db-shm"
    cp -f "$COMUN/estado/state.db" "$HERMES_HOME_DIR/state.db" || morir "no pude escribir state.db"
    chmod 600 "$HERMES_HOME_DIR/state.db" 2>/dev/null || true

    # Traer los árboles y ficheros sueltos
    for d in "${ARBOLES[@]}"; do
        if [ -d "$COMUN/estado/$d" ]; then
            mkdir -p "$HERMES_HOME_DIR/$d"
            rsync -rt --delete --no-perms --no-owner --no-group --modify-window=2 \
                  "$COMUN/estado/$d/" "$HERMES_HOME_DIR/$d/" || avisar "⚠️  rsync falló en $d"
        fi
    done
    for f in kanban.db SOUL.md; do
        [ -f "$COMUN/estado/$f" ] && cp -f "$COMUN/estado/$f" "$HERMES_HOME_DIR/$f"
    done
    # NTFS no guarda el bit de ejecución: devolvérselo a los scripts de skills
    find "$HERMES_HOME_DIR/skills" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod u+x {} + 2>/dev/null || true

    guardar_local "$r_epoch"
    ULTIMO_IMPORT_EPOCH="$r_epoch"
    log "✅ Importado. Backup local previo en $BACKUPS_LOCALES/$r_epoch"

    if [ "$REINICIAR_GATEWAY" = "si" ] && systemctl --user is-enabled hermes-gateway.service >/dev/null 2>&1; then
        systemctl --user start hermes-gateway.service 2>/dev/null && log "🔄 Gateway reiniciado con el estado nuevo"
    fi
    return 0
}

#==============================================================================
# Estado / historial / restauración
#==============================================================================
mostrar_estado() {
    leer_local
    echo "── Carpeta común ─────────────────────────────────────────"
    echo "  Ruta        : $COMUN   ($([ "$ESCRIBIBLE" = "si" ] && echo 'escritura OK' || echo 'SOLO LECTURA'))"
    if [ -f "$COMUN/estado/MANIFEST.json" ]; then
        echo "  Publicado por: $(json_get "$COMUN/estado/MANIFEST.json" host) el $(date -d "@$(json_get "$COMUN/estado/MANIFEST.json" publicado_epoch)" '+%d/%m/%Y %H:%M')"
        echo "  Sesiones    : $(json_get "$COMUN/estado/MANIFEST.json" sesiones) · mensajes: $(json_get "$COMUN/estado/MANIFEST.json" mensajes)"
        echo "  Versión     : $(json_get "$COMUN/estado/MANIFEST.json" hermes_version)"
    else
        echo "  Publicado por: (nada publicado todavía)"
    fi
    echo "── Este equipo ($HOST_ACTUAL) ────────────────────────────"
    echo "  Última importación: $([ "${ULTIMO_IMPORT_EPOCH:-0}" -gt 0 ] && date -d "@$ULTIMO_IMPORT_EPOCH" '+%d/%m/%Y %H:%M' || echo 'nunca')"
    echo "  Sesiones locales  : $(sqlite3 "$HERMES_HOME_DIR/state.db" 'SELECT COUNT(*) FROM sessions;' 2>/dev/null || echo '?')"
    echo "  Semilla           : $([ -f "$COMUN/semilla/config.yaml" ] && echo 'disponible en la carpeta común (borrar si ya está aplicada: lleva claves)' || echo 'sin generar (solo con: semilla)')"
    if [ -d "$COMUN/historial" ]; then
        echo "  Historial         : $(find "$COMUN/historial" -name '*-state.db.gz' 2>/dev/null | wc -l) copias"
    fi
    echo "  Últimas líneas del log:"
    tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/    /'
}

listar_historico() {
    [ -d "$COMUN/historial" ] || { echo "Sin historial."; return 0; }
    for h in "$COMUN/historial"/*/; do
        [ -d "$h" ] || continue
        for f in "$h"*-state.db.gz; do
            [ -f "$f" ] || continue
            e="$(basename "$f" | cut -d- -f1)"
            resto=""; [ -f "$h${e}-resto.tar.gz" ] && resto="+ resto"
            printf '%s  %s  %s  %s\n' "$(basename "$h")" "$(date -d "@$e" '+%d/%m/%Y %H:%M')" "$(du -h "$f" | cut -f1)" "$resto"
        done
    done | sort -k1,1 -k2,2
}

restaurar_historico() {  # restaurar <host> <epoch>
    local host="$1" epoch="$2" src="$COMUN/historial/$1/${2}-state.db.gz" dest
    [ -f "$src" ] || morir "no encuentro $src"
    dest="$BACKUPS_LOCALES/restaurado-$epoch"
    mkdir -p "$dest"
    gunzip -c "$src" > "$dest/state.db"
    sqlite3 "$dest/state.db" 'PRAGMA integrity_check;' | head -1 | grep -q '^ok$' || morir "la copia restaurada no es válida"
    echo "Copia extraída en $dest/state.db (con Hermes cerrado: cp $dest/state.db $HERMES_HOME_DIR/state.db)"
}

#==============================================================================
# Main
#==============================================================================
while [ $# -gt 0 ]; do
    case "$1" in
        auto|import|export|estado|semilla|listar-historico) ACCION="${ACCION:-$1}"; [ "$1" = "semilla" ] && CON_SEMILLA="si" ;;
        restaurar) ACCION="restaurar"; shift; HOST_REST="$1"; shift; EPOCH_REST="$1" ;;
        --quiet) QUIET="si" ;;
        --forzar) FORZAR="si" ;;
        --solo-si-cambia) SOLO_SI_CAMBIA="si" ;;
        --comun) shift; COMUN_FORZADO="${1:-}" ;;
        --semilla) CON_SEMILLA="si" ;;
        --reiniciar-gateway) REINICIAR_GATEWAY="si" ;;
        --sin-import) SIN_IMPORT="si" ;;
        -h|--help|ayuda) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) morir "opción desconocida: $1" ;;
    esac
    shift
done
[ -n "$ACCION" ] || { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

command -v python3 >/dev/null 2>&1 || morir "hace falta python3"
command -v sqlite3 >/dev/null 2>&1 || morir "hace falta sqlite3"

# Un solo proceso a la vez
mkdir -p "$ESTADO_LOCAL_DIR" || morir "no puedo crear $ESTADO_LOCAL_DIR"
if command -v flock >/dev/null 2>&1; then
    exec 8>"$LOCK_FILE"
    flock -n 8 || { avisar "ℹ️  Ya hay una sincronización en curso."; exit 0; }
fi

preparar_comun
leer_local

case "$ACCION" in
    auto)   hacer_import; hacer_export ;;
    import) hacer_import ;;
    export) hacer_export ;;
    estado) mostrar_estado ;;
    semilla) hacer_export ;;
    listar-historico) listar_historico ;;
    restaurar) restaurar_historico "$HOST_REST" "$EPOCH_REST" ;;
esac
