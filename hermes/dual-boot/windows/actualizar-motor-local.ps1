<#
  actualizar-motor-local.ps1 — pasa a la copia LOCAL del motor del dual boot (la que
  Windows ejecuta de verdad, %LOCALAPPDATA%\hermes\dual-boot\) los arreglos publicados
  en la carpeta compartida (D:\HermesSync\windows\).

  Windows no ejecuta la copia distribuida a propósito: así una republicación desde Linux
  no puede revertir los arreglos hechos en Windows.  Por eso la actualización es explícita
  y con red: se guarda copia de la versión anterior antes de sustituir nada.

  Uso (sin administrador):
      powershell -ExecutionPolicy Bypass -File .\actualizar-motor-local.ps1
      powershell -ExecutionPolicy Bypass -File .\actualizar-motor-local.ps1 -SoloEstado
      ... -Local "$env:LOCALAPPDATA\hermes\dual-boot" -Comun "D:\HermesSync"

  Además comprueba (solo lectura) que el lanzador de la carpeta Inicio sigue siendo el
  que importa antes de arrancar el gateway: si `hermes gateway install` o una
  actualización lo revirtió, la importación de arranque desaparece sin avisar.
#>
[CmdletBinding()]
param(
    [string]$Comun = '',
    [string]$Local = '',
    [switch]$SoloEstado
)

$ErrorActionPreference = 'Stop'

function Ok($m)    { Write-Host "   [ok] $m" -ForegroundColor Green }
function Aviso($m) { Write-Host "   [!]  $m" -ForegroundColor Yellow }
function Mal($m)   { Write-Host "   [x]  $m" -ForegroundColor Red }

$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME }
              elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'hermes' }
              else { throw 'No encuentro HERMES_HOME: define HERMES_HOME o usa -Local.' }
if (-not $Local) { $Local = Join-Path $HermesHome 'dual-boot' }
$raiz = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Comun) { $Comun = $raiz }

$ficheros = @('hermes-dual-sync.ps1', 'copiar-state.py')

Write-Host '=== Actualizar la copia local del motor del dual boot ===' -ForegroundColor Cyan
Write-Host "   distribuido : $Comun"
Write-Host "   local (uso) : $Local"

if (-not (Test-Path $Local)) { Mal "no existe la carpeta local del motor: $Local"; exit 1 }

$marca = Get-Date -Format 'yyyyMMdd-HHmmss'
$pendientes = @()
foreach ($f in $ficheros) {
    $o = Join-Path $Comun $f
    $d = Join-Path $Local $f
    if (-not (Test-Path $o)) { Mal "falta la copia distribuida: $o"; exit 1 }
    if (-not (Test-Path $d)) { $pendientes += $f; continue }
    if ((Get-FileHash $o).Hash -ne (Get-FileHash $d).Hash) { $pendientes += $f }
}

if ($pendientes.Count -eq 0) {
    Ok 'la copia local ya está al día (idéntica a la distribuida)'
}
elseif ($SoloEstado) {
    foreach ($f in $pendientes) { Aviso "pendiente de actualizar: $f" }
}
else {
    foreach ($f in $pendientes) {
        $o = Join-Path $Comun $f
        $d = Join-Path $Local $f
        if (Test-Path $d) {
            $copia = "$d.bak-$marca"
            Copy-Item $d $copia -Force
            Ok "copia previa de ${f}: $(Split-Path -Leaf $copia)"
        }
        Copy-Item $o $d -Force
        if ((Get-FileHash $o).Hash -eq (Get-FileHash $d).Hash) { Ok "$f actualizado" }
        else { Mal "$f NO coincide tras copiarlo: revisa $d"; exit 1 }
    }
    Write-Host ''
    Write-Host '   Reinicia Hermes para que la próxima pasada use el motor nuevo.' -ForegroundColor Cyan
}

# ── Lanzador de la carpeta Inicio: ¿sigue integrando antes de arrancar el gateway? ──
Write-Host ''
Write-Host 'Lanzador de la carpeta Inicio (importación previa al gateway)'
$inicio = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\Hermes_Gateway.vbs'
if (-not (Test-Path $inicio)) { Aviso "no hay lanzador en $inicio (el gateway no arranca solo)" }
else {
    $texto = Get-Content $inicio -Raw -Encoding Default
    if ($texto -match 'hermes-sync\.cmd') { Ok 'el lanzador importa el estado antes de arrancar el gateway' }
    else { Aviso 'el lanzador NO llama a hermes-sync.cmd: hazlo con registrar-tareas.cmd (¿hermes gateway install lo revirtió?)' }
}
