<#
  restaurar-hermes.ps1 — Restauración / instalación desde limpio de Hermes Agent en Windows.

  Equivale a setup-hermes-completo.sh + restore.sh de Linux. Fuentes, en orden de preferencia:
    1. -DesdeCarpeta <dir>   (carpeta ya extraída de un zip; es lo que usa restore-win.cmd)
    2. -Zip <fichero.zip>    (zip concreto)
    3. El último zip de X:\Linux\Config\Hermes-Win\backups\
    4. -SoloSesion           (el respaldo canónico sesion-hermes\, si no hay zip)

  PRUEBA DE VERDAD: restaura en una carpeta temporal con -Destino, no encima de la instalación
  activa, y comprueba que el resultado tiene los ficheros clave y que 'hermes doctor' sale limpio.

  Uso:
    powershell -ExecutionPolicy Bypass -File restaurar-hermes.ps1 -Destino "C:\Temp\restore-hermes"
    powershell -ExecutionPolicy Bypass -File restaurar-hermes.ps1 -SoloSesion -Destino "C:\Temp\restore-sesion"
    powershell -ExecutionPolicy Bypass -File restaurar-hermes.ps1            (restaura sobre el activo)
#>
[CmdletBinding()]
param(
    [string]$Zip = '',
    [string]$DesdeCarpeta = '',
    [string]$Destino = '',
    [string]$Disco = '',
    [string]$HermesHome = '',
    [switch]$SoloSesion,
    [switch]$Instalar,
    [switch]$SinDoctor,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$script:Fallos = 0
$script:SalidaNativa = ''

function Paso  { param([string]$m) if (-not $Quiet) { Write-Host ''; Write-Host "── $m ─────────────────────────────" } }
function ok    { param([string]$m) if (-not $Quiet) { Write-Host "   [ok] $m" } }
function aviso { param([string]$m) if (-not $Quiet) { Write-Host "   [aviso] $m" } }
function mal   { param([string]$m) if (-not $Quiet) { Write-Host "   [FALLO] $m" }; $script:Fallos++ }

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

function Set-AclPrivada {
    param([string]$Ruta, [switch]$Fichero)
    if (-not (Test-Path $Ruta)) { return }
    $usuario = "$env:USERDOMAIN\$env:USERNAME"
    $permiso = if ($Fichero) { "${usuario}:F" } else { "${usuario}:(OI)(CI)F" }
    [void](Correr -Exe 'icacls.exe' -Argumentos @($Ruta, '/inheritance:r', '/grant:r', $permiso))
}

function Test-HermesVivo {
    try {
        $vivos = Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
            $_.CommandLine -and ($_.CommandLine -match 'hermes\.exe|hermes_cli|hermes-agent')
        }
        if ($vivos) { return $true }
    } catch { }
    return $false
}

$RaizLinux = Find-RaizLinux -Letra $Disco
if (-not $RaizLinux) {
    Write-Host 'ERROR: no encuentro el disco compartido (busco <letra>:\HermesSync\.hermes-sync).'
    exit 1
}
$Base = Join-Path $RaizLinux 'Config\Hermes-Win'
$SesionDir = Join-Path $Base 'sesion-hermes'
$BackupDir = Join-Path $Base 'backups'

if (-not $HermesHome) {
    $HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME }
                  elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'hermes' }
                  else { '' }
}
if (-not $Destino) { $Destino = $HermesHome }
$EsActivo = ($Destino -eq $HermesHome)

if (-not $Quiet) {
    Write-Host '==============================================='
    Write-Host ' RESTAURACIÓN DE HERMES AGENT (Windows)'
    Write-Host " Fecha:   $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
    Write-Host " Origen:  $(if ($DesdeCarpeta) { $DesdeCarpeta } elseif ($Zip) { $Zip } elseif ($SoloSesion) { $SesionDir } else { "$BackupDir (último zip)" })"
    Write-Host " Destino: $Destino$(if ($EsActivo) { '  (INSTALACIÓN ACTIVA)' })"
    Write-Host '==============================================='
}

