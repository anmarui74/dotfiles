<#
.SYNOPSIS
  Backup del grafo de memoria de OpenCode + sincronizacion de la config activa.

.DESCRIPTION
  1. Copia el grafo de memoria (memory.jsonl) a data\memory\mcp-memory-backup-<fecha>.jsonl
     en D:\Linux\Config\opencode-win (retencion de 30 dias).
  2. Ejecuta sync-opencode.ps1 para sincronizar la config activa con el backup.
  3. Es idempotente y seguro: no borra nada salvo backups antiguos (retencion).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File backup-opencode.ps1
#>
[CmdletBinding()]
param(
  [string]$BackupRoot = "D:\Linux\Config\opencode-win",
  [int]$RetentionDays = 30
)

$ErrorActionPreference = "Continue"

$MemoryFile   = Join-Path $env:USERPROFILE ".config\opencode\data\memory\memory.jsonl"
$MemoryBackup = Join-Path $BackupRoot "data\memory"
$SyncScript   = Join-Path $BackupRoot "scripts\sync-opencode.ps1"
$CheckScript  = Join-Path $BackupRoot "scripts\check-setup-completo.ps1"

function Write-Step($msg, $color = "Cyan") { Write-Host $msg -ForegroundColor $color }
function Write-Ok($msg)  { Write-Host "🟢 $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "🟡 $msg" -ForegroundColor Yellow }

# --- 0) Verificacion previa (check-setup-completo.ps1) --------------------
if (Test-Path -LiteralPath $CheckScript) {
  Write-Step "Verificando el setup antes del backup..."
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $CheckScript -BackupRoot $BackupRoot
  if ($LASTEXITCODE -ne 0) {
    Write-Warn2 "check-setup-completo.ps1 devolvio errores -> BACKUP ABORTADO."
    exit 1
  }
} else {
  Write-Warn2 "No se encontro check-setup-completo.ps1 (se continua sin verificar)."
}

# --- 1) Grafo de memoria --------------------------------------------------
New-Item -ItemType Directory -Path $MemoryBackup -Force | Out-Null

if (Test-Path -LiteralPath $MemoryFile) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $dest  = Join-Path $MemoryBackup ("mcp-memory-backup-{0}.jsonl" -f $stamp)
  Copy-Item -LiteralPath $MemoryFile -Destination $dest -Force
  Write-Ok "Grafo de memoria copiado: $dest"
} else {
  Write-Warn2 "No existe el grafo de memoria en $MemoryFile (aun no se ha usado OpenCode con el MCP memory)."
}

# Retencion
$cutoff = (Get-Date).AddDays(-$RetentionDays)
$old = Get-ChildItem -LiteralPath $MemoryBackup -Filter "mcp-memory-backup-*.jsonl" -ErrorAction SilentlyContinue |
       Where-Object { $_.LastWriteTime -lt $cutoff }
foreach ($f in $old) {
  Remove-Item -LiteralPath $f.FullName -Force
  Write-Warn2 "Backup antiguo eliminado (retencion): $($f.Name)"
}

# --- 2) Sincronizacion de la config ---------------------------------------
if (Test-Path -LiteralPath $SyncScript) {
  Write-Step "Sincronizando config activa con el backup..."
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SyncScript
} else {
  Write-Warn2 "No se encontro sync-opencode.ps1 en $SyncScript"
}

# --- 3) Copia saneada a dotfiles (espejo, sin claves API) ------------------
# Regenera la copia de dotfiles desde cero (espejo), preservando .git y
# .gitignore. Evita la acumulacion de residuos (equivale a rsync --delete).
$DotfilesRoot = "D:\Linux\Documentos\dotfiles\opencode-win"
$BackupConfig = Join-Path $BackupRoot "config"

