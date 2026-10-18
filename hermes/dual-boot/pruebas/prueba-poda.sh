#!/usr/bin/env bash
# Prueba en seco de la PODA del historial (misma regla en los dos motores).
# Regla: se conservan las 15 publicaciones más recientes de cada equipo; NUNCA se borra nada con
# menos de 7 días; se borra la publicación COMPLETA (ficheros, sidecars y directorios 'resto');
# la última publicación nunca se toca.
# Monta un historial sintético en un laboratorio y ejecuta el motor de verdad contra él.
# Uso: bash prueba-poda.sh
set -u
MOTOR="${MOTOR:-$HOME/Config/hermes/dual-boot/hermes-dual-sync.sh}"
LAB="${LAB:-$HOME/.hermes/cache/scratch/prueba-poda}"
AHORA=$(date +%s)
fallo=0

rm -rf "$LAB"; mkdir -p "$LAB/home" "$LAB/com/estado" "$LAB/com/historial/PC-ANTONIO" "$LAB/com/historial/cachyos"
sqlite3 "$HOME/.hermes/state.db" ".backup '$LAB/home/state.db'"
cp "$LAB/home/state.db" "$LAB/com/estado/state.db"

# equipo PC-ANTONIO: 20 publicaciones ANTIGUAS (>7 días) + 1 reciente  → 6 deben borrarse
for i in $(seq 1 20); do
    ep=$(( AHORA - 10*86400 - i*600 ))
    touch "$LAB/com/historial/PC-ANTONIO/$ep-state.db" "$LAB/com/historial/PC-ANTONIO/$ep-resto.zip" \
          "$LAB/com/historial/PC-ANTONIO/$ep-state.db-wal" "$LAB/com/historial/PC-ANTONIO/$ep-state.db-shm"
done
# al más antiguo le ponemos un 'resto' DESCOMPRIMIDO (directorio), que es lo que `rm -f` no borraba
VIEJO_DIR=$(( AHORA - 10*86400 - 20*600 ))
mkdir -p "$LAB/com/historial/PC-ANTONIO/$VIEJO_DIR-resto/sessions"
touch "$LAB/com/historial/PC-ANTONIO/$VIEJO_DIR-resto/sessions/x.json"
# y una publicación reciente de ese equipo (la última): no debe tocarse nunca
RECIENTE_PC=$(( AHORA - 300 ))
touch "$LAB/com/historial/PC-ANTONIO/$RECIENTE_PC-state.db" "$LAB/com/historial/PC-ANTONIO/$RECIENTE_PC-resto.zip"

# equipo cachyos: 18 publicaciones RECIENTES (<7 días) → pasan de la retención pero no se tocan
for i in $(seq 1 18); do
    ep=$(( AHORA - 3600 - i*60 ))
    touch "$LAB/com/historial/cachyos/$ep-state.db" "$LAB/com/historial/cachyos/$ep-resto.zip"
done

# manifiesto del propio equipo (para que el export no intente importar nada)
python3 - "$LAB/com/estado/state.db" "$LAB/com/estado/MANIFEST.json" <<'PY'
import hashlib, json, sqlite3, sys, time
bd, salida = sys.argv[1], sys.argv[2]
c = sqlite3.connect(bd)
s = c.execute("select count(*) from sessions").fetchone()[0]
m = c.execute("select count(*) from messages").fetchone()[0]
c.close()
sha = hashlib.sha256(open(bd, "rb").read()).hexdigest()
json.dump({"protocolo": 1, "host": "cachyos", "publicado_epoch": int(time.time()) - 86400,
           "sesiones": s, "mensajes": m, "sha256_state_db": sha},
          open(salida, "w", encoding="utf-8"), indent=2)
PY

antes_pc=$(ls -1 "$LAB/com/historial/PC-ANTONIO" | sed -n 's/^\([0-9]\{9,\}\)-.*/\1/p' | sort -u | wc -l)
antes_ca=$(ls -1 "$LAB/com/historial/cachyos" | sed -n 's/^\([0-9]\{9,\}\)-.*/\1/p' | sort -u | wc -l)
echo "1) Antes de podar: PC-ANTONIO=$antes_pc publicaciones · cachyos=$antes_ca publicaciones"

echo "2) Ejecutando el motor real (export) contra el laboratorio…"
env HERMES_HOME="$LAB/home" bash "$MOTOR" export --comun "$LAB/com" --sin-import --quiet 2>&1 | sed 's/^/   /' | tail -3

despues_pc=$(ls -1 "$LAB/com/historial/PC-ANTONIO" | sed -n 's/^\([0-9]\{9,\}\)-.*/\1/p' | sort -u | wc -l)
despues_ca=$(ls -1 "$LAB/com/historial/cachyos" | sed -n 's/^\([0-9]\{9,\}\)-.*/\1/p' | sort -u | wc -l)
queda_ultima=$(ls -1 "$LAB/com/historial/PC-ANTONIO/$RECIENTE_PC"-* 2>/dev/null | wc -l)
queda_dir=$(ls -1d "$LAB/com/historial/PC-ANTONIO/$VIEJO_DIR"-* 2>/dev/null | wc -l)
sueltos=$(ls -1 "$LAB/com/historial/PC-ANTONIO" | grep -c -- "-resto.zip" || true)

echo
echo "3) Resultados"
echo "   PC-ANTONIO: $antes_pc → $despues_pc publicaciones (esperado 15: se conservan las 15 más recientes)"
echo "   cachyos:    $antes_ca → $despues_ca publicaciones (esperado 18: todas son de <7 días)"
echo "   la última de PC-ANTONIO ($RECIENTE_PC): $queda_ultima ficheros (esperado 2, intacta)"
echo "   el 'resto' descomprimido de la publicación antigua: $queda_dir ficheros (esperado 0, borrado con -r)"
echo "   '-resto.zip' sueltos que quedan: $sueltos (ninguna publicación puede quedar a medias)"

[ "$despues_pc" -eq 15 ] || { echo "   ✗ la retención de PC-ANTONIO no queda en 15"; fallo=1; }
[ "$despues_ca" -eq 18 ] || { echo "   ✗ se ha borrado algo con menos de 7 días"; fallo=1; }
[ "$queda_ultima" -eq 2 ] || { echo "   ✗ la última publicación se tocó"; fallo=1; }
[ "$queda_dir" -eq 0 ] || { echo "   ✗ el directorio 'resto' NO se borró (bug de rm -f)"; fallo=1; }
if [ "$fallo" -eq 0 ]; then echo; echo "✅ PRUEBA SUPERADA"; else echo; echo "❌ PRUEBA FALLIDA"; fi
exit "$fallo"
