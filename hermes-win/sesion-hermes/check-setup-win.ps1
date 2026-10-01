<#
  check-setup-win.ps1 — Verificación automática del esquema de backup de Hermes en Windows.

  Se ejecuta SIEMPRE al inicio de backup-hermes.ps1: si devuelve error, el backup se ABORTA
  para no guardar un setup defectuoso (misma filosofía que check-setup-completo.sh en Linux).

  Comprueba:
    1. Sintaxis de los scripts del esquema ([Parser]::ParseFile)
    2. Que existe el instalador desde limpio (sesion-hermes\restaurar-hermes.ps1)
    3. Estructura del esquema (raíz, backups\, sesion-hermes\, AGENTS-WIN.md, .gitignore)
    4. Que existe todo lo que el backup necesita copiar (config.yaml, .env, auth.json, SOUL.md,
       skills\, memories\)
    5. Permisos restringidos de las credenciales del respaldo canónico (sesion-hermes)

  Uso:
    powershell -ExecutionPolicy Bypass -File check-setup-win.ps1
    ... -Disco D -HermesHome "C:\Users\evo01\AppData\Local\hermes"
#>
[CmdletBinding()]
param(
    [string]$Disco = '',
    [string]$HermesHome = ''
)

$ErrorActionPreference = 'Stop'

$script:Errores = 0

function ok   { param([string]$m) Write-Host "   [ok] $m" }
function warn { param([string]$m) Write-Host "   [aviso] $m" }
function fail { param([string]$m) Write-Host "   [FALLO] $m"; $script:Errores++ }

function Correr {
    # Ejecuta un .exe con $ErrorActionPreference='Continue' y devuelve su exit code.
    # Con 'Stop', PowerShell 5.1 convierte en error terminante (NativeCommandError) cualquier
    # línea que un .exe escriba en stderr; 2>$null NO lo evita.
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
    # La letra del disco SEAGATE puede cambiar entre arranques. Se localiza con la marca del
    # estado compartido (HermesSync\.hermes-sync) y se usa <letra>:\Linux como raíz.
    param([string]$Letra = '')
    if ($Letra -ne '') {
        $raiz = "${Letra}:\Linux"
        if (Test-Path $raiz) { return $raiz }
        Write-Host "   [FALLO] el disco indicado no tiene carpeta Linux: $raiz"
        return $null
    }
    foreach ($l in ([char[]](68..90))) {
        $cand = "${l}:\HermesSync\.hermes-sync"
        try { if (Test-Path $cand) { return "${l}:\Linux" } } catch { }
    }
    return $null
}

# ── 0. Localización de rutas ────────────────────────────────────────────────────────────
$RaizLinux = Find-RaizLinux -Letra $Disco
if (-not $RaizLinux) {
    Write-Host "[FALLO] no encuentro el disco compartido (busco <letra>:\HermesSync\.hermes-sync)."
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
$DotfilesWin = Join-Path $RaizLinux 'Documentos\dotfiles\hermes-win'

Write-Host "== check-setup-win.ps1 — $(Get-Date -Format 'dd/MM/yyyy HH:mm') =="
Write-Host "   Raíz del esquema: $Base"
Write-Host "   Hermes activo:    $HermesHome"

# ── 1. Sintaxis de los scripts ──────────────────────────────────────────────────────────
Write-Host "── 1. Sintaxis de los scripts ──"
foreach ($s in @('backup-hermes.ps1', 'sync-hermes.ps1', 'check-setup-win.ps1', 'restaurar-hermes.ps1', 'registrar-tareas.ps1', 'instalar-desde-cero.ps1')) {
    $ruta = Join-Path $Base $s
    if (-not (Test-Path $ruta)) { fail "$s : no existe en $Base"; continue }
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        fail "$s : error de sintaxis -> $($errs[0].Message)"
    } else {
        # Trampa clásica: una variable del script seguida de dos puntos dentro de una cadena
        # expandible se lee como referencia de scope y el script no arranca del todo
        # ("El carácter ':' no va seguido..."). Hay que delimitar el nombre: ${Var}.
        $texto = Get-Content -Path $ruta -Raw -Encoding UTF8
        $sospechosos = @()
        foreach ($m in [regex]::Matches($texto, '\$([A-Za-z_][A-Za-z0-9_]*):')) {
            if ($m.Groups[1].Value -notin @('env', 'script', 'global', 'local', 'using', 'args')) { $sospechosos += $m.Value }
        }
        if ($sospechosos.Count -gt 0) {
            fail ("$s : variable seguida de ':' dentro de una cadena (" + ($sospechosos -join ', ') + ') -> usa ${var}')
        } else {
            ok $s
        }
    }
}

