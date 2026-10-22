# Encargo 22 - Instalar el aviso de arranque completo (Linux -> Windows)
#
# Que hace: copia el aviso de arranque nuevo (`hermes-ready-notify.ps1`) desde el
# canal comun al esquema de Windows y a la copia local que ejecuta el lanzador
# (`gateway-service\` en los dos sitios), guardando el anterior
# como .bak-<fecha>, y VALIDA su sintaxis con el parser de PowerShell 5.1 antes de
# dejarlo instalado (si no compila, restaura el anterior y sale con 1).
#
# Por que: el aviso de Windows solo decia "Hermes activo + import". El de Linux
# lleva ademas Update, Dual boot (nota nueva y encargos pendientes), veredicto y
# estado del parche Ctrl+Q. Antonio quiere la misma informacion en los dos.
#
# Reglas del canal: sin argumentos, sin interaccion, idempotente, sin secretos.
# Si ya esta al dia sale con 0 sin tocar nada.

$ErrorActionPreference = 'Continue'

function Buscar-Comun {
    foreach ($codigo in 68..90) {
        $letra = [string][char]$codigo
        $raiz = "${letra}:\"
        if (-not (Test-Path -LiteralPath $raiz -ErrorAction SilentlyContinue)) { continue }
        $cand = "${letra}:\HermesSync"
        if (Test-Path -LiteralPath "$cand\.hermes-sync" -PathType Leaf -ErrorAction SilentlyContinue) { return $cand }
    }
    return $null
}

function Buscar-Esquema {
    # El esquema de Windows es la carpeta que contiene AGENTS-WIN.md bajo Linux\Config\Hermes-Win.
    foreach ($codigo in 68..90) {
        $letra = [string][char]$codigo
        $raiz = "${letra}:\"
        if (-not (Test-Path -LiteralPath $raiz -ErrorAction SilentlyContinue)) { continue }
        $cand = "${letra}:\Linux\Config\Hermes-Win"
        if (Test-Path -LiteralPath "$cand\AGENTS-WIN.md" -PathType Leaf -ErrorAction SilentlyContinue) { return $cand }
    }
    return $null
}

$comun = Buscar-Comun
if (-not $comun) {
    Write-Output 'AVISO: no encuentro la carpeta compartida (HermesSync\.hermes-sync en D:..Z:)'
    exit 1
}
$esquema = Buscar-Esquema
if (-not $esquema) {
    Write-Output 'AVISO: no encuentro el esquema de Windows (Linux\Config\Hermes-Win\AGENTS-WIN.md en D:..Z:)'
    exit 1
}
Write-Output "canal:   $comun"
Write-Output "esquema: $esquema"

$origen = Join-Path $comun 'windows\hermes-ready-notify.ps1'
if (-not (Test-Path -LiteralPath $origen -PathType Leaf)) {
    Write-Output "AVISO: no existe el aviso publicado en $origen"
    exit 1
}

$dirDestino = Join-Path $esquema 'gateway-service'
$destino = Join-Path $dirDestino 'hermes-ready-notify.ps1'
if (-not (Test-Path -LiteralPath $dirDestino)) {
    New-Item -ItemType Directory -Path $dirDestino -Force | Out-Null
}

$hOrigen = (Get-FileHash -LiteralPath $origen -Algorithm SHA256).Hash
if (Test-Path -LiteralPath $destino) {
    $hDestino = (Get-FileHash -LiteralPath $destino -Algorithm SHA256).Hash
    if ($hOrigen -eq $hDestino) {
        Write-Output "OK: el aviso ya esta al dia (sha256 $($hOrigen.Substring(0,12)))"
        exit 0
    }
}

# Copia de seguridad del anterior (si lo hay) antes de sustituirlo.
$bak = $null
if (Test-Path -LiteralPath $destino) {
    $bak = "$destino.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item -LiteralPath $destino -Destination $bak -Force
    Write-Output "copia del anterior: $bak"
}

