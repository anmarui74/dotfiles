<#
.SYNOPSIS
  Gestiona el servidor TTS persistente de Kokoro (kokoro-server.py).

.DESCRIPTION
  Mantiene el modelo Kokoro v1.0 cargado en GPU para que cada locucion tarde
  ~0.2-0.7 s en lugar de ~2 s (arranque en frio).

  El servidor escucha solo en 127.0.0.1 (por defecto puerto 4210) y expone:
    GET  /health   -> estado
    POST /tts      -> sintetiza texto -> WAV
    POST /shutdown -> lo detiene

.PARAMETER Action
  start | stop | restart | status  (por defecto: status)

.PARAMETER Port
  Puerto local del servidor (por defecto 4210 o $env:KOKORO_TTS_PORT).

.EXAMPLE
  tts-server.ps1 start
  tts-server.ps1 status
  tts-server.ps1 stop
#>
[CmdletBinding()]
param(
  [ValidateSet('start', 'stop', 'restart', 'status')]
  [string]$Action = 'status',
  [int]$Port = $(if ($env:KOKORO_TTS_PORT) { [int]$env:KOKORO_TTS_PORT } else { 4210 })
)

$ErrorActionPreference = 'Continue'

function Get-VenvPython {
  $p = Join-Path $env:USERPROFILE '.config\opencode\voice\venv\Scripts\python.exe'
  if (Test-Path -LiteralPath $p) { return $p }
  return $null
}

function Get-ServerScript {
  return (Join-Path $env:USERPROFILE '.config\opencode\voice\kokoro-server.py')
}

function Test-Server {
  try {
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -ErrorAction Stop
    return $r
  } catch { return $null }
}

function Start-Server {
  $health = Test-Server
  if ($health) { Write-Host "[tts-server] ya esta activo en el puerto $Port" -ForegroundColor Yellow; return }
  $venvpy = Get-VenvPython
  $script = Get-ServerScript
  if (-not $venvpy) { Write-Host "[tts-server] ERROR: no se encontro el venv de voz" -ForegroundColor Red; return }
  if (-not (Test-Path -LiteralPath $script)) { Write-Host "[tts-server] ERROR: no existe $script" -ForegroundColor Red; return }
  Start-Process -FilePath $venvpy -ArgumentList @("`"$script`"", '--port', "$Port") -WindowStyle Hidden | Out-Null
  Write-Host "[tts-server] arrancando (cargando modelo en GPU)..." -ForegroundColor Cyan
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-Server) { Write-Host "[tts-server] listo en el puerto $Port" -ForegroundColor Green; return }
  }
  Write-Host "[tts-server] ERROR: no respondio tras 20 s" -ForegroundColor Red
}

function Stop-Server {
  $health = Test-Server
  if (-not $health) { Write-Host "[tts-server] no esta activo" -ForegroundColor Yellow; return }
  try { Invoke-RestMethod -Uri "http://127.0.0.1:$Port/shutdown" -Method Post -TimeoutSec 5 | Out-Null } catch {}
  Start-Sleep -Milliseconds 800
  if (Test-Server) {
    Write-Host "[tts-server] el shutdown HTTP no respondio; buscando proceso..." -ForegroundColor Yellow
    Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
      Where-Object { $_.CommandLine -match 'kokoro-server\.py' } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  }
  if (Test-Server) { Write-Host "[tts-server] ERROR: sigue activo" -ForegroundColor Red }
  else { Write-Host "[tts-server] detenido" -ForegroundColor Green }
}

function Show-Status {
  $health = Test-Server
  if ($health) {
    Write-Host "[tts-server] ACTIVO en el puerto $Port" -ForegroundColor Green
    Write-Host ("  voz: {0}" -f $health.voice)
    Write-Host ("  providers: {0}" -f ($health.providers -join ', '))
  } else {
    Write-Host "[tts-server] inactivo" -ForegroundColor Yellow
  }
}

switch ($Action) {
  'start'   { Start-Server }
  'stop'    { Stop-Server }
  'restart' { Stop-Server; Start-Server }
  'status'  { Show-Status }
}
