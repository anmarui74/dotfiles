<#
  hermes-ready-notify.ps1 - avisa por Telegram cuando el gateway de Hermes
  esta listo tras un arranque de Windows.

  Lo lanza arranque-ready-notify.vbs desde la carpeta Inicio (oculto).
  No hace nada si Hermes ya manda su propio aviso (reinicio planificado o
  /restart) ni si el gateway no arranca.

  El mensaje lleva la misma informacion que el aviso de Linux
  (hermes-ready-notify.sh), adaptada al lado Windows:

    OK Hermes activo - gateway listo y Telegram conectado (arranque HH:mm)
    (1) Update: al dia / HAY ACTUALIZACION / no se pudo comprobar
    (2) Dual boot: ultima importacion, nota nueva de Linux y encargos pendientes
    (3) Veredicto del dual boot (solo si hay algo que mirar)
    (4) Parche Ctrl+Q (solo si NO esta aplicado)
    (5) Import de arranque (verificador del estado compartido)

  Prueba sin reiniciar nada:
     $env:DRY_RUN='1'; $env:HERMES_READY_FORZAR='1'   # compone el aviso sin enviarlo
     $env:HERMES_READY_FORZAR='1'                     # lo envia de verdad

  Nota: este fichero se guarda en UTF-8 CON BOM. PowerShell 5.1 lee los .ps1
  sin BOM como ANSI y romperia los acentos y los emojis. Los emojis que no
  caben en un [char] se construyen con ConvertFromUtf32.
#>
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $env:LOCALAPPDATA 'hermes' }
$EnvFile    = Join-Path $HermesHome '.env'
$GatewayLog = Join-Path $HermesHome 'logs\gateway.log'
$NotifyLog  = Join-Path $HermesHome 'logs\ready-notify.log'
$TimeoutSec = if ($env:HERMES_READY_TIMEOUT) { [int]$env:HERMES_READY_TIMEOUT } else { 180 }
$DryRun     = ($env:DRY_RUN -eq '1')

function Write-Log([string]$msg) {
  $line = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg
  try { Add-Content -LiteralPath $NotifyLog -Value $line -Encoding UTF8 } catch { }
}

# --- credenciales -----------------------------------------------------------
$token = $null
$chatId = $null
if (Test-Path -LiteralPath $EnvFile) {
  foreach ($line in Get-Content -LiteralPath $EnvFile -Encoding UTF8) {
    if ($line -match '^\s*TELEGRAM_BOT_TOKEN\s*=\s*(.*)$') { $token = $matches[1].Trim().Trim('"').Trim("'") }
    elseif ($line -match '^\s*TELEGRAM_HOME_CHANNEL\s*=\s*(.*)$') { $chatId = $matches[1].Trim().Trim('"').Trim("'") }
  }
}
if (-not $token -or -not $chatId) {
  Write-Log "ERROR: faltan TELEGRAM_BOT_TOKEN o TELEGRAM_HOME_CHANNEL en $EnvFile"
  exit 1
}

# --- no duplicar el aviso nativo de Hermes ----------------------------------
foreach ($marker in @('.restart_pending.json', '.restart_notify.json')) {
  if (Test-Path -LiteralPath (Join-Path $HermesHome $marker)) {
    Write-Log "marcador nativo presente ($marker): el gateway avisa por su cuenta"
    exit 0
  }
}

