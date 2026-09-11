#Requires -Version 5.1
<#
.SYNOPSIS
  Instalador automatico de OpenCode + LM Studio para Windows (desde cero).

.DESCRIPTION
  Deja OpenCode totalmente operativo instalando y configurando todo lo necesario:
    1. Requisitos: Node.js LTS, Python 3.14, LM Studio y Git (via winget)
    2. OpenCode (paquete npm opencode-ai)
    3. Configuracion de OpenCode (opencode.jsonc, opencode-local.json, tui.json,
       AGENTS.md, prompts) en %USERPROFILE%\.config\opencode
    4. Proxy de LM Studio (lmstudio-proxy.py, puerto 4001) y start-lmstudio.ps1
    5. Perfil de PowerShell con los lanzadores ocv / ocv-cloud / ocv-status
    6. Politica de ejecucion RemoteSigned (CurrentUser)
    7. Modelo Qwen3.8-9B en LM Studio (copia/enlace desde una ruta configurable)
    8. Arranque del stack (servidor + modelo + proxy) y verificacion final

  Se auto-eleva a administrador (UAC) para los winget install.

.PARAMETER SourceDir
  Carpeta que contiene config\ y perfil\. Por defecto, la carpeta del script.

.PARAMETER ModelSource
  Ruta al .gguf del modelo a colocar en LM Studio.

.PARAMETER ModelKey
  Identificador/alias del modelo (por defecto: qwen3.8-9b).

.PARAMETER ContextLength
  Contexto a cargar (por defecto: 80000).

.PARAMETER SkipPrereqs
  No instala Node/Python/LM Studio/Git (asume que ya estan).

.PARAMETER SkipModel
  No coloca el modelo en LM Studio.

.PARAMETER WithTasks
  Crea tareas programadas (backup diario + comprobacion de whitelist NVIDIA).

.PARAMETER Unattended
  No hace pausas interactivas.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\instalar-opencode-win.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\instalar-opencode-win.ps1 -WithTasks -Unattended
#>
[CmdletBinding()]
param(
  [string]$SourceDir,
  [string]$ModelSource = "D:\Linux\modelos_ia\Qwen3.8-9B-Q6_K.gguf",
  [string]$ModelKey = "qwen3.8-9b",
  [int]$ContextLength = 80000,
  [int]$ProxyPort = 4001,
  [switch]$SkipPrereqs,
  [switch]$SkipModel,
  [switch]$WithVoice,
  [switch]$WithTasks,
  [switch]$Unattended,
  [switch]$NoElevate,
  [string]$TargetProfile = $env:USERPROFILE
)

$ErrorActionPreference = "Continue"
$ScriptVersion = "1.0"

if (-not $SourceDir) { $SourceDir = $PSScriptRoot }
$ConfigSrc = Join-Path $SourceDir "config"
$PerfilSrc = Join-Path $SourceDir "perfil"

# =====================================================================
#  Utilidades de consola
# =====================================================================
function Write-Banner {
  Write-Host ""
  Write-Host "=====================================================================" -ForegroundColor DarkCyan
  Write-Host "  INSTALADOR DE OPENCODE + LM STUDIO PARA WINDOWS  v$ScriptVersion" -ForegroundColor Cyan
  Write-Host "=====================================================================" -ForegroundColor DarkCyan
  Write-Host ""
}
function Write-Step($msg, $color = "Cyan") { Write-Host $msg -ForegroundColor $color }
function Write-Ok($msg)   { Write-Host "🟢 $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "🟡 $msg" -ForegroundColor Yellow }
function Write-Err2($msg) { Write-Host "🔴 $msg" -ForegroundColor Red }

$script:LogFile = Join-Path $env:TEMP ("instalar-opencode-win-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
function Write-Log($msg) {
  $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $msg
  Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
}

# =====================================================================
#  Auto-elevacion a administrador
# =====================================================================
function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not $NoElevate -and -not (Test-Admin)) {
  Write-Warn2 "Se necesitan permisos de administrador. Solicitando elevacion (UAC)..."
  $a = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"",
    "-SourceDir", "`"$SourceDir`"",
    "-ModelSource", "`"$ModelSource`"",
    "-ModelKey", "`"$ModelKey`"",
    "-ContextLength", "$ContextLength",
    "-ProxyPort", "$ProxyPort",
    "-TargetProfile", "`"$TargetProfile`""
  )
  if ($SkipPrereqs) { $a += "-SkipPrereqs" }
  if ($SkipModel)   { $a += "-SkipModel" }
  if ($WithVoice)   { $a += "-WithVoice" }
  if ($WithTasks)   { $a += "-WithTasks" }
  if ($Unattended)  { $a += "-Unattended" }
  if ($NoElevate)   { $a += "-NoElevate" }
  Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $a
  exit
}

