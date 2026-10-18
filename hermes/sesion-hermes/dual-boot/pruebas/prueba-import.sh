#!/usr/bin/env bash
# Prueba en seco del import del motor dual-boot.
# Verifica dos cosas sobre un LABORATORIO en scratch (no toca el estado real):
#   1) que el import INTEGRA en vez de sustituir: ninguna conversación local se pierde
#      y la sesión que solo existe en el otro equipo entra;
#   2) que NO pisa el SOUL.md local cuando el publicado difiere: lo archiva y avisa.
# Uso: bash prueba-import.sh
set -u
MOTOR="${MOTOR:-$HOME/Config/hermes/dual-boot/hermes-dual-sync.sh}"
BASE="${BASE:-$HOME/.hermes/state.db}"
COMUN="${COMUN:-/mnt/seagate/HermesSync}"
LAB="${LAB:-$HOME/.hermes/cache/scratch/prueba-import}"
fallo=0

rm -rf "$LAB"; mkdir -p "$LAB/lab" "$LAB/com/estado" "$LAB/com/scripts"

echo "1) Preparando el laboratorio…"
sqlite3 "$BASE" ".backup '$LAB/lab/state.db'"
cp "$LAB/lab/state.db" "$LAB/com/estado/state.db"

# La "publicación del otro": sin los 5 últimos mensajes de la sesión más reciente
SID="$(sqlite3 "$LAB/com/estado/state.db" "SELECT session_id FROM messages GROUP BY session_id ORDER BY MAX(timestamp) DESC LIMIT 1;")"
sqlite3 "$LAB/com/estado/state.db" "DELETE FROM messages WHERE id IN (SELECT id FROM messages WHERE session_id='$SID' ORDER BY id DESC LIMIT 5);"
# … y con una sesión que solo existe en el otro equipo
sqlite3 "$LAB/com/estado/state.db" "INSERT INTO sessions (id,source,started_at,message_count) VALUES ('SESION-SOLO-DEL-OTRO','desktop',strftime('%s','now'),1);
INSERT INTO messages (session_id,role,content,timestamp,display_order) VALUES ('SESION-SOLO-DEL-OTRO','user','mensaje que solo existe en el otro equipo',strftime('%s','now'),1);"

# SOUL.md distintos a propósito (local ≠ publicado)
printf 'LOCAL: identidad de Antonio en Linux\n' > "$LAB/lab/SOUL.md"
printf 'COMUN: regla neutra del SO\n' > "$LAB/com/estado/SOUL.md"
cp "$COMUN/scripts/fusionar-mensajes.py" "$LAB/com/scripts/"

python3 - "$LAB/com/estado/state.db" "$LAB/com/estado/MANIFEST.json" <<'PY'
import hashlib, json, sqlite3, sys, time
bd, salida = sys.argv[1], sys.argv[2]
c = sqlite3.connect(bd)
s = c.execute("select count(*) from sessions").fetchone()[0]
m = c.execute("select count(*) from messages").fetchone()[0]
c.close()
with open(bd, "rb") as fh:
    sha = hashlib.sha256(fh.read()).hexdigest()
json.dump({"protocolo": 1, "host": "PC-ANTONIO", "publicado_epoch": int(time.time()),
           "sesiones": s, "mensajes": m, "sha256_state_db": sha},
          open(salida, "w", encoding="utf-8"), indent=2)
print(f"   publicación simulada: {s} sesiones / {m} mensajes")
PY

antes_msg="$(sqlite3 "$LAB/lab/state.db" 'select count(*) from messages;')"
antes_sid="$(sqlite3 "$LAB/lab/state.db" "select count(*) from messages where session_id='$SID';")"
antes_soul="$(sha256sum "$LAB/lab/SOUL.md" | cut -c1-16)"

echo "2) Ejecutando el import sobre el laboratorio…"
env HERMES_HOME="$LAB/lab" bash "$MOTOR" import --forzar --comun "$LAB/com" 2>&1 | sed 's/^/   /'

despues_msg="$(sqlite3 "$LAB/lab/state.db" 'select count(*) from messages;')"
despues_sid="$(sqlite3 "$LAB/lab/state.db" "select count(*) from messages where session_id='$SID';")"
despues_soul="$(sha256sum "$LAB/lab/SOUL.md" | cut -c1-16)"
otro_insertada="$(sqlite3 "$LAB/lab/state.db" "select count(*) from sessions where id='SESION-SOLO-DEL-OTRO';")"
archivado="$(find "$LAB/lab/.dual-sync/backups" -name "SOUL.md.de-PC-ANTONIO" 2>/dev/null | head -1)"

echo
echo "3) Resultados"
echo "   mensajes: $antes_msg → $despues_msg"
echo "   sesión más reciente ($SID): $antes_sid → $despues_sid"
echo "   sesión exclusiva del otro importada: $otro_insertada (esperado 1)"
echo "   SOUL.md local: $antes_soul → $despues_soul (debe ser igual)"
[ -n "$archivado" ] && echo "   SOUL.md del otro archivado en: ${archivado#$LAB/}" || { echo "   ✗ NO se archivó el SOUL.md del otro"; fallo=1; }

[ "$despues_msg" -ge "$antes_msg" ] || { echo "   ✗ SE HAN PERDIDO MENSAJES"; fallo=1; }
[ "$despues_sid" -eq "$antes_sid" ] || { echo "   ✗ la sesión más reciente perdió mensajes"; fallo=1; }
[ "$otro_insertada" -eq 1 ] || { echo "   ✗ no llegó la sesión del otro equipo"; fallo=1; }
[ "$antes_soul" = "$despues_soul" ] || { echo "   ✗ el SOUL.md local fue pisado"; fallo=1; }
if [ "$fallo" -eq 0 ]; then echo; echo "✅ PRUEBA SUPERADA"; else echo; echo "❌ PRUEBA FALLIDA"; fi
exit "$fallo"
