#!/usr/bin/env bash
# ============================================================
# check-setup-completo.sh — Verificación OBLIGATORIA del
# setup-opencode-completo.sh ANTES de cada backup.
#
# Comprueba que el setup:
#  1. Tiene sintaxis válida (bash -n)
#  2. Pasa shellcheck sin errores reales (SC2016 en heredocs = OK)
#  3. TODOS los heredocs embebidos == archivos activos (uno a uno)
#  4. Contiene la estructura completa de pasos (1-19 + sub-pasos)
#  5. Los comandos que usa existen en el sistema
#
# Este script se ejecuta AUTOMÁTICAMENTE desde backup-opencode.sh.
# Si falla algún punto, el backup se ABORTA (no se genera tarball).
# ============================================================

SETUP="$HOME/Config/opencode/sesion-opencode/setup-opencode-completo.sh"
ACTIVO="$HOME/.config/opencode"
LOG="$HOME/.config/opencode/data/setup-check.log"

log() { echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" | tee -a "$LOG"; }

ERRORS=0
WARNINGS=0

mkdir -p "$(dirname "$LOG")"
log "═══════════ VERIFICACIÓN DEL SETUP ═══════════"
log "Setup: $SETUP"

# ─── 1. ¿Existe el setup? ───
if [ ! -f "$SETUP" ]; then
    log "❌ ERROR: No existe $SETUP"
    log "El backup se ABORTA."
    exit 1
fi
log "✅ Setup encontrado ($(wc -l < "$SETUP") líneas)"

# ─── 2. Sintaxis (bash -n) ───
if bash -n "$SETUP" 2>/dev/null; then
    log "✅ Sintaxis válida (bash -n)"
else
    log "❌ ERROR: Sintaxis inválida"
    ERRORS=$((ERRORS+1))
fi

# ─── 3. Shellcheck (solo errores/warnings reales; SC2016 info = OK) ───
SC_OUT=$(shellcheck "$SETUP" 2>&1 | grep -E "SC[0-9]+" || true)
SC_INFO=$(echo "$SC_OUT" | grep -c "SC2016" || true)
SC_OTHER=$(echo "$SC_OUT" | grep -vE "SC2016" | grep -c "SC[0-9]+" || true)
if [ "$SC_OTHER" -gt 0 ] 2>/dev/null; then
    log "❌ ERROR: shellcheck reporta $SC_OTHER avisos no-SC2016"
    ERRORS=$((ERRORS+1))
else
    log "✅ Shellcheck limpio (${SC_INFO:-0} notas SC2016 intencionales, 0 errores)"
fi

# ─── 4. Estructura de pasos (1-19 + sub-pasos) ───
PASOS=$(grep -c '# PASO' "$SETUP")
if [ "$PASOS" -ge 19 ] 2>/dev/null; then
    log "✅ Estructura completa ($PASOS pasos)"
else
    log "❌ ERROR: Solo $PASOS pasos (esperado >= 19)"
    ERRORS=$((ERRORS+1))
fi

# ─── 5. Heredocs embebidos vs archivos activos (UNO A UNO) ───
# Usamos python3 para comparar byte a byte
HERE_RESULT=$(python3 - "$SETUP" "$ACTIVO" << 'PYEOF'
import re, json, sys

setup_path = sys.argv[1]
activo_dir = sys.argv[2]

with open(setup_path) as f:
    c = f.read()

def extract(delim):
    marker = f"<< '{delim}'\n"
    if marker not in c: return None
    start = c.index(marker) + len(marker)
    end = c.index(f"\n{delim}", start)
    return c[start:end+1]

def norm(s): return json.dumps(json.loads(s), sort_keys=True)

# Mapeo archivo -> delimitador (TODOS los embebidos en ~/.config/opencode)
archivos = {
    'opencode.json': 'JSONEOF', 'opencode-local.json': 'LOCALEOF', 'opencode-cloud.json': 'CLOUDEOF',
    'tui.json': 'TUIEOF',
    'AGENTS.md': 'AGEOF', '.env': 'ENVEOF',
    'sync-opencode.sh': 'SYNCEOF',
    'init-opencode.sh': 'INITEOF', 'start-lmstudio-server.sh': 'SERVEREOF',
    'start-lmstudio.sh': 'LMSEOF', 'start-opencode-server.sh': 'STARTEOF',
    'start-opencode.sh': 'OPENCODEEOF', 'hardware-query.sh': 'HARDWARE-QUERY_SHEOF',
    'hardware-query.py': 'HARDWARE-QUERY_PYEOF',
    'check-fix.sh': 'CHECK-FIX_SHEOF', 'check-timeline-fix.sh': 'TIMELINE-FIX_SHEOF',
    'lmstudio-proxy.py': 'LMPROXYEOF', 'lmstudio-metrics-server.py': 'METRICSSRVEOF',
    'backup-opencode.sh': 'BKUEOF', 'bootstrap-ocv.sh': 'BOOTEOF',
    'settings.lmstudio.json': 'LMSETEOF',
    'package.json': 'ROOTPKGEOF',
}

# Archivos embebidos fuera de activo_dir (con su ruta real)
extra_archivos = [
    ('timeline-completo', 'TIMELINE_SHEOF', '/home/antonio/.local/bin/timeline-completo'),
    ('speak', 'SPEAKEOF', '/home/antonio/.local/bin/speak'),
    ('package.json (plugin voz)', 'PLUGPKG', '/home/antonio/.config/opencode/opencode-voice-modified/package.json'),
    ('plugin voz index.js', 'PLUGINJS', '/home/antonio/.config/opencode/opencode-voice-modified/index.js'),
    ('plugin voz lib/stt.js', 'STTJS', '/home/antonio/.config/opencode/opencode-voice-modified/lib/stt.js'),
    ('plugin voz lib/tts.js', 'TTSJS', '/home/antonio/.config/opencode/opencode-voice-modified/lib/tts.js'),
    ('plugin voz lib/logger.js', 'LOGGERJS', '/home/antonio/.config/opencode/opencode-voice-modified/lib/logger.js'),
    ('plugin voz lib/session.js', 'SESSIONJS', '/home/antonio/.config/opencode/opencode-voice-modified/lib/session.js'),
    ('plugin voz lib/llm-client.js', 'LLMCLIENTJS', '/home/antonio/.config/opencode/opencode-voice-modified/lib/llm-client.js'),
    ('systemd check-opencode-fix.service', 'CHKFIXSERVEOF', '/home/antonio/.config/systemd/user/check-opencode-fix.service'),
    ('systemd check-opencode-fix.timer', 'CHKFIXTIMEREOF', '/home/antonio/.config/systemd/user/check-opencode-fix.timer'),
]

ok = 0
fails = []
for fname, delim in archivos.items():
    emb = extract(delim)
    act_path = f"{activo_dir}/{fname}"
    if emb is None:
        fails.append(f"{fname} (heredoc {delim} no encontrado)")
        continue
    try:
        with open(act_path) as f:
            act = f.read()
    except FileNotFoundError:
        fails.append(f"{fname} (no existe en activo)")
        continue
    if fname.endswith('.json'):
        match = norm(emb) == norm(act)
    else:
        match = emb == act
    if match:
        ok += 1
    else:
        fails.append(f"{fname} (DIFIERE: activo {len(act)} vs embebido {len(emb)} chars)")

for fname, delim, path in extra_archivos:
    emb = extract(delim)
    if emb is None:
        fails.append(f"{fname} (heredoc {delim} no encontrado)")
        continue
    try:
        with open(path) as f:
            act = f.read()
    except FileNotFoundError:
        fails.append(f"{fname} (no existe en {path})")
        continue
    if emb == act:
        ok += 1
    else:
        fails.append(f"{fname} (DIFIERE: activo {len(act)} vs embebido {len(emb)} chars)")

total = len(archivos) + len(extra_archivos)
print(f"OK:{ok}")
print(f"TOTAL:{total}")
for f in fails:
    print(f"FAIL:{f}")
PYEOF
)

HERE_OK=$(echo "$HERE_RESULT" | grep "^OK:" | cut -d: -f2)
HERE_TOTAL=$(echo "$HERE_RESULT" | grep "^TOTAL:" | cut -d: -f2)
HERE_FAILS=$(echo "$HERE_RESULT" | grep "^FAIL:" | sed 's/^FAIL://')

if [ -z "$HERE_OK" ]; then
    log "❌ ERROR: La comparación de heredocs falló (python)"
    ERRORS=$((ERRORS+1))
elif [ -n "$HERE_FAILS" ]; then
    log "❌ ERROR: ${HERE_FAILS}"
    ERRORS=$((ERRORS+1))
else
    log "✅ Heredocs embebidos: ${HERE_OK}/${HERE_TOTAL:-0} coinciden con el activo"
fi

# ─── 6. Comandos que usa el setup existen ───
MISSING=""
for cmd in pkexec pacman pipx npm rustup go curl git sqlite3 systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING="$MISSING $cmd"
    fi
done
if [ -n "$MISSING" ]; then
    log "❌ ERROR: Comandos faltantes:$MISSING"
    ERRORS=$((ERRORS+1))
else
    log "✅ Comandos necesarios presentes (pkexec, pacman, pipx, npm, rustup, go, curl, git, sqlite3, systemctl)"
fi

# ─── Resultado final ───
if [ "$ERRORS" -gt 0 ]; then
    log "❌❌❌ VERIFICACIÓN FALLIDA ($ERRORS errores) — EL BACKUP SE ABORTA ❌❌❌"
    exit 1
else
    log "✅✅✅ VERIFICACIÓN COMPLETA: SETUP CORRECTO — SE PUEDE HACER EL BACKUP ✅✅✅"
    exit 0
fi
