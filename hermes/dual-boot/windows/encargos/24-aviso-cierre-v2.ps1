# 24-aviso-cierre-v2.ps1 - instala la v2 del aviso de cierre y deja un diagnostico.
#
# Problema (22/10/2026): Antonio cerro el gateway y no llego el aviso. Dos causas:
#   1) la v1 solo buscaba procesos llamados python.exe/pythonw.exe;
#   2) si el vigilante no llegaba a arrancar, no quedaba ni rastro en el log.
#
# Este encargo: copia la v2 a la copia LOCAL que ejecuta el lanzador, comprueba el
# lanzador de Inicio, lo arranca si no esta corriendo y deja en la nota un diagnostico
# con los procesos que llevan 'gateway' y el contenido del log.
#
# Reglas del canal: sin argumentos, sin interaccion, idempotente, sin secretos.
$ErrorActionPreference = 'Continue'
$Hermes = Join-Path $env:LOCALAPPDATA 'hermes'
$Local  = Join-Path $Hermes 'gateway-service'
$Log    = Join-Path $Hermes 'logs\cierre-notify.log'
$Inicio = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$VbsDest = Join-Path $Inicio 'Hermes_CierreNotify.vbs'

function Escribe($t) { Write-Output $t }

# --- 1. localizar el canal --------------------------------------------------
$comun = $null
foreach ($c in [char[]]'DEFGHIJKLMNOPQRSTUVWXYZ') {
  $raiz = "${c}:\"
  if (-not (Test-Path -LiteralPath $raiz -ErrorAction SilentlyContinue)) { continue }
  $cand = "$raiz" + 'HermesSync'
  if (Test-Path -LiteralPath ($cand + '\.hermes-sync')) { $comun = $cand; break }
}
if (-not $comun) { Escribe 'ERROR: no encuentro la carpeta compartida'; exit 1 }
$origen = Join-Path $comun 'windows\hermes-cierre-notify.ps1'
if (-not (Test-Path -LiteralPath $origen)) { Escribe 'ERROR: falta el aviso en el canal'; exit 1 }

# --- 2. copiar a la copia que se ejecuta -----------------------------------
if (-not (Test-Path -LiteralPath $Local)) { New-Item -ItemType Directory -Path $Local -Force | Out-Null }
$destino = Join-Path $Local 'hermes-cierre-notify.ps1'
$hOrig = (Get-FileHash -LiteralPath $origen -Algorithm SHA256).Hash
$hLocal = if (Test-Path -LiteralPath $destino) { (Get-FileHash -LiteralPath $destino -Algorithm SHA256).Hash } else { $null }
if ($hLocal -eq $hOrig) {
  Escribe 'OK: el aviso local ya esta al dia'
} else {
  if (Test-Path -LiteralPath $destino) {
    Copy-Item -LiteralPath $destino -Destination ("$destino.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')) -Force
  }
  Copy-Item -LiteralPath $origen -Destination $destino -Force
  $nativo = (Get-Item -LiteralPath $destino).FullName
  $err = $null; $tok = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($nativo, [ref]$tok, [ref]$err)
  if ($err -and $err.Count -gt 0) {
    foreach ($e in $err) { Escribe ("ERROR de sintaxis linea " + $e.Extent.StartLineNumber + ": " + $e.Message) }
    Copy-Item -LiteralPath (Get-ChildItem "$destino.bak-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName -Destination $destino -Force
    Escribe 'AVISO: la v2 no compila; restaurada la anterior'
    exit 1
  }
  Escribe 'copiado el aviso v2 a la copia que se ejecuta'
}

# --- 3. lanzador de Inicio --------------------------------------------------
$vbsOrigen = Join-Path $comun 'windows\Hermes_CierreNotify.vbs'
$cambioVbs = 'no hacia falta'
if (-not (Test-Path -LiteralPath $VbsDest)) {
  if (Test-Path -LiteralPath $vbsOrigen) {
    Copy-Item -LiteralPath $vbsOrigen -Destination $VbsDest -Force
    $cambioVbs = 'creado (faltaba)'
  } else {
    $cambioVbs = 'ERROR: no hay VBS en el canal'
  }
}

# --- 4. arrancarlo si no esta corriendo -------------------------------------
$corriendo = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -and $_.CommandLine -match 'hermes-cierre-notify\.ps1' -and $_.CommandLine -notmatch '24-aviso-cierre' })
$arrancado = 'ya estaba corriendo'
if ($corriendo.Count -eq 0) {
  $nativo = (Get-Item -LiteralPath $destino).FullName
  Start-Process powershell.exe -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', $nativo) -WindowStyle Hidden
  Start-Sleep -Seconds 3
  $comprobar = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -match 'hermes-cierre-notify\.ps1' })
  if ($comprobar.Count -gt 0) {
    $arrancado = 'lanzado ahora (pid ' + (($comprobar | ForEach-Object { $_.ProcessId }) -join ',') + ')'
  } else {
    $arrancado = 'AVISO: lo intente lanzar y no aparece en la lista de procesos'
  }
}

# --- 5. diagnostico ---------------------------------------------------------
$procesos = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -and $_.CommandLine -match 'gateway' } |
  Select-Object -First 6)
$lineas = @(
  ('- Procesos con "gateway" en la linea de comandos: ' + $procesos.Count)
)
foreach ($p in $procesos) {
  $cl = [string]$p.CommandLine
  if ($cl.Length -gt 120) { $cl = $cl.Substring(0, 120) + '...' }
  $lineas += @(('  - pid ' + $p.ProcessId + ' [' + $p.Name + '] ' + $cl))
}
$lineas += @(('- Vigilante de cierre: ' + $arrancado + ' (' + $corriendo.Count + ' en marcha antes)'))
$lineas += @(('- Lanzador de Inicio: ' + $cambioVbs))
$lineas += @(('- Copia local del aviso: ' + (Split-Path $destino -Leaf) + ' sha ' + $hOrig.Substring(0, 12)))
if (Test-Path -LiteralPath $Log) {
  $lineas += @('- Ultimas lineas del log de cierre:')
  foreach ($l in (Get-Content -LiteralPath $Log -Tail 10)) { $lineas += @(('  ' + $l)) }
} else {
  $lineas += @('- No existe el log de cierre (el vigilante no llego a ejecutarse nunca)')
}

$nota = Join-Path $comun 'NOTA-PARA-LINUX.md'
$cabecera = "`r`n## " + (Get-Date -Format 'dd/MM/yyyy HH:mm') + " - Aviso de cierre: diagnostico e instalacion de la v2 (Windows -> Linux)`r`n"
Add-Content -LiteralPath $nota -Value $cabecera -Encoding UTF8
foreach ($l in $lineas) { Add-Content -LiteralPath $nota -Value $l -Encoding UTF8 }
Add-Content -LiteralPath $nota -Value '' -Encoding UTF8

Escribe ("informe escrito en la nota (" + $lineas.Count + " lineas)")
exit 0