Write-Banner
Write-Log "Inicio del instalador v$ScriptVersion. Usuario destino: $TargetProfile"
Write-Step "📁 Origen:      $SourceDir"
Write-Step "📁 Config destino: $TargetProfile\.config\opencode"
Write-Step "📝 Log:         $script:LogFile"
Write-Host ""

$TargetConfig = Join-Path $TargetProfile ".config\opencode"

# =====================================================================
#  Helpers
# =====================================================================
function Refresh-Path {
  $m = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $u = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = (@($m, $u) | Where-Object { $_ }) -join ";"
}

function Resolve-Lms {
  $candidates = @(
    (Join-Path $TargetProfile ".lmstudio\bin\lms.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\LM Studio\resources\app\.webpack\lms.exe"),
    (Join-Path ${env:ProgramFiles} "LM Studio\resources\app\.webpack\lms.exe")
  )
  foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
  $cmd = Get-Command lms -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Resolve-Python {
  $cmd = Get-Command python -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -notmatch "WindowsApps") { return $cmd.Source }
  foreach ($c in @("C:\Python314\python.exe", "C:\Python313\python.exe", "C:\Python312\python.exe", "C:\Python311\python.exe")) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  return $null
}

function Test-Winget { [bool](Get-Command winget -ErrorAction SilentlyContinue) }

function Install-WingetPackage {
  param([string]$Id, [string]$Name)
  Write-Warn2 "Instalando $Name ($Id)..."
  Write-Log "winget install $Id"
  $out = (winget install --id $Id -e --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1 | Out-String)
  if ($out -match "Successfully installed|instalado correctamente|already installed|ya instalad") {
    Write-Ok "$Name listo."
    return $true
  }
  Write-Warn2 "Resultado de winget para ${Name}:"
  Write-Host $out
  return $false
}

