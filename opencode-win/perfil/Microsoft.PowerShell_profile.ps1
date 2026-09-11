# =====================================================================
#  Perfil de PowerShell - Antonio
#  Lanzadores de OpenCode con LM Studio local (equivalente Windows de ocv)
# =====================================================================

$global:OpenCodeConfigDir = "C:\Users\evo01\.config\opencode"

function ocv {
    <#
    .SYNOPSIS
      Arranca LM Studio (servidor + modelo Qwen) + proxy 4001 y abre OpenCode
      en modo LOCAL (agente 'local', modelo qwen3.8-9b).

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

function ocv-local {
    <#
    .SYNOPSIS
      Arranca LM Studio + proxy y abre OpenCode con el perfil LOCAL MINIMO:
      solo MCPs esenciales (fetch, filesystem, memory). El resto de MCPs quedan
      deshabilitados.

    .EXAMPLE
      ocv-local
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )

    & "$global:OpenCodeConfigDir\start-lmstudio.ps1"

    $prev = $env:OPENCODE_CONFIG
    $env:OPENCODE_CONFIG = "$global:OpenCodeConfigDir\opencode-local-min.json"
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
      Abre OpenCode en modo CLOUD (sin cargar LM Studio). Usa la config global
      (opencode.jsonc), con el agente 'cloud' por defecto.

    .EXAMPLE
      ocv-cloud
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )

    $prev = $env:OPENCODE_CONFIG
    Remove-Item Env:OPENCODE_CONFIG -ErrorAction SilentlyContinue
    try {
        if ($Rest) { opencode @Rest } else { opencode }
    }
    finally {
        if ($null -ne $prev) { $env:OPENCODE_CONFIG = $prev }
    }
}

function ocv-status {
    <#
    .SYNOPSIS
      Muestra el estado de LM Studio, el modelo cargado y el proxy local.
    #>
    $ErrorActionPreference = "SilentlyContinue"
    $lms = "C:\Users\evo01\.lmstudio\bin\lms.exe"

    Write-Host "`n=== LM Studio (puerto 1234) ===" -ForegroundColor Cyan
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:1234/v1/models" -TimeoutSec 3 | Out-Null
        Write-Host "🟢 Servidor activo" -ForegroundColor Green
    } catch {
        Write-Host "🔴 Servidor no responde" -ForegroundColor Red
    }

    Write-Host "=== Modelo en VRAM ===" -ForegroundColor Cyan
    (& $lms ps 2>&1 | Out-String).Trim() | Write-Host

    Write-Host "=== Proxy 4001 ===" -ForegroundColor Cyan
    try {
        $h = Invoke-RestMethod -Uri "http://127.0.0.1:4001/health" -TimeoutSec 3
        Write-Host ("🟢 Activo -> {0} (puerto {1})" -f $h.upstream, $h.port) -ForegroundColor Green
    } catch {
        Write-Host "🔴 Proxy no responde en el puerto 4001" -ForegroundColor Red
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