# ── PASO 1. Comprobación del sistema ──────────────────────────────────────────────────
Paso 'PASO 1: comprobación del sistema'
foreach ($c in @('tar.exe', 'robocopy.exe', 'icacls.exe')) {
    if (Get-Command $c -ErrorAction SilentlyContinue) { ok "$c disponible" } else { aviso "$c no encontrado (puede ser necesario)" }
}
$cmdHermes = $null
# Preferir el launcher del home destino: si se restaura en otro home, el `hermes` del PATH
# ejecutaría OTRA instalación (con este HERMES_HOME), que no es lo que se quiere verificar.
$launcherDestino = Join-Path $Destino 'bin\hermes.exe'
if (Test-Path $launcherDestino) {
    $cmdHermes = [pscustomobject]@{ Source = $launcherDestino }
} else {
    $cmdHermes = Get-Command hermes -ErrorAction SilentlyContinue
}
if ($cmdHermes) {
    [void](Correr -Exe $cmdHermes.Source -Argumentos @('--version'))
    $ver = ($script:SalidaNativa -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    ok "Hermes ya instalado: $ver"
} else {
    aviso 'Hermes no está instalado todavía'
}

# ── PASO 2. Instalación de Hermes si falta ────────────────────────────────────────────
Paso 'PASO 2: instalación de Hermes Agent'
if ($cmdHermes) {
    ok 'Se omite la instalación (ya está presente)'
} elseif ($Instalar) {
    if (-not $Quiet) { Write-Host '   Instalando con el instalador oficial...' }
    [void](Correr -Exe 'powershell.exe' -Argumentos @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
        'iex (irm https://hermes-agent.nousresearch.com/install.ps1)'))
    if ($LASTEXITCODE -eq 0) { ok 'Hermes instalado (abre una terminal nueva para tener el comando en PATH)' }
    else { mal 'Fallo al instalar Hermes: instálalo a mano y vuelve a ejecutar este script'; exit 1 }
} else {
    aviso 'Hermes no está instalado. Ejecuta este script con -Instalar, o instálalo con:'
    if (-not $Quiet) { Write-Host '      iex (irm https://hermes-agent.nousresearch.com/install.ps1)' }
}

# ── PASO 3. Localizar la fuente de restauración ───────────────────────────────────────
Paso 'PASO 3: localización de la copia de seguridad'
$FuenteDir = ''
$Temporal = ''

