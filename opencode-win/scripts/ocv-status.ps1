<#
.SYNOPSIS
  Muestra el estado de LM Studio, el modelo cargado en VRAM y el proxy local.

.DESCRIPTION
  Version standalone (para lanzadores .cmd). Equivale a la funcion ocv-status del
  perfil de PowerShell. Comprueba: servidor LM Studio (1234), modelo en VRAM y
  proxy (4001).
#>
$ErrorActionPreference = "SilentlyContinue"
$lms = Join-Path $env:USERPROFILE ".lmstudio\bin\lms.exe"

Write-Host "`n=== LM Studio (puerto 1234) ===" -ForegroundColor Cyan
try {
  Invoke-RestMethod -Uri "http://127.0.0.1:1234/v1/models" -TimeoutSec 3 | Out-Null
  Write-Host "🟢 Servidor activo" -ForegroundColor Green
} catch {
  Write-Host "🔴 Servidor no responde" -ForegroundColor Red
}

Write-Host "=== Modelo en VRAM ===" -ForegroundColor Cyan
if (Test-Path -LiteralPath $lms) {
  (& $lms ps 2>&1 | Out-String).Trim() | Write-Host
} else {
  Write-Host "(no se encontro lms.exe en $lms)" -ForegroundColor Yellow
}

Write-Host "=== Proxy 4001 ===" -ForegroundColor Cyan
try {
  $h = Invoke-RestMethod -Uri "http://127.0.0.1:4001/health" -TimeoutSec 3
  Write-Host ("🟢 Activo -> {0} (puerto {1})" -f $h.upstream, $h.port) -ForegroundColor Green
} catch {
  Write-Host "🔴 Proxy no responde en el puerto 4001" -ForegroundColor Red
}