function Copy-TextWithPaths {
  param([string]$SrcFile, [string]$DstFile)
  $text = [System.IO.File]::ReadAllText($SrcFile, [System.Text.Encoding]::UTF8)
  $srcUser = "C:\Users\evo01"
  $srcUserFwd = "C:/Users/evo01"
  $tgtUser = $TargetProfile.TrimEnd('\')
  $tgtUserFwd = $tgtUser.Replace('\', '/')
  if ($tgtUser -ne $srcUser) {
    $text = $text.Replace($srcUserFwd, $tgtUserFwd).Replace($srcUser, $tgtUser)
  }
  # Encoding: .ps1 → UTF-8 con BOM (obligatorio en PS 5.1); resto (json/txt) → sin BOM
  if ($DstFile -match '\.ps1$') {
    $enc = New-Object System.Text.UTF8Encoding($true)
  } else {
    $enc = New-Object System.Text.UTF8Encoding($false)
  }
  $dir = Split-Path -Parent $DstFile
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($DstFile, $text, $enc)
}

function Copy-Binary {
  param([string]$SrcFile, [string]$DstFile)
  $dir = Split-Path -Parent $DstFile
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Copy-Item -LiteralPath $SrcFile -Destination $DstFile -Force
}

# =====================================================================
#  PASO 1: Requisitos previos (winget)
# =====================================================================
Write-Host ""
Write-Step "──────────────── PASO 1/9 · Requisitos previos ────────────────" "DarkCyan"

if ($SkipPrereqs) {
  Write-Warn2 "Omitido por -SkipPrereqs."
} elseif (-not (Test-Winget)) {
  Write-Err2 "winget no esta disponible. Instala 'App Installer' desde la Microsoft Store."
  Write-Warn2 "Se continua sin instalar requisitos; asegurate de tener Node.js, Python y LM Studio."
} else {
  # Node.js LTS
  if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Ok "Node.js ya instalado ($(node --version))."
  } else {
    Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
    Refresh-Path
  }
  # Python 3.14
  if (Resolve-Python) {
    Write-Ok "Python ya instalado."
  } else {
    Install-WingetPackage -Id "Python.Python.3.14" -Name "Python 3.14"
    Refresh-Path
  }
  # LM Studio
  if (Resolve-Lms) {
    Write-Ok "LM Studio ya instalado."
  } else {
    Install-WingetPackage -Id "ElementLabs.LMStudio" -Name "LM Studio"
  }
  # Git (necesario para algunas skills/MCPs)
  if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Ok "Git ya instalado."
  } else {
    Install-WingetPackage -Id "Git.Git" -Name "Git"
    Refresh-Path
  }
}

Refresh-Path

# =====================================================================
#  PASO 2: OpenCode (npm)
# =====================================================================
Write-Host ""
Write-Step "──────────────── PASO 2/9 · OpenCode (npm) ────────────────" "DarkCyan"
if (Get-Command opencode -ErrorAction SilentlyContinue) {
  Write-Ok "OpenCode ya instalado ($(opencode --version 2>&1))."
} else {
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Err2 "npm no esta disponible; no se puede instalar OpenCode."
  } else {
    Write-Warn2 "Instalando OpenCode globalmente (opencode-ai)..."
    $out = (npm install -g opencode-ai 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0) { Write-Ok "OpenCode instalado." } else { Write-Err2 "Fallo npm install:"; Write-Host $out }
    Refresh-Path
  }
}

# =====================================================================
#  PASO 3: Configuracion de OpenCode
# =====================================================================
Write-Host ""
Write-Step "──────────────── PASO 3/9 · Configuracion de OpenCode ────────────────" "DarkCyan"
if (-not (Test-Path -LiteralPath $ConfigSrc)) { throw "No se encuentra $ConfigSrc" }
New-Item -ItemType Directory -Path $TargetConfig -Force | Out-Null

# Ficheros de texto (con sustitucion de rutas) y binarios
$textFiles = @(
  "opencode.jsonc", "opencode-local.json", "opencode-local-min.json", "tui.json", "AGENTS.md",
  "README.md", "package.json", "prompts\read-agents.txt"
)
foreach ($rel in $textFiles) {
  $s = Join-Path $ConfigSrc $rel
  if (Test-Path -LiteralPath $s) {
    Copy-TextWithPaths -SrcFile $s -DstFile (Join-Path $TargetConfig $rel)
    Write-Ok "Config: $rel"
  }
}
$binFiles = @("lmstudio-proxy.py", "start-lmstudio.ps1")
foreach ($rel in $binFiles) {
  $s = Join-Path $ConfigSrc $rel
  if (Test-Path -LiteralPath $s) {
    Copy-Binary -SrcFile $s -DstFile (Join-Path $TargetConfig $rel)
    Write-Ok "Script: $rel"
  }
}
# Carpetas completas (voz): scripts de voz y plugin de OpenCode
foreach ($rel in @("voice", "opencode-voice-modified")) {
  $s = Join-Path $ConfigSrc $rel
  if (Test-Path -LiteralPath $s) {
    Copy-Item -LiteralPath $s -Destination (Join-Path $TargetConfig $rel) -Recurse -Force
    Write-Ok "Carpeta: $rel"
  }
}
# Carpeta scripts (utilidades: timeline, hardware, nvidia, sync, backup, setup-voz, ocv-status)
$scriptsSrc = Join-Path $SourceDir "scripts"
$scriptsDst = Join-Path $TargetConfig "scripts"
if (Test-Path -LiteralPath $scriptsSrc) {
  New-Item -ItemType Directory -Path $scriptsDst -Force | Out-Null
  Copy-Item -Path (Join-Path $scriptsSrc "*.ps1") -Destination $scriptsDst -Force
  Write-Ok "Carpeta: scripts (utilidades .ps1)"
}
# data\memory
$memDir = Join-Path $TargetConfig "data\memory"
New-Item -ItemType Directory -Path $memDir -Force | Out-Null

