# =====================================================================
#  Perfil de PowerShell - Antonio
#  Lanzadores de OpenCode con LM Studio local (equivalente Windows de ocv)
# =====================================================================

$global:OpenCodeConfigDir = "C:\Users\evo01\.config\opencode"

# ---------------------------------------------------------------------
#  Servidor TTS persistente (Kokoro). Mantiene el modelo cargado en GPU
#  para que cada locucion tarde ~0.5 s en lugar de ~2 s.
# ---------------------------------------------------------------------
function Start-TtsServerIfNeeded {
    $port = if ($env:KOKORO_TTS_PORT) { [int]$env:KOKORO_TTS_PORT } else { 4210 }
    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -TimeoutSec 1 -ErrorAction Stop
        if ($r.ok) { return }
    } catch {}
    $venvpy = "$global:OpenCodeConfigDir\voice\venv\Scripts\python.exe"
    $srv = "$global:OpenCodeConfigDir\voice\kokoro-server.py"
    if ((Test-Path -LiteralPath $venvpy) -and (Test-Path -LiteralPath $srv)) {
        try {
            Start-Process -FilePath $venvpy -ArgumentList @("`"$srv`"", '--port', "$port") -WindowStyle Hidden | Out-Null
        } catch {}
    }
}

function tts-server {
    <#
    .SYNOPSIS
      Gestiona el servidor TTS persistente de Kokoro (start/stop/restart/status).
    .EXAMPLE
      tts-server status
      tts-server stop
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('start', 'stop', 'restart', 'status')]
        [string]$Action = 'status'
    )
    & "$global:OpenCodeConfigDir\voice\tts-server.ps1" -Action $Action
}

function ocv {
    <#
    .SYNOPSIS
      Arranca LM Studio + proxy 4001 + servidor TTS y abre OpenCode con la config
      GLOBAL (opencode.jsonc): todos los agentes y MCPs activos.

    .EXAMPLE
      ocv
      ocv "arreglame este bug"
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )

    & "$global:OpenCodeConfigDir\start-lmstudio.ps1"
    Start-TtsServerIfNeeded

    $prev = $env:OPENCODE_CONFIG
    $env:OPENCODE_CONFIG = "$global:OpenCodeConfigDir\opencode.jsonc"
    try {
        if ($Rest) { opencode @Rest } else { opencode }
    }
    finally {
        if ($null -eq $prev) { Remove-Item Env:OPENCODE_CONFIG -ErrorAction SilentlyContinue }
        else { $env:OPENCODE_CONFIG = $prev }
    }
}

function ocv-local {
    <#
    .SYNOPSIS
      Arranca LM Studio + proxy + servidor TTS y abre OpenCode con
      opencode-local.json: solo MCPs esenciales (fetch, filesystem, memory).
      context7 y sequential_thinking deshabilitados.

    .EXAMPLE
      ocv-local
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )

    & "$global:OpenCodeConfigDir\start-lmstudio.ps1"
    Start-TtsServerIfNeeded

    $prev = $env:OPENCODE_CONFIG
    $env:OPENCODE_CONFIG = "$global:OpenCodeConfigDir\opencode-local.json"
    try {
        if ($Rest) { opencode @Rest } else { opencode }
    }
    finally {
        if ($null -eq $prev) { Remove-Item Env:OPENCODE_CONFIG -ErrorAction SilentlyContinue }
        else { $env:OPENCODE_CONFIG = $prev }
    }
}

function ocv-cloud {
    <#
    .SYNOPSIS
      Abre OpenCode en modo CLOUD (sin cargar LM Studio). Usa opencode-cloud.json,
      que bloquea providers locales y desactiva el agente local. Tambien arranca
      el servidor TTS para la locucion.

    .EXAMPLE
      ocv-cloud
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )

    Start-TtsServerIfNeeded

    $prev = $env:OPENCODE_CONFIG
    $env:OPENCODE_CONFIG = "$global:OpenCodeConfigDir\opencode-cloud.json"
    try {
        if ($Rest) { opencode @Rest } else { opencode }
    }
    finally {
        if ($null -eq $prev) { Remove-Item Env:OPENCODE_CONFIG -ErrorAction SilentlyContinue }
        else { $env:OPENCODE_CONFIG = $prev }
    }
}

function ocv-status {
    <#
    .SYNOPSIS
      Muestra el estado de LM Studio, el modelo cargado, el proxy local y el
      servidor TTS.
    #>
    $ErrorActionPreference = "SilentlyContinue"
    $lms = "C:\Users\evo01\.lmstudio\bin\lms.exe"
    $ttsPort = if ($env:KOKORO_TTS_PORT) { [int]$env:KOKORO_TTS_PORT } else { 4210 }

    Write-Host "`n=== LM Studio (puerto 1234) ===" -ForegroundColor Cyan
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:1234/v1/models" -TimeoutSec 3 | Out-Null
        Write-Host "[OK] Servidor activo" -ForegroundColor Green
    } catch {
        Write-Host "[--] Servidor no responde" -ForegroundColor Red
    }

    Write-Host "=== Modelo en VRAM ===" -ForegroundColor Cyan
    (& $lms ps 2>&1 | Out-String).Trim() | Write-Host

    Write-Host "=== Proxy 4001 ===" -ForegroundColor Cyan
    try {
        $h = Invoke-RestMethod -Uri "http://127.0.0.1:4001/health" -TimeoutSec 3
        Write-Host ("[OK] Activo -> {0} (puerto {1})" -f $h.upstream, $h.port) -ForegroundColor Green
    } catch {
        Write-Host "[--] Proxy no responde en el puerto 4001" -ForegroundColor Red
    }

    Write-Host "=== Servidor TTS (Kokoro) ===" -ForegroundColor Cyan
    try {
        $t = Invoke-RestMethod -Uri "http://127.0.0.1:$ttsPort/health" -TimeoutSec 2
        Write-Host ("[OK] Activo -> voz {0} ({1})" -f $t.voice, ($t.providers -join ', ')) -ForegroundColor Green
    } catch {
        Write-Host "[--] Servidor TTS no responde (se arrancara al locutar)" -ForegroundColor Yellow
    }
}

function timeline-completo {
    <#
    .SYNOPSIS
      Historial COMPLETO de peticiones de OpenCode (el TUI solo muestra ~6).
    .EXAMPLE
      timeline-completo
      timeline-completo -Sesiones
      timeline-completo -Buscar "bug"
      timeline-completo <sessionId>
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )
    & "$global:OpenCodeConfigDir\scripts\timeline-completo.ps1" @Rest
}

function hw_query {
    <#
    .SYNOPSIS
      Consulta de hardware del equipo (CPU, GPU, RAM, disco, red).
    .EXAMPLE
      hw_query
      hw_query gpu
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Campo = "todo"
    )
    & "$global:OpenCodeConfigDir\scripts\hardware-query.ps1" -Campo $Campo
}
