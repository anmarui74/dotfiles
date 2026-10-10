# hermes-auditoria-manual.ps1 — Contrasta AGENTS-WIN.md con la configuración viva del equipo Windows.
#
# Gemelo de ~/Config/hermes/hermes-auditoria-manual.py: inventario del esquema, tareas programadas,
# alias de modelo, voz, plugins, skills propias, hooks, cron, parche del CLI, rutas citadas,
# documentos\, copias (canónica, réplica de Linux y publicada), espejo de Obsidian y último ZIP.
#
# Uso:    powershell -NoProfile -ExecutionPolicy Bypass -File hermes-auditoria-manual.ps1 [-Json]
# Salida: 0 = sin desfases · 1 = hay desfases · 2 = error de entorno
#
# IMPORTANTE: guardar este fichero en UTF-8 **con BOM**. PowerShell 5.1 lo lee en ANSI si no lo
# lleva y los emojis de las rutas del vault rompen el parser.

param(
    [switch]$Json
)

$ErrorActionPreference = 'Continue'
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } else { Join-Path $env:LOCALAPPDATA 'hermes' }
$Vault = Join-Path $env:USERPROFILE 'MEGA\Obsidian\Obsidian\armarui74\Hermes-win'
$Manual = Join-Path $Base 'AGENTS-WIN.md'
$Inventario = Join-Path $Base 'SISTEMA-WINDOWS.md'

if (-not (Test-Path -LiteralPath $Manual)) {
    Write-Output "ERROR: no encuentro el manual: $Manual"
    exit 2
}
$Man = Get-Content -LiteralPath $Manual -Raw -Encoding UTF8

$script:ok = 0
$script:fallos = New-Object System.Collections.ArrayList
$script:avisos = New-Object System.Collections.ArrayList

function Check($cond, $msg) {
    if ($cond) { $script:ok++ } else { [void]$script:fallos.Add($msg) }
}
function Aviso($msg) { [void]$script:avisos.Add($msg) }

# El manual abrevia listas ("backup-hermes.{ps1,cmd}") y usa patrones ("informe-instalacion-*.txt")
function Citado($nombre) {
    if ($Man.Contains($nombre)) { return $true }
    foreach ($abrev in [regex]::Matches($Man, '[\w./\\-]*\{[^{}]+\}[\w./\\-]*')) {
        $t = $abrev.Value
        $pre = $t.Substring(0, $t.IndexOf('{'))
        $resto = $t.Substring($t.IndexOf('{') + 1)
        $cuerpo = $resto.Substring(0, $resto.IndexOf('}'))
        $suf = $resto.Substring($resto.IndexOf('}') + 1)
        foreach ($p in $cuerpo.Split(',')) {
            if (($pre + $p.Trim() + $suf) -eq $nombre) { return $true }
        }
    }
    foreach ($pat in [regex]::Matches($Man, '[\w.-]*\*[\w.-]*')) {
        $rx = '^' + [regex]::Escape($pat.Value).Replace('\*', '.*') + '$'
        if ($nombre -match $rx) { return $true }
    }
    return $false
}

# Letras reales (se localizan por marca, no por letra fija)
$seagate = $null
$linuxDisk = $null
foreach ($l in [char[]]'DEFGHIJKLMNOPQRSTUVWXYZ') {
    if (-not $seagate   -and (Test-Path -LiteralPath "${l}:\HermesSync\.hermes-sync")) { $seagate = "${l}:" }
    if (-not $linuxDisk -and (Test-Path -LiteralPath "${l}:\@home\antonio\.hermes")) { $linuxDisk = "${l}:" }
}

# ─── 1. Inventario: lo que hay en el esquema está citado en el manual ───
$Ignorar = @('AGENTS-WIN.md', 'SISTEMA-WINDOWS.md', 'documentos', 'backups', 'sesion-hermes',
             'sync.log', 'commit-parche.txt')
