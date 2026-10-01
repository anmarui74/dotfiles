<#
  instalar-desde-cero.ps1 — Deja un Windows limpio con Hermes funcionando EXACTAMENTE como
  está ahora este equipo: instalación oficial + configuración/credenciales/datos actuales +
  parche Ctrl+Q + alias de modelo + plugin nvidia (whitelist de OpenCode) + LM Studio +
  tarea de backup + hook de cierre.

  Es el equivalente Windows de setup-hermes-completo.sh de Linux, ampliado con los ajustes de
  entorno que en Linux no hacen falta (parche del CLI, plugin nvidia, LM Studio, tareas).

  Pasos:
    1. Comprobación del sistema (PowerShell, git, tar, robocopy, node, red)
    2. Instalación de Hermes si falta (instalador oficial, -SkipSetup)
    3. Restauración del último ZIP (config, credenciales, skills, plugins, memories, cron, kanban)
    4. Ajustes de entorno (HermesSync\windows\aplicar-ajustes-linux.ps1): parche Ctrl+Q, alias
       de modelo, plugin nvidia, LM_API_KEY y whitelist NVIDIA de OpenCode
    5. Hook de cierre de sesión (config.yaml + shell-hooks-allowlist.json)
    6. LM Studio: servidor en el 1234, modelo de los alias local-*, LM_API_KEY
    7. Tareas programadas (backup cada 30 min)
    8. Verificación final e informe

  Uso (sin administrador):
    powershell -ExecutionPolicy Bypass -File instalar-desde-cero.ps1
    # Prueba aislada, sin tocar la instalación real:
    ... -HermesHome "D:\prueba\hermes" -InstallDir "D:\prueba\hermes\hermes-agent" -SinTareas -SinLMStudio
#>
[CmdletBinding()]
param(
    [string]$Disco = '',
    [string]$HermesHome = '',
    [string]$InstallDir = '',
    [string]$Zip = '',
    [string]$Commit = '',
    [switch]$SinHermes,
    [switch]$SinAjustes,
    [switch]$SinLMStudio,
    [switch]$SinTareas,
    [switch]$DescargarModelo,
    [switch]$SoloVerificar,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$script:Fallos = 0
$script:Avisos = 0
$script:SalidaNativa = ''
$script:Informe = New-Object System.Collections.Generic.List[string]

function Paso  { param([string]$m) Write-Host ''; Write-Host "── $m ─────────────────────────────" -ForegroundColor Cyan }
function ok    { param([string]$m) Write-Host "   [ok] $m" -ForegroundColor Green; $script:Informe.Add("ok    $m") }
function aviso { param([string]$m) Write-Host "   [aviso] $m" -ForegroundColor Yellow; $script:Avisos++; $script:Informe.Add("aviso $m") }
function mal   { param([string]$m) Write-Host "   [FALLO] $m" -ForegroundColor Red; $script:Fallos++; $script:Informe.Add("FALLO $m") }

function Correr {
    # Ver la nota de backup-hermes.ps1: con $ErrorActionPreference='Stop', PowerShell 5.1
    # convierte en error terminante cualquier línea que un .exe escriba en stderr.
    param([string]$Exe, [string[]]$Argumentos)
    $eap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $salida = @(& $Exe @Argumentos 2>&1)
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $eap
    $script:SalidaNativa = ($salida | Out-String)
    return $rc
}

function Find-RaizLinux {
    param([string]$Letra = '')
    if ($Letra -ne '') {
        $raiz = "${Letra}:\Linux"
        if (Test-Path $raiz) { return $raiz }
        return $null
    }
    foreach ($l in ([char[]](68..90))) {
        try { if (Test-Path "${l}:\HermesSync\.hermes-sync") { return "${l}:\Linux" } } catch { }
    }
    return $null
}

function Find-Comun {
    # Carpeta compartida del disco (aquí viven windows\aplicar-ajustes-linux.ps1, parches\ y plugins\)
    param([string]$Letra = '')
    if ($Letra -ne '') {
        $c = "${Letra}:\HermesSync"
        if (Test-Path $c) { return $c }
        return $null
    }
    foreach ($l in ([char[]](68..90))) {
        try { if (Test-Path "${l}:\HermesSync\.hermes-sync") { return "${l}:\HermesSync" } } catch { }
    }
    return $null
}

function Get-IsoUtc {
    # Mismo formato que datetime.fromtimestamp(mtime, tz=utc).isoformat() de Python:
    # sin fracción si los microsegundos son 0 (Hermes compara el texto para detectar deriva).
    param([datetime]$Fecha)
    $us = [long][math]::Floor([double]($Fecha.Ticks % 10000000L) / 10.0)
    $iso = $Fecha.ToString('yyyy-MM-ddTHH:mm:ss')
    if ($us -ne 0) { $iso += '.' + $us.ToString('000000') }
    return $iso + 'Z'
}

function Get-RutaBarras {
    param([string]$Ruta)
    return ($Ruta -replace '\\', '/')
}

# ════════════════════════════════════════════════════════════════════════════════════════
Write-Host '===============================================' -ForegroundColor Cyan
Write-Host ' INSTALACIÓN DE HERMES DESDE CERO (Windows)'
Write-Host " Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
Write-Host '==============================================='

# Rutas base
$RaizLinux = Find-RaizLinux -Letra $Disco
if (-not $RaizLinux) { Write-Host 'ERROR: no encuentro el disco compartido (busco <letra>:\HermesSync\.hermes-sync).'; exit 1 }
$Comun = Find-Comun -Letra $Disco
if (-not $Comun) { $Comun = Split-Path -Parent $RaizLinux }   # <letra>:\ ... por si acaso
$Base = Join-Path $RaizLinux 'Config\Hermes-Win'
$BackupDir = Join-Path $Base 'backups'
$SesionDir = Join-Path $Base 'sesion-hermes'

if (-not $HermesHome) {
    $HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME } elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'hermes' } else { '' }
}
if (-not $HermesHome) { Write-Host 'ERROR: no sé dónde va HERMES_HOME.'; exit 1 }
if (-not $InstallDir) { $InstallDir = Join-Path $HermesHome 'hermes-agent' }
$env:HERMES_HOME = $HermesHome     # los procesos hijos (hermes.exe, instalador) lo heredan
$HermesExe = Join-Path $HermesHome 'bin\hermes.exe'