# ── 2. Instalador desde limpio ──────────────────────────────────────────────────────────
Write-Host "── 2. Instalador desde limpio ──"
$instalador = Join-Path $SesionDir 'restaurar-hermes.ps1'
$instaladorRaiz = Join-Path $Base 'restaurar-hermes.ps1'
if (Test-Path $instalador) {
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($instalador, [ref]$null, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) { fail "sesion-hermes\restaurar-hermes.ps1 : error de sintaxis" }
    else { ok 'sesion-hermes\restaurar-hermes.ps1' }
} elseif (Test-Path $instaladorRaiz) {
    warn 'sesion-hermes\restaurar-hermes.ps1 todavía no existe (se copiará en este backup)'
} else {
    fail 'restaurar-hermes.ps1 : NO EXISTE ni en la raíz ni en sesion-hermes (instalador desde limpio)'
}

# ── 3. Estructura del esquema ───────────────────────────────────────────────────────────
Write-Host "── 3. Estructura del esquema ──"
foreach ($d in @($Base, $BackupDir, $SesionDir, $DotfilesWin)) {
    if (Test-Path $d) { ok "existe $d" } else { warn "falta $d (se creará en el backup)" }
}
foreach ($f in @('AGENTS-WIN.md', '.gitignore')) {
    if (Test-Path (Join-Path $Base $f)) { ok $f } else { warn "sin $f en $Base" }
}

# ── 4. Origen a respaldar ───────────────────────────────────────────────────────────────
Write-Host "── 4. Origen a respaldar ($HermesHome) ──"
if (-not (Test-Path $HermesHome)) {
    fail "no existe el directorio de Hermes: $HermesHome"
} else {
    foreach ($f in @('config.yaml', '.env', 'auth.json', 'SOUL.md')) {
        if (Test-Path (Join-Path $HermesHome $f)) { ok $f } else { fail "$f no existe en $HermesHome" }
    }
    foreach ($d in @('skills', 'memories')) {
        if (Test-Path (Join-Path $HermesHome $d)) { ok "$d\" } else { fail "$d\ no existe en $HermesHome" }
    }
}

# ── 5. Permisos de las credenciales ─────────────────────────────────────────────────────
Write-Host "── 5. Permisos de las credenciales ──"
function Get-AclResumen {
    param([string]$Ruta)
    $acl = Get-Acl -Path $Ruta
    return (($acl.Access | ForEach-Object { "$($_.IdentityReference)" } | Sort-Object -Unique) -join ',')
}
foreach ($f in @('.env', 'auth.json')) {
    $p = Join-Path $SesionDir $f
    if (-not (Test-Path $p)) { continue }
    $quien = Get-AclResumen $p
    if ($quien -match 'evo01' -and $quien -notmatch 'Users|Todos|Everyone' ) {
        ok "sesion-hermes\$f (solo $quien)"
    } else {
        fail "sesion-hermes\$f accesible por: $quien (debe ser solo el usuario)"
    }
}

Write-Host ''
if ($script:Errores -eq 0) {
    Write-Host "VERIFICACIÓN CORRECTA (0 errores)"
    exit 0
} else {
    Write-Host "VERIFICACIÓN FALLIDA ($($script:Errores) errores)"
    exit 1
}
