<#
  backup-hermes.ps1 — Backup de Hermes Agent en Windows (esquema Hermes-Win)

  Equivalente Windows de ~/Config/hermes/backup-hermes.sh: genera el ZIP de restauración
  (con las credenciales dentro y permisos restringidos), refresca el respaldo canónico
  sesion-hermes\ y deja la copia saneada SIN claves en dotfiles\hermes-win\.

  Puntos del esquema (ver AGENTS-WIN.md):
    - %LOCALAPPDATA%\hermes            -> configuración ACTIVA (la que usa Hermes)
    - X:\Linux\Config\Hermes-Win\      -> copia de SEGURIDAD (instalación desde limpio)
    - X:\Linux\Config\Hermes-Win\backups\        -> zips hermes-win-backup-*.zip
    - X:\Linux\Config\Hermes-Win\sesion-hermes\  -> respaldo canónico + instalador
    - X:\Linux\Documentos\dotfiles\hermes-win\   -> copia saneada SIN claves de API

  Uso:
    powershell -ExecutionPolicy Bypass -File backup-hermes.ps1
    ... -Quiet             (para el programador de tareas: solo escribe el log)
    ... -SinDotfiles       (no refrescar la copia saneada)
    ... -Disco D           (forzar la letra del disco compartido)
#>
[CmdletBinding()]
param(
    [string]$Disco = '',
    [string]$HermesHome = '',
    [switch]$SinDotfiles,
    [switch]$SinRetencion,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$script:LogFile = $null
$script:SalidaNativa = ''
$script:Nombre = ''
$script:RetencionDias = 30

function Escribir-Log {
    param([string]$Mensaje, [switch]$SoloLog)
    $linea = "[{0}] {1}" -f (Get-Date -Format 'dd/MM/yyyy HH:mm:ss'), $Mensaje
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value $linea -Encoding UTF8 }
    if (-not $SoloLog -and -not $Quiet) { Write-Host $Mensaje }
}

function Abortar {
    param([string]$Mensaje)
    Escribir-Log "ERROR: $Mensaje"
    Write-Host "ERROR: $Mensaje"
    exit 1
}