foreach ($f in (Get-ChildItem -LiteralPath $Base -Force | Sort-Object Name)) {
    $n = $f.Name
    if ($Ignorar -contains $n -or $n.StartsWith('.') -or $n -like '*.log' -or $n -like '*.bak-*') { continue }
    Check (Citado $n) "pieza del esquema sin documentar en el manual: $n"
}
foreach ($d in @('documentos', 'parches')) {
    Check (Test-Path -LiteralPath (Join-Path $Base $d)) "falta la carpeta $d\ del esquema"
}
Check ((Get-ChildItem -LiteralPath (Join-Path $Base 'documentos') -File).Count -ge 3) 'documentos\ debería tener los 3 markdown de configuración'

# ─── 2. Tareas programadas ───
foreach ($t in @('HermesBackup-Win', 'HermesBackup-Diario', 'HermesSync-Publicar')) {
    $tk = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    Check ($null -ne $tk) "la tarea $t no existe (¿registrar-tareas.ps1?)"
    Check (Citado $t) "tarea no citada en el manual: $t"
    if ($tk) {
        $i = $tk | Get-ScheduledTaskInfo
        if ($i.LastTaskResult -notin @(0, 267009)) {
            Aviso "la tarea $t terminó con resultado $($i.LastTaskResult) en su última pasada ($($i.LastRunTime))"
        } elseif ($i.LastTaskResult -eq 267009) {
            Write-Output "     (la tarea $t está en ejecución ahora mismo: 0x00041301)"
        }
    }
}

# ─── 3. Alias de modelo y modelo por defecto ───
$cfg = Join-Path $HermesHome 'config.yaml'
$aliases = @{}
if (Test-Path -LiteralPath $cfg) {
    $texto = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8
    $enAlias = $false
    foreach ($linea in ($texto -split "`n")) {
        if ($linea -match '^  aliases:\s*$') { $enAlias = $true; continue }
        if ($enAlias) {
            if ($linea -match '^    ([a-z0-9-]+):\s*(\S+)\s*$') { $aliases[$Matches[1]] = $Matches[2] }
            elseif ($linea -match '^  \S') { $enAlias = $false }
        }
    }
    $def = [regex]::Match($texto, '(?m)^  default:\s*"?([^"\r\n]+)"?').Groups[1].Value.Trim()
    $prov = [regex]::Match($texto, '(?m)^  provider:\s*"?([^"\r\n]+)"?').Groups[1].Value.Trim()
    if ($def) { Check (Citado $def) "model.default ($def) no citado en el manual" }
    if ($prov) { Check (Citado $prov) "model.provider ($prov) no citado en el manual" }
} else {
    Aviso "no encuentro $cfg"
}
$tabla = @{}
foreach ($r in [regex]::Matches($Man, '(?m)^\|\s*`([a-z0-9-]+)`\s*\|\s*`([^`]+)`')) {
    $tabla[$r.Groups[1].Value] = $r.Groups[2].Value
}
if ($aliases.Count -gt 0) {
    Check ($aliases.Count -eq $tabla.Count) "alias: manual $($tabla.Count) vs config $($aliases.Count)"
    foreach ($k in $aliases.Keys) {
        Check ($tabla[$k] -eq $aliases[$k]) "alias ${k}: manual=$($tabla[$k]) config=$($aliases[$k])"
    }
} else {
    Aviso 'no pude leer model.aliases de config.yaml'
}

# ─── 4. Voz (TTS/STT por comando) ───
if (Test-Path -LiteralPath $cfg) {
    $t2 = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8
    $tts = [regex]::Match($t2, '(?m)^tts:[\s\S]*?\n\s+provider:\s*"?(\w+)"?').Groups[1].Value
    $stt = [regex]::Match($t2, '(?m)^stt:[\s\S]*?\n\s+provider:\s*"?(\w+)"?').Groups[1].Value
    if ($tts) { Check (Citado $tts) "proveedor TTS ($tts) no citado" }
    if ($stt) { Check (Citado $stt) "proveedor STT ($stt) no citado" }
    foreach ($s in @('hermes-kokoro-tts.py', 'hermes-whisper-stt.py')) {
        Check (Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".local\bin\$s")) "falta el script de voz $s en .local\bin"
        Check (Citado $s) "script de voz no citado en el manual: $s"
    }
} else {
    Aviso 'sin config.yaml: no se comprueba la voz'
}

