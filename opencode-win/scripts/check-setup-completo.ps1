<#
.SYNOPSIS
  Verifica la integridad del setup de OpenCode Windows antes de generar el backup.

.DESCRIPTION
  Equivalente Windows del check-setup-completo.sh de Linux. Comprueba:
    1. Sintaxis del instalador (parser de PowerShell)
    2. Estructura del backup completa (config, perfil, scripts, bin, documentacion, data)
    3. Que TODOS los .ps1 parsean sin errores
    4. PSScriptAnalyzer del instalador (sin errores)
    5. Comandos requeridos presentes (winget, npm, node, python, lms)

  Devuelve 0 si todo OK (con o sin avisos) y 1 si hay errores -> el backup debe abortar.

.PARAMETER BackupRoot
  Raiz del backup (por defecto D:\Linux\Config\opencode-win).
#>
[CmdletBinding()]
param(
  [string]$BackupRoot = "D:\Linux\Config\opencode-win"
)

$ErrorActionPreference = "Continue"
$script:errors = @()
$script:warnings = @()

function OK($m)   { Write-Host "  [OK]   $m" -ForegroundColor Green }
function WARN2($m){ Write-Host "  [WARN] $m" -ForegroundColor Yellow; $script:warnings += $m }
function ERR2($m) { Write-Host "  [ERR]  $m" -ForegroundColor Red; $script:errors += $m }

Write-Host "== Verificando el setup de OpenCode (Windows) ==" -ForegroundColor Cyan

# --- 1) Sintaxis del instalador -------------------------------------------
$inst = Join-Path $BackupRoot "instalar-opencode-win.ps1"
if (-not (Test-Path -LiteralPath $inst)) {
  ERR2 "No existe el instalador: $inst"
} else {
  $e = $null
  [System.Management.Automation.Language.Parser]::ParseFile($inst, [ref]$null, [ref]$e) | Out-Null
  if ($e.Count -eq 0) { OK "Sintaxis del instalador" }
  else { ERR2 "Sintaxis del instalador: $($e[0].Message) (L$($e[0].Extent.StartLineNumber))" }
}

# --- 2) Estructura ---------------------------------------------------------
foreach ($d in @("config", "perfil", "scripts", "bin", "documentacion", "data\memory")) {
  if (Test-Path -LiteralPath (Join-Path $BackupRoot $d)) { OK "Carpeta: $d" }
  else { ERR2 "Falta la carpeta: $d" }
}
foreach ($f in @("AGENTS.md", "README.md")) {
  if (Test-Path -LiteralPath (Join-Path $BackupRoot $f)) { OK "Fichero: $f" }
  else { ERR2 "Falta el fichero: $f" }
}

# Ficheros clave de config
foreach ($f in @("opencode.jsonc", "opencode-local.json", "opencode-local-min.json", "tui.json", "AGENTS.md", "lmstudio-proxy.py", "start-lmstudio.ps1")) {
  $p = Join-Path $BackupRoot "config\$f"
  if (Test-Path -LiteralPath $p) { OK "config: $f" } else { ERR2 "Falta en config: $f" }
}

# --- 3) Parseo de todos los .ps1 ------------------------------------------
$ps1 = Get-ChildItem $BackupRoot -Recurse -Filter "*.ps1" -File -ErrorAction SilentlyContinue
foreach ($p in $ps1) {
  $e = $null
  [System.Management.Automation.Language.Parser]::ParseFile($p.FullName, [ref]$null, [ref]$e) | Out-Null
  if ($e.Count -eq 0) { OK "parse OK: $($p.Name)" }
  else { ERR2 "parse ERROR: $($p.Name) -> $($e[0].Message)" }
}

# --- 4) PSScriptAnalyzer del instalador (solo errores) --------------------
if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
  Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue
  $issues = Invoke-ScriptAnalyzer -Path $inst -Severity Error
  if ($issues) { $issues | ForEach-Object { ERR2 "PSScriptAnalyzer: $($_.Message) (L$($_.Line))" } }
  else { OK "PSScriptAnalyzer del instalador (sin errores)" }
} else {
  WARN2 "PSScriptAnalyzer no instalado (se omite)"
}

# --- 5) Comandos requeridos -----------------------------------------------
foreach ($c in @("winget", "npm", "node", "python")) {
  if (Get-Command $c -ErrorAction SilentlyContinue) { OK "comando: $c" } else { ERR2 "falta el comando: $c" }
}
$lms = Join-Path $env:USERPROFILE ".lmstudio\bin\lms.exe"
if (Test-Path -LiteralPath $lms) { OK "lms.exe" } else { ERR2 "falta lms.exe" }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { WARN2 "git no instalado (el instalador lo instala con winget)" }

# --- Resultado -------------------------------------------------------------
Write-Host ""
if ($script:errors.Count -gt 0) {
  Write-Host "RESULTADO: $($script:errors.Count) error(es), $($script:warnings.Count) aviso(s) -> BACKUP ABORTADO" -ForegroundColor Red
  exit 1
}
Write-Host "RESULTADO: OK ($($script:warnings.Count) aviso(s))" -ForegroundColor Green
exit 0