function Correr {
    # Ejecuta un programa externo con $ErrorActionPreference='Continue' y devuelve su exit code.
    # Con 'Stop', PowerShell 5.1 convierte en error terminante (NativeCommandError) cualquier
    # línea que un .exe escriba en stderr; 2>$null NO lo evita.  Se captura stdout+stderr en
    # $script:SalidaNativa para poder registrarlo.
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
    # La letra del disco SEAGATE cambia entre arranques: se localiza con la marca del estado
    # compartido (HermesSync\.hermes-sync) y se usa <letra>:\Linux como raíz.
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

function Find-Python {
    $candidatos = @()
    if ($HermesHome) {
        $candidatos += (Join-Path $HermesHome 'hermes-agent\.venv\Scripts\python.exe')
        $candidatos += (Join-Path $HermesHome 'venv\Scripts\python.exe')
    }
    foreach ($c in $candidatos) { if (Test-Path $c) { return $c } }
    foreach ($n in @('python', 'python3', 'py')) {
        $cmd = Get-Command $n -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Copy-Sqlite {
    # Copia consistente de una base SQLite (nunca el fichero abierto tal cual).
    param([string]$Origen, [string]$Destino)
    if (-not (Test-Path $Origen)) { return $false }
    $dir = Split-Path -Parent $Destino
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $py = Find-Python
    $ok = $false
    if ($py) {
        $codigo = 'import sqlite3,sys; src=sqlite3.connect(sys.argv[1]); dst=sqlite3.connect(sys.argv[2]); src.backup(dst); dst.close(); src.close()'
        $rc = Correr -Exe $py -Argumentos @('-c', $codigo, $Origen, $Destino)
        if ($rc -eq 0) { $ok = $true } else { Escribir-Log "AVISO: falló la copia consistente de $Origen; se copia el fichero tal cual" -SoloLog }
    }
    if (-not $ok) {
        Copy-Item -Path $Origen -Destination $Destino -Force
    }
    return $true
}

function Set-AclPrivada {
    # NTFS equivalente al 0700 (carpetas) / 0600 (ficheros): hereda quitada y solo el usuario.
    param([string]$Ruta, [switch]$Fichero)
    if (-not (Test-Path $Ruta)) { return }
    $usuario = "$env:USERDOMAIN\$env:USERNAME"
    $permiso = if ($Fichero) { "${usuario}:F" } else { "${usuario}:(OI)(CI)F" }
    $rc = Correr -Exe 'icacls.exe' -Argumentos @($Ruta, '/inheritance:r', '/grant:r', $permiso)
    if ($rc -ne 0) { Escribir-Log "AVISO: no se han podido restringir los permisos de $Ruta ($rc)" -SoloLog }
}

function Invoke-Robocopy {
    param([string]$Origen, [string]$Destino, [string[]]$Extra = @())
    if (-not (Test-Path $Origen)) { return 0 }
    New-Item -ItemType Directory -Force -Path $Destino | Out-Null
    $op = @($Origen, $Destino, '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/R:1', '/W:1') + $Extra
    $rc = Correr -Exe 'robocopy.exe' -Argumentos $op
    if ($rc -ge 8) { Escribir-Log "AVISO: robocopy devolvió $rc al copiar $Origen -> $Destino" -SoloLog }
    return $rc
}

function New-Zip {
    param([string]$Directorio, [string]$Zip)
    if (Test-Path $Zip) { Remove-Item $Zip -Force }
    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (Test-Path $tar) {
        $rc = Correr -Exe $tar -Argumentos @('-a', '-c', '-f', $Zip, '-C', $Directorio, '.')
        if ($rc -ne 0) { Abortar "no se pudo crear el zip con tar ($rc): $($script:SalidaNativa)" }
    } else {
        Compress-Archive -Path (Join-Path $Directorio '*') -DestinationPath $Zip -Force
    }
}

# ── Escaneo de claves (dos fases, como en Linux) ──────────────────────────────────────
function Recolectar-Secretos {
    param($Objeto)
    if ($null -eq $Objeto) { return }
    if ($Objeto -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $Objeto.PSObject.Properties) {
            if ($p.Value -is [string]) {
                if ($p.Name -match '(?i)token|key|secret|password|credential|refresh|cookie|session' -and $p.Value.Length -ge 12) {
                    $script:Recolectados.Add($p.Value)
                }
            } else {
                Recolectar-Secretos $p.Value
            }
        }
    } elseif (($Objeto -is [System.Collections.IEnumerable]) -and ($Objeto -isnot [string])) {
        foreach ($e in $Objeto) { Recolectar-Secretos $e }
    }
}

function Get-ValoresSecretos {
    # Saca los valores REALES de .env y auth.json (no patrones): es la comprobación que de
    # verdad encuentra claves escondidas en ficheros que el escaneo por patrones no ve.
    param([string]$EnvFile, [string]$AuthFile)
    $valores = New-Object System.Collections.Generic.List[string]
    if (Test-Path $EnvFile) {
        foreach ($linea in (Get-Content $EnvFile -ErrorAction SilentlyContinue)) {
            if ($linea -match '^\s*[A-Za-z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|PASS|CRED|COOKIE)[A-Za-z0-9_]*\s*=\s*(.+)$') {
                $v = $Matches[2].Trim().Trim('"').Trim("'")
                if ($v.Length -ge 12) { $valores.Add($v) }
            }
        }
    }
    if (Test-Path $AuthFile) {
        try {
            $json = Get-Content $AuthFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $script:Recolectados = New-Object System.Collections.Generic.List[string]
            Recolectar-Secretos $json
            foreach ($v in $script:Recolectados) { $valores.Add($v) }
        } catch {
            Escribir-Log "AVISO: no he podido leer auth.json para el escaneo de valores ($($_.Exception.Message))" -SoloLog
        }
    }
    return ($valores | Where-Object { $_ } | Select-Object -Unique)
}

function Test-Claves {
    # Devuelve la lista de ficheros con posibles claves y los BORRA de la copia saneada.
    param([string]$Directorio, [string]$HermesHome)
    $patrones = @(
        '(nvapi-|oc_sk_)[A-Za-z0-9_-]{15,}',
        '(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{25,}',
        'AEMET_API_KEY=[A-Za-z0-9]{15,}',
        'NVIDIA_API_KEY=[A-Za-z0-9_-]{15,}',
        'OPENCODE_GO_API_KEY=[A-Za-z0-9_-]{15,}',
        'ssh-(rsa|ed25519|dss) [A-Za-z0-9+/=]{20,}',
        'BEGIN [A-Z ]*PRIVATE KEY',
        '[0-9]{8,12}:[A-Za-z0-9_-]{30,}'
    )
    $valores = @(Get-ValoresSecretos -EnvFile (Join-Path $HermesHome '.env') -AuthFile (Join-Path $HermesHome 'auth.json'))
    Escribir-Log "   🔎 Escaneo: $($patrones.Count) patrones + $($valores.Count) valores reales de credenciales" -SoloLog
    $hallazgos = New-Object System.Collections.Generic.List[string]
    foreach ($f in (Get-ChildItem -Path $Directorio -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        $texto = ''
        try { $texto = Get-Content -Path $f.FullName -Raw -Encoding UTF8 -ErrorAction Stop } catch { continue }
        $motivo = $null
        if ($f.Extension -ne '.md') {
            foreach ($p in $patrones) { if ($texto -match $p) { $motivo = "patron $p"; break } }
        }
        if (-not $motivo) {
            foreach ($v in $valores) { if ($texto.Contains($v)) { $motivo = 'valor real de .env/auth.json'; break } }
        }
        if ($motivo) {
            $rel = $f.FullName.Substring($Directorio.Length).TrimStart('\')
            $hallazgos.Add("$rel : $motivo")
            Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
        }
    }
    return $hallazgos
}

# ════════════════════════════════════════════════════════════════════════════════════════
$RaizLinux = Find-RaizLinux -Letra $Disco
if (-not $RaizLinux) { Abortar 'no encuentro el disco compartido (busco <letra>:\HermesSync\.hermes-sync).' }
$Base = Join-Path $RaizLinux 'Config\Hermes-Win'
$BackupDir = Join-Path $Base 'backups'
$SesionDir = Join-Path $Base 'sesion-hermes'
$DotfilesWin = Join-Path $RaizLinux 'Documentos\dotfiles\hermes-win'

if (-not $HermesHome) {
    $HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME }
                  elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'hermes' }
                  else { '' }
}
if (-not $HermesHome -or -not (Test-Path $HermesHome)) { Abortar "no existe el directorio activo de Hermes: $HermesHome" }

New-Item -ItemType Directory -Force -Path $Base, $BackupDir, $SesionDir | Out-Null
$script:LogFile = Join-Path $Base 'sync.log'

$Fecha = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:Nombre = "hermes-win-backup-$Fecha"
$Root = Join-Path $BackupDir "tmp-$($script:Nombre)"
$Zip = Join-Path $BackupDir "$($script:Nombre).zip"

Escribir-Log "=== Backup Hermes Agent (Windows) - $(Get-Date -Format 'dd/MM/yyyy HH:mm') ==="

# ── 0. VERIFICACIÓN OBLIGATORIA (si falla, se ABORTA el backup) ─────────────────────────
$check = Join-Path $Base 'check-setup-win.ps1'
if (Test-Path $check) {
    Escribir-Log '🔍 Verificando setup (check-setup-win.ps1)...'
    $argsCheck = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $check)
    if ($Disco -ne '') { $argsCheck += @('-Disco', $Disco) }
    if ($HermesHome -ne '') { $argsCheck += @('-HermesHome', $HermesHome) }
    $rcCheck = Correr -Exe 'powershell.exe' -Argumentos $argsCheck
    $salidaCheck = $script:SalidaNativa
    if (-not $Quiet) { Write-Host $salidaCheck.TrimEnd() }
    if ($rcCheck -ne 0) {
        Escribir-Log '❌❌❌ VERIFICACIÓN DEL SETUP FALLIDA ❌❌❌'
        Escribir-Log '   El esquema de backup no está correcto/completo. Backup ABORTADO.'
        foreach ($l in ($salidaCheck -split "`r?`n")) {
            if ($l -match '\[FALLO\]') { Escribir-Log "   $($l.Trim())" -SoloLog }
        }
        exit 1
    }
    Escribir-Log '✅ Setup verificado. Continuando backup...'
} else {
    Escribir-Log "⚠️  check-setup-win.ps1 no encontrado en $Base"
}

if (Test-Path $Root) { Remove-Item $Root -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Root | Out-Null
Set-AclPrivada $BackupDir
Set-AclPrivada $SesionDir

# ── 1. Refrescar el respaldo canónico (sesion-hermes) ──────────────────────────────────
Escribir-Log '🔄 Refrescando respaldo canónico en sesion-hermes\...'
foreach ($f in @('config.yaml', '.env', 'auth.json', 'SOUL.md')) {
    $o = Join-Path $HermesHome $f
    if (Test-Path $o) { Copy-Item $o (Join-Path $SesionDir $f) -Force }
}
foreach ($s in @('AGENTS-WIN.md', 'backup-hermes.ps1', 'sync-hermes.ps1', 'check-setup-win.ps1',
                 'restaurar-hermes.ps1', 'bootstrap-hermes.ps1', 'registrar-tareas.ps1',
                 'instalar-desde-cero.ps1', 'hook-backup-hermes.sh', 'commit-parche.txt', '.gitignore')) {
    $o = Join-Path $Base $s
    if (Test-Path $o) { Copy-Item $o (Join-Path $SesionDir $s) -Force }
}
foreach ($f in @('.env', 'auth.json')) {
    $p = Join-Path $SesionDir $f
    if (Test-Path $p) { Set-AclPrivada $p -Fichero }
}

# ── 2. Archivos sueltos de configuración ───────────────────────────────────────────────
Escribir-Log "📦 Copiando configuración desde $HermesHome\..."
foreach ($f in @('config.yaml', 'SOUL.md', 'install_id', 'channel_directory.json', 'shell-hooks-allowlist.json')) {
    $o = Join-Path $HermesHome $f
    if (Test-Path $o) { Copy-Item $o (Join-Path $Root $f) -Force }
}

# ── 3. Directorios de datos (whitelist; nunca binarios ni estado) ──────────────────────
# Fuera a propósito: state.db* y sessions\ (histórico de conversaciones, viaja por el
# esquema dual boot), cache\, logs\, runtime\, sandboxes\, terminal-sessions\, tools\,
# installs\, hermes-agent\ (clon git), clones temporales, pairing\, pending_messages\.
foreach ($d in @('skills', 'plugins', 'memories', 'hooks', 'agent-hooks', 'skins',
                 'tui-widgets', 'desktop-plugins', 'pets')) {
    $o = Join-Path $HermesHome $d
    if (Test-Path $o) {
        [void](Invoke-Robocopy -Origen $o -Destino (Join-Path $Root $d) `
              -Extra @('/XF', '*.lock', '*.sock', '*.pid', '*.pyc', '/XD', '__pycache__'))
    }
}

# Credencial del Portal Nous (access/refresh token): va al zip, NUNCA a dotfiles
$shared = Join-Path $HermesHome 'shared'
if (Test-Path $shared) {
    [void](Invoke-Robocopy -Origen $shared -Destino (Join-Path $Root 'shared') -Extra @('/XF', '*.lock', '*.pid'))
    Escribir-Log '   ✅ shared\ (auth del Portal Nous) incluido'
}

# Trabajos programados (sin la BD de ejecuciones, que es de runtime)
$cron = Join-Path $HermesHome 'cron'
if (Test-Path $cron) {
    [void](Invoke-Robocopy -Origen $cron -Destino (Join-Path $Root 'cron') `
          -Extra @('/XF', 'executions.db', '*.lock', '*.sock', 'ticker_*', '/XD', 'ticker_*'))
}

# Tablero kanban (datos, no runtime): copia consistente
$kanban = Join-Path $HermesHome 'kanban.db'
if (Test-Path $kanban) {
    if (Copy-Sqlite -Origen $kanban -Destino (Join-Path $Root 'kanban.db')) {
        Escribir-Log '   ✅ kanban.db incluido (copia consistente)'
    }
}

# ── 4. Credenciales (.env + auth.json): SOLO en el zip / sesion-hermes, ACL restringida ─
$CredDir = Join-Path $Root 'credenciales'
New-Item -ItemType Directory -Force -Path $CredDir | Out-Null
Set-AclPrivada $CredDir
foreach ($c in @('.env', 'auth.json')) {
    $o = Join-Path $HermesHome $c
    if (Test-Path $o) {
        $dst = Join-Path $CredDir $c
        Copy-Item $o $dst -Force
        Set-AclPrivada $dst -Fichero
        Escribir-Log "   ✅ credenciales\$c incluido"
    } else {
        Escribir-Log "   ⚠️  $o no encontrado"
    }
}

# ── 5. INFO.txt (trazabilidad) ─────────────────────────────────────────────────────────
$info = New-Object System.Collections.Generic.List[string]
$info.Add("Backup: $($script:Nombre)")
$info.Add("Fecha:  $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')")
$info.Add("HERMES_HOME: $HermesHome")
$info.Add("Equipo: $env:COMPUTERNAME")
$hermesCmd = Get-Command hermes -ErrorAction SilentlyContinue
if ($hermesCmd) {
    $rcv = Correr -Exe $hermesCmd.Source -Argumentos @('--version')
    foreach ($l in ($script:SalidaNativa -split "`r?`n")) { if ($l.Trim()) { $info.Add($l.Trim()) } }
}
$info.Add('')
$info.Add('Contenido (nivel raíz):')
Get-ChildItem -Path $Root -Force | Sort-Object Name | ForEach-Object { $info.Add("  $($_.Name)") }
Set-Content -Path (Join-Path $Root 'INFO.txt') -Value $info -Encoding UTF8

# ── 6. restore-win.cmd dentro del zip (autosuficiente, como el restore.sh de Linux) ────
$cmd = @'
@echo off
REM Restaurar Hermes Agent desde este backup - generado por backup-hermes.ps1
REM Uso: restore-win.cmd [-Destino "<ruta>"]

setlocal
set "AQUI=%~dp0"
REM %~dp0 acaba en barra invertida: al pasarla entre comillas a powershell,
REM la barra escaparía la comilla y el argumento se tragaría el resto de la linea.
set "AQUI=%AQUI:~0,-1%"
echo === Restaurando Hermes Agent desde %AQUI% ===
powershell -NoProfile -ExecutionPolicy Bypass -File "%AQUI%\restaurar-hermes.ps1" -DesdeCarpeta "%AQUI%" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" echo AVISO: la restauracion devolvio %RC%
endlocal & exit /b %RC%
'@ -split "`r?`n" -join "`r`n"
Set-Content -Path (Join-Path $Root 'restore-win.cmd') -Value $cmd -Encoding ASCII -NoNewline
$instalador = Join-Path $Base 'restaurar-hermes.ps1'
if (Test-Path $instalador) {
    Copy-Item $instalador (Join-Path $Root 'restaurar-hermes.ps1') -Force
    Escribir-Log '   ✅ restaurar-hermes.ps1 + restore-win.cmd incluidos'
} else {
    Escribir-Log '   ⚠️  restaurar-hermes.ps1 no encontrado en la raíz del esquema'
}

# ── 7. ZIP (dentro van las credenciales en claro: ACL restringida) ────────────────────
Escribir-Log ''
Escribir-Log '📦 Creando ZIP...'
New-Zip -Directorio $Root -Zip $Zip
Set-AclPrivada $Zip -Fichero
$tam = [math]::Round((Get-Item $Zip).Length / 1MB, 2)
Escribir-Log "   ✅ ZIP creado ($tam MB): $Zip"

# ── 8. Limpiar el directorio temporal ──────────────────────────────────────────────────
Remove-Item $Root -Recurse -Force

# ── 9. Retención (30 días) y poda de duplicados del mismo día ─────────────────────────
if (-not $SinRetencion) {
    Escribir-Log ''
    Escribir-Log "🧹 Aplicando retención ($($script:RetencionDias) días)..."
    $limite = (Get-Date).AddDays(-$script:RetencionDias)
    $viejos = @(Get-ChildItem -Path $BackupDir -Filter 'hermes-win-backup-*.zip' -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $limite })
    foreach ($v in $viejos) { Remove-Item $v.FullName -Force }
    Escribir-Log "   🗑️  $($viejos.Count) zips antiguos eliminados"

    $podados = 0
    $todos = @(Get-ChildItem -Path $BackupDir -Filter 'hermes-win-backup-*.zip' -ErrorAction SilentlyContinue |
               Sort-Object Name)
    $porDia = $todos | Group-Object { ($_.Name -replace '^hermes-win-backup-(\d{8})-.*$', '$1') }
    foreach ($g in $porDia) {
        $sobrantes = @($g.Group | Sort-Object Name | Select-Object -SkipLast 1)
        foreach ($s in $sobrantes) { Remove-Item $s.FullName -Force; $podados++ }
    }
    Escribir-Log "   🗂️  $podados duplicados del mismo día eliminados"
}

# ── 10. Copia saneada en dotfiles (SIN claves de API) ─────────────────────────────────
if (-not $SinDotfiles) {
    Escribir-Log ''
    Escribir-Log '🔐 Sincronizando copia en dotfiles\hermes-win (SIN claves de API)...'
    New-Item -ItemType Directory -Force -Path $DotfilesWin | Out-Null
    $exclF = @('/XF', '.env', '*.env', 'auth.json', '*.zip', '*.tar.gz', '*-restore.*',
               'restore-win.cmd', '*.lock', '*.pyc', '*.pid', '*.sock')
    $exclD = @('/XD', 'credenciales', 'shared', 'backups', '__pycache__', '.git')
    $rc = Correr -Exe 'robocopy.exe' -Argumentos (@($Base, $DotfilesWin, '/MIR',
              '/NFL', '/NDL', '/NJH', '/NJS', '/R:1', '/W:1') + $exclF + $exclD)
    if ($rc -ge 8) { Escribir-Log "AVISO: robocopy de dotfiles devolvió $rc" -SoloLog }

    # Purga explícita en el destino (por si algo se coló: --delete-excluded de Linux)
    foreach ($pat in @('*.zip', '*.tar.gz', '.env', '*.env', 'auth.json', '*.lock')) {
        Get-ChildItem -Path $DotfilesWin -Filter $pat -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    foreach ($d in @('credenciales', 'shared', 'backups')) {
        $p = Join-Path $DotfilesWin $d
        if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # ── 10b. Escaneo de claves (fase 1: patrones; fase 2: valores reales del .env/auth.json)
    $hallazgos = @(Test-Claves -Directorio $DotfilesWin -HermesHome $HermesHome)
    if ($hallazgos.Count -eq 0) {
        Escribir-Log '   ✅ Copia en dotfiles libre de claves (patrones + valores reales)'
    } else {
        Escribir-Log "   ⚠️  ATENCIÓN: $($hallazgos.Count) fichero(s) con posibles claves. Se han borrado de la copia saneada:"
        foreach ($h in $hallazgos) { Escribir-Log "      - $h" -SoloLog }
        Set-Content -Path (Join-Path $DotfilesWin "AVISO-CLAVES-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt") `
                    -Value $hallazgos -Encoding UTF8
    }
}

Escribir-Log ''
Escribir-Log '✅ Backup completado.'
Escribir-Log "   ZIP: $Zip"
Escribir-Log '   Para restaurar (prueba SIEMPRE en una carpeta temporal):'
Escribir-Log "     1. powershell -ExecutionPolicy Bypass -File `"$Base\restaurar-hermes.ps1`" -Destino `"$env:TEMP\restore-hermes`""
Escribir-Log "     2. o descomprimir el zip y ejecutar restore-win.cmd"
exit 0
