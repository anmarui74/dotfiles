#!/usr/bin/env bash
#==============================================================================
# instalar-volumen-ldm.sh — Deja montado y ordenado el volumen de un grupo
# dinámico (LDM) de Windows: el disco en espejo TOSHIBA (sdb + sdc, letra E:).
#
# Hace todo lo necesario, de forma idempotente:
#   1. Instala libldm (paquete que trae `ldmtool`) si falta.
#   2. Habilita `ldmtool.service`, que crea el mapeo en cada arranque.
#   3. Añade a /etc/fstab el volumen mapeado, montado en /mnt/toshiba
#      (por RUTA DEL MAPPER, nunca por UUID: los dos plexos comparten UUID).
#   4. Instala la regla udev que oculta los miembros del grupo a udisks/GNOME
#      (si no, Nautilus ofrece dos «TOSHIBA» que fallan al montar).
#
# Hay que ejecutarlo como root:
#   pkexec bash ~/Config/hermes/dual-boot/instalar-volumen-ldm.sh
#==============================================================================
set -euo pipefail

GRUPO="PC-ANTONIO-Dg0"
VOLUMEN="Volume1"
MAPPER="/dev/mapper/ldm_vol_${GRUPO}_${VOLUMEN}"
PUNTO="/mnt/toshiba"
ESQUEMA="$(dirname "$(readlink -f "$0")")"
REGLA="$ESQUEMA/90-ocultar-miembros-ldm.rules"
DESTINO_REGLA="/etc/udev/rules.d/90-ocultar-miembros-ldm.rules"
USUARIO="${SUDO_USER:-antonio}"
UID_USUARIO="$(id -u "$USUARIO")"
GID_USUARIO="$(id -g "$USUARIO")"
LINEA="$MAPPER $PUNTO ntfs3 rw,uid=$UID_USUARIO,gid=$GID_USUARIO,umask=022,noatime,prealloc,windows_names,nofail,x-systemd.automount,x-systemd.device-timeout=10,x-systemd.requires=ldmtool.service 0 0"

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: hay que ejecutarlo como root (pkexec)." >&2
    exit 1
fi

# 1. libldm -------------------------------------------------------------------
if command -v ldmtool >/dev/null 2>&1; then
    echo "→ ldmtool ya está instalado."
else
    echo "→ Instalando libldm (trae ldmtool)..."
    pacman -S --needed --noconfirm libldm
fi

# 2. Mapeo persistente --------------------------------------------------------
systemctl enable --now ldmtool.service >/dev/null
echo "→ ldmtool.service habilitado (crea el mapeo en cada arranque)."

if [ ! -e "$MAPPER" ]; then
    ldmtool create all >/dev/null 2>&1 || true
    udevadm settle --timeout=10 || true
fi
if [ -e "$MAPPER" ]; then
    echo "→ Mapeo presente: $MAPPER"
else
    echo "⚠️  El mapeo no existe todavía (¿están los discos conectados?). Se recreará en el próximo arranque."
fi

# 3. fstab --------------------------------------------------------------------
cp -a /etc/fstab "/etc/fstab.bak-$(date +%Y%m%d-%H%M%S)"
echo "→ Copia de seguridad de /etc/fstab creada."

if grep -q "^$MAPPER" /etc/fstab; then
    echo "→ El volumen ya estaba en /etc/fstab; no se toca."
else
    printf '\n# Volumen LDM de Windows (grupo %s, espejo sdb+sdc) — letra E:\n%s\n' "$GRUPO" "$LINEA" >> /etc/fstab
    echo "→ Añadida la entrada a /etc/fstab."
fi

mkdir -p "$PUNTO"
chown "$UID_USUARIO:$GID_USUARIO" "$PUNTO"
systemctl daemon-reload

# 4. Regla udev ---------------------------------------------------------------
if [ -f "$REGLA" ]; then
    cp -a "$REGLA" "$DESTINO_REGLA"
    chmod 0644 "$DESTINO_REGLA"
    udevadm control --reload-rules
    udevadm trigger --subsystem-match=block --settle
    echo "→ Regla udev instalada en $DESTINO_REGLA (Nautilus no ofrecerá los plexos)."
else
    echo "⚠️  No encuentro $REGLA; me salto la regla udev."
fi

# 5. Montaje y resultado ------------------------------------------------------
if findmnt -rn -S "$MAPPER" -o TARGET | grep -q .; then
    echo "→ Ya había un montaje activo del volumen."
else
    mount "$PUNTO" && echo "→ Montado en $PUNTO." || echo "⚠️  No se ha podido montar ahora (se montará al acceder o en el próximo arranque)."
fi

echo "── Resultado ──────────────────────────────────────────"
findmnt "$PUNTO" || true
echo
grep -n "$MAPPER" /etc/fstab
echo
echo "Comprobación de que udisks ya no ofrece los plexos:"
for d in /dev/sdb /dev/sdb3 /dev/sdc3; do
    printf '  %-12s ' "$(basename "$d")"
    udisksctl info -b "$d" 2>/dev/null | grep -i HintIgnore | tr -d ' ' || echo "(no encontrado)"
done
