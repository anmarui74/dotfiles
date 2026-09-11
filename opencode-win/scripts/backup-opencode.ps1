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

Write-Ok "Backup completado."