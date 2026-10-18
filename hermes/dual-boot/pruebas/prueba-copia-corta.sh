#!/usr/bin/env bash
# Prueba: si la copia de state.db sale CORTA, el motor debe ABORTAR sin publicar.
# Se simula con un `sqlite3` falso en el PATH que, al contar el temporal que se va a publicar,
# devuelve 2 mensajes de menos (es exactamente lo que pasó el 14/10/2026: la publicación viajó 2
# mensajes corta y el MANIFEST quedó coherente consigo mismo, así que nadie lo notó).
# Uso: bash prueba-copia-corta.sh
set -u
MOTOR="${MOTOR:-$HOME/Config/hermes/dual-boot/hermes-dual-sync.sh}"
LAB="${LAB:-$HOME/.hermes/cache/scratch/prueba-corta}"
REAL_SQLITE="$(command -v sqlite3)"
fallo=0

rm -rf "$LAB"; mkdir -p "$LAB/home/.dual-sync" "$LAB/com/estado" "$LAB/com/historial" "$LAB/falso"
sqlite3 "$HOME/.hermes/state.db" ".backup '$LAB/home/state.db'"
cp "$LAB/home/state.db" "$LAB/com/estado/state.db"
viva=$(sqlite3 "$LAB/home/state.db" 'select count(*) from messages;')

python3 - "$LAB/com/estado/MANIFEST.json" "$viva" <<'PY'
import json, sys, time
json.dump({"protocolo": 1, "host": "cachyos", "publicado_epoch": int(time.time()) - 86400,
           "sesiones": 1, "mensajes": int(sys.argv[2]), "sha256_state_db": "x"},
          open(sys.argv[1], "w", encoding="utf-8"), indent=2)
PY

# --- sqlite3 falso: al contar el temporal .tmp devuelve 2 menos ---
cat > "$LAB/falso/sqlite3" <<EOF
#!/usr/bin/env bash
if [[ "\$*" == *state.db.tmp* && "\$*" == *COUNT*FROM*messages* ]]; then
    n=\$("$REAL_SQLITE" "\$@")
    echo \$((n - 2))
    exit 0
fi
exec "$REAL_SQLITE" "\$@"
EOF
chmod +x "$LAB/falso/sqlite3"

echo "1) Base viva: $viva mensajes. Ejecutando el motor con el sqlite3 que simula copia corta…"
sha_antes=$(sha256sum "$LAB/com/estado/state.db" | cut -c1-12)
salida=$(env HERMES_HOME="$LAB/home" PATH="$LAB/falso:$PATH" bash "$MOTOR" export --comun "$LAB/com" --sin-import 2>&1)
rc=$?
echo "$salida" | sed 's/^/   /'
sha_despues=$(sha256sum "$LAB/com/estado/state.db" | cut -c1-12)

echo
echo "2) Resultados"
echo "   código de salida del motor: $rc (esperado != 0)"
echo "   estado/state.db publicado: $sha_antes → $sha_despues (no debe haber cambiado)"
echo "   ¿dijo que no publicaba?  $(grep -c 'NO publico un estado incompleto' <<<"$salida") (esperado >= 1)"

[ "$rc" -ne 0 ] || { echo "   ✗ el motor salió con 0: habría publicado"; fallo=1; }
[ "$sha_antes" = "$sha_despues" ] || { echo "   ✗ el estado publicado cambió pese a la copia corta"; fallo=1; }
grep -q 'NO publico un estado incompleto' <<<"$salida" || { echo "   ✗ no avisó del motivo"; fallo=1; }

# --- y con el sqlite3 de verdad, publica con normalidad ---
echo "3) Control: con el sqlite3 real debe publicar sin problema…"
env HERMES_HOME="$LAB/home" PATH="$PATH" bash "$MOTOR" export --comun "$LAB/com" --sin-import --quiet >/dev/null 2>&1
rc2=$?
publicados=$(sqlite3 "$LAB/com/estado/state.db" 'select count(*) from messages;' 2>/dev/null || echo 0)
echo "   código: $rc2 (esperado 0) · mensajes publicados: $publicados (esperado >= $viva)"
[ "$rc2" -eq 0 ] || { echo "   ✗ con sqlite3 real no publica"; fallo=1; }
[ "$publicados" -ge "$viva" ] || { echo "   ✗ la publicación real sale corta"; fallo=1; }

if [ "$fallo" -eq 0 ]; then echo; echo "✅ PRUEBA SUPERADA"; else echo; echo "❌ PRUEBA FALLIDA"; fi
exit "$fallo"
