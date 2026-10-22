# Encargo 21 - Aplicar el parche Ctrl+Q al arrancar (idempotente)
#
# Que hace: comprueba el arbol de Hermes de Windows y, si el parche local Ctrl+Q no
# esta aplicado, lo aplica desde el canal comun. El parche hace que Ctrl+Q corte solo
# la locucion (sin interrumpir el turno) y que Ctrl+C corte la locucion ademas de
# conservar su comportamiento de siempre.
#
# Por que: tras cada `hermes update` el actualizador puede dejar el parche aparcado
# ("NO aplica limpio (no forzado)") y Windows se queda sin Ctrl+Q hasta que alguien
# lo re-porta. Este encargo lo reaplica solo en cada arranque.
#
# Reglas del canal: sin argumentos, sin interaccion, idempotente, sin secretos.
# Si no consigue aplicarlo sale con 1 (se reintenta al siguiente arranque) y NO fuerza
# nada: un parche de otro commit se rechaza en vez de dejar el arbol a medias.
#
# Nota: el parche se aplica mientras el gateway ya ha cargado sus modulos, asi que el
# efecto se nota en el siguiente arranque. No rompe el que esta en marcha.

$ErrorActionPreference = 'Continue'

function Buscar-Comun {
    # La letra del SEAGATE cambia entre arranques: se localiza por el marcador .hermes-sync.
    # Sin Join-Path: con una unidad inexistente (Z:..) lanza error aunque el resultado sea
    # "no existe", y ensuciaria el log del encargo.
    foreach ($codigo in 68..90) {
        $letra = [string][char]$codigo
        $raiz = "${letra}:\"
        if (-not (Test-Path -LiteralPath $raiz -ErrorAction SilentlyContinue)) { continue }
        $cand = "${letra}:\HermesSync"
        if (Test-Path -LiteralPath "$cand\.hermes-sync" -PathType Leaf -ErrorAction SilentlyContinue) {
            return $cand
        }
    }
    return $null
}

$comun = Buscar-Comun
if (-not $comun) {
    Write-Output 'AVISO: no encuentro la carpeta compartida (HermesSync\.hermes-sync en D:..Z:)'
    exit 1
}
Write-Output "carpeta compartida: $comun"

$repo = Join-Path $env:LOCALAPPDATA 'hermes\hermes-agent'
if (-not (Test-Path -LiteralPath $repo -PathType Container)) {
    Write-Output "AVISO: no existe el arbol de Hermes ($repo)"
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Output 'AVISO: git no esta en el PATH; no puedo comprobar el parche'
    exit 1
}

$parche = Join-Path $comun 'windows\parches\ctrl-q-corta-audio.patch'
if (-not (Test-Path -LiteralPath $parche -PathType Leaf)) {
    Write-Output "nada que hacer: no hay parche en $parche"
    exit 0
}

$head = (& git -C $repo rev-parse --short HEAD 2>$null) -join ''
Write-Output "commit actual: $head"

# 1) Ya aplicado -> nada que hacer.
& git -C $repo apply --reverse --check $parche 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Output 'OK: el parche Ctrl+Q ya esta aplicado'
    exit 0
}

# 2) No aplica limpio -> no forzar; se reintenta cuando llegue un parche de este commit.
& git -C $repo apply --check $parche 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Output "PENDIENTE: el parche no aplica limpio sobre $head; no se fuerza (pide re-porte en NOTA-PARA-LINUX.md)"
    exit 1
}

# 3) Aplicar y verificar.
& git -C $repo apply $parche
if ($LASTEXITCODE -ne 0) {
    Write-Output 'FALLO: git apply devolvio error'
    exit 1
}

& git -C $repo apply --reverse --check $parche 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Output 'FALLO: se aplico pero el reverse-check no cuadra; revisar el arbol'
    exit 1
}

$stat = (& git -C $repo diff --stat 2>$null) -join ' | '
Write-Output "OK: parche Ctrl+Q aplicado ($stat)"
Write-Output 'El efecto se nota en el siguiente arranque: Ctrl+Q corta solo la locucion.'
exit 0
