<#
  bootstrap-hermes.ps1 — Atajo: instalación/restauración desde limpio en Windows.

  Llama a restaurar-hermes.ps1 (el instalador de verdad, único en sesion-hermes\).
  Uso:  powershell -ExecutionPolicy Bypass -File bootstrap-hermes.ps1
        ... -Destino "C:\Temp\prueba"   (prueba de restauración en carpeta temporal)
#>
[CmdletBinding()]
param(
    [string]$Destino = '',
    [string]$Zip = '',
    [string]$Disco = '',
    [switch]$SoloSesion,
    [switch]$SinDoctor
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$instalador = Join-Path $ScriptDir 'restaurar-hermes.ps1'
if (-not (Test-Path $instalador)) {
    $instalador = Join-Path $ScriptDir 'sesion-hermes\restaurar-hermes.ps1'
}
if (-not (Test-Path $instalador)) {
    Write-Host "ERROR: no encuentro restaurar-hermes.ps1 en $ScriptDir"
    exit 1
}

$args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $instalador)
if ($Destino -ne '')    { $args += @('-Destino', $Destino) }
if ($Zip -ne '')        { $args += @('-Zip', $Zip) }
if ($Disco -ne '')      { $args += @('-Disco', $Disco) }
if ($SoloSesion)        { $args += '-SoloSesion' }
if ($SinDoctor)         { $args += '-SinDoctor' }

& powershell.exe @args
exit $LASTEXITCODE
