#!/usr/bin/env bash
# hermes-auditoria-manual.sh — atajo del auditor del esquema de Hermes.
# Toda la lógica está en hermes-auditoria-manual.py (ver ~/Config/hermes/AGENTS.md).
# Devuelve 0 si el manual, el espejo, las copias y el sistema están coherentes; 1 si hay desfases.
exec python3 "$(dirname "$(readlink -f "$0")")/hermes-auditoria-manual.py" "$@"