# --- envio ------------------------------------------------------------------
function Send-Telegram([string]$text) {
  if ($DryRun) { Write-Log "[dry-run] no se envia: $text"; return $true }
  $uri = "https://api.telegram.org/bot$token/sendMessage"
  for ($i = 1; $i -le 3; $i++) {
    try {
      # JSON en bytes UTF-8: con un hashtable normal PowerShell 5.1 enviaria
      # los emojis y acentos mal codificados.
      $json = @{ chat_id = $chatId; text = $text } | ConvertTo-Json -Compress
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
      $resp = Invoke-RestMethod -Uri $uri -Method Post -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 20
      if ($resp.ok) {
        Write-Log "mensaje enviado a telegram:$chatId (message_id=$($resp.result.message_id))"
        return $true
      }
      Write-Log "intento ${i}: Telegram respondio ok=false"
    } catch {
      Write-Log "intento $i fallido: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 3
  }
  return $false
}

# --- utilidades -------------------------------------------------------------
# Ejecuta un comando externo con tope de tiempo, en un job aparte.
# Devuelve @{ Code = <entero>; Out = <texto> } y nunca lanza.
function Invoke-ConTimeout {
  param([string]$Exe, [string[]]$Argumentos = @(), [int]$TimeoutSeg = 120)
  try {
    $job = Start-Job -ScriptBlock {
      param($e, $a)
      $ErrorActionPreference = 'Continue'
      $out = (& $e @a 2>&1 | Out-String)
      $code = $LASTEXITCODE
      if ($null -eq $code) { $code = 0 }
      [pscustomobject]@{ Code = [int]$code; Out = [string]$out }
    } -ArgumentList $Exe, $Argumentos
    if (Wait-Job $job -Timeout $TimeoutSeg) {
      $res = Receive-Job $job
      Remove-Job $job -Force -ErrorAction SilentlyContinue
      if ($null -eq $res) { return @{ Code = 1; Out = '' } }
      return @{ Code = [int]$res.Code; Out = [string]$res.Out }
    }
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return @{ Code = 124; Out = '' }
  } catch {
    return @{ Code = 127; Out = '' }
  }
}

$comun = $null
foreach ($codigo in 68..90) {
  $letra = [string][char]$codigo
  $raiz = "${letra}:\"
  if (-not (Test-Path -LiteralPath $raiz -ErrorAction SilentlyContinue)) { continue }
  $cand = "${letra}:\HermesSync"
  if (Test-Path -LiteralPath "$cand\.hermes-sync" -PathType Leaf -ErrorAction SilentlyContinue) { $comun = $cand; break }
}

$ok    = [string][char]0x2705
$warn  = [string][char]0x26A0 + [string][char]0xFE0F
$up    = [string][char]0x2B06 + [string][char]0xFE0F
$reload = [char]::ConvertFromUtf32(0x1F504)
$hand  = [char]::ConvertFromUtf32(0x1F91D)
$mail  = [char]::ConvertFromUtf32(0x1F4E8)
$inbox = [char]::ConvertFromUtf32(0x1F4E5)
$hora  = Get-Date -Format 'HH:mm'

# --- 1) actualizacion disponible -------------------------------------------
# Solo lectura: `hermes update --check` hace un git fetch y no toca nada.
$updateLine = "$warn no he podido comprobar si hay actualizacion"
$hermesExe = $null
foreach ($nombre in @('hermes.cmd', 'hermes.exe', 'hermes')) {
  $cmd = Get-Command $nombre -ErrorAction SilentlyContinue
  if ($cmd) { $hermesExe = $cmd.Source; break }
}
if ($hermesExe) {
  $r = Invoke-ConTimeout -Exe $hermesExe -Argumentos @('update', '--check') -TimeoutSeg 150
  $chk = [string]$r.Out
  $canal = ''
  $m = [regex]::Match($chk, 'Update channel:\s*(\S+)')
  if ($m.Success) { $canal = $m.Groups[1].Value }
  # Los textos de `update --check` cambian entre versiones: reconocer TODOS los
  # veredictos. Un canal fijado a release (stable) imprime «Selected release
  # available» cuando SI hay actualizacion; si no se reconoce, cae en el aviso
  # de "no se pudo comprobar" y miente (falso negativo).
  if ($chk -match 'No newer release|Up to date with|Already up to date|up to date') {
    $updateLine = "$ok al dia" + $(if ($canal) { " (canal $canal)" } else { '' })
  } elseif ($chk -match 'Selected release available|Update available|behind') {
    $det = ''
    $md = [regex]::Match($chk, '(Selected release available|Update available|behind)[^\r\n]*')
    if ($md.Success) {
      $det = ($md.Value -replace '^Selected release available:\s*', '' -replace '^Update available:\s*', '').TrimEnd('.')
    }
    if (-not $det) { $det = 'ver hermes update --check' }
    $updateLine = "$up HAY ACTUALIZACION - $det"
  }
  $chkUno = $chk -replace "`r?`n", ' | '
  Write-Log ("update --check (" + $hermesExe + "): " + $chkUno.Substring(0, [Math]::Min(300, $chkUno.Length)))
} else {
  Write-Log 'update --check: no encuentro el ejecutable hermes en el PATH'
}

# --- 2) canal del dual boot: que ha dejado Linux ----------------------------
$dualLine = "$warn no encuentro el disco compartido (HermesSync\.hermes-sync en D:..Z:)"
if ($comun) {
  $estado = Join-Path $HermesHome '.dual-sync\estado.json'
  $imp = 'desconocida'
  if (Test-Path -LiteralPath $estado) {
    try {
      $txt = Get-Content -LiteralPath $estado -Raw -Encoding UTF8
      $mi = [regex]::Match($txt, '"ultimo_import_utc"\s*:\s*"([^"]*)"')
      if ($mi.Success) { $imp = $mi.Groups[1].Value }
    } catch { }
  }
  # NOTA NUEVA: la que Linux deja para Windows. La marca de tamano evita repetir
  # el aviso si la misma nota se ve dos veces.
  $notaTxt = 'sin novedades en NOTA-PARA-WINDOWS.md'
  $nota = Join-Path $comun 'NOTA-PARA-WINDOWS.md'
  $marca = Join-Path $HermesHome 'state\arranque-nota-win.size'
  if (Test-Path -LiteralPath $nota) {
    try {
      $size = (Get-Item -LiteralPath $nota).Length
      $prev = ''
      if (Test-Path -LiteralPath $marca) { $prev = (Get-Content -LiteralPath $marca -Raw -ErrorAction SilentlyContinue) }
      if ("$size" -ne "$($prev -replace '\s', '')") {
        $ult = (Get-Content -LiteralPath $nota -Encoding UTF8 | Where-Object { $_ -match '^## ' } | Select-Object -Last 1)
        if ($ult) { $ult = $ult -replace '^##\s*', '' }
        if (-not $ult) { $ult = '' }
        if ($ult.Length -gt 90) { $ult = $ult.Substring(0, 90) }
        $notaTxt = "$mail NOTA NUEVA de Linux - $ult"
        $dir = Split-Path -Parent $marca
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -LiteralPath $marca -Value "$size" -Encoding ASCII -NoNewline
      }
    } catch { }
  }
  # Encargos que Linux ha dejado para este equipo y siguen sin ejecutarse.
  $pend = 0
  $dirEnc = Join-Path $comun 'windows\encargos'
  $hechos = Join-Path $HermesHome 'state\encargos-hechos.json'
  $hechosTxt = ''
  if (Test-Path -LiteralPath $hechos) {
    try { $hechosTxt = Get-Content -LiteralPath $hechos -Raw -Encoding UTF8 } catch { }
  }
  if (Test-Path -LiteralPath $dirEnc) {
    foreach ($f in (Get-ChildItem -LiteralPath $dirEnc -Filter '*.ps1' -File -ErrorAction SilentlyContinue)) {
      if ($hechosTxt -notmatch [regex]::Escape('"' + $f.Name + '"')) { $pend++ }
    }
  }
  $dualLine = "ultima importacion: $imp · $notaTxt · encargos pendientes de Linux: $pend"
}

# --- 3) veredicto del dual boot --------------------------------------------
# orientar.py --veredicto responde en una linea; si todo esta bien no se dice
# nada en Telegram (solo queda en el log).
$veredictoLine = ''
$orientar = if ($comun) { Join-Path $comun 'scripts\orientar.py' } else { $null }
$py = $null
foreach ($nombre in @('python.exe', 'python', 'python3.exe', 'python3')) {
  $c = Get-Command $nombre -ErrorAction SilentlyContinue
  if ($c) { $py = $c.Source; break }
}
if ($orientar -and (Test-Path -LiteralPath $orientar) -and $py) {
  $r = Invoke-ConTimeout -Exe $py -Argumentos @($orientar, '--veredicto') -TimeoutSeg 90
  $v = ([string]$r.Out).Trim()
  if ($r.Code -eq 124) { $veredictoLine = "$warn no pude comprobar el estado del dual boot (agoto el tiempo)" }
  elseif (-not $v) { $veredictoLine = "$warn no pude comprobar el estado del dual boot" }
  elseif ($v -match '^VEREDICTO:\s*OK') { $veredictoLine = '' }
  else { $veredictoLine = "$warn " + ($v -replace '^VEREDICTO:\s*', '') }
}
Write-Log ("veredicto del dual boot: " + $(if ($veredictoLine) { $veredictoLine } else { 'OK' }))

# --- 4) parche local del CLI (Ctrl+Q corta la locucion) ---------------------
# Vive fuera de git: si un `hermes update` lo deja aparcado, las teclas dejan de
# cortar el audio y eso solo se nota al usarlas. SOLO se avisa si NO esta aplicado.
$parcheLine = ''
if ($comun) {
  $parche = Join-Path $comun 'windows\parches\ctrl-q-corta-audio.patch'
  $repo = Join-Path $HermesHome 'hermes-agent'
  if ((Test-Path -LiteralPath $parche) -and (Test-Path -LiteralPath $repo)) {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
      $r = Invoke-ConTimeout -Exe $git.Source -Argumentos @('-C', $repo, 'apply', '--reverse', '--check', $parche) -TimeoutSeg 30
      if ($r.Out -match 'error|fatal|No such file|does not exist') { $r.Code = 1 }
      if ($r.Code -ne 0) {
        $parcheLine = "$warn parche Ctrl+Q/Ctrl+C del CLI NO aplicado (el encargo 21 lo reintenta al arrancar)"
      }
    }
  }
}
Write-Log ("parche local del CLI: " + $(if ($parcheLine) { $parcheLine } else { 'aplicado' }))

