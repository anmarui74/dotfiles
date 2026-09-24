<#
.SYNOPSIS
    Verificacion del whitelist de modelos NVIDIA (PowerShell 5.1).
    Port de ~/.config/opencode/check-nvidia-whitelist.sh (Linux).

.DESCRIPTION
    Aplica la METODOLOGIA 05/09/2026 (documentada en
    04-perfiles-opencode-json.md) contra la API real de NVIDIA:

    1. Catalogo real: GET https://integrate.api.nvidia.com/v1/models
    2. HTTP 200 real en POST /chat/completions (404/410 se descartan;
       410 Gone = retirados y se SUGIEREN para eliminar del whitelist).
    3. Velocidad: generacion real de ~180-200 tokens, exigir >= 10 tok/s.
    4. Tool calling: tools: [get_current_time] + tool_choice auto, exigir
       tool_calls reales en la respuesta.
    5. Reintentos: 429/500/503/timeout se reintentan con mas margen antes
       de decidir.

    ⚠️ DECISION DE PORTABILIDAD (documentada):
    - El script Linux ELIMINA automaticamente los modelos 410 de los JSON.
      Este port en PowerShell NO modifica los JSON: solo INFORMA y SUGIERE
      (log + salida). La edicion de opencode.jsonc (JSONC con comentarios)
      desde PS 5.1 es fragil y el usuario prefiere revisar a mano.
    - El catalogo models.dev de OpenCode esta desactualizado para NVIDIA:
      por eso el whitelist manual es necesario.

.PARAMETER SoloLog
    Escribe el log y estado SIN hacer llamadas a la API (prueba offline).

.PARAMETER Ayuda
    Muestra esta ayuda.

.EXAMPLE
    .\check-nvidia-whitelist.ps1
.EXAMPLE
    .\check-nvidia-whitelist.ps1 -SoloLog
