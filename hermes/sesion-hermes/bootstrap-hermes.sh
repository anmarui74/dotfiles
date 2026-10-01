#!/usr/bin/env bash
# bootstrap-hermes.sh — Acceso directo al instalador desde limpio.
# El instalador real (única copia en disco) vive en sesion-hermes/.
set -euo pipefail
exec bash "$HOME/Config/hermes/sesion-hermes/setup-hermes-completo.sh" "$@"
