# hermes-cierre-notify.ps1 - avisa por Telegram cuando el gateway de Hermes se cierra.
#
# Hermes no tiene evento de cierre (los hooks son gateway:startup, session:* y agent:*),
# asi que este script vigila el proceso del gateway y avisa cuando desaparece.
#
# Hermes_CierreNotify.vbs lo lanza oculto desde la carpeta Inicio.
#
# Reglas de deteccion (v2, 22/10/2026):
#   - NO se filtra por nombre de proceso: el gateway puede correr como python.exe,
#     pythonw.exe o hermes.exe, y antes solo se miraba python*. Ese fue el fallo.
#   - Se vigila "hay gateway / no hay gateway", no un PID concreto: asi un reinicio
#     con PID nuevo no se confunde con un cierre.
#   - Ventana de gracia de 30 s: si el gateway vuelve a aparecer, es un reinicio
#     (update o restart) y NO se avisa.
#   - Escribe en el log en cuanto arranca, para poder distinguir "no se ejecuto"
#     de "se ejecuto y no vio el gateway".
#
# Prueba:  $env:DRY_RUN='1' PowerShell -File ...\hermes-cierre-notify.ps1
# Log:     %LOCALAPPDATA%\hermes\logs\cierre-notify.log

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$HermesHome  = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $env:LOCALAPPDATA 'hermes' }
$EnvFile     = Join-Path $HermesHome '.env'
$NotifyLog   = Join-Path $HermesHome 'logs\cierre-notify.log'
$Intervalo   = if ($env:CIERRE_SONDEO) { [int]$env:CIERRE_SONDEO } else { 5 }
$Gracia      = if ($env:CIERRE_GRACIA) { [int]$env:CIERRE_GRACIA } else { 30 }
$EsperaMax   = if ($env:CIERRE_ESPERA) { [int]$env:CIERRE_ESPERA } else { 21600 }   # 6 h
$DryRun      = ($env:DRY_RUN -eq '1')

function Write-Log([string]$msg) {
  $line = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg
  try {
    $dir = Split-Path -Parent $NotifyLog
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -LiteralPath $NotifyLog -Value $line -Encoding UTF8
  } catch { }
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

function Send-Telegram([string]$text) {
  if (-not $token -or -not $chatId) { Write-Log "ERROR: faltan credenciales en $EnvFile"; return $false }
  if ($DryRun) { Write-Log "[dry-run] no se envia: $text"; return $true }
  $uri = "https://api.telegram.org/bot$token/sendMessage"
  for ($i = 1; $i -le 3; $i++) {
    try {
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

# --- deteccion del gateway --------------------------------------------------
function Get-GatewayPids {
  # Sin filtro por nombre de ejecutable: se mira la linea de comandos de TODOS los
  # procesos. Se excluye este script y cualquier cosa que no sea 'gateway run'.
  try {
    $todos = @(Get-CimInstance Win32_Process -ErrorAction Stop)
  } catch {
    Write-Log "no pude enumerar procesos: $($_.Exception.Message)"
    return @()
  }
  $pids = @()
  foreach ($p in $todos) {
    $cl = [string]$p.CommandLine
    if (-not $cl) { continue }
    if ($cl -match 'hermes-cierre-notify') { continue }
    if ($cl -match 'gateway\s+run') { $pids += [int]$p.ProcessId }
  }
  return $pids
}

Write-Log ("vigilante iniciado (pid $PID); sondeo ${Intervalo}s, gracia ${Gracia}s, tope ${EsperaMax}s")

$enchufe = [char]::ConvertFromUtf32(0x1F50C)

# --- fase 1: esperar a que aparezca el gateway -------------------------------
$limite = (Get-Date).AddSeconds($EsperaMax)
$visto = $false
$ultimoAviso = Get-Date
while ((Get-Date) -lt $limite) {
  $pids = Get-GatewayPids
  if ($pids.Count -gt 0) {
    if (-not $visto) { Write-Log ("gateway detectado (pid " + ($pids -join ',') + "); vigilando su cierre") }
    $visto = $true
    Start-Sleep -Seconds $Intervalo
    continue
  }
  if ($visto) { break }
  if (((Get-Date) - $ultimoAviso).TotalMinutes -ge 10) {
    Write-Log "todavia no hay proceso de gateway; sigo esperando"
    $ultimoAviso = Get-Date
  }
  Start-Sleep -Seconds $Intervalo
}

if (-not $visto) {
  Write-Log "no aparecio ningun gateway en $EsperaMax s; salgo sin avisar"
  exit 0
}

# --- fase 2: ventana de gracia ---------------------------------------------
Write-Log "gateway ausente; ventana de gracia de ${Gracia}s para distinguir reinicio de cierre"
$fin = (Get-Date).AddSeconds($Gracia)
while ((Get-Date) -lt $fin) {
  Start-Sleep -Seconds ([Math]::Min($Intervalo, 5))
  $pids = Get-GatewayPids
  if ($pids.Count -gt 0) {
    Write-Log ("gateway de nuevo en marcha (pid " + ($pids -join ',') + "): era un reinicio, no aviso")
    exit 0
  }
}

# --- fase 3: avisar ---------------------------------------------------------
$hora = Get-Date -Format 'HH:mm'
$texto = "$enchufe Hermes se ha cerrado en Windows (hora $hora). No te contestare hasta que vuelva a arrancar."
Write-Log "cierre confirmado tras $Gracia s sin gateway"
if (Send-Telegram $texto) { exit 0 }
exit 1