Copy-Item -LiteralPath $origen -Destination $destino -Force
Write-Output "copiado a: $destino"

# Validacion con el parser de PowerShell 5.1 (este mismo proceso).
# ParseFile no entiende rutas de proveedor/PSDrive: se le pasa la ruta nativa.
$destinoNativo = (Get-Item -LiteralPath $destino).FullName
$errores = $null
$tokens = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($destinoNativo, [ref]$tokens, [ref]$errores)
if ($errores -and $errores.Count -gt 0) {
    foreach ($e in $errores) {
        Write-Output ("ERROR de sintaxis linea " + $e.Extent.StartLineNumber + ": " + $e.Message)
    }
    if ($bak) {
        Copy-Item -LiteralPath $bak -Destination $destino -Force
        Write-Output 'restaurado el aviso anterior'
    } else {
        Remove-Item -LiteralPath $destino -Force -ErrorAction SilentlyContinue
        Write-Output 'borrado el aviso copiado (no compila)'
    }
    exit 1
}
Write-Output "OK: sintaxis valida; sha256 $($hOrigen.Substring(0,12))"

# La copia que REALMENTE se ejecuta al arrancar es la LOCAL, no la del esquema:
# el lanzador del Inicio (Hermes_ReadyNotify.vbs) apunta a
# %LOCALAPPDATA%\hermes\gateway-service\hermes-ready-notify.ps1. Sin este paso el
# arranque sigue usando la copia vieja aunque el esquema este al dia.
$dirLocal = Join-Path $env:LOCALAPPDATA 'hermes\gateway-service'
$destinoLocal = Join-Path $dirLocal 'hermes-ready-notify.ps1'
if (-not (Test-Path -LiteralPath $dirLocal)) {
    New-Item -ItemType Directory -Path $dirLocal -Force | Out-Null
}
$hLocal = $null
if (Test-Path -LiteralPath $destinoLocal) {
    $hLocal = (Get-FileHash -LiteralPath $destinoLocal -Algorithm SHA256).Hash
}
if ($hLocal -eq $hOrigen) {
    Write-Output "OK: la copia que se ejecuta ya estaba al dia ($destinoLocal)"
} else {
    if (Test-Path -LiteralPath $destinoLocal) {
        Copy-Item -LiteralPath $destinoLocal -Destination ("$destinoLocal.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
    }
    Copy-Item -LiteralPath $origen -Destination $destinoLocal -Force
    $localNativo = (Get-Item -LiteralPath $destinoLocal).FullName
    $errLocal = $null
    $tokLocal = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($localNativo, [ref]$tokLocal, [ref]$errLocal)
    if ($errLocal -and $errLocal.Count -gt 0) {
        foreach ($e in $errLocal) {
            Write-Output ("ERROR de sintaxis (copia local) linea " + $e.Extent.StartLineNumber + ": " + $e.Message)
        }
        Write-Output 'AVISO: la copia local no compila; revisa a mano antes del proximo arranque'
        exit 1
    }
    Write-Output "copiado a la copia que se ejecuta: $destinoLocal"
}

# El aviso se lanza desde la carpeta Inicio: comprobar que el lanzador sigue ahi.
$inicio = $null
if ($env:APPDATA) { $inicio = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup' }
$lanzadores = @()
if ($inicio -and (Test-Path -LiteralPath $inicio)) {
    $lanzadores = @(Get-ChildItem -LiteralPath $inicio -Filter '*notify*.vbs' -File -ErrorAction SilentlyContinue)
}
if ($lanzadores.Count -eq 0) {
    Write-Output 'AVISO: no veo el lanzador *notify*.vbs en la carpeta Inicio; el aviso no se ejecutara al arrancar'
} else {
    Write-Output ("lanzador de arranque: " + ($lanzadores.Name -join ', '))
}
Write-Output 'El aviso nuevo se usara en el proximo inicio de sesion.'
exit 0
