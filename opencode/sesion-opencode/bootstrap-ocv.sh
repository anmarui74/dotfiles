#!/usr/bin/env bash
# ==============================================================
# Bootstrap script: OpenCode Voice (OCV) - instalación desde limpio
# ==============================================================
# Uso: chmod +x bootstrap-ocv.sh && ./bootstrap-ocv.sh
# ==============================================================
set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
PLUGIN_DIR="${CONFIG_DIR}/opencode-voice-modified"
LOCAL_BIN="${HOME}/.local/bin"
SHARE_DIR="${HOME}/.local/share"
WHISPER_DIR="${SHARE_DIR}/whisper-cpp"

log()  { echo -e "\e[1;32m[INFO]\e[0m $*"; }
warn() { echo -e "\e[1;33m[WARN]\e[0m $*"; }
err()  { echo -e "\e[1;31m[ERR]\e[0m $*" >&2; }

# ---- 0. Setup symlink libggml-cpu.so.0 (whisper-cli lo necesita) ----
setup_ggml_cpu_symlink() {
  local BIN_DIR="${SHARE_DIR}/whisper-cpp/bin"
  local VARIANT=""
  # Elegir la mejor variante de CPU disponible (Ryzen 9 7900 = Zen 4)
  for cand in zen4 alderlake skylakex icelake haswell cascadelake x64 sse42; do
    if [ -f "${BIN_DIR}/libggml-cpu-${cand}.so" ]; then
      VARIANT="${cand}"
      break
    fi
  done
  if [ -n "${VARIANT}" ] && [ -f "${BIN_DIR}/libggml-cpu-${VARIANT}.so" ]; then
    ln -sf "libggml-cpu-${VARIANT}.so" "${BIN_DIR}/libggml-cpu.so.0"
    ln -sf "libggml-cpu-${VARIANT}.so" "${BIN_DIR}/libggml-cpu.so"
    log "Symlink libggml-cpu.so.0 -> libggml-cpu-${VARIANT}.so"
  else
    warn "No se encontró variante libggml-cpu-*.so para crear el symlink"
  fi
}

# ---- 1. Dependencias del sistema ----
log "Instalando dependencias del sistema..."
pkexec apt-get update -qq
pkexec apt-get install -y -qq \
  sox \
  pulseaudio-utils \
  pipx \
  nodejs npm 2>/dev/null || {
  warn "Algunos paquetes no están disponibles en los repositorios, se instalarán por otros medios."
  pkexec apt-get install -y -qq sox pulseaudio-utils pipx nodejs npm 2>/dev/null || true
}

mkdir -p "${LOCAL_BIN}"

