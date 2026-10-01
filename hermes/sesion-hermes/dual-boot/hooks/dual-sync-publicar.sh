#!/usr/bin/env bash
# Hook de Hermes (evento on_session_end): publica el estado de este equipo en la
# carpeta compartida para que Windows lo recoja al arrancar. Ver ~/Config/hermes/AGENTS.md.
# Recibe el JSON del evento por stdin; se ignora deliberadamente.
cat >/dev/null 2>&1 || true
exec /home/antonio/.local/bin/hermes-dual-sync export --quiet --solo-si-cambia
