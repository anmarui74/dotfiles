# sync-obsidian.ps1 - Espeja los manuales de OpenCode (Windows) en el vault de Obsidian.
# ---------------------------------------------------------------------------------------
# Equivalente Windows de sync-obsidian.sh (Linux).
#   - Toma los manuales de D:\Linux\Config\opencode-win\documentacion\ (+ AGENTS.md,
#     README.md y PORT-WINDOWS.md de la config) y los escribe en la carpeta
#     del vault (OpenCode-win), con el mismo criterio que Linux:
#       * manuales 01-09 numerados, notas sin numero, config con prefijo "Windows - ".
#   - Transformacion: anade una linea en blanco al inicio y reescribe los enlaces
#     relativos .md al nombre de la nota en Obsidian (espacios como %20).
#   - Borra del destino los "Windows NN ..." que ya no correspondan (espejo).
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File sync-obsidian.ps1            (aplica)
#   powershell -ExecutionPolicy Bypass -File sync-obsidian.ps1 -Check     (solo comprueba; exit 1 si hay desfases)
#   powershell -ExecutionPolicy Bypass -File sync-obsidian.ps1 -Quiet     (salida minima)
#   powershell -ExecutionPolicy Bypass -File sync-obsidian.ps1 -Vault "D:\otro\OpenCode-win"
# ---------------------------------------------------------------------------------------
[CmdletBinding()]
param(
    [string]$Vault = '',
    [switch]$Check,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$ConfigRoot = Join-Path $env:USERPROFILE '.config\opencode'
$DocDir     = 'D:\Linux\Config\opencode-win\documentacion'
$LogFile    = Join-Path $ConfigRoot 'data\sync-obsidian.log'
if ([string]::IsNullOrWhiteSpace($Vault)) {
    $Vault = 'C:\Users\evo01\MEGA\Obsidian\Obsidian\armarui74\OpenCode-win'
}

$E = [char]::ConvertFromUtf32(0x1F4BB)   # emoji de la nota (portatil)

if (-not (Test-Path -LiteralPath $Vault)) {
    Write-Host "AVISO: no existe el vault: $Vault"
    exit 2
}

# Mapa: origen (ruta completa) -> nombre de la nota en el vault.
$map = [ordered]@{
    (Join-Path $DocDir '01-configuracion-ollama.md')     = "$E Windows 01 Configuración de Ollama + Proxy.md"
    (Join-Path $DocDir '02-configuracion-lmstudio.md')   = "$E Windows 02 Configuración de LM Studio + Proxy.md"
    (Join-Path $DocDir '03-configuracion-voz.md')        = "$E Windows 03 Configuración Completa de Voz.md"
    (Join-Path $DocDir '04-perfiles-opencode-json.md')   = "$E Windows 04 Los Perfiles de OpenCode en Windows.md"
    (Join-Path $DocDir '05-configuracion-adicional.md')  = "$E Windows 05 Configuración Adicional.md"
    (Join-Path $DocDir '06-agents-md.md')                = "$E Windows 06 AGENTS.md — Reglas de comportamiento.md"
    (Join-Path $DocDir '07-playbook-recuperacion.md')    = "$E Windows 07 Playbook de Recuperación.md"
    (Join-Path $DocDir '08-incidencia-gpu-xid79.md')     = "$E Windows 08 Incidencia GPU Xid 79.md"
    (Join-Path $DocDir '09-informe-sistema.md')          = "$E Windows 09 Informe del sistema.md"
    (Join-Path $DocDir 'hardware-info.md')               = "$E Windows Hardware del equipo.md"
    (Join-Path $DocDir 'notas-opencode-go.md')           = "$E Windows Notas OpenCode Go.md"
    (Join-Path $DocDir 'README-hardware.md')             = "$E Windows README hardware.md"
    (Join-Path $DocDir 'seguimiento-issue-memory.md')    = "$E Windows Seguimiento Issue MCP memory.md"
    (Join-Path $DocDir 'README.md')                      = "$E Windows — README de la documentación.md"
    (Join-Path $ConfigRoot 'AGENTS.md')                  = "$E Windows — AGENTS.md de OpenCode.md"
    (Join-Path $ConfigRoot 'README.md')                  = "$E Windows — Índice de la configuración.md"
    (Join-Path $ConfigRoot 'opencode-voice-modified\PORT-WINDOWS.md') = "$E Windows — Voice modificado · PORT-WINDOWS.md"
}

# Mapa de enlaces relativos -> nombre de nota (para reescribir los .md internos).
$linkMap = @{}
foreach ($src in $map.Keys) {
    $base = Split-Path $src -Leaf
    if (-not $linkMap.ContainsKey($base)) { $linkMap[$base] = $map[$src] }
}
# README.md -> manual de documentacion (no el de la config)
$linkMap['README.md'] = $map[(Join-Path $DocDir 'README.md')]

function Convert-Texto([string]$txt) {
    $transformado = [regex]::Replace($txt, '\]\(([^)]*\.md)\)', {
        param($m)
        $k = $m.Groups[1].Value
        if ($linkMap.ContainsKey($k)) {
            '](' + ($linkMap[$k] -replace ' ', '%20') + ')'
        } else {
            $m.Value
        }
    })
    return "`n" + $transformado
}

$ok = 0; $cambiados = New-Object System.Collections.ArrayList; $nuevos = New-Object System.Collections.ArrayList

foreach ($src in $map.Keys) {
    if (-not (Test-Path -LiteralPath $src)) { continue }
    $vpath = Join-Path $Vault $map[$src]
    $esperado = Convert-Texto (Get-Content -LiteralPath $src -Raw -Encoding UTF8)
    $actual = $null
    if (Test-Path -LiteralPath $vpath) {
        $actual = (Get-Content -LiteralPath $vpath -Raw -Encoding UTF8)
    }
    if ($actual -eq $esperado) { $ok++; continue }
    if ($null -eq $actual) { [void]$nuevos.Add($map[$src]) } else { [void]$cambiados.Add($map[$src]) }
    if (-not $Check) {
        [System.IO.File]::WriteAllText($vpath, $esperado, (New-Object System.Text.UTF8Encoding($false)))
    }
}

# --- Indice del vault (README) generado automaticamente --------------------
$hubName = "$E README.md"
$hubPath = Join-Path $Vault $hubName

$filas = New-Object System.Collections.ArrayList
foreach ($src in $map.Keys) {
    $note  = $map[$src]
    $label = ($note.Substring(("$E Windows ").Length)) -replace '\.md$', ''
    $origen = if ($src.StartsWith($DocDir)) { 'documentacion/' + (Split-Path $src -Leaf) }
              elseif ($src.StartsWith($ConfigRoot)) { $src.Substring($ConfigRoot.Length).TrimStart('\') }
              else { $src }
    $url = $note -replace ' ', '%20'
    [void]$filas.Add([pscustomobject]@{ Label = $label; Url = $url; Origen = $origen })
}
$manuales = @($filas | Where-Object { $_.Label -match '^\d{2} ' } | Sort-Object Label)
$conf     = @($filas | Where-Object { $_.Label -like '— *' })
$notas    = @($filas | Where-Object { $_.Label -notmatch '^\d{2} ' -and $_.Label -notlike '— *' } | Sort-Object Label)

$revFuente = Get-ChildItem -LiteralPath $DocDir -File -Filter '*.md' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
$revTxt = if ($revFuente) { $revFuente.LastWriteTime.ToString('dd/MM/yyyy') } else { (Get-Date).ToString('dd/MM/yyyy') }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# 🗂️ Documentación de configuración de OpenCode en Windows')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| ⚙️ Estado | 📅 Fecha | 👤 Usuario |')
[void]$sb.AppendLine('|-----------|----------|------------|')
[void]$sb.AppendLine("| ✅ Índice de documentación | $revTxt · rev. $revTxt | Antonio |")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> Copia de **solo lectura** de los manuales del equipo **Windows**, espejada por')
[void]$sb.AppendLine('> `sync-obsidian.ps1` (equivalente de `sync-obsidian.sh` en Linux). **No editar aquí**:')
[void]$sb.AppendLine('> los cambios se hacen en `D:\Linux\Config\opencode-win\` y se vuelven a espejar.')
[void]$sb.AppendLine('> Manuales del lado Linux: carpeta `OpenCode`.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('---')
[void]$sb.AppendLine('')
function Add-Tabla($titulo, $items) {
    if (-not $items -or $items.Count -eq 0) { return }
    [void]$sb.AppendLine($titulo)
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Nota | Origen |')
    [void]$sb.AppendLine('|------|--------|')
    foreach ($f in $items) {
        [void]$sb.AppendLine("| [$($f.Label)]($($f.Url)) | ``$($f.Origen)`` |")
    }
    [void]$sb.AppendLine('')
}
Add-Tabla '## 📑 Manuales (01–09)' $manuales
Add-Tabla '## 📊 Notas y hardware' $notas
Add-Tabla '## ⚙️ Configuración' $conf
[void]$sb.AppendLine('---')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> 📁 Vault: `C:\Users\evo01\MEGA\Obsidian\Obsidian\armarui74\` · 🔄 Espejo: `sync-obsidian.ps1`')

$hubEsperado = ($sb.ToString() -replace "`r`n", "`n")
$hubActual = $null
if (Test-Path -LiteralPath $hubPath) {
    $hubActual = ((Get-Content -LiteralPath $hubPath -Raw -Encoding UTF8) -replace "`r`n", "`n")
}
if ($hubActual -ne $hubEsperado) {
    if ($null -eq $hubActual) { [void]$nuevos.Add($hubName) } else { [void]$cambiados.Add($hubName) }
    if (-not $Check) {
        [System.IO.File]::WriteAllText($hubPath, $hubEsperado, (New-Object System.Text.UTF8Encoding($false)))
    }
} else {
    $ok++
}

# Espejo: borrar notas "Windows ..." que ya no correspondan (excepto el indice README).
$eliminados = New-Object System.Collections.ArrayList
$deseados = @($map.Values)
Get-ChildItem -LiteralPath $Vault -File -Filter '*.md' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "$E Windows *" -and ($deseados -notcontains $_.Name) } |
    ForEach-Object {
        [void]$eliminados.Add($_.Name)
        if (-not $Check) { Remove-Item -LiteralPath $_.FullName -Force }
    }

# --- Salida y log -----------------------------------------------------------
if (-not $Quiet) {
    foreach ($n in $nuevos)     { Write-Host ("  nuevo:      " + $n) }
    foreach ($n in $cambiados)  { Write-Host ("  actualizado:" + $n) }
    foreach ($n in $eliminados) { Write-Host ("  eliminado:  " + $n) }
}

$desfases = $cambiados.Count + $nuevos.Count + $eliminados.Count
$msg = "Obsidian (Windows): {0} actualizados, {1} nuevos, {2} eliminados, {3} al dia" -f $cambiados.Count, $nuevos.Count, $eliminados.Count, $ok

$modo = if ($Check) { 'check' } else { 'apply' }
try {
    $ts = (Get-Date).ToString('dd/MM/yyyy HH:mm:ss')
    Add-Content -LiteralPath $LogFile -Value "[$ts] sync-obsidian-win ($modo): $($cambiados.Count) actualizados, $($nuevos.Count) nuevos, $($eliminados.Count) eliminados, $ok al dia" -Encoding UTF8
} catch { }

if ($Quiet) {
    if ($desfases -gt 0) { Write-Host $msg }
} else {
    Write-Host $msg
}

if ($Check -and $desfases -gt 0) { exit 1 }
exit 0
