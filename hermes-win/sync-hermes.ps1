<#
  sync-hermes.ps1 — Sincroniza %LOCALAPPDATA%\hermes con el respaldo canónico y regenera el ZIP.

  Es el envoltorio que ejecuta la tarea programada (cada 30 min): sin salida por consola
  (todo al log) para no molestar. Equivale a sync-hermes.sh de Linux.

  Uso:
    powershell -ExecutionPolicy Bypass -File sync-hermes.ps1            (manual, con salida)
    powershell -ExecutionPolicy Bypass -File sync-hermes.ps1 -Quiet     (tarea programada)
#>
[CmdletBinding()]
param(
    [string]$Disco = '',
    [string]$HermesHome = '',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Correr {
    # Ver la nota de backup-hermes.ps1: con $ErrorActionPreference='Stop', PowerShell 5.1
    # convierte en error terminante cualquier línea que un .exe escriba en stderr.
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
if (-not $RaizLinux) {
    Write-Host 'ERROR: no encuentro el disco compartido (busco <letra>:\HermesSync\.hermes-sync).'
    exit 1
}
$Base = Join-Path $RaizLinux 'Config\Hermes-Win'
$LogFile = Join-Path $Base 'sync.log'
$LockFile = Join-Path $Base '.sync.lock'

function Log {
    param([string]$Mensaje)
    $linea = "[{0}] {1}" -f (Get-Date -Format 'dd/MM/yyyy HH:mm:ss'), $Mensaje
    Add-Content -Path $LogFile -Value $linea -Encoding UTF8
    if (-not $Quiet) { Write-Host $Mensaje }
}

New-Item -ItemType Directory -Force -Path $Base | Out-Null

# Evitar ejecuciones simultáneas (backup manual + tarea programada)
if (Test-Path $LockFile) {
    $pidPrev = 0
    try { $pidPrev = [int]((Get-Content $LockFile -Raw).Trim()) } catch { $pidPrev = 0 }
    if ($pidPrev -gt 0 -and (Get-Process -Id $pidPrev -ErrorAction SilentlyContinue)) {
        if (-not $Quiet) { Write-Host 'AVISO: ya hay una sincronización en curso.' }
        exit 0
    }
}
Set-Content -Path $LockFile -Value $PID -Encoding ASCII

try {
    Log "🔄 Sincronizando Hermes (Windows) -> respaldo canónico y ZIP"
    $argsBackup = @('-NoProfile', '-ExecutionPolicy', 'Bypass',
                    '-File', (Join-Path $Base 'backup-hermes.ps1'), '-Quiet')
    if ($Disco -ne '') { $argsBackup += @('-Disco', $Disco) }
    if ($HermesHome -ne '') { $argsBackup += @('-HermesHome', $HermesHome) }
    $rc = Correr -Exe 'powershell.exe' -Argumentos $argsBackup
    $salida = $script:SalidaNativa
    if ($rc -eq 0) {
        # Con -Quiet el backup solo escribe en el log: de ahí se saca la línea del ZIP
        $creado = (Get-Content $LogFile -Tail 15 -ErrorAction SilentlyContinue |
                   Where-Object { $_ -match 'ZIP:' } | Select-Object -Last 1)
        if ($creado) { $creado = ($creado -replace '^\[[^\]]+\]\s*', '').Trim() }
        Log "✅ Backup regenerado: $creado"
    } else {
        Log "❌ FALLO al regenerar el backup (exit $rc)"
        foreach ($l in ($salida -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 5)) {
            Log "   $($l.Trim())"
        }
        exit 1
    }
    Log '─────────────────────────────────────'
} finally {
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
