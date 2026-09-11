<#
.SYNOPSIS
  Arranca LM Studio (servidor + modelo local) y el proxy del puerto 4001.

.DESCRIPTION
  Equivalente Windows del start-lmstudio.sh de Linux. Es idempotente: si el
  servidor, el modelo o el proxy ya estan activos, no los reinicia.
  Autodetecta las rutas de LM Studio (lms.exe) y de Python, por lo que es
  portable entre equipos y usuarios.

.PARAMETER Model
  Identificador del modelo en LM Studio (por defecto: qwen3.8-9b).

.PARAMETER ContextLength
  Longitud de contexto a cargar (por defecto: 80000).

.PARAMETER ProxyPort
  Puerto del proxy (por defecto: 4001).
#>
[CmdletBinding()]
param(
  [string]$Model = "qwen3.8-9b",
  [int]$ContextLength = 80000,
  [int]$ProxyPort = 4001
)

$ErrorActionPreference = "Continue"

$ConfigDir = Join-Path $env:USERPROFILE ".config\opencode"
$Proxy     = Join-Path $ConfigDir "lmstudio-proxy.py"

function Write-Step($msg, $color = "Cyan") { Write-Host $msg -ForegroundColor $color }

function Resolve-Lms {
  $candidates = @(
    (Join-Path $env:USERPROFILE ".lmstudio\bin\lms.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\LM Studio\resources\app\.webpack\lms.exe"),
    (Join-Path ${env:ProgramFiles} "LM Studio\resources\app\.webpack\lms.exe")
  )
  foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  $cmd = Get-Command lms -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Resolve-Python {
  $cmd = Get-Command python -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  foreach ($c in @("C:\Python314\python.exe", "C:\Python313\python.exe", "C:\Python312\python.exe", "C:\Python311\python.exe")) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  return $null
}

$Lms    = Resolve-Lms
$Python = Resolve-Python

if (-not $Lms)    { throw "No se encontro lms.exe. Instala LM Studio o anade su carpeta bin al PATH." }
if (-not $Python) { throw "No se encontro python.exe. Instala Python 3 o anade su carpeta al PATH." }
if (-not (Test-Path -LiteralPath $Proxy)) { throw "No se encuentra el proxy en $Proxy" }

# --- 1) Servidor LM Studio ------------------------------------------------
$serverUp = $false
try {
  $status = (& $Lms server status 2>&1 | Out-String)
  if ($status -match "running on port") { $serverUp = $true }
} catch { }

if (-not $serverUp) {
  Write-Step "🟡 Arrancando servidor LM Studio..." "Yellow"
  & $Lms server start 2>&1 | Out-Null
  Start-Sleep -Seconds 2
} else {
  Write-Step "🟢 Servidor LM Studio ya activo (puerto 1234)." "Green"
}

# --- 2) Modelo cargado en VRAM --------------------------------------------
$modelLoaded = $false
try {
  $psOut = (& $Lms ps 2>&1 | Out-String)
  if ($psOut -match [regex]::Escape($Model)) { $modelLoaded = $true }
} catch { }

if (-not $modelLoaded) {
  Write-Step "🟡 Cargando modelo '$Model' (ctx $ContextLength, GPU max)..." "Yellow"
  & $Lms load $Model --gpu max -c $ContextLength -y 2>&1 | Out-Null
  Write-Step "🟢 Modelo '$Model' cargado." "Green"
} else {
  Write-Step "🟢 Modelo '$Model' ya estaba en VRAM." "Green"
}

# --- 3) Proxy en el puerto indicado ---------------------------------------
function Test-Proxy {
  try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:$ProxyPort/health" -TimeoutSec 2 -UseBasicParsing
    return ($r.StatusCode -eq 200)
  } catch { return $false }
}

if (-not (Test-Proxy)) {
  Write-Step "🟡 Arrancando proxy en el puerto $ProxyPort..." "Yellow"
  Start-Process -FilePath $Python -ArgumentList "`"$Proxy`"" -WindowStyle Hidden
  $ok = $false
  for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-Proxy) { $ok = $true; break }
  }
  if ($ok) { Write-Step "🟢 Proxy activo en http://127.0.0.1:$ProxyPort/v1" "Green" }
  else     { Write-Warning "⚠️ El proxy no respondio en el puerto $ProxyPort" }
} else {
  Write-Step "🟢 Proxy ya activo en el puerto $ProxyPort." "Green"
}

Write-Step "✅ LM Studio + proxy listos. API local: http://127.0.0.1:$ProxyPort/v1" "Green"
