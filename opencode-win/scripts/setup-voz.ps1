<#
.SYNOPSIS
  Instala el stack de VOZ (STT + TTS) en GPU para OpenCode en Windows.

.DESCRIPTION
  Deja operativa la voz en Windows replicando el setup de Linux:
    - STT: ffmpeg (captura DirectShow) + whisper.cpp build CUDA + modelo large-v3-turbo
    - TTS: Kokoro v1.0 ONNX en GPU (venv + onnxruntime-gpu 1.26 CUDA 12) + edge-tts (reserva)

  Descarga binarios portables (sin instalador del sistema) en %USERPROFILE%\.local
  y crea el venv en %USERPROFILE%\.config\opencode\voice\venv.

  Requiere: conexion a internet y (para GPU) una GPU NVIDIA con driver CUDA.
  ONNX Runtime 1.26 usa CUDA 12; 1.27+ exige CUDA 13 (por eso se fija 1.26.0).

.PARAMETER SkipModel
  No descarga el modelo de whisper (large-v3-turbo-q5_0).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File setup-voz.ps1
#>
[CmdletBinding()]
param(
  [switch]$SkipModel
)

$ErrorActionPreference = "Continue"
$BinDir   = Join-Path $env:USERPROFILE ".local\bin"
$ModelsDir = Join-Path $env:USERPROFILE ".local\models"
$VoiceDir = Join-Path $env:USERPROFILE ".config\opencode\voice"
$Tmp      = Join-Path $env:TEMP "opencode-voz-setup"
$Python   = "C:\Python314\python.exe"
$Venv     = Join-Path $VoiceDir "venv"

function Step($m) { Write-Host "🟡 $m" -ForegroundColor Yellow }
function Ok($m)   { Write-Host "🟢 $m" -ForegroundColor Green }
function Warn2($m) { Write-Host "⚠️  $m" -ForegroundColor Yellow }

function Get-File($url, $dest) {
  if (Test-Path -LiteralPath $dest) { return }
  Step "Descargando $(Split-Path $dest -Leaf)..."
  & curl.exe -L --retry 3 -s -o $dest $url
  if (-not (Test-Path -LiteralPath $dest)) { throw "Fallo al descargar $url" }
}

New-Item -ItemType Directory -Path $BinDir, $ModelsDir, $VoiceDir, $Tmp -Force | Out-Null

# ---- 1) ffmpeg portable ----------------------------------------------------
if (-not (Test-Path "$BinDir\ffmpeg\bin\ffmpeg.exe")) {
  Get-File "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" "$Tmp\ffmpeg.zip"
  $ex = Join-Path $Tmp "ffmpeg-extract"; Expand-Archive "$Tmp\ffmpeg.zip" $ex -Force
  $verDir = Get-ChildItem $ex -Directory | Select-Object -First 1
  New-Item -ItemType Directory -Path "$BinDir\ffmpeg" -Force | Out-Null
  Move-Item "$($verDir.FullName)\bin" "$BinDir\ffmpeg\bin" -Force
  Ok "ffmpeg instalado en $BinDir\ffmpeg\bin"
} else { Ok "ffmpeg ya presente." }

# ---- 2) whisper.cpp build CUDA --------------------------------------------
if (-not (Test-Path "$BinDir\whisper.cpp-cuda\Release\whisper-cli.exe")) {
  Get-File "https://github.com/ggml-org/whisper.cpp/releases/download/b4938/whisper-cublas-12.4.0-bin-x64.zip" "$Tmp\whisper-cuda.zip"
  Expand-Archive "$Tmp\whisper-cuda.zip" "$BinDir\whisper.cpp-cuda" -Force
  Ok "whisper.cpp (CUDA) instalado en $BinDir\whisper.cpp-cuda"
} else { Ok "whisper.cpp (CUDA) ya presente." }

# ---- 3) Modelo de whisper --------------------------------------------------
$wModel = Join-Path $ModelsDir "whisper\ggml-large-v3-turbo-q5_0.bin"
New-Item -ItemType Directory -Path (Split-Path $wModel) -Force | Out-Null
if ((-not $SkipModel) -and (-not (Test-Path -LiteralPath $wModel))) {
  Get-File "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin" $wModel
  Ok "Modelo whisper descargado."
} else { Ok "Modelo whisper ya presente (o -SkipModel)." }

# ---- 4) edge-tts (reserva TTS, Python del sistema) -------------------------
& $Python -m pip install --user --quiet edge-tts 2>&1 | Out-Null
Ok "edge-tts instalado (reserva)."

# ---- 5) venv de Kokoro + onnxruntime-gpu CUDA 12 ---------------------------
if (-not (Test-Path "$Venv\Scripts\python.exe")) {
  & $Python -m venv $Venv
}
$vpy = "$Venv\Scripts\python.exe"
Step "Instalando librerias Python de voz (Kokoro + CUDA)..."
& $vpy -m pip install --quiet --upgrade pip
& $vpy -m pip install --quiet kokoro-onnx "onnxruntime-gpu==1.26.0" nvidia-cudnn-cu12 nvidia-cublas-cu12 nvidia-cuda-runtime-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 nvidia-cusolver-cu12 nvidia-cusparse-cu12
# Evitar el conflicto: onnxruntime (CPU) rompe onnxruntime-gpu
& $vpy -m pip uninstall -y onnxruntime 2>&1 | Out-Null
& $vpy -m pip install --force-reinstall --no-deps --quiet "onnxruntime-gpu==1.26.0"
Ok "venv de Kokoro listo."

# ---- 6) Modelo Kokoro + voces ---------------------------------------------
$kModel  = Join-Path $ModelsDir "kokoro\kokoro-v1.0.onnx"
$kVoices = Join-Path $ModelsDir "kokoro\voices-v1.0.bin"
New-Item -ItemType Directory -Path (Split-Path $kModel) -Force | Out-Null
Get-File "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx" $kModel
Get-File "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin" $kVoices
Ok "Modelo Kokoro + voces listos."

# ---- 7) Verificacion -------------------------------------------------------
Write-Host ""
Write-Host "=== Verificacion ===" -ForegroundColor Cyan
$prov = & $vpy -c "import os,sys; site=os.path.join(sys.prefix,'Lib','site-packages'); [os.add_dll_directory(os.path.join(site,'nvidia',s,'bin')) for s in ('cudnn','cublas','cuda_runtime','cuda_nvrtc','cufft','curand','cusolver','cusparse') if os.path.isdir(os.path.join(site,'nvidia',s,'bin'))]; import onnxruntime as ort; print(ort.get_available_providers())" 2>$null
Write-Host ("ONNX providers: {0}" -f $prov)
Write-Host ("whisper-cli:    {0}" -f (Test-Path "$BinDir\whisper.cpp-cuda\Release\whisper-cli.exe"))
Write-Host ("ffmpeg:         {0}" -f (Test-Path "$BinDir\ffmpeg\bin\ffmpeg.exe"))
Write-Host ""
Ok "Stack de voz instalado. Usa 'ocv' y los atajos de voz en la TUI."