# --- 5) import del estado compartido en este arranque -----------------------
$lineaImport = $null
$codigoImport = 0
$verificador = Join-Path $HermesHome 'dual-boot\verificar-import-arranque.ps1'
if (Test-Path -LiteralPath $verificador) {
  $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  try {
    $salida = @(& $psExe -NoProfile -ExecutionPolicy Bypass -File $verificador -EsperaSegundos 30 2>&1)
    $codigoImport = $LASTEXITCODE
    $lineaImport = ($salida | Where-Object { $_ -and ("$_\").Trim() -ne '' } | Select-Object -First 1)
  } catch {
    $codigoImport = 3
    $lineaImport = "no se pudo comprobar: $($_.Exception.Message)"
  }
  Write-Log "import de arranque (codigo $codigoImport): $lineaImport"
}

# --- espera a que el gateway este listo -------------------------------------
# Listo = el log muestra conexion de Telegram o plataforma levantada con una
# marca reciente (los ultimos 5 minutos), no basta con que el proceso exista.
$t0 = Get-Date
$deadline = $t0.AddSeconds($TimeoutSec)
$ready = $false
$pattern = 'Connected to Telegram \(polling mode\)|telegram connected|Gateway running with'

while ((Get-Date) -lt $deadline) {
  if (Test-Path -LiteralPath $GatewayLog) {
    $tail = Get-Content -LiteralPath $GatewayLog -Tail 400 -ErrorAction SilentlyContinue
    $hit = $tail | Where-Object { $_ -match $pattern } | Select-Object -Last 1
    if ($hit) {
      $stamp = $hit.Substring(0, [Math]::Min(19, $hit.Length))
      $dt = [datetime]::MinValue
      if ([datetime]::TryParseExact($stamp, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$dt)) {
        if ($dt -ge $t0.AddSeconds(-300)) { $ready = $true; break }
      }
    }
  }
  Start-Sleep -Seconds 5
}

if ($env:HERMES_READY_FORZAR -eq '1') {
  $ready = $true
  Write-Log 'modo forzado (HERMES_READY_FORZAR=1): se envia el aviso aunque el log no tenga marca reciente'
}

# --- registro local de arranque --------------------------------------------
function Write-ArranqueLog {
  try {
    $dir = Split-Path -Parent $NotifyLog
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $sello = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $lineas = @(
      "$sello  arranque: gateway listo",
      "$sello  arranque: update -> $updateLine",
      "$sello  arranque: dual boot -> $dualLine"
    )
    if ($veredictoLine) { $lineas += "$sello  arranque: veredicto -> $veredictoLine" }
    if ($parcheLine)    { $lineas += "$sello  arranque: parche -> $parcheLine" }
    if ($lineaImport)   { $lineas += "$sello  arranque: import -> $lineaImport" }
    Add-Content -LiteralPath $NotifyLog -Value $lineas -Encoding UTF8
  } catch { }
}

if ($ready) {
  Write-ArranqueLog
  $texto = "$ok Hermes activo - gateway listo y Telegram conectado (arranque $hora). Ya puedes escribirme.`n" +
           "${reload} Update: $updateLine`n" +
           "${hand} Dual boot: $dualLine"
  if ($parcheLine)    { $texto += "`n$parcheLine" }
  if ($veredictoLine) { $texto += "`n$veredictoLine" }
  if ($lineaImport) {
    $icono = if ($codigoImport -eq 0) { $reload } else { $warn }
    $texto += "`n$icono Import de arranque: $lineaImport"
  }
  if (Send-Telegram $texto) { exit 0 }
  exit 1
}

if (Test-Path -LiteralPath $GatewayLog) {
  Send-Telegram "$warn Hermes arranco pero Telegram no conecto en ${TimeoutSec}s. Revisa: $GatewayLog" | Out-Null
} else {
  Send-Telegram "$warn Hermes no arranco: no hay $GatewayLog tras ${TimeoutSec}s." | Out-Null
}
exit 1
