<#
.SYNOPSIS
  Locucion TTS (texto a voz) para OpenCode en Windows.

.DESCRIPTION
  Convierte texto en voz y lo reproduce. Motores disponibles:
    - kokoro : Kokoro v1.0 ONNX en GPU (requiere el venv de voz)  [por defecto]
    - edge   : edge-tts (voz neuronal, requiere internet)
    - sapi   : SAPI5 del sistema (offline)

  Acepta el texto por parametro (-Text), por posicion, por tuberia o por stdin.
  IMPORTANTE: sin bloques begin/process/end, para que `powershell -File ... -Text`
  enlace correctamente los parametros (requisito del plugin de OpenCode).

.PARAMETER Text
  Texto a locutar.

.PARAMETER Engine
  Motor de sintesis: 'kokoro', 'edge' o 'sapi'.

.PARAMETER Voice
  Voz de edge-tts (por defecto es-ES-AlvaroNeural).

.PARAMETER KokoroVoice
  Voz de Kokoro (por defecto ef_dora).

.PARAMETER Rate
  Velocidad relativa: 1.0 = normal, 1.2 = 20% mas rapido.

.PARAMETER OutFile
  Si se indica, guarda el audio en esa ruta y NO lo reproduce.

.PARAMETER NoPlay
  Genera el audio pero no lo reproduce.

.EXAMPLE
  speak.ps1 -Text "Hola Antonio"
  speak.ps1 "Hola Antonio"
  "Hola Antonio" | speak.ps1
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Text,
  [ValidateSet('kokoro', 'edge', 'sapi')]
  [string]$Engine = 'kokoro',
  [string]$Voice = 'es-ES-AlvaroNeural',
  [string]$KokoroVoice = 'ef_dora',
  [double]$Rate = 1.0,
  [string]$OutFile,
  [switch]$NoPlay
)

$ErrorActionPreference = 'Continue'

$TmpDir = Join-Path $env:TEMP 'opencode-tts'
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

function Resolve-Python {
  $c = Get-Command python -ErrorAction SilentlyContinue
  if ($c -and $c.Source -notmatch 'WindowsApps') { return $c.Source }
  foreach ($p in @('C:\Python314\python.exe', 'C:\Python313\python.exe', 'C:\Python312\python.exe', 'C:\Python311\python.exe')) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return $null
}

function Resolve-VenvPython {
  $p = Join-Path $env:USERPROFILE '.config\opencode\voice\venv\Scripts\python.exe'
  if (Test-Path -LiteralPath $p) { return $p }
  return $null
}

function Resolve-Ffplay {
  $candidates = @(
    (Join-Path $env:USERPROFILE '.local\bin\ffmpeg\bin\ffplay.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\Gyan.FFmpeg.Essentials_Microsoft.Winget.Source_8wekyb3d8bbwe')
  )
  foreach ($c in $candidates) {
    if (-not $c) { continue }
    $item = Get-Item -LiteralPath $c -ErrorAction SilentlyContinue
    if ($item -and -not $item.PSIsContainer) { return $item.FullName }
    if ($item -and $item.PSIsContainer) {
      $exe = Get-ChildItem $c -Recurse -Filter 'ffplay.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($exe) { return $exe.FullName }
    }
  }
  $cmd = Get-Command ffplay -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Play-Audio([string]$Path) {
  # Cortar cualquier locucion anterior para no superponer voces
  Get-Process ffplay -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  $ffplay = Resolve-Ffplay
  if ($ffplay) {
    & $ffplay -nodisp -autoexit -loglevel quiet $Path 2>$null
  } else {
    Start-Process -FilePath $Path
  }
}

function Speak-Sapi([string]$text, [double]$rate) {
  Add-Type -AssemblyName System.Speech
  $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
  $es = $synth.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -eq 'es-ES' } | Select-Object -First 1
  if ($es) { $synth.SelectVoice($es.VoiceInfo.Name) }
  $r = [int][math]::Round(($rate - 1) * 10)
  if ($r -lt -10) { $r = -10 }; if ($r -gt 10) { $r = 10 }
  $synth.Rate = $r
  $synth.Speak($text)
}

function Speak-Edge([string]$text, [string]$voice, [double]$rate) {
  $python = Resolve-Python
  if (-not $python) { throw 'No se encontro python para edge-tts.' }
  $out = Join-Path $TmpDir ("tts-{0}.mp3" -f ([guid]::NewGuid().ToString('N')))
  $pct = [int][math]::Round(($rate - 1) * 100)
  $rateStr = if ($pct -ge 0) { "+$pct%" } else { "$pct%" }
  # Texto por archivo temporal para evitar problemas de comillas
  $txtFile = Join-Path $TmpDir ("edge-{0}.txt" -f ([guid]::NewGuid().ToString('N')))
  Set-Content -LiteralPath $txtFile -Value $text -Encoding UTF8
  & $python -m edge_tts --voice $voice --rate $rateStr --file $txtFile --write-media $out 2>$null
  Remove-Item -LiteralPath $txtFile -Force -ErrorAction SilentlyContinue
  return $out
}

