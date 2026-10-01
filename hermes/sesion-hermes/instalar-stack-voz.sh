#!/usr/bin/env bash
# instalar-stack-voz.sh — Repone las DEPENDENCIAS del stack de voz local de Hermes
# (Kokoro TTS por GPU + whisper.cpp STT por CUDA).
#
# Los scripts adaptadores (kokoro-tts, whisper-stt, speak-kokoro*) vienen dentro del
# tarball de backup (extras/bin). Lo que NO puede viajar en el tarball son sus
# dependencias (~1,5 GB): el venv de Kokoro, sus modelos y el binario/modelo de
# whisper.cpp. Este script las instala desde cero, de forma idempotente.
#
# Uso:
#   bash instalar-stack-voz.sh              # instala lo que falte
#   bash instalar-stack-voz.sh --comprobar  # solo verifica y sale (0 = completo)
# ---------------------------------------------------------------------------

set -euo pipefail

SHARE="${HOME}/.local/share"
KOKORO_DIR="${SHARE}/kokoro"
TTS_VENV="${SHARE}/tts-local/venv313"
WHISPER_DIR="${SHARE}/whisper-cpp"
WHISPER_MODEL="${STT_WHISPER_MODEL:-${WHISPER_DIR}/models/ggml-large-v3-turbo-q5_0.bin}"
PY="${PYTHON313:-/usr/bin/python3.13}"
BOOTSTRAP_OCV="${HOME}/Config/opencode/bootstrap-ocv.sh"

KOKORO_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
VOICES_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

MODO="${1:-}"
FALTAN=0

ok()    { echo "   ✅ $*"; }
aviso() { echo "   ⚠️  $*"; }
mal()   { echo "   ❌ $*"; }

# ─── 1. Comprobación del estado (sin tocar nada) ───
comprobar() {
    if [ -x "${TTS_VENV}/bin/python3" ]; then ok "venv de Kokoro (${TTS_VENV/#$HOME/~})"; else mal "falta el venv de Kokoro (${TTS_VENV/#$HOME/~})"; FALTAN=$((FALTAN+1)); fi
    if [ -f "${KOKORO_DIR}/kokoro-v1.0.onnx" ]; then ok "modelo kokoro-v1.0.onnx"; else mal "falta ${KOKORO_DIR/#$HOME/~}/kokoro-v1.0.onnx"; FALTAN=$((FALTAN+1)); fi
    if [ -f "${KOKORO_DIR}/voices-v1.0.bin" ]; then ok "voces voices-v1.0.bin"; else mal "faltan ${KOKORO_DIR/#$HOME/~}/voices-v1.0.bin"; FALTAN=$((FALTAN+1)); fi
    if [ -x "${WHISPER_DIR}/bin/whisper-cli" ]; then ok "whisper-cli (build local)"; else mal "falta ${WHISPER_DIR/#$HOME/~}/bin/whisper-cli"; FALTAN=$((FALTAN+1)); fi
    if [ -f "${WHISPER_MODEL}" ]; then ok "modelo whisper $(basename "${WHISPER_MODEL}")"; else mal "falta ${WHISPER_MODEL/#$HOME/~}"; FALTAN=$((FALTAN+1)); fi
}

if [ "$MODO" = "--comprobar" ]; then
    comprobar
    if [ "$FALTAN" -eq 0 ]; then echo "✅ stack de voz completo"; exit 0; fi
    echo "⚠️  faltan ${FALTAN} componente(s): ejecuta 'bash instalar-stack-voz.sh'"
    exit 1
fi

echo "=== Instalando dependencias del stack de voz local ==="

# ─── 2. Kokoro: venv + paquetes + modelos ───
if [ ! -x "${TTS_VENV}/bin/python3" ]; then
    if [ ! -x "$PY" ]; then
        aviso "no encuentro ${PY}: instala python3.13 (en Arch: 'yay -S python313' o el paquete de tu distro)"
        aviso "puedes indicar otro intérprete con PYTHON313=/ruta/python3.13"
    else
        echo "   Creando venv de Kokoro con ${PY}..."
        "$PY" -m venv "$TTS_VENV"
        "${TTS_VENV}/bin/python3" -m pip install --quiet --upgrade pip
        if "${TTS_VENV}/bin/python3" -m pip install --quiet kokoro-onnx onnxruntime-gpu soundfile; then
            ok "venv de Kokoro creado (kokoro-onnx + onnxruntime-gpu + soundfile)"
        else
            mal "falló la instalación de paquetes en el venv de Kokoro"
        fi
    fi
else
    ok "venv de Kokoro ya presente"
fi

mkdir -p "$KOKORO_DIR"
for par in "kokoro-v1.0.onnx:${KOKORO_URL}" "voices-v1.0.bin:${VOICES_URL}"; do
    fichero="${par%%:*}"; url="${par#*:}"
    if [ -f "${KOKORO_DIR}/${fichero}" ]; then
        ok "modelo ${fichero} ya presente"
    else
        echo "   Descargando ${fichero} (~$( [ "${fichero##*.}" = "onnx" ] && echo 310 || echo 27 ) MB)..."
        if curl -fL --retry 3 -o "${KOKORO_DIR}/${fichero}.parcial" "$url"; then
            mv "${KOKORO_DIR}/${fichero}.parcial" "${KOKORO_DIR}/${fichero}"
            ok "${fichero} descargado"
        else
            rm -f "${KOKORO_DIR}/${fichero}.parcial"
            mal "no se pudo descargar ${fichero}"
        fi
    fi
done

# ─── 3. whisper.cpp (build CUDA) + modelo ───
if [ -x "${WHISPER_DIR}/bin/whisper-cli" ] && [ -f "${WHISPER_MODEL}" ]; then
    ok "whisper.cpp ya instalado con su modelo"
else
    if [ -f "$BOOTSTRAP_OCV" ]; then
        echo "   Delegando en el instalador del stack de voz de OpenCode (${BOOTSTRAP_OCV/#$HOME/~})..."
        if bash "$BOOTSTRAP_OCV"; then
            ok "whisper.cpp instalado por bootstrap-ocv.sh"
        else
            mal "bootstrap-ocv.sh devolvió error (revisa su salida)"
        fi
    else
        aviso "falta whisper.cpp y no encuentro ${BOOTSTRAP_OCV/#$HOME/~}"
        aviso "instálalo así: git clone https://github.com/ggml-org/whisper.cpp && cmake -B build -DGGML_CUDA=ON && cmake --build build -j\$(nproc)"
        aviso "y descarga el modelo: curl -L -o ${WHISPER_MODEL/#$HOME/~} https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin"
    fi
fi

# ─── 4. Verificación final ───
echo ""
echo "── Verificación ──"
FALTAN=0
comprobar
if [ -x "${TTS_VENV}/bin/python3" ]; then
    if "${TTS_VENV}/bin/python3" -c "import kokoro_onnx, onnxruntime" 2>/dev/null; then
        ok "el venv importa kokoro_onnx y onnxruntime"
    else
        mal "el venv no importa kokoro_onnx/onnxruntime (¿instalación incompleta?)"
    fi
fi
if [ "$FALTAN" -eq 0 ]; then
    echo "✅ Stack de voz listo (reinicia Hermes para que lo usen los adaptadores)"
    exit 0
fi
echo "⚠️  Quedan ${FALTAN} componente(s) sin resolver (ver líneas ❌)"
exit 1