# whisper-cli desde release oficial (no disponible en apt)
WHISPER_BIN="${SHARE_DIR}/whisper-cpp/bin/whisper-cli"
if [ ! -x "${LOCAL_BIN}/whisper-cli" ]; then
  mkdir -p "${SHARE_DIR}/whisper-cpp/bin"
  # Opción A: compilar con CUDA si hay GPU y nvcc (transcripción rápida)
  if command -v nvcc >/dev/null 2>&1 && command -v cmake >/dev/null 2>&1 && command -v gcc >/dev/null 2>&1; then
    log "Compilando whisper.cpp con CUDA (transcripción por GPU)..."
    WHISPER_TMP="$(mktemp -d)"
    git clone --depth 1 --branch v1.9.1 "https://github.com/ggml-org/whisper.cpp" "${WHISPER_TMP}/whisper-src"
    cmake -B "${WHISPER_TMP}/whisper-src/build" \
      -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release \
      "${WHISPER_TMP}/whisper-src" 2>/dev/null
    cmake --build "${WHISPER_TMP}/whisper-src/build" --config Release -j "$(nproc)" 2>/dev/null || true
    if [ -x "${WHISPER_TMP}/whisper-src/build/bin/whisper-cli" ]; then
      cp "${WHISPER_TMP}/whisper-src/build/bin/whisper-cli" "${WHISPER_BIN}"
      cp -dP "${WHISPER_TMP}"/whisper-src/build/bin/libggml*.so* "${SHARE_DIR}/whisper-cpp/bin/" 2>/dev/null || true
      setup_ggml_cpu_symlink
      log "whisper.cpp compilado con CUDA"
    else
      warn "Falló la compilación CUDA, usando versión CPU"
    fi
    rm -rf "${WHISPER_TMP}"
  fi
  # Opción B: descargar binario CPU si no se compiló
  if [ ! -x "${WHISPER_BIN}" ]; then
    log "Descargando whisper.cpp v1.9.1 (CPU)..."
    WHISPER_TMP="$(mktemp -d)"
    curl -sL -o "${WHISPER_TMP}/whisper-bin.tar.gz" \
      "https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.1/whisper-bin-ubuntu-x64.tar.gz"
    tar -xzf "${WHISPER_TMP}/whisper-bin.tar.gz" -C "${WHISPER_TMP}"
    cp "${WHISPER_TMP}"/whisper-bin-ubuntu-x64/whisper-cli "${WHISPER_BIN}"
    cp "${WHISPER_TMP}"/whisper-bin-ubuntu-x64/*.so* "${SHARE_DIR}/whisper-cpp/bin/" 2>/dev/null || true
    setup_ggml_cpu_symlink
    rm -rf "${WHISPER_TMP}"
  fi
  cat > "${LOCAL_BIN}/whisper-cli" << 'WHISPEREOF'
#!/bin/bash
# Wrapper whisper-cli con CUDA: añade el directorio local a LD_LIBRARY_PATH
export LD_LIBRARY_PATH="/home/antonio/.local/share/whisper-cpp/bin:${LD_LIBRARY_PATH}"
exec /home/antonio/.local/share/whisper-cpp/bin/whisper-cli "$@"
WHISPEREOF
  chmod +x "${LOCAL_BIN}/whisper-cli"
  # Verificación: lanzar whisper-cli (debe resolver libggml-cpu.so.0)
  if "${LOCAL_BIN}/whisper-cli" --help >/dev/null 2>&1; then
    log "whisper-cli operativo (GPU/CUDA si hay nvidia)"
  else
    warn "whisper-cli no arranca: comprueba libggml*.so en ${SHARE_DIR}/whisper-cpp/bin"
  fi
fi

# ---- 2. edge-tts vía pipx ----
if ! pipx list 2>/dev/null | grep -q edge-tts; then
  log "Instalando edge-tts vía pipx..."
  pipx install edge-tts
else
  log "edge-tts ya instalado vía pipx"
fi

# ---- 3. Modelos whisper ----
log "Verificando modelos whisper..."
mkdir -p "${WHISPER_DIR}"

download_model() {
  local name="$1"
  local file="$2"
  if [ ! -f "${WHISPER_DIR}/${file}" ]; then
    log "Descargando modelo whisper: ${name}..."
    wget -q --show-progress \
      "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${file}" \
      -O "${WHISPER_DIR}/${file}"
  else
    log "Modelo ${name} ya presente"
  fi
}

download_model "large-v3-turbo-q5_0" "ggml-large-v3-turbo-q5_0.bin"
download_model "small"              "ggml-small.bin"
download_model "base"               "ggml-base.bin"

# ---- 4. Directorio del plugin ----
log "Creando plugin opencode-voice..."
mkdir -p "${PLUGIN_DIR}"

# ---- 5. plugin/package.json (instalación via npm) ----
cat > "${PLUGIN_DIR}/package.json" << 'EOF'
{
  "name": "@renjfk/opencode-voice",
  "version": "0.6.0",
  "description": "Speech-to-text and text-to-speech for OpenCode.",
  "license": "MIT",
  "type": "module",
  "main": "index.js",
  "exports": { ".": { "import": "./index.js" }, "./tui": { "import": "./index.js" } },
  "files": ["index.js", "lib"]
}
EOF

# ---- 6. script speak (edge-tts) ----
log "Instalando script speak..."
cat > "${LOCAL_BIN}/speak" << 'SPEAKEOF'
#!/usr/bin/env python3
import sys
import subprocess
import tempfile
import os
import re
import signal

ANSI_RE = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]|\x1b\][^\x1b]*\x1b\\|\x1b[PX^_]|[^\x1b]*\x1b\\|\x1b][0-9;]*[\x07\x1b]|\x1b[=<>FGH]|\x1b[NOPQ\\]')
BOX_RE = re.compile(r'[\u2500-\u257f\u2500-\u257f\u2580-\u259f\u25a0-\u25ff]')
EMOJI_RE = re.compile(
    '['
    '\U0001F300-\U0001F9FF'   # Pictogramas, emoticonos, transporte, banderas
    '\U0001FA00-\U0001FA6F'   # Símbolos de ajedrez
    '\U0001FA70-\U0001FAFF'   # Símbolos adicionales
    '\u2600-\u27BF'           # Misceláneos y dingbats (✅, ⚠, ☀, ✂, etc.)
    '\u2300-\u23FF'           # Técnicos misceláneos (⏳, ⌨, ⏩, etc.)
    '\u25A0-\u25FF'           # Formas geométricas (■, □, ▲, ▼)
    '\u2B05-\u2B55'           # Flechas y símbolos varios (⬅, ⬛, ⭐)
    '\u2934-\u2935'           # Flechas suplementarias
    '\u3030\u303D'            # Símbolos de onda y alternancia
    '\u3297\u3299'            # Felicitaciones y secreto
    '\uFE00-\uFE0F'           # Selectores de variación de emoji
    '\u200D'                  # Zero width joiner
    ']+'
)

VOICE = os.environ.get("SPEAK_VOICE", "es-ES-AlvaroNeural")
RATE = os.environ.get("SPEAK_RATE", "+5%")
PITCH = os.environ.get("SPEAK_PITCH", "+0Hz")

_current_paplay = None

def _sigterm_handler(signum, frame):
    global _current_paplay
    if _current_paplay and _current_paplay.poll() is None:
        _current_paplay.kill()
    sys.exit(0)

signal.signal(signal.SIGTERM, _sigterm_handler)

def clean_line(text):
    text = ANSI_RE.sub("", text)
    text = BOX_RE.sub("", text)
    text = EMOJI_RE.sub("", text)
    text = re.sub(r'[⬝■▣●▸▀▄╹┃╻━┏┓┗┛┣┫┳┻╋┠┨┷┯┥┝┰┱┲┳┴┵┶┷┸┹┺┻┼┽┾┿╀╁╂╃╄╅╆╇╈╉╊╋]+', '', text)
    text = re.sub(r'[▰▱▔▏▎▍▌▋▊▉]+', '', text)
    text = ' '.join(text.split())
    return text.strip()

def ensure_ending_punctuation(text):
    """Asegura que la linea termine con un punto para pausa natural"""
    if not text:
        return text
    if text[-1] in '.!?':
        return text
    # Si ya termina con ..., se queda igual
    if text.endswith('...'):
        return text
    return text + '.'

def speak(text):
    global _current_paplay
    if not text:
        return
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        fname = f.name
    try:
        cmd = ["edge-tts", "--voice", VOICE, "--rate", RATE, "--pitch", PITCH,
               "--text", text, "--write-media", fname]
        subprocess.run(cmd, capture_output=True, timeout=60)
        _current_paplay = subprocess.Popen(["paplay", fname], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        _current_paplay.wait()
        _current_paplay = None
    except Exception:
        pass
    finally:
        try:
            os.unlink(fname)
        except OSError:
            pass

def main():
    lines = []
    for line in sys.stdin:
        line = line.rstrip("\n")
        clean = clean_line(line)
        if not clean or len(clean) < 4:
            continue
        if clean.lower() in ('build', 'opencode zen', 'max', 'tab', 'agents', 'ctrl+p', 'commands', 'tip'):
            continue
        lines.append(clean)

    if lines:
        # Unir con punto y espacio para pausa natural entre segmentos
        text = '. '.join(ensure_ending_punctuation(l) for l in lines)
        speak(text)

if __name__ == "__main__":
    main()
SPEAKEOF
chmod +x "${LOCAL_BIN}/speak"

# ---- 7. tui.json ----
log "Configurando tui.json..."
cat > "${CONFIG_DIR}/tui.json" << 'TUIEOF'
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "session_rename": "f8"
  },
  "plugin": [
    [
      "/home/antonio/.config/opencode/opencode-voice-modified/index.js",
      {
        "endpoint": "http://localhost:4001/v1",
        "model": "models-qwen3.5-9b"
      }
    ]
  ]
}
TUIEOF

# Copiar archivos reales del plugin desde la copia de seguridad si existe
if [ -d "${HOME}/Config/opencode/sesion-opencode/opencode-voice-modified" ]; then
  log "Copiando plugin completo desde la copia de seguridad..."
  cp -r "${HOME}/Config/opencode/sesion-opencode/opencode-voice-modified/." "${PLUGIN_DIR}/"
fi

# ---- 8. npm dependencies del plugin ----
log "Instalando dependencias npm..."
cd "${CONFIG_DIR}"
if [ ! -f package.json ]; then
  cat > package.json << 'PKGEOF'
{
  "dependencies": {
    "@opencode-ai/plugin": "1.18.8"
  }
}
PKGEOF
fi
npm install --no-audit --no-fund 2>/dev/null || npm install

# ---- 9. Verificación final ----
log ""
log "=================================="
log " Instalación completada"
log "=================================="
log ""
log "Archivos instalados:"
ls -la "${PLUGIN_DIR}/"
ls -la "${LOCAL_BIN}/speak"
ls -la "${CONFIG_DIR}/tui.json"
ls -la "${WHISPER_DIR}/"
log ""
log "Para usar OCV:"
log "  1. edge-tts está listo (voz: es-ES-AlvaroNeural)"
log "  2. Modelos whisper: large-v3-turbo-q5_0, small, base"
log "  3. Inicia opencode en el TUI"
log "  4. Usa Ctrl+R para grabar voz, Leader+V para toggle TTS"
log ""
log "Actualizar plugin: npm install @renjfk/opencode-voice@latest en ${PLUGIN_DIR}"
log ""
log "Variables de entorno disponibles:"
log "  SPEAK_VOICE  (voz edge-tts, ej: es-ES-AlvaroNeural)"
log "  SPEAK_RATE   (velocidad, ej: +5%)"
log "  SPEAK_PITCH  (tono, ej: +0Hz)"
