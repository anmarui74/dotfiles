<#
  verificar-import-arranque.ps1 - comprueba si el estado que publico el otro
  sistema (la "memoria de intercambio" de Hermes entre Linux y Windows) llego a
  integrarse en este arranque de Windows.

  Lee el log del motor de sincronizacion (X:\HermesSync\logs\<equipo>.log) y mira
  lo que paso desde que arranco Windows, sin tocar nada.

  Salida: una linea resumida (pensada para el aviso de Telegram) y, si aplica, una
  segunda linea indentada con el detalle.  Codigo de salida:
     0 = integrado, o sin novedades del otro sistema (todo correcto)
     1 = hay estado del otro sistema pendiente de integrar
     2 = no consta ninguna importacion desde el arranque
     3 = no se pudo comprobar (disco compartido, log o fecha no disponibles)

  Uso:
     powershell -ExecutionPolicy Bypass -File verificar-import-arranque.ps1
     ... -EsperaSegundos 30        # reintenta por si el import aun esta corriendo
     ... -Desde '05/10/2026 15:10' -MargenSegundos 30

  OJO con -Desde: los parametros [datetime] de PowerShell se convierten con la
  cultura invariante (MM/dd/yyyy), asi que '05/10/2026' se leeria como 10 de mayo.
  Por eso aqui el parametro es una cadena y se parsea a mano con formato espanol.

  Nota: este fichero se guarda en UTF-8 CON BOM (PowerShell 5.1 leeria los acentos
  mal sin el).
#>
[CmdletBinding()]
param(
    [string]$Desde = '',
    [int]$MargenSegundos = 30,
    [int]$EsperaSegundos = 0,
    [string]$Comun = ''
)

$ErrorActionPreference = 'Stop'

function Buscar-Comun {
    param([string]$Pista)
    if ($Pista -ne '' -and (Test-Path (Join-Path $Pista '.hermes-sync') -ErrorAction SilentlyContinue)) { return $Pista }
    foreach ($letra in ([char[]](68..90))) {
        $cand = "${letra}:\HermesSync"
        try { if (Test-Path (Join-Path $cand '.hermes-sync')) { return $cand } } catch { }
    }
    return $null
}

function Leer-Fecha {
    param([string]$Texto)
    $formatos = @('dd/MM/yyyy HH:mm:ss', 'dd/MM/yyyy HH:mm', 'dd/MM/yyyy', 'yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm')
    foreach ($f in $formatos) {
        $dt = [datetime]::MinValue
        if ([datetime]::TryParseExact($Texto.Trim(), $f,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::None, [ref]$dt)) { return $dt }
    }
    return $null
}

function Obtener-Eventos {
    param([string]$Ruta, [datetime]$Corte)
    $acc = New-Object System.Collections.ArrayList
    $lineas = Get-Content -LiteralPath $Ruta -Tail 500 -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($l in @($lineas)) {
        if ($l -match '^\[(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2})\]\s?(.*)$') {
            $dt = Leer-Fecha $Matches[1]
            if ($dt -and $dt -ge $Corte) {
                [void]$acc.Add([pscustomobject]@{ Fecha = $dt; Texto = $Matches[2] })
            }
        }
    }
    return $acc
}

# --- 1) carpeta compartida ---------------------------------------------------
$raiz = Buscar-Comun -Pista $Comun
if (-not $raiz) {
    Write-Output 'no encuentro la carpeta compartida HermesSync en ninguna unidad'
    exit 3
}

# --- 2) log del motor de este equipo ----------------------------------------
$logsDir = Join-Path $raiz 'logs'
$log = Join-Path $logsDir "$env:COMPUTERNAME.log"
if (-not (Test-Path -LiteralPath $log)) {
    $cand = Get-ChildItem -LiteralPath $logsDir -Filter '*.log' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'cachyos.log' } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($cand) { $log = $cand.FullName }
}
if (-not (Test-Path -LiteralPath $log)) {
    Write-Output "no encuentro el log del motor de sincronizacion en $logsDir"
    exit 3
}

# --- 3) desde cuando mirar ---------------------------------------------------
if ($Desde -eq '') {
    $desdeDt = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $etiqueta = 'arranque de Windows'
} else {
    $desdeDt = Leer-Fecha $Desde
    if (-not $desdeDt) {
        Write-Output "fecha -Desde no reconocida: '$Desde' (usa dd/MM/yyyy HH:mm)"
        exit 3
    }
    $etiqueta = $desdeDt.ToString('dd/MM/yyyy HH:mm')
}
$corte = $desdeDt.AddSeconds(-1 * $MargenSegundos)

# --- 4) leer y clasificar ----------------------------------------------------
$eventos = Obtener-Eventos -Ruta $log -Corte $corte
$esperado = 0
while ($eventos.Count -eq 0 -and $esperado -lt $EsperaSegundos) {
    Start-Sleep -Seconds 5
    $esperado += 5
    $eventos = Obtener-Eventos -Ruta $log -Corte $corte
}

$resumen = $null
$detalle = "log: $log"
$codigo = 2

# Se recorre del evento mas antiguo al mas reciente: el primero que resuelve es el del
# import de arranque (lo que viene despues son las publicaciones de la tarea de 5 minutos).
for ($i = 0; $i -lt $eventos.Count; $i++) {
    $t = $eventos[$i].Texto
    $hora = $eventos[$i].Fecha.ToString('HH:mm')

    if ($t -match '^Importado( por fusi\u00f3n)?\.') {
        $codigo = 0
        $resumen = "integrado a las $hora"
        for ($j = $i - 1; $j -ge 0; $j--) {
            if ($eventos[$j].Texto -match "^Importando estado de '(.+)' de (\d{2}/\d{2}/\d{4} \d{2}:\d{2}) \((\d+) sesiones\)") {
                $resumen = "integrado a las $hora - estado de '$($Matches[1])' del $($Matches[2]) ($($Matches[3]) sesiones)"
                break
            }
        }
        break
    }
    elseif ($t -match 'lo public\u00f3 este mismo equipo') {
        $codigo = 0
        $resumen = "sin novedades del otro sistema (a las $hora lo publicado era de este equipo)"
        break
    }
    elseif ($t -match 'sin integrar') {
        $codigo = 1
        $resumen = "hay estado del otro sistema SIN integrar ($hora) - $t"
        break
    }
}

switch ($codigo) {
    0 { Write-Output $resumen }
    1 { Write-Output $resumen; Write-Output "   $detalle" }
    2 {
        $textoDesde = if ($etiqueta -eq 'arranque de Windows') { "el arranque de Windows ($($desdeDt.ToString('dd/MM/yyyy HH:mm')))" } else { $etiqueta }
        Write-Output ("no consta ninguna importacion desde {0}" -f $textoDesde)
        Write-Output "   $detalle"
        Write-Output '   revisa que el lanzador de Inicio siga importando antes del gateway (registrar-tareas.cmd)'
    }
}
exit $codigo