Write-Host " HERMES_HOME:  $HermesHome"
Write-Host " InstallDir:   $InstallDir"
Write-Host " Esquema:      $Base"

# ── PASO 1: sistema ────────────────────────────────────────────────────────────────────
Paso 'PASO 1: comprobación del sistema'
if ($PSVersionTable.PSVersion.Major -ge 5) { ok "PowerShell $($PSVersionTable.PSVersion)" } else { mal 'PowerShell demasiado antiguo' }
foreach ($c in @('git', 'tar', 'robocopy', 'node')) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) { ok "$c disponible" } else { aviso "$c no encontrado en el PATH (puede hacer falta)" }
}
$tieneRed = $false
try {
    $r = Invoke-WebRequest -Uri 'https://hermes-agent.nousresearch.com/install.ps1' -Method Head -TimeoutSec 15 -UseBasicParsing
    if ($r.StatusCode -eq 200) { $tieneRed = $true; ok 'acceso a hermes-agent.nousresearch.com' }
} catch { }
if (-not $tieneRed) { aviso 'sin acceso al sitio de descarga de Hermes (¿red?); la instalación oficial no podrá bajar nada' }

# ── PASO 2: Hermes ─────────────────────────────────────────────────────────────────────
Paso 'PASO 2: instalación de Hermes Agent'
# "Instalado" significa instalado EN ESTE HOME (el launcher <home>\bin\hermes.exe). Que haya
# otro hermes en el PATH (el de otra instalación) no cuenta: en un equipo limpio no habrá
# ninguno, y si se pide otro home hay que instalar ahí.
$HermesPresente = Test-Path $HermesExe
$otroHermes = (Get-Command hermes -ErrorAction SilentlyContinue).Source
if ($HermesPresente) {
    ok "Hermes ya está instalado en $HermesHome (se omite la instalación)"
} elseif ($SoloVerificar) {
    aviso 'modo -SoloVerificar: no se instala nada'
} elseif ($SinHermes) {
    aviso 'falta Hermes en este home y se ha pasado -SinHermes: no se instala'
} else {
    if ($otroHermes) { aviso "hay otro Hermes en el PATH ($otroHermes); este script instala el suyo en $HermesHome" }
    if (-not $tieneRed) { mal 'no puedo instalar Hermes sin red' } else {
        Write-Host '   Instalando con el instalador oficial (uv + Python + Node si faltan)...'
        $expr = '[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ' +
                '& ([scriptblock]::Create((irm https://hermes-agent.nousresearch.com/install.ps1))) ' +
                "-HermesHome '$HermesHome' -InstallDir '$InstallDir' -SkipSetup"
        if ($Commit -ne '') { $expr += " -Commit '$Commit'" }
        $rc = Correr -Exe 'powershell.exe' -Argumentos @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $expr)
        $log = Join-Path $env:TEMP ("hermes-install-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
        Set-Content -Path $log -Value $script:SalidaNativa -Encoding UTF8
        if ($rc -eq 0 -and (Test-Path $HermesExe)) {
            ok "Hermes instalado (launcher: $HermesExe). Salida completa: $log"
            $env:Path = "$(Join-Path $HermesHome 'bin');$env:Path"   # en esta sesión
            aviso "el instalador oficial ha añadido $(Join-Path $HermesHome 'bin') al PATH del usuario: abre una terminal nueva para tener 'hermes'"
            $HermesPresente = $true
        } else {
            mal "el instalador oficial devolvió $rc (salida en $log)"
        }
    }
}
if (-not (Test-Path $HermesExe) -and $SoloVerificar) {
    $cmdHermes = Get-Command hermes -ErrorAction SilentlyContinue
    if ($cmdHermes) { $HermesExe = $cmdHermes.Source; ok "uso el hermes del PATH: $HermesExe" }
}
if (Test-Path $HermesExe) {
    [void](Correr -Exe $HermesExe -Argumentos @('--version'))
    $ver = ($script:SalidaNativa -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    if ($ver) { ok "versión: $($ver.Trim())" }
}
# El repo instalado (para el parche del CLI y los plugins)
if (-not (Test-Path (Join-Path $InstallDir '.git'))) {
    foreach ($cand in @($InstallDir, (Join-Path $HermesHome 'hermes-agent'))) {
        if (Test-Path (Join-Path $cand '.git')) { $InstallDir = $cand; break }
    }
}

# ── PASO 3: restauración de la configuración actual ────────────────────────────────────
Paso 'PASO 3: restauración de la configuración actual (último ZIP)'
if (-not $SoloVerificar) {
    $restaurador = Join-Path $Base 'restaurar-hermes.ps1'
    if (-not (Test-Path $restaurador)) { mal "no existe $restaurador" } else {
        $argsR = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $restaurador, '-Destino', $HermesHome, '-HermesHome', $HermesHome)
        if ($Zip -ne '')         { $argsR += @('-Zip', $Zip) }
        if ($Disco -ne '')       { $argsR += @('-Disco', $Disco) }
        # El doctor se hace al final (paso 8) con el launcher del home destino
        $argsR += '-SinDoctor'
        $rc = Correr -Exe 'powershell.exe' -Argumentos $argsR
        if (-not $Quiet) { Write-Host ($script:SalidaNativa.TrimEnd() -split "`r?`n" | Where-Object { $_ -match '\[ok\]|\[aviso\]|\[FALLO\]|RESTAURACIÓN' }) }
        if ($rc -eq 0) { ok 'configuración, credenciales y datos restaurados' }
        else { mal "la restauración devolvió $rc" }
    }
} else { ok 'modo -SoloVerificar: sin restauración' }

