<#
  hermes-dual-sync.ps1 — Estado compartido de Hermes entre Windows y Linux (dual boot)

  Uso:
    powershell -ExecutionPolicy Bypass -File hermes-dual-sync.ps1 -Accion auto
    ... -Accion import | export | estado | semilla
  Opciones: -Forzar  -SoloSiCambia  -Quiet  -SinImport  -Comun "D:\HermesSync"

  La lógica es la misma que la del script de Linux
  (~/Config/hermes/dual-boot/hermes-dual-sync.sh): nunca hay dos sistemas
  encendidos a la vez, así que vale el criterio "el último que publicó manda",
  con historial y copia local de seguridad antes de cada importación.

  IMPORT CON HERMES EN MARCHA (desde 05/10/2026): no se sustituye state.db —una base
  abierta por el gateway quedaría ilegible— pero el import tampoco se descarta: se
  FUSIONAN las sesiones que falten (sin borrar nada de este equipo) y se copian los
  árboles.  Así la publicación no se queda bloqueada y Windows puede importar y
  publicar aunque estés usando Hermes.  kanban.db (base que el gateway puede tener
  abierta) se completa en el primer import con Hermes cerrado; queda anotado en
  estado.json como importación parcial.
#>
[CmdletBinding()]
param(
    [ValidateSet('auto', 'import', 'export', 'estado', 'semilla')] [string]$Accion = 'auto',
    [switch]$Forzar,
    [switch]$SoloSiCambia,
    [switch]$Quiet,
    [switch]$SinImport,
    [string]$Comun = ''
)

function Join-Ruta {
    # Rutas escritas siempre con '/' y convertidas al separador nativo del sistema
    param([string]$Base, [string]$Hijo)
    return (Join-Path $Base ($Hijo -replace '/', [IO.Path]::DirectorySeparatorChar))
}

$ErrorActionPreference = 'Stop'
$HostActual = $env:COMPUTERNAME
$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME }
              elseif ($env:LOCALAPPDATA) { Join-Ruta $env:LOCALAPPDATA 'hermes' }
              else { throw 'No encuentro el directorio de datos de Hermes: define HERMES_HOME.' }
$EstadoLocalDir = Join-Ruta $HermesHome '.dual-sync'
$EstadoLocalJson = Join-Ruta $EstadoLocalDir 'estado.json'
$BackupsLocales = Join-Ruta $EstadoLocalDir 'backups'
$MarcaPublicacion = Join-Ruta $EstadoLocalDir '.ultima-publicacion'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CopiadorPy = Join-Ruta $ScriptDir 'copiar-state.py'

$Arboles = @('sessions', 'memories', 'skills', 'cron')
$Ficheros = @('state.db', 'kanban.db', 'SOUL.md')
$ComunRaiz = $null


function Write-Log {
    param([string]$Mensaje, [switch]$SoloLog)
    $linea = "[{0}] {1}" -f (Get-Date -Format 'dd/MM/yyyy HH:mm:ss'), $Mensaje
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value $linea -Encoding UTF8 }
    if (-not $SoloLog -and -not $Quiet) { Write-Host $Mensaje }
}

function Stop-ConError {
    param([string]$Mensaje)
    Write-Log "ERROR: $Mensaje" -SoloLog
    Write-Error "ERROR: $Mensaje"
    exit 1
}

function Find-Comun {
    if ($Comun -ne '' -and (Test-Path (Join-Ruta $Comun '.hermes-sync') -ErrorAction SilentlyContinue)) { return $Comun }
    if ($Comun -ne '' -and (Test-Path $Comun -ErrorAction SilentlyContinue)) { return $Comun }
    foreach ($letra in ([char[]](68..90))) {
        $cand = "${letra}:\HermesSync"
        try { if (Test-Path (Join-Ruta $cand '.hermes-sync')) { return $cand } } catch { }
    }
    return $null
}