# =====================================================================
#  PASO 4: Perfil de PowerShell
# =====================================================================
Write-Host ""
Write-Step "──────────────── PASO 4/9 · Perfil de PowerShell ────────────────" "DarkCyan"
$docs = [Environment]::GetFolderPath("MyDocuments")
$profilePaths = @(
  (Join-Path $docs "WindowsPowerShell\Microsoft.PowerShell_profile.ps1")
)
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
  $profilePaths += (Join-Path $docs "PowerShell\Microsoft.PowerShell_profile.ps1")
}
$perfilFile = Join-Path $PerfilSrc "Microsoft.PowerShell_profile.ps1"
foreach ($pp in $profilePaths) {
  if (Test-Path -LiteralPath $perfilFile) {
    Copy-TextWithPaths -SrcFile $perfilFile -DstFile $pp
    Write-Ok "Perfil: $pp"
  }
}

# =====================================================================
#  PASO 4b: Lanzadores .cmd (funcionan fuera de PowerShell: cmd/Terminal)
# =====================================================================
Write-Host ""
Write-Step "──────────────── PASO 4b · Lanzadores .cmd ────────────────" "DarkCyan"
$binSrc = Join-Path $SourceDir "bin"
$binDst = Join-Path $TargetProfile ".local\bin"
if (Test-Path -LiteralPath $binSrc) {
  New-Item -ItemType Directory -Path $binDst -Force | Out-Null
  Copy-Item -Path (Join-Path $binSrc "*.cmd") -Destination $binDst -Force
  Write-Ok "Lanzadores .cmd copiados a $binDst"
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($userPath -notlike "*$binDst*") {
    [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ";" + $binDst), "User")
    Write-Ok "PATH de usuario actualizado (+$binDst)"
  } else {
    Write-Ok "PATH de usuario ya contenia $binDst"
  }
} else {
  Write-Warn2 "No se encontro la carpeta bin\ con lanzadores .cmd"
}

# =====================================================================
#  PASO 5: Politica de ejecucion
# =====================================================================
Write-Host ""
Write-Step "──────────────── PASO 5/9 · Politica de ejecucion ────────────────" "DarkCyan"
$cur = Get-ExecutionPolicy -Scope CurrentUser
if ($cur -in @("Restricted", "Undefined", "AllSigned")) {
  try {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Write-Ok "Politica de ejecucion (CurrentUser) fijada a RemoteSigned."
  } catch {
    Write-Warn2 "No se pudo fijar la politica de ejecucion: $_"
  }
} else {
  Write-Ok "Politica de ejecucion ya adecuada ($cur)."
}

