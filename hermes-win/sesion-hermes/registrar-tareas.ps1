<#
  registrar-tareas.ps1 — Deja montado el backup automático de Hermes en Windows.

  Registra la tarea programada HermesBackup-Win (cada 30 minutos) que ejecuta
  sync-hermes.ps1 -Quiet. Es idempotente: se puede reejecutar cuando haga falta
  (por ejemplo si el disco SEAGATE cambia de letra).

  Sin administrador: `schtasks /sc minute` funciona con permisos de usuario normal
  (los disparadores "al iniciar/cerrar sesión" sí exigen admin, por eso no se usan).

  Uso: powershell -ExecutionPolicy Bypass -File registrar-tareas.ps1
#>
[CmdletBinding()]
param(
    [string]$Disco = '',
    [int]$Minutos = 30,
    [string]$Nombre = 'HermesBackup-Win',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Correr {
    param([string]$Exe, [string[]]$Argumentos)
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $salida = @(& $Exe @Argumentos 2>&1)
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $eap
    $script:SalidaNativa = ($salida | Out-String)
    return $rc
}

function Find-RaizLinux {
    param([string]$Letra = '')
    if ($Letra -ne '') {
        $raiz = "${Letra}:\Linux"
        if (Test-Path $raiz) { return $raiz }
        return $null
    }
    foreach ($l in ([char[]](68..90))) {
        try { if (Test-Path "${l}:\HermesSync\.hermes-sync") { return "${l}:\Linux" } } catch { }
    }
    return $null
}

$RaizLinux = Find-RaizLinux -Letra $Disco
if (-not $RaizLinux) { Write-Host 'ERROR: no encuentro el disco compartido.'; exit 1 }
$Base = Join-Path $RaizLinux 'Config\Hermes-Win'
if (-not (Test-Path $Base)) { Write-Host "ERROR: no existe $Base"; exit 1 }

# Wrapper: la tarea llama a un .cmd que se localiza a sí mismo (%~dp0), así no lleva la
# letra del disco a fuego más que en el momento del registro.
$wrapper = Join-Path $Base 'backup-tarea.cmd'
$contenido = @'
@echo off
REM Lanzador de la tarea programada HermesBackup-Win (generado por registrar-tareas.ps1)
setlocal
set "AQUI=%~dp0"
set "AQUI=%AQUI:~0,-1%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%AQUI%\sync-hermes.ps1" -Quiet
endlocal
'@ -split "`r?`n" -join "`r`n"
Set-Content -Path $wrapper -Value $contenido -Encoding ASCII -NoNewline

$rc = Correr -Exe 'schtasks.exe' -Argumentos @('/create', '/tn', $Nombre, '/sc', 'minute',
        '/mo', "$Minutos", '/tr', $wrapper, '/f')
if ($rc -ne 0) {
    Write-Host "ERROR: schtasks /create devolvió $rc"
    Write-Host $script:SalidaNativa
    exit 1
}
if (-not $Quiet) { Write-Host $script:SalidaNativa.Trim() }
Write-Host "OK: tarea '$Nombre' registrada cada $Minutos minutos -> $wrapper"

# Estado de la tarea
[void](Correr -Exe 'schtasks.exe' -Argumentos @('/query', '/tn', $Nombre, '/fo', 'LIST'))
Write-Host $script:SalidaNativa.Trim()

# Disparador "al cerrar sesión" (opcional, exige administrador): se intenta y se informa.
$rcCierre = Correr -Exe 'schtasks.exe' -Argumentos @('/create', '/tn', "$Nombre-Cierre",
             '/sc', 'onlogoff', '/tr', $wrapper, '/f')
if ($rcCierre -eq 0) {
    Write-Host "OK: tarea '$Nombre-Cierre' registrada al cerrar sesión."
} else {
    Write-Host "AVISO: no se ha podido registrar el disparador 'al cerrar sesión' (schtasks exit $rcCierre);" -ForegroundColor Yellow
    Write-Host '       hace falta administrador. El respaldo del cierre de sesión de Hermes se cubre con el hook on_session_end.' -ForegroundColor Yellow
}
exit 0