if ($DesdeCarpeta -ne '') {
    if (Test-Path $DesdeCarpeta) { $FuenteDir = (Resolve-Path $DesdeCarpeta).Path; ok "Carpeta de backup: $FuenteDir" }
    else { mal "no existe la carpeta indicada: $DesdeCarpeta"; exit 1 }
} else {
    if (-not $Zip -and -not $SoloSesion -and (Test-Path $BackupDir)) {
        $ultimo = Get-ChildItem -Path $BackupDir -Filter 'hermes-win-backup-*.zip' -ErrorAction SilentlyContinue |
                  Sort-Object Name | Select-Object -Last 1
        if ($ultimo) { $Zip = $ultimo.FullName }
    }
    if ($Zip -and (Test-Path $Zip)) {
        $mb = [math]::Round((Get-Item $Zip).Length / 1MB, 2)
        ok "ZIP encontrado: $Zip ($mb MB)"
        $Temporal = Join-Path $env:TEMP ("restore-hermes-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Force -Path $Temporal | Out-Null
        $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
        $rc = 1
        if (Test-Path $tar) {
            $rc = Correr -Exe $tar -Argumentos @('-x', '-f', $Zip, '-C', $Temporal)
        } else {
            try { Expand-Archive -Path $Zip -DestinationPath $Temporal -Force; $rc = 0 } catch { $rc = 1 }
        }
        if ($rc -ne 0) { mal 'no se pudo extraer el ZIP'; exit 1 }
        $FuenteDir = $Temporal
        ok "ZIP extraído en $Temporal"
    } elseif ($SoloSesion -or (Test-Path $SesionDir)) {
        if ($SoloSesion) { aviso 'Modo -SoloSesion: se restaura solo el respaldo canónico' }
        else { aviso "No hay ningún ZIP en ${BackupDir}: se restaura solo sesion-hermes\" }
        $FuenteDir = $SesionDir
    } else {
        mal "No hay NINGUNA copia de seguridad en $Base. Nada que restaurar."
        exit 1
    }
}

# ── PASO 4. Restauración de configuración y datos ─────────────────────────────────────
Paso 'PASO 4: restauración de configuración y datos'
New-Item -ItemType Directory -Force -Path $Destino | Out-Null
$exclF = @('/XF', '*-restore.*', 'restore-win.cmd', 'restaurar-hermes.ps1', 'backup-hermes.ps1',
           'sync-hermes.ps1', 'check-setup-win.ps1', 'INFO.txt', '*.zip', '*.lock')
$exclD = @('/XD', 'credenciales', '__pycache__')
$rc = Correr -Exe 'robocopy.exe' -Argumentos (@($FuenteDir, $Destino, '/E',
          '/NFL', '/NDL', '/NJH', '/NJS', '/R:1', '/W:1') + $exclF + $exclD)
if ($rc -ge 8) { mal "robocopy devolvió $rc al restaurar en $Destino" } else { ok "Contenido restaurado en $Destino" }

# Credenciales a su ubicación original, con ACL restringida
foreach ($c in @('.env', 'auth.json')) {
    $origenCred = Join-Path (Join-Path $FuenteDir 'credenciales') $c
    if (Test-Path $origenCred) {
        $dst = Join-Path $Destino $c
        Copy-Item $origenCred $dst -Force
        Set-AclPrivada $dst -Fichero
        ok "credenciales\$c restaurado en $Destino\"
    } elseif ($EsActivo) {
        aviso "no hay credenciales\$c en la copia de seguridad"
    }
}
foreach ($c in @('.env', 'auth.json')) {
    $p = Join-Path $Destino $c
    if (Test-Path $p) { Set-AclPrivada $p -Fichero }
}
if (Test-Path $Destino) { Set-AclPrivada $Destino }

# Reponer los scripts del esquema en su sitio, SOLO cuando se restaura el equipo real: con
# -Destino apuntando a otro home no se debe tocar el esquema, porque sesion-hermes puede ir
# por detrás y se pisarían los scripts buenos con la copia.
if ($EsActivo) {
    foreach ($s in @('AGENTS-WIN.md', 'backup-hermes.ps1', 'sync-hermes.ps1', 'check-setup-win.ps1',
                     'restaurar-hermes.ps1', 'registrar-tareas.ps1', 'instalar-desde-cero.ps1',
                     'hook-backup-hermes.sh', 'commit-parche.txt', '.gitignore')) {
        $o = Join-Path $SesionDir $s
        if ((Test-Path $o) -and (Test-Path $Base)) { Copy-Item $o (Join-Path $Base $s) -Force }
    }
}

# ── PASO 5. Verificación final ───────────────────────────────────────────────────────
Paso 'PASO 5: verificación'
foreach ($f in @('config.yaml', '.env', 'auth.json', 'SOUL.md', 'memories\MEMORY.md', 'skills')) {
    if (Test-Path (Join-Path $Destino $f)) { ok $f } else { mal "falta $f en $Destino" }
}
if ($cmdHermes -and $EsActivo -and -not $SinDoctor) {
    if (Test-HermesVivo) { aviso 'Hermes está en marcha: cierra la aplicación antes de usar la instalación restaurada' }
    if (-not $Quiet) { Write-Host ''; Write-Host '   hermes doctor:' }
    [void](Correr -Exe $cmdHermes.Source -Argumentos @('doctor'))
    if (-not $Quiet) { Write-Host ($script:SalidaNativa.TrimEnd() -split "`r?`n" | Select-Object -First 25 | Out-String) }
}
if ($cmdHermes -and $EsActivo) {
    [void](Correr -Exe $cmdHermes.Source -Argumentos @('config', 'get', 'model.default'))
    $modelo = ($script:SalidaNativa -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    if ($modelo) { ok "modelo configurado: $($modelo.Trim())" }
}

# ── PASO 6. Limpieza ─────────────────────────────────────────────────────────────────
if ($Temporal -and (Test-Path $Temporal)) { Remove-Item $Temporal -Recurse -Force -ErrorAction SilentlyContinue }

if (-not $Quiet) {
    Write-Host ''
    Write-Host '==============================================='
    if ($script:Fallos -eq 0) {
        Write-Host ' RESTAURACIÓN COMPLETADA SIN FALLOS'
        Write-Host " Destino: $Destino"
    } else {
        Write-Host " RESTAURACIÓN COMPLETADA CON $($script:Fallos) AVISOS/FALLOS"
        Write-Host ' Revisa las líneas [FALLO] de arriba.'
    }
    Write-Host '==============================================='
}
if ($script:Fallos -eq 0) { exit 0 } else { exit 2 }