# =====================================================================
#  PASO 6: Modelo en LM Studio
# =====================================================================
Write-Host ""
Write-Step "──────────────── PASO 6/9 · Modelo en LM Studio ────────────────" "DarkCyan"
if ($SkipModel) {
  Write-Warn2 "Omitido por -SkipModel."
} else {
  $lmsModels = Join-Path $TargetProfile ".lmstudio\models"
  $modelFile = Split-Path -Leaf $ModelSource
  $dstDir = Join-Path $lmsModels "Qwen\Qwen3.8-9B"
  $dstFile = Join-Path $dstDir $modelFile

  if (Test-Path -LiteralPath $dstFile) {
    Write-Ok "Modelo ya presente en LM Studio: $dstFile"
  } elseif (-not (Test-Path -LiteralPath $ModelSource)) {
    Write-Warn2 "No se encuentra el modelo de origen: $ModelSource"
    Write-Warn2 "Coloca el .gguf ahi o pasa -ModelSource <ruta>. Se omite este paso."
  } else {
    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    # Intentar enlace duro (mismo volumen, sin duplicar espacio); si no, copiar.
    $linked = $false
    try {
      New-Item -ItemType HardLink -Path $dstFile -Target $ModelSource -ErrorAction Stop | Out-Null
      $linked = $true
      Write-Ok "Modelo enlazado (hard link): $dstFile"
    } catch {
      Write-Warn2 "Enlace duro no posible; copiando el modelo (7 GB, puede tardar)..."
      Copy-Item -LiteralPath $ModelSource -Destination $dstFile -Force
      Write-Ok "Modelo copiado: $dstFile"
    }
  }
}

# =====================================================================
#  PASO 6b: Stack de voz (STT/TTS en GPU) - opcional con -WithVoice
# =====================================================================
if ($WithVoice) {
  Write-Host ""
  Write-Step "──────────────── PASO 6b · Voz (STT/TTS GPU) ────────────────" "DarkCyan"
  $setupVoz = Join-Path $SourceDir "scripts\setup-voz.ps1"
  if (Test-Path -LiteralPath $setupVoz) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setupVoz
  } else {
    Write-Warn2 "No se encontro scripts\setup-voz.ps1"
  }
}

# =====================================================================
#  PASO 7: Primer arranque de LM Studio (bootstrap del CLI lms)
# =====================================================================
Write-Host ""
Write-Step "──────────────── PASO 7/9 · Arranque de LM Studio ────────────────" "DarkCyan"
if (-not (Resolve-Lms)) {
  Write-Warn2 "No se encuentra el CLI 'lms'. Se abre LM Studio para que lo instale..."
  $lmExe = Get-ChildItem -Path @(
      (Join-Path $env:LOCALAPPDATA "Programs\LM Studio\LM Studio.exe"),
      (Join-Path ${env:ProgramFiles} "LM Studio\LM Studio.exe")
    ) -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($lmExe) {
    Start-Process -FilePath $lmExe.FullName
    Write-Warn2 "Esperando a que LM Studio genere el CLI lms (hasta 60 s)..."
    for ($i = 0; $i -lt 30; $i++) {
      Start-Sleep -Seconds 2
      if (Resolve-Lms) { break }
    }
  }
}

$lms = Resolve-Lms
if ($lms) {
  Write-Ok "CLI lms encontrado: $lms"
  $startScript = Join-Path $TargetConfig "start-lmstudio.ps1"
  if (Test-Path -LiteralPath $startScript) {
    Write-Warn2 "Arrancando servidor + modelo + proxy..."
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $startScript -Model $ModelKey -ContextLength $ContextLength -ProxyPort $ProxyPort
  }
} else {
  Write-Err2 "LM Studio no esta operativo. Abrelo una vez manualmente y vuelve a ejecutar el instalador."
}

