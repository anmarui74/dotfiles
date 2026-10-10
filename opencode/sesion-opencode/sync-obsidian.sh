#!/usr/bin/env bash
# sync-obsidian.sh — Espeja los manuales de configuración de OpenCode en el vault de Obsidian
# -------------------------------------------------------------------
# Uso:
#   bash sync-obsidian.sh            → comprueba y actualiza el vault
#   bash sync-obsidian.sh --check    → solo comprueba (no escribe; sale 1 si hay desfases)
#   bash sync-obsidian.sh --quiet    → salida mínima (para systemd/cron)
#   OBSIDIAN_VAULT=/ruta bash sync-obsidian.sh   → vault alternativo
#
# Transformación aplicada a cada manual (~/.config/opencode/documentacion/*.md):
#   1. Añade una línea en blanco al inicio.
#   2. Reescribe los enlaces relativos .md al nombre de la nota en Obsidian
#      ("💻 Título.md"), con los espacios como %20.
# -------------------------------------------------------------------
set -euo pipefail

CONFIG_DOC="${HOME}/.config/opencode/documentacion"
VAULT="${OBSIDIAN_VAULT:-${HOME}/MEGA/Obsidian/Obsidian/armarui74/OpenCode}"
LOG_FILE="${HOME}/.config/opencode/data/sync-obsidian.log"

MODE="apply"
QUIET=0
for a in "$@"; do
    case "$a" in
        --check|-n|--dry-run) MODE="check" ;;
        --quiet|-q) QUIET=1 ;;
    esac
done

if [ ! -d "$VAULT" ]; then
    echo "⚠️  Vault de Obsidian no encontrado: $VAULT" >&2
    echo "    Define OBSIDIAN_VAULT=/ruta/a/la/carpeta para otro vault." >&2
    exit 2
fi

export SYNC_OBS_CONFIG_DOC="$CONFIG_DOC"
export SYNC_OBS_VAULT="$VAULT"
export SYNC_OBS_MODE="$MODE"
export SYNC_OBS_LOG="$LOG_FILE"
export SYNC_OBS_QUIET="$QUIET"

python3 - << 'PYEOF'
import datetime
import os
import re
import sys

cfg_dir = os.environ["SYNC_OBS_CONFIG_DOC"]
vault = os.environ["SYNC_OBS_VAULT"]
mode = os.environ["SYNC_OBS_MODE"]
log_file = os.environ["SYNC_OBS_LOG"]
quiet = os.environ.get("SYNC_OBS_QUIET") == "1"

# Mapa: fichero en documentacion/  ->  nota en el vault de Obsidian
M = {
    "01-configuracion-ollama.md": "💻 01 Configuración de Ollama + Proxy.md",
    "02-configuracion-lmstudio.md": "💻 02 Configuración de LM Studio + Proxy.md",
    "03-configuracion-voz.md": "💻 03 Configuración Completa de Voz.md",
    "04-perfiles-opencode-json.md": "💻 04 Perfiles de opencode.json.md",
    "05-configuracion-adicional.md": "💻 05 Configuración Adicional.md",
    "06-agents-md.md": "💻 06 AGENTS.md.md",
    "07-playbook-recuperacion.md": "💻 07 Playbook de Recuperación.md",
    "08-incidencia-gpu-xid79.md": "💻 08 Incidencia GPU Xid 79.md",
    "09-informe-sistema.md": "💻 09 Informe del sistema.md",
    "hardware-info.md": "💻 Hardware del equipo.md",
    "README-hardware.md": "💻 README hardware.md",
    "notas-opencode-go.md": "💻 Notas OpenCode Go.md",
    "seguimiento-issue-memory.md": "💻 Seguimiento Issue MCP memory.md",
    "README.md": "💻 README.md",
    "../data/onlyoffice-ai/ONLYOFFICE-AI-OPENCODE.md": "💻 ONLYOFFICE AI + OpenCode.md",
}

def _link(m):
    t = m.group(1)
    return "](%s)" % M[t].replace(" ", "%20") if t in M else m.group(0)

def transform(txt):
    return "\n" + re.sub(r"\]\(([^)]*\.md)\)", _link, txt)

ok, cambiados, faltan = [], [], []
for cfg, vname in M.items():
    cpath = os.path.join(cfg_dir, cfg)
    if not os.path.exists(cpath):
        continue
    vpath = os.path.join(vault, vname)
    esperado = transform(open(cpath, encoding="utf-8").read())
    actual = None
    if os.path.exists(vpath):
        actual = open(vpath, encoding="utf-8").read()
    else:
        faltan.append(vname)
    if actual == esperado:
        ok.append(vname)
        continue
    cambiados.append(vname)
    if mode == "apply":
        with open(vpath, "w", encoding="utf-8") as f:
            f.write(esperado)
        os.chmod(vpath, 0o644)

nuevos = [n for n in cambiados if n in faltan]
act = [n for n in cambiados if n not in faltan]

if mode == "check":
    if not quiet:
        for n in ok:
            print(f"  ✅ {n}")
        for n in cambiados:
            print(f"  ⚠️  desfasado: {n}")
    print(f"Obsidian: {len(cambiados)} desfasado(s) · {len(ok)} al día")
else:
    if not quiet:
        for n in act:
            print(f"  🔄 actualizado: {n}")
        for n in nuevos:
            print(f"  🆕 creado: {n}")
    if cambiados or not quiet:
        print(f"Obsidian: {len(cambiados)} actualizado(s) · {len(ok)} al día")

# Registro en el log
try:
    with open(log_file, "a", encoding="utf-8") as f:
        ts = datetime.datetime.now().strftime("%d/%m/%Y %H:%M:%S")
        modo = "check" if mode == "check" else "apply"
        f.write(f"[{ts}] sync-obsidian ({modo}): {len(act)} actualizados, "
                f"{len(nuevos)} nuevos, {len(ok)} al día\n")
except OSError:
    pass

sys.exit(1 if (mode == "check" and cambiados) else 0)
PYEOF