# ── PASO 4: ajustes de entorno (parche, alias, plugin nvidia) ─────────────────────────
Paso 'PASO 4: ajustes de entorno (parche Ctrl+Q, alias de modelo, plugin nvidia)'
if ($SinAjustes -or $SoloVerificar) {
    ok 'omitido (-SinAjustes/-SoloVerificar)'
} else {
    $ajustes = ''
    foreach ($cand in @((Join-Path $Comun 'windows\aplicar-ajustes-linux.ps1'),
                        (Join-Path $HermesHome 'dual-boot\aplicar-ajustes-linux.ps1'),
                        (Join-Path $HermesHome 'dual-boot\windows\aplicar-ajustes-linux.ps1'),
                        (Join-Path $Base 'aplicar-ajustes-linux.ps1'))) {
        if (Test-Path $cand) { $ajustes = $cand; break }
    }
    if (-not $ajustes) {
        mal 'no encuentro aplicar-ajustes-linux.ps1 (está en HermesSync\windows\); sin él NO se aplican el parche Ctrl+Q ni el plugin nvidia'
    } else {
        ok "usando $ajustes"
        $rc = Correr -Exe 'powershell.exe' -Argumentos @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ajustes,
                '-Repo', $InstallDir, '-HermesHome', $HermesHome)
        $salidaAjustes = $script:SalidaNativa
        if (-not $Quiet) { Write-Host ($salidaAjustes.TrimEnd() -split "`r?`n" | Where-Object { $_ -match '\[ok\]|\[!\]|\[x\]' }) }
        if ($rc -eq 0) { ok 'ajustes aplicados' } else { mal "aplicar-ajustes-linux.ps1 devolvió $rc" }

        # El parche Ctrl+Q se hizo contra un commit concreto: si el repo se ha clonado en HEAD
        # (upstream movido), no aplica. Se reintenta fijando el commit de referencia
        # (parámetro -Commit o el sha guardado en commit-parche.txt).
        $parcheRuta = Join-Path $Comun 'windows\parches\ctrl-q-corta-audio.patch'
        if ((Test-Path $parcheRuta) -and (Test-Path (Join-Path $InstallDir '.git'))) {
            $rcParche = Correr -Exe 'git' -Argumentos @('-C', $InstallDir, 'apply', '--reverse', '--check', $parcheRuta)
            if ($rcParche -eq 0) {
                ok 'parche Ctrl+Q aplicado'
            } else {
                $commitRef = $Commit
                if (-not $commitRef) {
                    $fichCommit = Join-Path $Base 'commit-parche.txt'
                    if (Test-Path $fichCommit) {
                        $commitRef = ((Get-Content $fichCommit | Where-Object { $_ -and $_ -notmatch '^\s*#' } | Select-Object -First 1)).Trim()
                    }
                }
                if (-not $commitRef) {
                    aviso 'el parche Ctrl+Q no aplica y no hay commit de referencia (commit-parche.txt)'
                } else {
                    aviso "el parche Ctrl+Q no aplica en HEAD; reintentando en el commit de referencia $commitRef"
                    if ((Correr -Exe 'git' -Argumentos @('-C', $InstallDir, 'checkout', '--quiet', $commitRef)) -ne 0) {
                        mal "no he podido cambiar el repo a $commitRef"
                    } else {
                        [void](Correr -Exe 'powershell.exe' -Argumentos @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ajustes,
                                '-Repo', $InstallDir, '-HermesHome', $HermesHome))
                        if ((Correr -Exe 'git' -Argumentos @('-C', $InstallDir, 'apply', '--reverse', '--check', $parcheRuta)) -eq 0) {
                            ok "parche Ctrl+Q aplicado fijando el repo en $commitRef"
                        } else {
                            mal "el parche Ctrl+Q sigue sin aplicar ni en ${commitRef}: hay que portarlo al código nuevo"
                        }
                    }
                }
            }
        }
    }
}