function Speak-Kokoro([string]$text, [string]$voice, [double]$rate) {
  $venvpy = Resolve-VenvPython
  if (-not $venvpy) { throw 'No se encontro el venv de voz (Kokoro).' }
  $scriptPy = Join-Path $env:USERPROFILE '.config\opencode\voice\kokoro-tts.py'
  if (-not (Test-Path -LiteralPath $scriptPy)) { throw 'No se encontro kokoro-tts.py.' }
  $out = Join-Path $TmpDir ("kokoro-{0}.wav" -f ([guid]::NewGuid().ToString('N')))
  $speedStr = $rate.ToString([System.Globalization.CultureInfo]::InvariantCulture)
  # Texto por fichero UTF-8 sin BOM (evita problemas de comillas y de acentos)
  $txtFile = Join-Path $TmpDir ("kokoro-{0}.txt" -f ([guid]::NewGuid().ToString('N')))
  [System.IO.File]::WriteAllText($txtFile, $text, (New-Object System.Text.UTF8Encoding($false)))
  & $venvpy $scriptPy --file $txtFile --voice $voice --speed $speedStr --out $out --quiet 2>$null | Out-Null
  Remove-Item -LiteralPath $txtFile -Force -ErrorAction SilentlyContinue
  return $out
}

function Clean-TtsText([string]$t) {
  if ([string]::IsNullOrEmpty($t)) { return $t }
  $t = [regex]::Replace($t, "\x1b\[[0-9;]*[a-zA-Z]", "")
  $t = [regex]::Replace($t, "[\uD800-\uDBFF][\uDC00-\uDFFF]", "")
  $t = [regex]::Replace($t, "[\u2190-\u21FF\u2300-\u23FF\u25A0-\u25FF\u2600-\u27BF\u2900-\u297F\u2B00-\u2BFF\u3030\u303D\u3297\u3299\uFE00-\uFE0F\u200D\u2500-\u257F\u2580-\u259F]", "")
  # Celdas de tabla: convertir pipes en dos puntos (genera pausa entre celdas)
  $t = [regex]::Replace($t, "\s*\|\s*", ": ")
  $t = [regex]::Replace($t, '[*_`~#>]+', " ")
  # IMPORTANTE: conservar los saltos de linea (pausas entre parrafos/lineas)
  $t = [regex]::Replace($t, "[ \t]+", " ")
  $t = [regex]::Replace($t, "[ \t]*\n[ \t]*", "`n")
  $t = [regex]::Replace($t, "(\n){2,}", "`n")
  return $t.Trim()
}

# --- Texto: parametro/posicional, o si no, stdin ---
if ([string]::IsNullOrWhiteSpace($Text)) {
  try {
    $stdinStream = [Console]::OpenStandardInput()
    $stdinReader = New-Object System.IO.StreamReader($stdinStream, [System.Text.Encoding]::UTF8)
    $Text = $stdinReader.ReadToEnd()
  } catch { }
}
$final = Clean-TtsText ($Text -replace "`r", "")
try { Add-Content -LiteralPath (Join-Path $env:TEMP 'opencode-voice.log') -Value ((Get-Date).ToUniversalTime().ToString('o') + " speak.ps1 recibido=" + $final.Length + " engine=" + $Engine) } catch {}
if ([string]::IsNullOrWhiteSpace($final)) { return }

if ($Engine -eq 'sapi') {
  if ($OutFile) {
    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $es = $synth.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -eq 'es-ES' } | Select-Object -First 1
    if ($es) { $synth.SelectVoice($es.VoiceInfo.Name) }
    $r = [int][math]::Round(($Rate - 1) * 10)
    if ($r -lt -10) { $r = -10 }; if ($r -gt 10) { $r = 10 }
    $synth.Rate = $r
    $synth.SetOutputToWaveFile($OutFile)
    $synth.Speak($final)
    $synth.SetOutputToNull()
  } else {
    Speak-Sapi $final $Rate
  }
}
elseif ($Engine -eq 'edge') {
  $file = Speak-Edge $final $Voice $Rate
  if (-not (Test-Path -LiteralPath $file)) { throw 'edge-tts no genero audio (¿sin internet?).' }
  if ($OutFile) { Move-Item -LiteralPath $file -Destination $OutFile -Force }
  elseif (-not $NoPlay) { Play-Audio $file; Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
  else { Write-Output $file }
}
else {
  $file = Speak-Kokoro $final $KokoroVoice $Rate
  if (-not (Test-Path -LiteralPath $file)) { throw 'kokoro-tts no genero audio.' }
  if ($OutFile) { Move-Item -LiteralPath $file -Destination $OutFile -Force }
  elseif (-not $NoPlay) { Play-Audio $file; Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
  else { Write-Output $file }
}