# ─── 5. Plugins ───
$plug = Join-Path $HermesHome 'plugins'
if (Test-Path -LiteralPath $plug) {
    foreach ($d in (Get-ChildItem -LiteralPath $plug -Directory)) {
        Check (Citado $d.Name) "plugin no citado en el manual: $($d.Name)"
    }
}

# ─── 6. Skills propias ───
$sk = Join-Path $HermesHome 'skills\autonomous-ai-agents'
if (Test-Path -LiteralPath $sk) {
    foreach ($d in (Get-ChildItem -LiteralPath $sk -Directory |
                    Where-Object { $_.Name -like 'hermes-*' -or $_.Name -eq 'modelos-locales-dimensionado' })) {
        Check (Citado $d.Name) "skill propia no citada en el manual: $($d.Name)"
    }
}

# ─── 7. Hooks ───
$hk = Join-Path $HermesHome 'hooks'
if (Test-Path -LiteralPath $hk) {
    foreach ($d in (Get-ChildItem -LiteralPath $hk -Directory)) {
        Check (Citado $d.Name) "hook no citado en el manual: $($d.Name)"
    }
}
$al = Join-Path $HermesHome 'shell-hooks-allowlist.json'
if (Test-Path -LiteralPath $al) {
    foreach ($r in [regex]::Matches((Get-Content -LiteralPath $al -Raw), '"command":\s*"([^"]+)"')) {
        Check (Citado (Split-Path $r.Groups[1].Value -Leaf)) "hook de shell no citado: $($r.Groups[1].Value)"
    }
}

# ─── 8. Cron ───
$jobs = Join-Path $HermesHome 'cron\jobs.json'
if (Test-Path -LiteralPath $jobs) {
    $j = Get-Content -LiteralPath $jobs -Raw -Encoding UTF8
    foreach ($r in [regex]::Matches($j, '"name":\s*"([^"]+)"')) {
        Check (Citado $r.Groups[1].Value) "trabajo de cron no citado en el manual: $($r.Groups[1].Value)"
    }
}

# ─── 9. Parche local del CLI ───
$cp = Join-Path $Base 'commit-parche.txt'
if (Test-Path -LiteralPath $cp) {
    $commit = (Get-Content -LiteralPath $cp -Raw).Trim()
    Check ($commit -ne '') 'commit-parche.txt está vacío'
    Check (Citado $commit) "commit del parche ($commit) no citado en el manual"
    $parcheHist = if ($seagate) { Join-Path "$seagate\HermesSync\windows\parches" "ctrl-q-$commit.patch" } else { Join-Path $Base "parches\ctrl-q-$commit.patch" }
    Check (Test-Path -LiteralPath $parcheHist) "no encuentro el parche histórico del commit $commit"
}
$parcheVivo = if ($seagate) { Join-Path "$seagate\HermesSync\windows\parches" 'ctrl-q-corta-audio.patch' } else { '' }
if ($parcheVivo -and (Test-Path -LiteralPath $parcheVivo)) {
    Check (Citado 'ctrl-q-corta-audio.patch') 'el parche vivo no está citado en el manual'
} else {
    Aviso 'no encuentro el parche vivo (¿está el disco compartido montado?)'
}