# ── PASO 5: hook de cierre de sesión ──────────────────────────────────────────────────
Paso 'PASO 5: hook de cierre de sesión (backup al cerrar)'
if ($SoloVerificar) { ok 'omitido (-SoloVerificar)' } else {
    $hookScript = Join-Path $HermesHome 'agent-hooks\backup-hermes.sh'
    if (-not (Test-Path $hookScript)) {
        $origenHook = Join-Path $Base 'hook-backup-hermes.sh'
        if (Test-Path $origenHook) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $hookScript) | Out-Null
            Copy-Item $origenHook $hookScript -Force
        }
    }
    if (-not (Test-Path $hookScript)) {
        aviso 'no hay agent-hooks\backup-hermes.sh (ni copia en el esquema): el backup al cerrar la sesión no queda montado'
    } else {
        ok "script del hook: $hookScript"
        if (Test-Path $HermesExe) {
            # El comando del hook lleva la ruta real del script, con barras inclinadas
            $comando = "$(Get-RutaBarras $hookScript)"
            if (-not $Quiet) { [void](Correr -Exe $HermesExe -Argumentos @('config', 'set', 'hooks.on_session_end',
                    "[{'command': '$comando', 'timeout': 120}]")) }
            else { [void](Correr -Exe $HermesExe -Argumentos @('config', 'set', 'hooks.on_session_end',
                    "[{'command': '$comando', 'timeout': 120}]")) }
            [void](Correr -Exe $HermesExe -Argumentos @('config', 'get', 'hooks'))
            if ($script:SalidaNativa -match 'on_session_end') { ok 'hook declarado en config.yaml' } else { mal 'el hook no aparece en config.yaml' }
        }
        # Aprobación (allowlist) calculada con el formato que lee Hermes
        $allow = Join-Path $HermesHome 'shell-hooks-allowlist.json'
        $datos = @{ approvals = @() }
        if (Test-Path $allow) {
            try { $datos = Get-Content $allow -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
                $datos = @{ approvals = @() }
            }
        }
        $mtime = Get-IsoUtc (Get-Item $hookScript).LastWriteTimeUtc
        $ahora = Get-IsoUtc ((Get-Date).ToUniversalTime())
        $lista = @()
        if ($datos.approvals) { $lista = @($datos.approvals) }
        $lista = @($lista | Where-Object { -not ($_.event -eq 'on_session_end' -and $_.command -eq $comando) })
        $lista += [pscustomobject]@{ event = 'on_session_end'; command = $comando; approved_at = $ahora; script_mtime_at_approval = $mtime }
        $salidaJson = [pscustomobject]@{ approvals = $lista } | ConvertTo-Json -Depth 6
        Set-Content -Path $allow -Value $salidaJson -Encoding UTF8
        ok "aprobación escrita en $allow"
    }
}

