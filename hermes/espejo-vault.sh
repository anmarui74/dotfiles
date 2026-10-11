#!/usr/bin/env bash
# Atajo del espejador de markdown de configuración → vault de Obsidian.
# Lo llaman hermes-espejo-vault.service (disparado por hermes-espejo-vault.path) y el atajo
# `espejo-vault` de ~/.local/bin. Detalle: ~/Config/hermes/AGENTS.md.
set -uo pipefail
exec python3 "$(dirname "$(readlink -f "$0")")/espejo-vault.py" "$@"
