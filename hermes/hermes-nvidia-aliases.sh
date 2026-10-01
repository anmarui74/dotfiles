#!/usr/bin/env bash
# hermes-nvidia-aliases.sh — atajo del sincronizador de alias NVIDIA de Hermes.
# Toda la lógica está en hermes-nvidia-aliases.py (ver ~/Config/hermes/AGENTS.md).
exec python3 "$(dirname "$(readlink -f "$0")")/hermes-nvidia-aliases.py" "$@"