function Find-Python {
    $candidatos = @(
        (Join-Ruta $HermesHome 'hermes-agent/.venv/Scripts/python.exe'),
        (Join-Ruta $HermesHome 'venv/Scripts/python.exe')
    )
    if ($env:LOCALAPPDATA) { $candidatos += (Join-Ruta $env:LOCALAPPDATA 'hermes/hermes-agent/.venv/Scripts/python.exe') }
    foreach ($c in $candidatos) { if (Test-Path $c) { return $c } }
    foreach ($n in @('python', 'python3', 'py')) {
        $cmd = Get-Command $n -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Copy-Sqlite {
    param([string]$Origen, [string]$Destino)
    if (-not $script:Python) { Stop-ConError "hace falta Python (viene con Hermes) para copiar la base de datos con seguridad." }
    if (-not (Test-Path $Origen)) { Stop-ConError "no existe $Origen" }
    $dirDestino = Split-Path -Parent $Destino
    if ($dirDestino) { New-Item -ItemType Directory -Force -Path $dirDestino | Out-Null }
    & $script:Python $CopiadorPy $Origen $Destino
    if ($LASTEXITCODE -ne 0) { Stop-ConError "falló la copia de $Origen ($LASTEXITCODE)" }
}

function Get-Sesiones {
    param([string]$Db)
    if (-not $script:Python) { return 0 }
    # El stderr de un ejecutable nativo, con $ErrorActionPreference='Stop', puede
    # abortar PowerShell 5.1 (NativeCommandError): se baja el listón un momento.
    $eapPrevio = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $n = @(& $script:Python $CopiadorPy --contar $Db 2>$null)
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $eapPrevio
    if ($rc -ne 0 -or $n.Count -eq 0) { return 0 }
    return [int]$n[0]
}

function Invoke-Robocopy {
    param([string]$Origen, [string]$Destino)
    if (-not (Test-Path $Origen)) { return }
    New-Item -ItemType Directory -Force -Path $Destino | Out-Null
    $opciones = @($Origen, $Destino, '/MIR', '/XF', '*.lock', '/NFL', '/NDL', '/NJH', '/NJS', '/R:1', '/W:1')
    robocopy @opciones | Out-Null
    if ($LASTEXITCODE -ge 8) { Write-Log "AVISO: robocopy devolvió $LASTEXITCODE al copiar $Origen" -SoloLog }
}

function Test-HermesVivo {
    # Nunca se sustituye state.db con Hermes en marcha: el gateway o cualquier
    # sesión (CLI, escritorio) pueden tener la base abierta, y reemplazarla bajo
    # un proceso vivo la deja ilegible.  El 28/09/2026 pasó exactamente eso: la
    # importación de arranque coincidió con el arranque de Hermes y corrompió
    # state.db.  Por eso ya no basta con mirar gateway.pid (que durante el
    # arranque puede estar obsoleto o aún sin escribir): se pregunta al sistema
    # por cualquier proceso de la aplicación.
    try {
        $vivos = Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
            $_.CommandLine -and ($_.CommandLine -match 'hermes\.exe|hermes_cli|hermes-agent')
        }
        if ($vivos) { return $true }
    } catch {
        Write-Log "AVISO: no he podido consultar los procesos (CIM); me apoyo en gateway.pid" -SoloLog
    }
    $pidFile = Join-Ruta $HermesHome 'gateway.pid'
    if (-not (Test-Path $pidFile)) { return $false }
    $pidGateway = $null
    try {
        $contenido = (Get-Content $pidFile -Raw -Encoding UTF8).Trim()
        if ($contenido.StartsWith('{')) { $pidGateway = [int](ConvertFrom-Json $contenido).pid }
        elseif ($contenido -match '^\d+$') { $pidGateway = [int]$contenido }
    } catch { return $false }
    if (-not $pidGateway) { return $false }
    return [bool](Get-Process -Id $pidGateway -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------- export
function Invoke-Export {
    param([switch]$ConSemilla)

    $remoto = $null
    $manifiesto = Join-Ruta $Comun 'estado/MANIFEST.json'
    if (Test-Path $manifiesto) { $remoto = Get-Content $manifiesto -Raw -Encoding UTF8 | ConvertFrom-Json }

    if ($remoto -and $remoto.host -ne $HostActual -and [int]$remoto.publicado_epoch -gt [int]$script:UltimoImportEpoch) {
        if ($SinImport) { Stop-ConError "hay estado más nuevo de '$($remoto.host)' sin integrar. Ejecuta 'import' primero." }
        Write-Log "Hay estado más reciente de '$($remoto.host)' sin integrar: lo importo antes de publicar."
        Invoke-Import
    }

    if ($SoloSiCambia -and (Test-Path $MarcaPublicacion)) {
        $marca = Get-Item $MarcaPublicacion
        # Cada ruta entre parentesis: sin ellos el operador coma de PowerShell agrupa
        # las seis rutas en un solo elemento, Test-Path falla siempre y el atajo
        # -SoloSiCambia concluye 'sin cambios' y no publica nunca (arreglado 05/10/2026).
        $vigilados = @(
            (Join-Ruta $HermesHome 'state.db'),
            (Join-Ruta $HermesHome 'memories'),
            (Join-Ruta $HermesHome 'skills'),
            (Join-Ruta $HermesHome 'cron'),
            (Join-Ruta $HermesHome 'kanban.db'),
            (Join-Ruta $HermesHome 'SOUL.md'))
        $cambios = $vigilados | Where-Object { Test-Path $_ } | ForEach-Object {
            Get-ChildItem -Path $_ -Recurse -File -ErrorAction SilentlyContinue
        } | Where-Object { $_.LastWriteTimeUtc -gt $marca.LastWriteTimeUtc } | Select-Object -First 1
        if (-not $cambios) { return }
    }

    Write-Log "Publicando estado de $HostActual en $Comun/estado/"

    if ($remoto -and $remoto.host -ne $HostActual -and (Test-Path (Join-Ruta $Comun 'estado/state.db'))) {
        $dirHist = Join-Ruta $Comun ("historial/{0}" -f $remoto.host)
        New-Item -ItemType Directory -Force -Path $dirHist | Out-Null
        Copy-Item (Join-Ruta $Comun 'estado/state.db') (Join-Ruta $dirHist ("{0}-state.db" -f $remoto.publicado_epoch)) -Force
        Compress-Archive -Path (Join-Ruta $Comun 'estado/*') -DestinationPath (Join-Ruta $dirHist ("{0}-resto.zip" -f $remoto.publicado_epoch)) -Force
    }

    Copy-Sqlite (Join-Ruta $HermesHome 'state.db') (Join-Ruta $Comun 'estado/state.db')
    foreach ($d in $Arboles) { Invoke-Robocopy (Join-Ruta $HermesHome $d) (Join-Ruta $Comun "estado/$d") }
    foreach ($f in $Ficheros) {
        $o = Join-Ruta $HermesHome $f
        if (Test-Path $o) { Copy-Item $o (Join-Ruta $Comun "estado/$f") -Force }
    }

    # La semilla (config.yaml, .env, auth.json: llevan claves en claro) solo se
    # genera a petición: `-Accion semilla`. Antes se recreaba sola en cada
    # publicación cuando faltaba, así que borrarla no servía de nada: volvía a
    # aparecer con las claves en el disco compartido a los pocos minutos.
    $semillaDir = Join-Ruta $Comun 'semilla'
    if ($ConSemilla) {
        New-Item -ItemType Directory -Force -Path $semillaDir | Out-Null
        foreach ($f in @('config.yaml', '.env', 'auth.json', 'SOUL.md')) {
            $o = Join-Ruta $HermesHome $f
            if (Test-Path $o) { Copy-Item $o (Join-Ruta $semillaDir $f) -Force }
        }
        Write-Log "Semilla de configuración generada en $semillaDir (solo para el primer arranque del otro sistema)"
    }

    $dbComun = Join-Ruta $Comun 'estado/state.db'
    $sesiones = Get-Sesiones $dbComun
    $mensajes = 0
    if ($script:Python) {
        $eapPrevio = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $salidaMensajes = @(& $script:Python $CopiadorPy --contar-mensajes $dbComun 2>$null)
        $ErrorActionPreference = $eapPrevio
        if ($LASTEXITCODE -eq 0 -and $salidaMensajes.Count -gt 0) { $mensajes = [int]$salidaMensajes[0] }
    }
    $sha = (Get-FileHash $dbComun -Algorithm SHA256).Hash.ToLower()
    $version = ''
    try {
        $lineaVersion = (& hermes --version 2>$null | Select-Object -First 1)
        if ($lineaVersion) { $version = ($lineaVersion -replace '^Hermes Agent\s+', '') -split '\s+' | Select-Object -First 1 }
    } catch { }

    $datos = [ordered]@{
        protocolo         = 1
        host              = $HostActual
        hostname          = $HostActual
        plataforma        = 'Windows'
        publicado_utc     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        publicado_epoch   = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        hermes_version    = "$version"
        hermes_home       = $HermesHome
        sesiones          = $sesiones
        mensajes          = $mensajes
        sha256_state_db   = $sha
        contenido         = @{ arboles = $Arboles; ficheros = $Ficheros }
    }
    $datos | ConvertTo-Json -Depth 6 | Set-Content -Path $manifiesto -Encoding UTF8

    foreach ($patron in @('*-state.db', '*-resto.zip')) {
        Get-ChildItem -Path (Join-Ruta $Comun 'historial') -Recurse -Filter $patron -ErrorAction SilentlyContinue |
            Group-Object DirectoryName | ForEach-Object {
                $_.Group | Sort-Object LastWriteTime -Descending | Select-Object -Skip 5 | Remove-Item -Force -ErrorAction SilentlyContinue
            }
    }

    New-Item -ItemType File -Force -Path $MarcaPublicacion | Out-Null
    Write-Log "Publicado: $sesiones sesiones / $mensajes mensajes (sha256 $($sha.Substring(0,12))…)"
}

# ------------------------------------------------- copia del estado de importación
function Write-EstadoImport {
    # Deja constancia de la última importación.  Con $Pendientes no vacío queda
    # marcada como parcial: el próximo import con Hermes cerrado la completa.
    param([int]$Epoch, [string[]]$Pendientes = @())
    # La marca se deriva de la época, no del publicado_utc del manifiesto: ConvertFrom-Json
    # lo convierte a [datetime] y acababa escrito en formato local.  Así el fichero queda
    # igual de legible que el del motor de Linux.
    $utc = [DateTimeOffset]::FromUnixTimeSeconds($Epoch).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $estado = [ordered]@{
        host                = $HostActual
        ultimo_import_epoch = $Epoch
        ultimo_import_utc   = "$utc"
        parcial             = ($Pendientes.Count -gt 0)
        pendientes          = @($Pendientes)
    }
    $estado | ConvertTo-Json | Set-Content -Path $EstadoLocalJson -Encoding UTF8
    $script:UltimoImportEpoch = $Epoch
    $script:PendientesImport = @($Pendientes)
}

# ------------------------------------------------- import con Hermes en marcha
function Invoke-ImportParcial {
    # sustituir state.db con Hermes en marcha la corrompe, pero ESO no impide traer
    # lo del otro equipo: se fusionan las sesiones que falten (la base local es un
    # superconjunto: no se pierde nada) y se copian los árboles, que son ficheros.
    # kanban.db se deja para el primer import con Hermes cerrado.
    param([object]$Remoto, [int]$Epoch)
    $dbComun = Join-Ruta $Comun 'estado/state.db'

    # Mismas comprobaciones que el import completo: ante una copia dudosa, no tocar nada.
    $shaReal = (Get-FileHash $dbComun -Algorithm SHA256).Hash.ToLower()
    if ($Remoto.sha256_state_db -and $shaReal -ne $Remoto.sha256_state_db.ToLower()) {
        Stop-ConError "la copia de state.db de la carpeta común está corrupta (sha256 no coincide). Import abortado."
    }
    $sesRemotas = Get-Sesiones $dbComun
    if ($sesRemotas -le 0) { Stop-ConError "state.db remota ilegible (sin tabla de sesiones). Import abortado." }
    if ($Remoto.sesiones -and [int]$Remoto.sesiones -ne 0 -and $sesRemotas -ne [int]$Remoto.sesiones) {
        # El manifiesto lo escribe el motor de Linux contando las sesiones de su base VIVA,
        # que puede llevar alguna mas que la copia publicada (p. ej. una sesion oculta sin
        # mensajes creada entre la copia y el recuento). El sha256 comprobado arriba ya
        # garantiza que la copia es exactamente la publicada: se avisa, no se bloquea.
        Write-Log "AVISO: la copia tiene $sesRemotas sesiones y el manifiesto declara $($Remoto.sesiones); el sha256 coincide, sigo con el import."
    }
    if (-not $script:Python) { Stop-ConError "hace falta Python (viene con Hermes) para fusionar las sesiones." }

    Write-Log "Hermes está en marcha: importo por fusión (no sustituyo la base de datos)."

    $destinoBackup = Join-Ruta $BackupsLocales "$Epoch-parcial"
    New-Item -ItemType Directory -Force -Path $destinoBackup | Out-Null
    Copy-Sqlite (Join-Ruta $HermesHome 'state.db') (Join-Ruta $destinoBackup 'state.db')
    foreach ($d in $Arboles) { Invoke-Robocopy (Join-Ruta $HermesHome $d) (Join-Ruta $destinoBackup $d) }

    # Ojo con PowerShell 5.1: con $ErrorActionPreference='Stop', el stderr de un
    # ejecutable nativo (2>&1) puede abortar el script (NativeCommandError).
    $eapPrevio = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $salida = @(& $script:Python $CopiadorPy --fusionar $dbComun (Join-Ruta $HermesHome 'state.db') 2>&1)
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $eapPrevio
    foreach ($linea in $salida) { if ("$linea".Trim() -ne '') { Write-Log "   $($linea.ToString().Trim())" -SoloLog } }
    if ($rc -ne 0) { Stop-ConError "falló la fusión de sesiones ($rc); la base local no se ha tocado." }

    $eapPrevio = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $salidaInt = @(& $script:Python $CopiadorPy --integridad (Join-Ruta $HermesHome 'state.db') 2>&1)
    $rcInt = $LASTEXITCODE
    $ErrorActionPreference = $eapPrevio
    $integridad = if ($salidaInt.Count -gt 0) { "$($salidaInt[0])".Trim() } else { '' }
    if ($rcInt -ne 0 -or $integridad -ne 'ok') {
        # No se sustituye state.db con Hermes en marcha: se avisa y se deja la copia.
        Write-Log "ERROR: la base local no queda sana ('$integridad'). Copia previa en $destinoBackup."
        Write-Log "       No sustituyo state.db con Hermes en marcha: ciérralo y restaura esa copia a mano."
        exit 1
    }

    foreach ($d in $Arboles) { Invoke-Robocopy (Join-Ruta $Comun "estado/$d") (Join-Ruta $HermesHome $d) }
    $soulComun = Join-Ruta $Comun 'estado/SOUL.md'
    if (Test-Path $soulComun) { Copy-Item $soulComun (Join-Ruta $HermesHome 'SOUL.md') -Force }

    Write-EstadoImport -Epoch $Epoch -Pendientes @('kanban.db')
    Write-Log "Importado por fusión. Copia de seguridad previa en $destinoBackup"
    Write-Log "Pendiente para el próximo import con Hermes cerrado: kanban.db"
}

# ---------------------------------------------------------------- import
function Invoke-Import {
    $manifiesto = Join-Ruta $Comun 'estado/MANIFEST.json'
    if (-not (Test-Path $manifiesto)) { Write-Log "Aún no hay nada publicado por el otro sistema."; return }
    $remoto = Get-Content $manifiesto -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($remoto.host -eq $HostActual) { Write-Log "Lo publicado en la carpeta común lo publicó este mismo equipo."; return }
    $epoch = [int]$remoto.publicado_epoch
    if ($epoch -le [int]$script:UltimoImportEpoch -and -not $Forzar -and $script:PendientesImport.Count -eq 0) {
        Write-Log "Sin novedades de '$($remoto.host)' (última importación: $($script:UltimoImportEpoch))"
        return
    }
    if (Test-HermesVivo) {
        if ($epoch -le [int]$script:UltimoImportEpoch) {
            # Nada nuevo que traer y solo queda pendiente lo que exige Hermes cerrado
            # (kanban.db): se espera sin repetir trabajo en cada pasada de 5 minutos.
            Write-Log "Pendiente completar la importación (kanban.db) cuando cierres Hermes." -SoloLog
            return
        }
        Invoke-ImportParcial -Remoto $remoto -Epoch $epoch
        return
    }

    $dbComun = Join-Ruta $Comun 'estado/state.db'
    $shaReal = (Get-FileHash $dbComun -Algorithm SHA256).Hash.ToLower()
    if ($remoto.sha256_state_db -and $shaReal -ne $remoto.sha256_state_db.ToLower()) {
        Stop-ConError "la copia de state.db de la carpeta común está corrupta (sha256 no coincide). Import abortado."
    }
    $sesRemotas = Get-Sesiones $dbComun
    if ($sesRemotas -le 0) { Stop-ConError "state.db remota ilegible (sin tabla de sesiones). Import abortado." }
    if ($remoto.sesiones -and [int]$remoto.sesiones -ne 0 -and $sesRemotas -ne [int]$remoto.sesiones) {
        # El manifiesto lo escribe el motor de Linux contando las sesiones de su base VIVA,
        # que puede llevar alguna mas que la copia publicada (p. ej. una sesion oculta sin
        # mensajes creada entre la copia y el recuento). El sha256 comprobado arriba ya
        # garantiza que la copia es exactamente la publicada: se avisa, no se bloquea.
        Write-Log "AVISO: la copia tiene $sesRemotas sesiones y el manifiesto declara $($remoto.sesiones); el sha256 coincide, sigo con el import."
    }

    Write-Log "Importando estado de '$($remoto.host)' de $(Get-Date -Date $remoto.publicado_utc -Format 'dd/MM/yyyy HH:mm') ($sesRemotas sesiones)"

    $destinoBackup = Join-Ruta $BackupsLocales "$epoch"
    New-Item -ItemType Directory -Force -Path $destinoBackup | Out-Null
    Copy-Sqlite (Join-Ruta $HermesHome 'state.db') (Join-Ruta $destinoBackup 'state.db')
    foreach ($d in @('memories', 'skills', 'cron')) { Invoke-Robocopy (Join-Ruta $HermesHome $d) (Join-Ruta $destinoBackup $d) }

    # Última comprobación justo antes de tocar la base: entre el aviso de arriba
    # y este punto pasan segundos (copias de seguridad incluidas) y Hermes puede
    # haber arrancado en medio.  Sustituir state.db con Hermes vivo la deja
    # ilegible, así que en cuanto aparezca cualquier proceso de Hermes no se
    # toca nada y se deja la importación pendiente para el siguiente intento.
    if (Test-HermesVivo) {
        Write-Log "AVISO: Hermes ha arrancado mientras preparaba la importación; cambio a fusión."
        Invoke-ImportParcial -Remoto $remoto -Epoch $epoch
        return
    }

    Copy-Item $dbComun (Join-Ruta $HermesHome 'state.db') -Force

    # Y verificación inmediata: si la base local no queda sana, se restaura la
    # copia previa en lugar de dejar el equipo sin historial de sesiones.
    # Ojo con PowerShell 5.1: con $ErrorActionPreference='Stop', redirigir el
    # stderr de un ejecutable nativo (2>$null) puede abortar el script con un
    # NativeCommandError, así que se baja el listón solo durante esa llamada.
    if ($script:Python) {
        $eapPrevio = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $salida = @(& $script:Python $CopiadorPy --integridad (Join-Ruta $HermesHome 'state.db') 2>&1)
        $rcIntegridad = $LASTEXITCODE
        $ErrorActionPreference = $eapPrevio
        $integridad = if ($salida.Count -gt 0) { "$($salida[0])".Trim() } else { '' }
        if ($rcIntegridad -ne 0 -or $integridad -ne 'ok') {
            Copy-Item (Join-Ruta $destinoBackup 'state.db') (Join-Ruta $HermesHome 'state.db') -Force
            Stop-ConError "la base importada no queda sana ('$integridad'); he restaurado la copia de seguridad previa."
        }
    }

    foreach ($d in $Arboles) { Invoke-Robocopy (Join-Ruta $Comun "estado/$d") (Join-Ruta $HermesHome $d) }
    foreach ($f in @('kanban.db', 'SOUL.md')) {
        $o = Join-Ruta $Comun "estado/$f"
        if (Test-Path $o) { Copy-Item $o (Join-Ruta $HermesHome $f) -Force }
    }

    Write-EstadoImport -Epoch $epoch
    Write-Log "Importado. Copia de seguridad previa en $destinoBackup"
}

# ---------------------------------------------------------------- estado
function Show-Estado {
    Write-Host "── Carpeta común ─────────────────────────────────────────"
    Write-Host "  Ruta          : $Comun"
    $manifiesto = Join-Ruta $Comun 'estado/MANIFEST.json'
    if (Test-Path $manifiesto) {
        $m = Get-Content $manifiesto -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host "  Publicado por : $($m.host) el $(Get-Date -Date $m.publicado_utc -Format 'dd/MM/yyyy HH:mm')"
        Write-Host "  Sesiones      : $($m.sesiones) · mensajes: $($m.mensajes)"
    } else {
        Write-Host "  Publicado por : (nada publicado todavía)"
    }
    Write-Host "── Este equipo ($HostActual) ────────────────────────────"
    $sufijo = ''
    if ($script:PendientesImport.Count -gt 0) {
        $sufijo = " (parcial; pendiente: $($script:PendientesImport -join ', '))"
    }
    Write-Host "  Última importación: $($script:UltimoImportEpoch)$sufijo"
    Write-Host "  Sesiones locales  : $(Get-Sesiones (Join-Ruta $HermesHome 'state.db'))"
    Write-Host "  Semilla           : $(if (Test-Path (Join-Ruta $Comun 'semilla/config.yaml')) { 'disponible en la carpeta común' } else { 'sin generar' })"
}

# ---------------------------------------------------------------- main
if (-not (Test-Path $HermesHome)) { Stop-ConError "no encuentro el directorio de datos de Hermes en $HermesHome" }
New-Item -ItemType Directory -Force -Path $EstadoLocalDir | Out-Null
$ComunDetectado = Find-Comun
if (-not $ComunDetectado) {
    if ($Accion -eq 'auto' -or $Quiet) { exit 0 }
    Stop-ConError "no encuentro la carpeta compartida HermesSync en ningún disco. Conecta el disco SEAGATE."
}
$Comun = $ComunDetectado
foreach ($sub in @('estado', 'historial', 'logs')) {
    New-Item -ItemType Directory -Force -Path (Join-Ruta $Comun $sub) | Out-Null
}
$script:LogFile = Join-Ruta $Comun "logs/$HostActual.log"
$script:Python = Find-Python
$script:UltimoImportEpoch = 0
$script:PendientesImport = @()
if (Test-Path $EstadoLocalJson) {
    try {
        $estadoPrevio = Get-Content $EstadoLocalJson -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:UltimoImportEpoch = [int]$estadoPrevio.ultimo_import_epoch
        # @(...) fuerza lista: un solo pendiente se deserializa como cadena suelta.
        $script:PendientesImport = @($estadoPrevio.pendientes) | Where-Object { $_ }
    } catch { $script:UltimoImportEpoch = 0; $script:PendientesImport = @() }
}

switch ($Accion) {
    'auto'   { Invoke-Import; Invoke-Export }
    'import' { Invoke-Import }
    'export' { Invoke-Export }
    'semilla' { Invoke-Export -ConSemilla }
    'estado' { Show-Estado }
}