#>
[CmdletBinding()]
param(
    [switch]$SoloLog,
    [switch]$Ayuda
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ($Ayuda) { Get-Help $MyInvocation.MyCommand.Path -Detailed; exit 0 }

$CONFIG_DIR   = "$env:USERPROFILE\.config\opencode"
$AUTH_FILE    = "$env:USERPROFILE\.local\share\opencode\auth.json"
$LOG_FILE     = Join-Path $CONFIG_DIR 'data\nvidia-whitelist.log'
$STATE_FILE   = Join-Path $CONFIG_DIR 'data\nvidia-whitelist-state.json'
$API_BASE     = 'https://integrate.api.nvidia.com/v1'
$PERFILES     = @(
    (Join-Path $CONFIG_DIR 'opencode.jsonc'),
    (Join-Path $CONFIG_DIR 'opencode-local.json')
)
$MIN_TOK_PER_SEC = 10
$GEN_TOKENS      = 200
$MAX_NUEVOS      = 10
$TIMEOUT_SEG     = 60
$RETRY_SEG       = 5

# ------------------------------------------------------------
# Utilidades
# ------------------------------------------------------------
function Write-Log {
    param([string]$Msg)
    $linea = '[{0}] {1}' -f (Get-Date -Format 'dd/MM/yyyy HH:mm:ss'), $Msg
    Add-Content -LiteralPath $LOG_FILE -Value $linea -Encoding UTF8
    Write-Output $linea
}

function Get-FechaISO {
    return (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
}

# ------------------------------------------------------------
# 1. API key de NVIDIA desde auth.json de OpenCode
# ------------------------------------------------------------
function Get-NvidiaApiKey {
    if (-not (Test-Path $AUTH_FILE)) { return $null }
    try {
        $auth = Get-Content -LiteralPath $AUTH_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
        $nv = $auth.nvidia
        if ($null -eq $nv) { return $null }
        $key = $nv.key
        if ([string]::IsNullOrWhiteSpace($key)) { return $null }
        return $key.Trim()
    } catch {
        return $null
    }
}

# ------------------------------------------------------------
# 2. Limpiar JSONC (elimina comentarios /* */ y //) antes de parsear
# ------------------------------------------------------------
function ConvertFrom-JsonC {
    param([string]$Path)
    $texto = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    # Eliminar comentarios de bloque /* ... */
    $texto = [regex]::Replace($texto, '/\*.*?\*/', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    # Eliminar comentarios de linea // (cuidando que no rompan URLs en strings:
    # se elimina solo si no esta dentro de una cadena JSON)
    $sb = New-Object System.Text.StringBuilder
    $inStr = $false
    for ($i = 0; $i -lt $texto.Length; $i++) {
        $ch = $texto[$i]
        if ($inStr) {
            [void]$sb.Append($ch)
            if ($ch -eq '"' -and $i -gt 0 -and $texto[$i-1] -ne '\') { $inStr = $false }
            continue
        }
        if ($ch -eq '"') { $inStr = $true; [void]$sb.Append($ch); continue }
        if ($ch -eq '/' -and $i + 1 -lt $texto.Length -and $texto[$i+1] -eq '/') {
            while ($i -lt $texto.Length -and $texto[$i] -ne "`n") { $i++ }
            [void]$sb.Append("`n")
            continue
        }
        [void]$sb.Append($ch)
    }
    return ($sb.ToString() | ConvertFrom-Json)
}

# ------------------------------------------------------------
# 3. Leer el whitelist actual de los perfiles
# ------------------------------------------------------------
function Get-WhitelistActual {
    $wl = @()
    foreach ($p in $PERFILES) {
        if (-not (Test-Path $p)) { continue }
        try {
            $cfg = ConvertFrom-JsonC $p
            $w = $cfg.provider.nvidia.whitelist
            if ($null -ne $w) { $wl += @($w) }
        } catch {
            Write-Log "⚠️ No se pudo leer el whitelist de $p ($($_.Exception.Message))"
        }
    }
    return @($wl | Sort-Object -Unique)
}

# ------------------------------------------------------------
# 4. Estado guardado de la ultima ejecucion
# ------------------------------------------------------------
function Get-Estado {
    $def = @{
        modelos_vistos = @()
        descartados    = @{}
        retirados      = @{}
    }
    if (-not (Test-Path $STATE_FILE)) { return $def }
    try {
        $e = Get-Content -LiteralPath $STATE_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
        return $e
    } catch {
        return $def
    }
}

function Save-Estado {
    param($Estado)
    $json = $Estado | ConvertTo-Json -Depth 8
    $dir = Split-Path $STATE_FILE -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($STATE_FILE, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# ------------------------------------------------------------
# 5. Peticion POST /chat/completions con Invoke-RestMethod
#    Devuelve @{ Codigo; Tokens; Segundos; ToolCalls }
#    Reintenta 429/500/503/000 con margen (metodologia punto 5).
# ------------------------------------------------------------
function Invoke-ChatTest {
    param(
        [string]$Model,
        [hashtable]$Payload,
        [int]$MaxIntentos = 2
    )
    $headers = @{ Authorization = "Bearer $script:API_KEY" }
    $intento = 0
    $delay = $RETRY_SEG
    while ($intento -lt $MaxIntentos) {
        $intento++
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $resp = Invoke-RestMethod -Uri "$API_BASE/chat/completions" -Method Post `
                -Headers $headers -ContentType 'application/json' `
                -Body ($Payload | ConvertTo-Json -Depth 10) `
                -TimeoutSec $TIMEOUT_SEG
            $sw.Stop()
            $ct = 0
            if ($null -ne $resp.usage) { $ct = [int]$resp.usage.completion_tokens }
            $tc = $false
            if ($null -ne $resp.choices -and $null -ne $resp.choices[0].message.tool_calls) {
                if ($resp.choices[0].message.tool_calls.Count -gt 0) { $tc = $true }
            }
            return @{ Codigo = 200; Tokens = $ct; Segundos = $sw.Elapsed.TotalSeconds; ToolCalls = $tc }
        } catch {
            $sw.Stop()
            $cod = 0
            if ($null -ne $_.Exception.Response) {
                $cod = [int]$_.Exception.Response.StatusCode
            }
            if (($cod -eq 429 -or $cod -eq 500 -or $cod -eq 503 -or $cod -eq 0) -and $intento -lt $MaxIntentos) {
                Write-Log "🔁 $Model -> HTTP $cod, reintentando en ${delay}s (sobrecarga/transitorio)..."
                Start-Sleep -Seconds $delay
                $delay = $delay * 2
                continue
            }
            return @{ Codigo = $cod; Tokens = 0; Segundos = $sw.Elapsed.TotalSeconds; ToolCalls = $false }
        }
    }
    return @{ Codigo = 0; Tokens = 0; Segundos = 0; ToolCalls = $false }
}

# ------------------------------------------------------------
# 6. Test completo de un modelo NUEVO (metodologia completa)
#    HTTP 200 + velocidad >= 10 tok/s + tool calling real
# ------------------------------------------------------------
function Test-NuevoModelo {
    param([string]$Model)
    $payload = @{
        model = $Model
        messages = @(
            @{ role = 'user'; content = 'Escribe un texto de unas 180 palabras sobre la historia de la informatica.' }
        )
        max_tokens = $GEN_TOKENS
        tools = @(
            @{
                type = 'function'
                function = @{
                    name = 'get_current_time'
                    description = 'Devuelve la hora actual'
                    parameters = @{ type = 'object'; properties = @{} }
                }
            }
        )
        tool_choice = 'auto'
    }
    $r = Invoke-ChatTest -Model $Model -Payload $payload
    if ($r.Codigo -ne 200) {
        $motivo = switch ($r.Codigo) {
            410 { 'HTTP 410 Gone (end of life)' }
            404 { 'HTTP 404 sin endpoint de chat' }
            429 { 'HTTP 429 rate limit' }
            default { "HTTP $($r.Codigo)" }
        }
        return @{ OK = $false; Detalle = $motivo }
    }
    $tps = 0
    if ($r.Segundos -gt 0 -and $r.Tokens -gt 0) {
        $tps = [math]::Round($r.Tokens / $r.Segundos, 1)
    }
    if ($tps -lt $MIN_TOK_PER_SEC) {
        return @{ OK = $false; Detalle = "solo $tps tok/s (minimo $MIN_TOK_PER_SEC)" }
    }
    if (-not $r.ToolCalls) {
        return @{ OK = $false; Detalle = 'sin tool calling (inutilizable en OpenCode)' }
    }
    return @{ OK = $true; Detalle = "$tps tok/s, tool calling OK" }
}

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------
$dirData = Join-Path $CONFIG_DIR 'data'
if (-not (Test-Path $dirData)) { New-Item -ItemType Directory -Path $dirData -Force | Out-Null }

Write-Output '== 🏆 Verificacion del whitelist NVIDIA =='
Write-Output ''

# --- API key ---
$script:API_KEY = Get-NvidiaApiKey
if ([string]::IsNullOrWhiteSpace($script:API_KEY)) {
    Write-Log '❌ No se encontro la API key de NVIDIA (nvidia.key en auth.json, formato nvapi-*). Abortando.'
    Write-Output '   💡 Revisa el campo "nvidia": {"key": "nvapi-..."} en:'
    Write-Output "      $AUTH_FILE"
    exit 1
}
if ($script:API_KEY -notlike 'nvapi-*') {
    Write-Log '⚠️ La clave nvidia.key no tiene formato nvapi-*. Se continua pero puede fallar.'
}

# --- Whitelist actual ---
$currentWl = Get-WhitelistActual
if ($currentWl.Count -eq 0) {
    Write-Log '❌ Whitelist vacio o no encontrado en los perfiles. Abortando.'
    exit 1
}
Write-Log "🔍 Whitelist actual ($($currentWl.Count) modelos):"
foreach ($m in $currentWl) { Write-Log "   - $m" }

# --- Estado previo ---
$estado = Get-Estado
$vistos = @()
if ($null -ne $estado.modelos_vistos) { $vistos = @($estado.modelos_vistos) }

# --- SoloLog: no toca la API ---
if ($SoloLog) {
    Write-Log 'ℹ️ Modo -SoloLog: no se realizan llamadas a la API.'
    Write-Log '✅ Verificacion completada (offline).'
    exit 0
}

# --- Catalogo real ---
Write-Output ''
Write-Log '📡 Consultando catalogo real de NVIDIA...'
try {
    $cat = Invoke-RestMethod -Uri "$API_BASE/models" -Method Get `
        -Headers @{ Authorization = "Bearer $script:API_KEY" } -TimeoutSec 30
    $catalogModelos = @($cat.data | ForEach-Object { $_.id } | Where-Object { $_ })
} catch {
    Write-Log "❌ Sin conexion con la API de NVIDIA o respuesta invalida. No se toca nada."
    exit 0
}
Write-Log "📦 Catalogo real: $($catalogModelos.Count) modelos."

# --- Fase 1: verificar los modelos del whitelist actual ---
Write-Output ''
Write-Log '🔎 Fase 1: verificando modelos del whitelist (HTTP 200 real)...'
$retirados = @()
$nuevoWl = @($currentWl)
foreach ($model in $currentWl) {
    $payload = @{
        model = $model
        messages = @(@{ role = 'user'; content = 'hola' })
        max_tokens = 5
    }
    $r = Invoke-ChatTest -Model $model -Payload $payload
    switch ($r.Codigo) {
        200 { Write-Log "✅ $model operativo (HTTP 200)" }
        410 {
            Write-Log "🗑️ $model RETIRADO (HTTP 410 Gone) -> SUGERIDO para eliminar del whitelist"
            $retirados += $model
            $nuevoWl = @($nuevoWl | Where-Object { $_ -ne $model })
        }
        404 {
            Write-Log "⚠️ $model HTTP 404 (sin endpoint de chat). Se mantiene para revision."
        }
        default {
            Write-Log "⚠️ $model respuesta inesperada (HTTP $($r.Codigo)). Se mantiene."
        }
    }
}

# --- Fase 2: modelos NUEVOS en el catalogo ---
Write-Output ''
Write-Log '🔎 Fase 2: buscando modelos nuevos en el catalogo...'
$vistosMasWl = @($vistos + $currentWl | Sort-Object -Unique)
$nuevos = @($catalogModelos | Where-Object { $_ -notin $vistosMasWl } | Select-Object -First $MAX_NUEVOS)

if ($nuevos.Count -gt 0) {
    Write-Log "🆕 Modelos nuevos detectados (probando hasta $MAX_NUEVOS): $($nuevos.Count)"
    $candidatos = @()
    foreach ($model in $nuevos) {
        Write-Log "🧪 Probando modelo nuevo: $model"
        $v = Test-NuevoModelo -Model $model
        if ($v.OK) {
            Write-Log "🌟 $model PASA la metodologia ($($v.Detalle)) -> CANDIDATO para revision manual"
            $candidatos += $model
        } else {
            Write-Log "❌ $model descartado: $($v.Detalle)"
        }
    }
} else {
    Write-Log 'ℹ️ Sin modelos nuevos en el catalogo.'
}

# --- Fase 3: NO se modifican los JSON. Solo informe y sugerencias. ---
Write-Output ''
Write-Log '📋 Informe (los JSON NO se modifican automaticamente):'
if ($retirados.Count -gt 0) {
    Write-Log '   🗑️ Sugerencia: ELIMINAR del whitelist (HTTP 410 Gone):'
    foreach ($m in $retirados) { Write-Log "      - $m" }
} else {
    Write-Log '   ✅ Sin modelos retirados: el whitelist no necesita cambios.'
}
if ($candidatos.Count -gt 0) {
    Write-Log '   🌟 Sugerencia: revisar y ANHADIR al whitelist si procede:'
    foreach ($m in $candidatos) { Write-Log "      - $m" }
} else {
    Write-Log '   ℹ️ Sin candidatos nuevos.'
}

# --- Fase 4: guardar estado ---
$hoy = Get-Date -Format 'yyyy-MM-dd'
$estadoObj = @{
    ultima_ejecucion = Get-FechaISO
    modelos_vistos   = @($catalogModelos | Sort-Object -Unique)
    descartados      = @{}
    retirados        = @{}
}
foreach ($m in $retirados) {
    $estadoObj.retirados[$m] = @{ fecha = $hoy; http = 410 }
}
Save-Estado $estadoObj
Write-Log "💾 Estado guardado en $STATE_FILE"
Write-Log '✅ Verificacion completada.'