# =====================================================================
#  PASO 8: Tareas programadas (opcional)
# =====================================================================
Write-Host ""
Write-Step "──────────────── PASO 8/9 · Tareas programadas ────────────────" "DarkCyan"
if ($WithTasks) {
  $backupScript = Join-Path $SourceDir "scripts\backup-opencode.ps1"
  if (Test-Path -LiteralPath $backupScript) {
    try {
      $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$backupScript`""
      $trigger = New-ScheduledTaskTrigger -Daily -At 20:00
      Register-ScheduledTask -TaskName "OpenCode-Backup" -Action $action -Trigger $trigger -Force | Out-Null
      Write-Ok "Tarea programada 'OpenCode-Backup' creada (diaria 20:00)."
    } catch { Write-Warn2 "No se pudo crear la tarea de backup: $_" }
  } else {
    Write-Warn2 "No hay backup-opencode.ps1; se omite la tarea."
  }
  $nvidiaScript = Join-Path $SourceDir "scripts\check-nvidia-whitelist.ps1"
  if (Test-Path -LiteralPath $nvidiaScript) {
    try {
      $action2 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$nvidiaScript`""
      $trigger2 = New-ScheduledTaskTrigger -Weekly -WeeksInterval 2 -DaysOfWeek Monday -At 10:00
      Register-ScheduledTask -TaskName "OpenCode-Nvidia-Whitelist" -Action $action2 -Trigger $trigger2 -Force | Out-Null
      Write-Ok "Tarea programada 'OpenCode-Nvidia-Whitelist' creada (quincenal, lunes 10:00)."
    } catch { Write-Warn2 "No se pudo crear la tarea NVIDIA: $_" }
  }
} else {
  Write-Warn2 "Omitido (usa -WithTasks para crearlas)."
}

# =====================================================================
#  PASO 9: Verificacion final
# =====================================================================
Write-Host ""
Write-Step "──────────────── PASO 9/9 · Verificacion ────────────────" "DarkCyan"

function Test-Url($url) {
  try { $r = Invoke-WebRequest -Uri $url -TimeoutSec 3 -UseBasicParsing; return ($r.StatusCode -eq 200) }
  catch { return $false }
}

$checks = [ordered]@{}
$checks["Node.js"]      = [bool](Get-Command node -ErrorAction SilentlyContinue)
$checks["npm"]          = [bool](Get-Command npm -ErrorAction SilentlyContinue)
$checks["Python"]       = [bool](Resolve-Python)
$checks["OpenCode"]     = [bool](Get-Command opencode -ErrorAction SilentlyContinue)
$checks["CLI lms"]      = [bool](Resolve-Lms)
$checks["Config local"] = (Test-Path -LiteralPath (Join-Path $TargetConfig "opencode-local.json"))
$checks["Proxy (4001)"] = (Test-Url "http://127.0.0.1:$ProxyPort/health")
$checks["LM Studio (1234)"] = (Test-Url "http://127.0.0.1:1234/v1/models")
$checks["Perfil PS"]    = (Test-Path -LiteralPath $profilePaths[0])

Write-Host ""
Write-Host "  Componente            Estado" -ForegroundColor White
Write-Host "  --------------------  ------"
foreach ($k in $checks.Keys) {
  $estado = if ($checks[$k]) { "OK" } else { "FALTA" }
  $color  = if ($checks[$k]) { "Green" } else { "Yellow" }
  Write-Host ("  {0,-20}  {1}" -f $k, $estado) -ForegroundColor $color
}

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor DarkCyan
Write-Ok "Instalacion finalizada. Log: $script:LogFile"
Write-Host ""
Write-Host "  Para usarlo, abre una NUEVA ventana de PowerShell y escribe:" -ForegroundColor White
Write-Host "    ocv          -> arranca LM Studio + proxy y abre OpenCode local" -ForegroundColor Gray
Write-Host "    ocv-cloud    -> OpenCode en modo cloud (sin LM Studio)" -ForegroundColor Gray
Write-Host "    ocv-status   -> estado de LM Studio, modelo y proxy" -ForegroundColor Gray
Write-Host "=====================================================================" -ForegroundColor DarkCyan
Write-Host ""

Write-Log "Instalacion finalizada."
if (-not $Unattended) {
  Write-Host "Pulsa ENTER para salir..." -ForegroundColor DarkGray
  Read-Host | Out-Null
}
