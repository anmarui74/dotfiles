#!/usr/bin/env bash
# hermes-modelos-viables.sh — atajo del comprobador de modelos viables de Hermes.
# Toda la lógica está en hermes-modelos-viables.py (ver ~/Config/hermes/AGENTS.md).
exec python3 "$(dirname "$(readlink -f "$0")")/hermes-modelos-viables.py" "$@"
