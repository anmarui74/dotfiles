#!/usr/bin/env bash
# Poda del historial del dual boot (MISMA regla que aplican los motores al publicar):
#   - conserva las RETENCION publicaciones más recientes de cada equipo;
#   - NUNCA borra nada con menos de DIAS_MIN_PODA días, aunque se pase del número;
#   - borra la publicación COMPLETA (todos los ficheros de ese instante): media copia no restaura;
#   - nunca toca la última publicación.
# Indicación de Antonio, 13/10/2026 (15 publicaciones, mínimo 7 días).
#
# Uso:
#   podar-historico.sh --simular    # solo cuenta lo que borraría
#   podar-historico.sh              # lo borra de verdad
set -u

RETENCION=${RETENCION:-15}
DIAS_MIN_PODA=${DIAS_MIN_PODA:-7}
SIMULAR=no
[ "${1:-}" = "--simular" ] && SIMULAR=si

COMUN=""
for c in /mnt/seagate/HermesSync /run/media/seagate/HermesSync; do
    [ -f "$c/.hermes-sync" ] && { COMUN="$c"; break; }
done
if [ -z "$COMUN" ]; then
    echo "No encuentro la carpeta compartida del dual boot" >&2
    exit 1
fi

limite=$(( $(date +%s) - DIAS_MIN_PODA * 86400 ))
echo "Poda del historial en $COMUN (retención: ${RETENCION} publicaciones, mínimo ${DIAS_MIN_PODA} días)"
[ "$SIMULAR" = si ] && echo "MODO SIMULACIÓN: no se borra nada"
total=0

for h in $(ls -1 "$COMUN/historial" 2>/dev/null); do
    [ -d "$COMUN/historial/$h" ] || continue
    pubs=0
    borradas=0
    while read -r ep; do
        [ -n "$ep" ] || continue
        pubs=$((pubs + 1))
        [ "$pubs" -le "$RETENCION" ] && continue      # dentro de la retención
        [ "$ep" -ge "$limite" ] && continue           # reciente: no se toca
        n=$(ls -1 "$COMUN/historial/$h/$ep"-* 2>/dev/null | wc -l)
        echo "  $h: borrar publicación $(date -d "@$ep" '+%d/%m/%Y %H:%M') ($n ficheros)"
        [ "$SIMULAR" = si ] || rm -rf "$COMUN/historial/$h/$ep"-*   # -r: los 'resto' descomprimidos son directorios
        borradas=$((borradas + 1))
    done < <(ls -1 "$COMUN/historial/$h" 2>/dev/null | grep -oE '^[0-9]{9,}' | sort -unr)
    quedan=$(ls -1 "$COMUN/historial/$h" 2>/dev/null | grep -oE '^[0-9]{9,}' | sort -u | wc -l)
    echo "  $h: $borradas borradas · quedan $quedan publicaciones"
    total=$((total + borradas))
done

echo "Total: $total publicaciones borradas"
