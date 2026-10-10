<#
.SYNOPSIS
  STT (voz a texto) para OpenCode en Windows: graba del microfono y transcribe.

.DESCRIPTION
  Equivalente Windows del flujo sox + whisper-cpp de Linux:
    1. Graba audio del microfono con ffmpeg (DirectShow)
    2. Transcribe el WAV con whisper.cpp (whisper-cli.exe)
    3. Devuelve el texto por la salida estandar (y opcionalmente lo guarda)

  El microfono por defecto es el TONOR TD510 Air Mic (configurado como
  predeterminado del sistema).

.PARAMETER Seconds
  Duracion de la grabacion en segundos (por defecto 8).

.PARAMETER Device
  Nombre del dispositivo de captura DirectShow (por defecto el TONOR).

.PARAMETER Language
  Idioma para whisper (por defecto 'es').

.PARAMETER Threads
  Numero de hilos para whisper (por defecto 8).

.PARAMETER Model
  Ruta al modelo GGML. Por defecto large-v3-turbo-q5_0.

.PARAMETER AudioFile
  Si se indica, transcribe ESE archivo en vez de grabar (util para pruebas).

.PARAMETER OutFile
  Si se indica, guarda el texto transcrito en esa ruta.

.EXAMPLE
  stt.ps1 -Seconds 8
  stt.ps1 -AudioFile "C:\tmp\prueba.wav"
#>
[CmdletBinding()]
param(
  [int]$Seconds = 8,
  [string]$Device = 'Micrófono (TONOR TD510 Air Mic)',
  [string]$Language = 'es',
  [int]$Threads = 8,
  [string]$Model,
  [string]$AudioFile,
  [string]$OutFile
)

$ErrorActionPreference = 'Continue'

function Resolve-Exe([string[]]$Candidates, [string]$Name) {
  foreach ($c in $Candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

$Ffmpeg = Resolve-Exe @(
  (Join-Path $env:USERPROFILE '.local\bin\ffmpeg\bin\ffmpeg.exe')
) 'ffmpeg'
if (-not $Ffmpeg) { throw 'No se encontro ffmpeg.exe.' }

$WhisperCli = Resolve-Exe @(
  (Join-Path $env:USERPROFILE '.local\bin\whisper.cpp-cuda\Release\whisper-cli.exe'),
  (Join-Path $env:USERPROFILE '.local\bin\whisper.cpp-cuda\whisper-cli.exe'),
  (Join-Path $env:USERPROFILE '.local\bin\whisper.cpp\Release\whisper-cli.exe'),
  (Join-Path $env:USERPROFILE '.local\bin\whisper.cpp\whisper-cli.exe')
) 'whisper-cli'
if (-not $WhisperCli) { throw 'No se encontro whisper-cli.exe.' }

if (-not $Model) {
  $models = @(
    (Join-Path $env:USERPROFILE '.local\models\whisper\ggml-large-v3-turbo-q5_0.bin'),
    (Join-Path $env:USERPROFILE '.local\models\whisper\ggml-small.bin'),
    (Join-Path $env:USERPROFILE '.local\models\whisper\ggml-base.bin')
  )
  $Model = Resolve-Exe $models ''
}
if (-not $Model -or -not (Test-Path -LiteralPath $Model)) {
  throw "No se encontro el modelo whisper. Usa -Model <ruta .bin>."
}

$tmp = Join-Path $env:TEMP 'opencode-stt'
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$wav = if ($AudioFile) { $AudioFile } else { Join-Path $tmp 'entrada.wav' }

# 1) Grabar (si no se paso un archivo)
if (-not $AudioFile) {
  Write-Host "🎤 Grabando $Seconds s de '$Device'..." -ForegroundColor Cyan
  & $Ffmpeg -hide_banner -loglevel error -f dshow -i "audio=$Device" -t $Seconds -ar 16000 -ac 1 -c:a pcm_s16le -y $wav
  if (-not (Test-Path -LiteralPath $wav)) { throw 'ffmpeg no genero el WAV de grabacion.' }
} else {
  # Normalizar a 16 kHz mono WAV para whisper
  $norm = Join-Path $tmp 'entrada-norm.wav'
  & $Ffmpeg -hide_banner -loglevel error -i $AudioFile -ar 16000 -ac 1 -c:a pcm_s16le -y $norm
  $wav = $norm
}

# 2) Transcribir
$outBase = Join-Path $tmp ('stt-' + [guid]::NewGuid().ToString('N'))
Write-Host "📝 Transcribiendo (whisper.cpp, $Language)..." -ForegroundColor Cyan
& $WhisperCli -m $Model -f $wav -l $Language -t $Threads -nt -otxt -of $outBase 2>&1 | Out-Null

$txtFile = "$outBase.txt"
if (-not (Test-Path -LiteralPath $txtFile)) { throw 'whisper no genero la transcripcion.' }
$text = (Get-Content -LiteralPath $txtFile -Raw -Encoding UTF8).Trim()

if ($OutFile) { Set-Content -LiteralPath $OutFile -Value $text -Encoding UTF8 }
Write-Output $text