# ─── 10. Ficheros del esquema y rutas citadas ───
foreach ($f in @('backup-hermes.ps1', 'sync-hermes.ps1', 'check-setup-win.ps1', 'restaurar-hermes.ps1',
                 'bootstrap-hermes.ps1', 'instalar-desde-cero.ps1', 'registrar-tareas.ps1',
                 'lanzar-oculto.vbs', 'backup-tarea.cmd', 'hook-backup-hermes.sh',
                 'SISTEMA-WINDOWS.md', 'AGENTS-WIN.md', 'hermes-auditoria-manual.ps1')) {
    Check (Test-Path -LiteralPath (Join-Path $Base $f)) "falta en el esquema: $f"
}
foreach ($m in [regex]::Matches($Man, 'D:\\Linux\\Config\\Hermes-Win\\([A-Za-z0-9_.\-]+\.(ps1|cmd|sh|md|txt|vbs))')) {
    Check (Test-Path -LiteralPath (Join-Path $Base $m.Groups[1].Value)) "el manual cita algo que no existe: $($m.Value)"
}
Check (-not ($Man -match 'X:\\Linux')) 'el manual vuelve a usar X:\Linux (letra inexistente; usa D: o la marca)'
if ($linuxDisk) { Check (Citado "$linuxDisk\@home") "el disco de Linux ($linuxDisk) no está citado en el manual" }
else { Aviso 'no encuentro el disco de Linux (WinBtrfs) montado' }
Check ($null -ne $seagate) 'no encuentro la carpeta compartida (SEAGATE) por su marca .hermes-sync'
if ($seagate) { Check ($seagate -eq 'D:') "la letra del SEAGATE es $seagate y el manual dice D:" }

# ─── 11. documentos\ fiel a sus orígenes ───
foreach ($par in @(@('AGENTS-WIN.md', $Manual), @('SISTEMA-WINDOWS.md', $Inventario),
                   @('SOUL.md', (Join-Path $HermesHome 'SOUL.md')))) {
    $copia = Join-Path (Join-Path $Base 'documentos') $par[0]
    if (-not (Test-Path -LiteralPath $copia)) { Aviso "documentos\$($par[0]) ausente"; continue }
    Check ((Get-FileHash -LiteralPath $copia).Hash -eq (Get-FileHash -LiteralPath $par[1]).Hash) `
        "documentos\$($par[0]) desfasado respecto a su original"
}

# ─── 12. Copias del manual (canónica, réplica de Linux y publicada) ───
$copias = @(
    @{ Ruta = (Join-Path $Base 'sesion-hermes\AGENTS-WIN.md');          Origen = $Manual },
    @{ Ruta = (Join-Path $Base 'sesion-hermes\SISTEMA-WINDOWS.md');     Origen = $Inventario },
    @{ Ruta = 'F:\@home\antonio\Config\Hermes-Win\AGENTS-WIN.md';       Origen = $Manual },
    @{ Ruta = 'F:\@home\antonio\Config\Hermes-Win\SISTEMA-WINDOWS.md';  Origen = $Inventario }
)
if ($seagate) {
    $copias += @{ Ruta = (Join-Path "$seagate\HermesSync\windows\esquema-windows" 'AGENTS-WIN.md');      Origen = $Manual }
    $copias += @{ Ruta = (Join-Path "$seagate\HermesSync\windows\esquema-windows" 'SISTEMA-WINDOWS.md'); Origen = $Inventario }
}
foreach ($c in $copias) {
    if (Test-Path -LiteralPath $c.Ruta) {
        Check ((Get-FileHash -LiteralPath $c.Ruta).Hash -eq (Get-FileHash -LiteralPath $c.Origen).Hash) `
            "copia desfasada: $($c.Ruta)"
    } else {
        Aviso "copia ausente: $($c.Ruta)"
    }
}

