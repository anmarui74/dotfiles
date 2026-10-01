#!/usr/bin/env bash
# backup-hermes.sh — Hook de Hermes (Windows) para el evento on_session_end.
#
# Regenera el backup del equipo cuando se cierra una sesión de Hermes: refresca el respaldo
# canónico (sesion-hermes) y el ZIP en el disco compartido. El payload del hook llega por stdin
# y no se necesita.
#
# Nunca debe bloquear el cierre de la sesión: siempre sale con 0.
set -u

cat >/dev/null 2>&1 || true

for L in d e f g h i j k; do
    raiz="/$L/Linux/Config/Hermes-Win"
    if [ -d "$raiz" ]; then
        # powershell.exe es un ejecutable nativo: necesita ruta estilo Windows
        if command -v cygpath >/dev/null 2>&1; then
            script="$(cygpath -w "$raiz/sync-hermes.ps1")"
        else
            script="$raiz/sync-hermes.ps1"
        fi
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$script" -Quiet >/dev/null 2>&1
        break
    fi
done

exit 0