function Test-BadPath([string]$full) {
  $name = Split-Path $full -Leaf
  if ($name -like '.env*' -or $name -eq 'auth.json' -or
      $name -like 'mcp-memory-backup-*.jsonl' -or $name -like '*.tar.gz' -or
      $name -like '*.bak*' -or $name -like '*.log' -or $name -like '*.pyc') { return $true }
  $parts = $full -split '\\'
  foreach ($d in @('credenciales', 'backups', 'node_modules', '__pycache__', 'venv')) {
    if ($parts -contains $d) { return $true }
  }
  return $false
}

if (Test-Path -LiteralPath $DotfilesRoot) {
  Write-Step "Purgando residuos de dotfiles (espejo)..."
  Get-ChildItem -LiteralPath $DotfilesRoot -Force |
    Where-Object { $_.Name -notin @('.git', '.gitignore') } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
} else {
  New-Item -ItemType Directory -Path $DotfilesRoot -Force | Out-Null
}

# Fuentes gestionadas -> destino (config va PLANO en la raiz de dotfiles)
$sources = [ordered]@{
  ""              = $BackupConfig
  "documentacion" = (Join-Path $BackupRoot "documentacion")
  "bin"           = (Join-Path $BackupRoot "bin")
  "perfil"        = (Join-Path $BackupRoot "perfil")
  "scripts"       = (Join-Path $BackupRoot "scripts")
}
Write-Step "Copiando config saneada a dotfiles (sin claves API)..."
foreach ($sub in $sources.Keys) {
  $src = $sources[$sub]
  if (-not (Test-Path -LiteralPath $src)) { continue }
  $dstBase = if ($sub) { Join-Path $DotfilesRoot $sub } else { $DotfilesRoot }
  Get-ChildItem -LiteralPath $src -Recurse -File | Where-Object { -not (Test-BadPath $_.FullName) } | ForEach-Object {
    $rel = $_.FullName.Substring($src.Length).TrimStart('\')
    $dst = Join-Path $dstBase $rel
    $dir = Split-Path $dst -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
  }
}

# Instalador (no embebe claves; se incluye para poder restaurar desde el repo)
$instSrc = Join-Path $BackupRoot "instalar-opencode-win.ps1"
if (Test-Path -LiteralPath $instSrc) {
  Copy-Item -LiteralPath $instSrc -Destination (Join-Path $DotfilesRoot "instalar-opencode-win.ps1") -Force
}

# Excluir el respaldo historico de documentacion con encoding roto
$moji = Join-Path $DotfilesRoot "documentacion\_mojibake-backup"
if (Test-Path -LiteralPath $moji) { Remove-Item -LiteralPath $moji -Recurse -Force -ErrorAction SilentlyContinue }

Write-Ok "Config saneada copiada a dotfiles en $DotfilesRoot"

# --- 3b) Verificacion: ninguna clave API en dotfiles -----------------------
$secretPatterns = @(
  'nvapi-[A-Za-z0-9_\-]{15,}',
  '(?<![A-Za-z0-9])sk-[A-Za-z0-9]{25,}',
  'AEMET_API_KEY=[A-Za-z0-9]{15,}'
)
$textExt = @('.md', '.json', '.jsonc', '.ps1', '.cmd', '.py', '.txt', '.js', '.tsx', '.ts', '.example', '.gitignore')
$leaks = @()
Get-ChildItem -LiteralPath $DotfilesRoot -Recurse -File -Force | Where-Object {
  $textExt -contains $_.Extension.ToLower() -or $_.Name -eq '.gitignore'
} | ForEach-Object {
  $hits = Select-String -LiteralPath $_.FullName -Pattern $secretPatterns -ErrorAction SilentlyContinue
  if ($hits) { $leaks += $_.FullName }
}
if ($leaks.Count -gt 0) {
  Write-Warn2 "ATENCION: posibles claves API en dotfiles (revisar antes de commitear):"
  $leaks | ForEach-Object { Write-Warn2 "  $_" }
} else {
  Write-Ok "Verificado: sin claves API en dotfiles"
}

Write-Ok "Backup completado."