# ─── 13. Espejo de Obsidian (carpeta Hermes-win) ───
if (Test-Path -LiteralPath $Vault) {
    foreach ($par in @(@($Manual, '💻 Manual de Hermes en Windows — AGENTS-WIN.md'),
                       @($Inventario, '💻 Sistema — Inventario del equipo en Windows · SISTEMA-WINDOWS.md'))) {
        $nota = Join-Path $Vault $par[1]
        if (-not (Test-Path -LiteralPath $nota)) { Aviso "nota del espejo ausente: $($par[1])"; continue }
        $a = ((Get-Content -LiteralPath $par[0] -Raw -Encoding UTF8) -split "`n") | ForEach-Object { $_.TrimEnd("`r") }
        $b = ((Get-Content -LiteralPath $nota    -Raw -Encoding UTF8) -split "`n") | ForEach-Object { $_.TrimEnd("`r") }
        $i = 0
        while ($i -lt $b.Count -and $b[$i].Trim() -eq '') { $i++ }
        Check (($a -join "`n") -eq (($b[$i..($b.Count - 1)]) -join "`n")) "nota del vault desfasada: $($par[1])"
    }
    $indice = Join-Path $Vault '💻 README.md'
    if (Test-Path -LiteralPath $indice) {
        $malos = @()
        foreach ($m in [regex]::Matches((Get-Content -LiteralPath $indice -Raw -Encoding UTF8), '\]\(([^)]+)\)')) {
            $p = [uri]::UnescapeDataString($m.Groups[1].Value)
            if ($p.StartsWith('http') -or $p.StartsWith('#')) { continue }
            $t = if ($p.EndsWith('.md')) { $p } else { "$p.md" }
            if (-not (Test-Path -LiteralPath (Join-Path $Vault $t))) { $malos += $p }
        }
        Check ($malos.Count -eq 0) "enlaces rotos en el índice del vault: $($malos -join ', ')"
    } else {
        Aviso 'no encuentro el índice del vault en Hermes-win'
    }
} else {
    Aviso "espejo de Obsidian no comprobado (no existe $Vault)"
}

# ─── 14. Frontera de credenciales en la copia saneada ───
$dot = 'D:\Linux\Documentos\dotfiles\hermes-win'
if (Test-Path -LiteralPath $dot) {
    foreach ($prohibido in @('.env', 'auth.json')) {
        Check (-not (Test-Path -LiteralPath (Join-Path $dot $prohibido))) "credencial en la copia saneada: $prohibido"
    }
    $patrones = '(nvapi-|oc_sk_)[A-Za-z0-9_-]{15,}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{25,}|API_KEY=[A-Za-z0-9_-]{15,}|BEGIN [A-Z ]*PRIVATE KEY'
    $fugas = @(Get-ChildItem -LiteralPath $dot -Recurse -File |
               Where-Object { $_.Extension -in @('.md', '.ps1', '.cmd', '.sh', '.json', '.yaml', '.txt', '.vbs') } |
               Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match $patrones })
    Check ($fugas.Count -eq 0) "claves detectadas en la copia saneada: $($fugas.Name -join ', ')"
} else {
    Aviso "no encuentro la copia saneada de dotfiles ($dot)"
}

# ─── 15. El último ZIP no es anterior a la última edición del manual ───
$zips = @(Get-ChildItem -LiteralPath (Join-Path $Base 'backups') -Filter 'hermes-win-backup-*.zip' |
          Sort-Object LastWriteTime)
if ($zips.Count -gt 0) {
    Check ($zips[-1].LastWriteTime -gt (Get-Item -LiteralPath $Manual).LastWriteTime) `
        'el último ZIP es anterior a la última edición del manual (¿backup pendiente?)'
} else {
    Aviso 'sin ZIPs en backups\'
}

# ─── Informe ───
if ($Json) {
    @{ ok = $script:ok; fallos = $script:fallos; avisos = $script:avisos } | ConvertTo-Json -Depth 3
} else {
    foreach ($a in $script:avisos) { Write-Output "   AVISO  $a" }
    if ($script:fallos.Count -gt 0) {
        Write-Output ""
        Write-Output "FALLOS: $($script:fallos.Count) desfase(s) entre el manual y la configuración viva:"
        foreach ($f in $script:fallos) { Write-Output "   - $f" }
        Write-Output ""
        Write-Output "   ($($script:ok) comprobaciones correctas)"
    } else {
        Write-Output "SIN DESFASES ($($script:ok) comprobaciones): manual, inventario, copias, espejo y sistema coherentes"
    }
}
exit $(if ($script:fallos.Count -gt 0) { 1 } else { 0 })
