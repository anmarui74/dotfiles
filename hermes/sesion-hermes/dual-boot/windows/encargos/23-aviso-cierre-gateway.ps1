# Encargo 23 - Instalar el aviso de cierre del gateway (Linux -> Windows)
#
# Que hace: copia a Windows el vigilante de cierre (`hermes-cierre-notify.ps1`) y su
# lanzador de la carpeta Inicio (`Hermes_CierreNotify.vbs`).
#
# Por que: Hermes no tiene evento de cierre (sus hooks son gateway:startup, session:*
# y agent:*), asi que el aviso se da desde fuera: un vigilante espera a que aparezca
# el proceso del gateway y manda un mensaje a Telegram cuando desaparece. Si en 30 s
# aparece otro gateway (un reinicio), NO avisa.
#
# Destinos (los dos, como en el encargo 22):
#   - <esquema>\gateway-service\hermes-cierre-notify.ps1   (fuente)
#   - %LOCALAPPDATA%\hermes\gateway-service\...            (la copia que ejecuta el lanzador)
#   - %APPDATA%\...\Startup\Hermes_CierreNotify.vbs         (lanzador)
#
# Reglas del canal: sin argumentos, sin interaccion, idempotente, sin secretos.

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
    foreach ($codigo in 68..90) {
        $letra = [string][char]$codigo
        $raiz = "${letra}:\"
        if (-not (Test-Path -LiteralPath $raiz -ErrorAction SilentlyContinue)) { continue }
        $cand = "${letra}:\Linux\Config\Hermes-Win"
        if (Test-Path -LiteralPath "$cand\AGENTS-WIN.md" -PathType Leaf -ErrorAction SilentlyContinue) { return $cand }
    }
    return $null
}

# Copia con .bak y validacion de sintaxis. Devuelve $true si quedo instalado.
function Instalar-Ps1 {
    param([string]$Origen, [string]$Destino, [string]$Etiqueta)
    $dir = Split-Path -Parent $Destino
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $hOrigen = (Get-FileHash -LiteralPath $Origen -Algorithm SHA256).Hash
    if (Test-Path -LiteralPath $Destino) {
        $hDestino = (Get-FileHash -LiteralPath $Destino -Algorithm SHA256).Hash
        if ($hOrigen -eq $hDestino) {
            Write-Output "OK: $Etiqueta ya estaba al dia"
            return $true
        }
        Copy-Item -LiteralPath $Destino -Destination ("$Destino.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
    }
    Copy-Item -LiteralPath $Origen -Destination $Destino -Force
    $nativo = (Get-Item -LiteralPath $Destino).FullName
    $errores = $null
    $tokens = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($nativo, [ref]$tokens, [ref]$errores)
    if ($errores -and $errores.Count -gt 0) {
        foreach ($e in $errores) {
            Write-Output ("ERROR de sintaxis en " + $Etiqueta + " linea " + $e.Extent.StartLineNumber + ": " + $e.Message)
        }
        return $false
    }
    Write-Output "OK: $Etiqueta instalado ($($hOrigen.Substring(0,12)))"
    return $true
}

$comun = Buscar-Comun
if (-not $comun) {
    Write-Output 'AVISO: no encuentro la carpeta compartida'
    exit 1
}
$esquema = Buscar-Esquema
if (-not $esquema) {
    Write-Output 'AVISO: no encuentro el esquema de Windows'
    exit 1
}

$origenPs1 = Join-Path $comun 'windows\hermes-cierre-notify.ps1'
$origenVbs = Join-Path $comun 'windows\Hermes_CierreNotify.vbs'
if (-not (Test-Path -LiteralPath $origenPs1 -PathType Leaf)) {
    Write-Output "AVISO: falta $origenPs1"
    exit 1
}

$okEsquema = Instalar-Ps1 -Origen $origenPs1 -Destino (Join-Path $esquema 'gateway-service\hermes-cierre-notify.ps1') -Etiqueta 'esquema'
$okLocal = Instalar-Ps1 -Origen $origenPs1 -Destino (Join-Path $env:LOCALAPPDATA 'hermes\gateway-service\hermes-cierre-notify.ps1') -Etiqueta 'copia local'
if (-not ($okEsquema -and $okLocal)) { exit 1 }

# Lanzador en la carpeta Inicio
if (Test-Path -LiteralPath $origenVbs -PathType Leaf) {
    if ($env:APPDATA) {
        $inicio = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
        if (-not (Test-Path -LiteralPath $inicio)) { New-Item -ItemType Directory -Path $inicio -Force | Out-Null }
        $destinoVbs = Join-Path $inicio 'Hermes_CierreNotify.vbs'
        $hO = (Get-FileHash -LiteralPath $origenVbs -Algorithm SHA256).Hash
        $hD = $null
        if (Test-Path -LiteralPath $destinoVbs) { $hD = (Get-FileHash -LiteralPath $destinoVbs -Algorithm SHA256).Hash }
        if ($hO -ne $hD) {
            Copy-Item -LiteralPath $origenVbs -Destination $destinoVbs -Force
            Write-Output "OK: lanzador instalado en Inicio ($destinoVbs)"
        } else {
            Write-Output 'OK: el lanzador de Inicio ya estaba al dia'
        }
    } else {
        Write-Output 'AVISO: APPDATA no definido; no copio el lanzador de Inicio'
    }
} else {
    Write-Output "AVISO: falta $origenVbs; no copio el lanzador"
}

Write-Output 'El vigilante de cierre se usara en el proximo inicio de sesion.'
exit 0