# ── PASO 6: LM Studio ─────────────────────────────────────────────────────────────────
Paso 'PASO 6: LM Studio (servidor local y modelo de los alias local-*)'
if ($SinLMStudio -or $SoloVerificar) { ok 'omitido (-SinLMStudio/-SoloVerificar)' } else {
    $lms = (Get-Command lms -ErrorAction SilentlyContinue).Source
    if (-not $lms) {
        foreach ($cand in @((Join-Path $env:USERPROFILE '.lmstudio\bin\lms.exe'),
                            (Join-Path $env:LOCALAPPDATA 'Programs\lm-studio\resources\app\.webpack\lms.exe'))) {
            if (Test-Path $cand) { $lms = $cand; break }
        }
    }
    if (-not $lms) {
        aviso 'LM Studio no está instalado (o su CLI `lms` no aparece). Instálalo y vuelve a ejecutar este script.'
        aviso 'El proveedor lmstudio seguirá sin modelos hasta entonces; los alias local-* no servirán.'
    } else {
        ok "lms: $lms"
        $apiOk = $false
        for ($i = 0; $i -lt 2; $i++) {
            try {
                $r = Invoke-WebRequest -Uri 'http://127.0.0.1:1234/v1/models' -TimeoutSec 5 -UseBasicParsing
                if ($r.StatusCode -eq 200) { $apiOk = $true; break }
            } catch { }
            if ($i -eq 0) {
                Write-Host '   Arrancando el servidor de LM Studio (headless, puerto 1234)...'
                [void](Correr -Exe $lms -Argumentos @('server', 'start'))
                Start-Sleep -Seconds 8
            }
        }
        if ($apiOk) { ok 'API de LM Studio respondiendo en http://127.0.0.1:1234' } else { aviso 'la API de LM Studio no responde en el 1234 (arráncala con: lms server start)' }

        # Modelos descargados vs. los que esperan los alias local-*
        $modelosLocal = @()
        [void](Correr -Exe $lms -Argumentos @('ls'))
        foreach ($l in ($script:SalidaNativa -split "`r?`n")) {
            if ($l -match '^\s*([A-Za-z0-9._\-/]+:[A-Za-z0-9._\-]+)') { $modelosLocal += $Matches[1] }
        }
        $modelosLocal = @($modelosLocal | Select-Object -Unique)
        if ($modelosLocal.Count) { ok "modelos en LM Studio: $($modelosLocal -join ', ')" } else { aviso 'no he podido listar los modelos de LM Studio (lms ls)' }

        $esperados = @()
        if (Test-Path $HermesExe) {
            [void](Correr -Exe $HermesExe -Argumentos @('config', 'get', 'model.aliases'))
            foreach ($l in ($script:SalidaNativa -split "`r?`n")) {
                # formato real: "alias: proveedor/modelo"
                if ($l -match '^\s*(local[\w\-]*)\s*:\s*(\S+)') {
                    $valor = $Matches[2]
                    if ($valor -match '^(?:lmstudio|local)/(.+)$') { $esperados += $Matches[1] } else { $esperados += $valor }
                }
            }
            $esperados = @($esperados | Select-Object -Unique)
        }
        if ($esperados.Count) { ok "alias locales a comprobar: $($esperados -join ', ')" } else { aviso 'no he podido leer los alias local-* de config.yaml' }
        foreach ($m in $esperados) {
            $base = ($m -split '/')[-1]
            $tiene = $false
            foreach ($d in $modelosLocal) { if ($d -eq $m -or $d -like "*$base*") { $tiene = $true; break } }
            if ($tiene) { ok "modelo de alias presente: $m" }
            elseif ($DescargarModelo) {
                Write-Host "   Descargando $m (puede tardar y pesar varios GB)..."
                [void](Correr -Exe $lms -Argumentos @('get', $m))
                if ($LASTEXITCODE -eq 0) { ok "modelo descargado: $m" } else { aviso "no se pudo descargar $m" }
            } else {
                aviso "falta el modelo '$m' de los alias: descárgalo con  lms get $m   (o repite con -DescargarModelo)"
            }
        }
    }
    # LM_API_KEY (sin ella el proveedor lmstudio no existe para el selector)
    $envFile = Join-Path $HermesHome '.env'
    if (Test-Path $envFile) {
        $tieneKey = (Get-Content $envFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*LM_API_KEY\s*=' })
        if ($tieneKey) { ok 'LM_API_KEY presente en .env' } else {
            Add-Content -Path $envFile -Value 'LM_API_KEY=lm-studio' -Encoding UTF8
            ok 'LM_API_KEY añadida a .env'
        }
    } else { aviso 'no hay .env: no puedo añadir LM_API_KEY' }
}

# ── PASO 7: tareas programadas ────────────────────────────────────────────────────────
Paso 'PASO 7: tareas programadas (backup cada 30 min)'
if ($SinTareas -or $SoloVerificar) {
    ok 'omitido (-SinTareas/-SoloVerificar)'
} else {
    $registrador = Join-Path $Base 'registrar-tareas.ps1'
    if (-not (Test-Path $registrador)) { aviso "no existe $registrador" } else {
        $rc = Correr -Exe 'powershell.exe' -Argumentos @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $registrador, '-Quiet')
        if ($rc -eq 0) { ok 'tarea HermesBackup-Win registrada/actualizada' } else { mal "registrar-tareas.ps1 devolvió $rc" }
    }
}

