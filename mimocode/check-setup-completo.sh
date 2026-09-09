#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sesion-mimocode"
CONFIG_SRC="${ROOT_DIR}/config"
echo "=== Check setup MiMoCode ==="
[ -d "${CONFIG_SRC}" ] && echo "OK config src" || { echo "FALTAN archivos de config"; exit 1; }
[ -f "${ROOT_DIR}/setup-mimocode-completo.sh" ] && echo "OK setup script" || { echo "Falta setup script"; exit 1; }
echo "Check completado. Ejecuta ${ROOT_DIR}/setup-mimocode-completo.sh para instalar desde cero"
