#!/usr/bin/env bash
#==============================================================================
# instalar-montaje.sh — Deja el disco compartido (SEAGATE) montado de forma
# permanente en /mnt/seagate para la sincronización de Hermes entre Linux y Windows.
#
# Hay que ejecutarlo como root:
#   pkexec bash ~/Config/hermes/dual-boot/instalar-montaje.sh
#==============================================================================
set -euo pipefail

UUID="A472BB2A72BB005A"       # partición NTFS del disco SEAGATE (datos compartidos)
PUNTO="/mnt/seagate"
USUARIO="${SUDO_USER:-antonio}"
UID_USUARIO="$(id -u "$USUARIO")"
GID_USUARIO="$(id -g "$USUARIO")"

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: hay que ejecutarlo como root (pkexec)." >&2
    exit 1
fi

LINEA="UUID=$UUID $PUNTO ntfs3 uid=$UID_USUARIO,gid=$GID_USUARIO,umask=022,noatime,prealloc,windows_names,nofail,x-systemd.automount,x-systemd.device-timeout=10 0 0"

cp -a /etc/fstab "/etc/fstab.bak-$(date +%Y%m%d-%H%M%S)"
echo "→ Copia de seguridad de /etc/fstab creada."

if grep -q "UUID=$UUID" /etc/fstab; then
    echo "→ La partición ya estaba en /etc/fstab; no se toca."
else
    printf '\n# Disco compartido Linux/Windows (sincronización de estado de Hermes)\n%s\n' "$LINEA" >> /etc/fstab
    echo "→ Añadida la entrada a /etc/fstab."
fi

mkdir -p "$PUNTO"
chown "$UID_USUARIO:$GID_USUARIO" "$PUNTO"
systemctl daemon-reload

if findmnt -rn -S "UUID=$UUID" -o TARGET | grep -q .; then
    echo "→ Ya había un montaje activo de la partición."
else
    mount "$PUNTO" && echo "→ Montado en $PUNTO." || echo "⚠️  No se ha podido montar ahora (se montará al acceder o en el próximo arranque)."
fi

echo "── Resultado ──────────────────────────────────────────"
findmnt "$PUNTO" || true
echo
grep -n "UUID=$UUID" /etc/fstab