# ── PASO 8: verificación final ────────────────────────────────────────────────────────
Paso 'PASO 8: verificación final'
Write-Host "   HERMES_HOME = $HermesHome"
if (Test-Path $HermesExe) {
    # Ficheros críticos
    foreach ($f in @('config.yaml', '.env', 'auth.json', 'SOUL.md', 'memories\MEMORY.md', 'skills')) {
        if (Test-Path (Join-Path $HermesHome $f)) { ok "$f" } else { mal "falta $f" }
    }
    # Aliases de modelo
    [void](Correr -Exe $HermesExe -Argumentos @('config', 'get', 'model.aliases'))
    $nAlias = (($script:SalidaNativa -split "`r?`n") | Where-Object { $_ -match '^\s*[\w\-]+\s*:\s*\S+' }).Count
    if ($nAlias -gt 0) { ok "alias de modelo: $nAlias" } else { aviso 'no he podido leer los alias de modelo' }
    # Plugin nvidia instalado y whitelist
    $pluginDst = Join-Path $HermesHome 'plugins\model-providers\nvidia\__init__.py'
    $pluginSrc = Join-Path $Comun 'windows\plugins\model-providers\nvidia\__init__.py'
    if (Test-Path $pluginDst) {
        $h1 = (Get-FileHash $pluginDst -Algorithm SHA256).Hash
        if (Test-Path $pluginSrc) {
            $h2 = (Get-FileHash $pluginSrc -Algorithm SHA256).Hash
            if ($h1 -eq $h2) { ok "plugin nvidia idéntico al de la carpeta común ($($h1.Substring(0,12))…)" }
            else { aviso "el plugin nvidia difiere de la carpeta común ($($h1.Substring(0,12))… vs $($h2.Substring(0,12))…)" }
        } else { ok "plugin nvidia presente ($($h1.Substring(0,12))…)" }
    } else { mal 'falta el plugin nvidia en plugins\model-providers\nvidia' }
    # Parche Ctrl+Q (si se aplicó, git apply --reverse --check debe pasar)
    if (Test-Path (Join-Path $InstallDir '.git')) {
        $parche = Join-Path $Comun 'windows\parches\ctrl-q-corta-audio.patch'
        if (Test-Path $parche) {
            $rc = Correr -Exe 'git' -Argumentos @('-C', $InstallDir, 'apply', '--reverse', '--check', $parche)
            if ($rc -eq 0) { ok 'parche Ctrl+Q aplicado en el repo' } else { mal 'el parche Ctrl+Q NO está aplicado' }
        } else { aviso 'no encuentro el parche ctrl-q-corta-audio.patch' }
    } else { aviso "no hay repo git en ${InstallDir}: no puedo comprobar el parche Ctrl+Q" }
    # Tareas y hook
    $t = Correr -Exe 'schtasks.exe' -Argumentos @('/query', '/tn', 'HermesBackup-Win')
    if ($t -eq 0) { ok 'tarea HermesBackup-Win registrada' } else { aviso 'tarea HermesBackup-Win no registrada' }
    $rcH = Correr -Exe $HermesExe -Argumentos @('hooks', 'doctor')
    if ($script:SalidaNativa -match 'All shell hooks look healthy') { ok 'hook on_session_end sano (hermes hooks doctor)' }
    elseif ($script:SalidaNativa -match '✗') {
        mal 'el hook on_session_end tiene problemas (hermes hooks doctor)'
        Write-Host ($script:SalidaNativa.TrimEnd() -split "`r?`n" | Where-Object { $_ -match '✗' })
    } else { aviso 'no he podido comprobar el hook (hermes hooks doctor no devolvió lo esperado)' }
    # Doctor de Hermes
    Write-Host ''
    Write-Host '   hermes doctor:'
    [void](Correr -Exe $HermesExe -Argumentos @('doctor'))
    Write-Host ($script:SalidaNativa.TrimEnd() -split "`r?`n" | Select-Object -First 30)
} else {
    mal "no encuentro el launcher de Hermes: $HermesExe"
}

# ── Informe ───────────────────────────────────────────────────────────────────────────
$informePath = Join-Path $Base ("informe-instalacion-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
$cabecera = @("Informe de instalación desde cero — $(Get-Date -Format 'dd/MM/yyyy HH:mm')",
              "HERMES_HOME: $HermesHome", "InstallDir: $InstallDir", '')
Set-Content -Path $informePath -Value ($cabecera + $script:Informe) -Encoding UTF8

Write-Host ''
Write-Host '===============================================' -ForegroundColor Cyan
if ($script:Fallos -eq 0) {
    Write-Host " INSTALACIÓN COMPLETADA  ($($script:Avisos) avisos)" -ForegroundColor Green
} else {
    Write-Host " INSTALACIÓN COMPLETADA CON $($script:Fallos) FALLOS  ($($script:Avisos) avisos)" -ForegroundColor Red
    Write-Host ' Revisa las líneas [FALLO] de arriba.'
}
Write-Host " Informe: $informePath"
Write-Host '==============================================='
if ($script:Fallos -eq 0) { exit 0 } else { exit 2 }
