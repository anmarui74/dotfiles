# hermes-cierre-notify.ps1 - avisa por Telegram cuando el gateway de Hermes se cierra.
#
# Hermes no tiene evento de cierre (los hooks son gateway:startup, session:* y agent:*),
# asi que este script vigila el proceso del gateway: espera a que aparezca, guarda su
# PID y, cuando desaparece, manda el aviso.
#
# Lo lanza Hermes_CierreNotify.vbs desde la carpeta Inicio (oculto), igual que el aviso
# de arranque. Cubre la parada del servicio, el cierre de sesion y el
# apagado ordenado (con el margen del intervalo de sondeo).
#
# Prueba sin reiniciar nada:
#   $env:DRY_RUN='1'                      # compone el aviso sin enviarlo
#   $env:CIERRE_PID=<pid> $env:CIERRE_SONDEO=1   # vigila un PID concreto (util para probar)
#
# Nota: este fichero se guarda en UTF-8 CON BOM y CRLF. PowerShell 5.1 lee los .ps1
# sin BOM como ANSI y romperia los acentos y los emojis.

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $env:LOCALAPPDATA 'hermes' }
$EnvFile    = Join-Path $HermesHome '.env'
$NotifyLog  = Join-Path $HermesHome 'logs\cierre-notify.log'
$Intervalo  = if ($env:CIERRE_SONDEO) { [int]$env:CIERRE_SONDEO } else { 5 }
$EsperaMax  = if ($env:CIERRE_ESPERA) { [int]$env:CIERRE_ESPERA } else { 900 }
$DryRun     = ($env:DRY_RUN -eq '1')

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
if (-not $token -or -not $chatId) {
  Write-Log "ERROR: faltan TELEGRAM_BOT_TOKEN o TELEGRAM_HOME_CHANNEL en $EnvFile"
  exit 1
}

function Send-Telegram([string]$text) {
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

# --- localizar el proceso del gateway ---------------------------------------
function Get-GatewayPids {
  # El gateway corre como python con 'gateway run' en la linea de comandos.
  # Se excluyen los procesos cuyo padre sea este mismo script.
  try {
    $todos = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction Stop)
  } catch {
    return @()
  }
  $pids = @()
  foreach ($p in $todos) {
    $cl = [string]$p.CommandLine
    if ($cl -and ($cl -match 'gateway\s+run')) { $pids += [int]$p.ProcessId }
  }
  return $pids
}

function Test-Vivo([int]$procId) {
  try { return $null -ne (Get-Process -Id $procId -ErrorAction Stop) } catch { return $false }
}

$enchufe = [char]::ConvertFromUtf32(0x1F50C)
$hora = Get-Date -Format 'HH:mm'

# --- PID a vigilar ----------------------------------------------------------
$pidVigilado = 0
if ($env:CIERRE_PID) {
  $pidVigilado = [int]$env:CIERRE_PID
  Write-Log "modo prueba: vigilo el PID $pidVigilado"
} else {
  $limite = (Get-Date).AddSeconds($EsperaMax)
  while ((Get-Date) -lt $limite) {
    $pids = Get-GatewayPids
    if ($pids.Count -gt 0) {
      $pidVigilado = $pids[0]
      Write-Log "gateway detectado (pid $pidVigilado); vigilando su cierre"
      break
    }
    Start-Sleep -Seconds $Intervalo
  }
  if ($pidVigilado -eq 0) {
    Write-Log "no vi arrancar el gateway en $EsperaMax s; salgo sin avisar"
    exit 0
  }
}

# --- esperar el cierre ------------------------------------------------------
while (Test-Vivo $pidVigilado) {
  Start-Sleep -Seconds $Intervalo
}

Write-Log "gateway (pid $pidVigilado) cerrado"

# Si en 30 s aparece otro proceso del gateway, era un reinicio y no se avisa.
Start-Sleep -Seconds 30
if ((Get-GatewayPids).Count -gt 0) {
  Write-Log "aparecio otro proceso del gateway: era un reinicio, no aviso"
  exit 0
}
$despedida = if ($env:CIERRE_MOTIVO) { $env:CIERRE_MOTIVO } else { 'Hermes se ha cerrado' }
$texto = "$enchufe $despedida en Windows (hora $hora). No te contestare hasta que vuelva a arrancar."
if (Send-Telegram $texto) { exit 0 }
exit 1
