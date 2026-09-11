<#
.SYNOPSIS
    Sincroniza la configuracion activa de OpenCode (Windows) con la copia
    de respaldo en D:\Linux\Config\opencode-win (PowerShell 5.1).
    Port de ~/Config/opencode/sync-opencode.sh (Linux).

.DESCRIPTION
    Copia los archivos de configuracion activos (C:\Users\evo01\.config\opencode)
    a la carpeta de respaldo. NO borra nada del destino: solo copia y sobrescribe
    (Copy-Item -Force). Tambien copia el perfil de PowerShell si existe.

    Archivos que se copian:
      - opencode.jsonc, opencode-local.json, tui.json, AGENTS.md, package.json
      - prompts\ (carpeta completa)
      - lmstudio-proxy.py, start-lmstudio.ps1
      - data\memory\memory.jsonl (solo si existe)
      - perfil PowerShell (Microsoft.PowerShell_profile.ps1)

.PARAMETER Ayuda
    Muestra esta ayuda.

.EXAMPLE
    .\sync-opencode.ps1
#>
[CmdletBinding()]
param(
    [switch]$Ayuda
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ($Ayuda) { Get-Help $MyInvocation.MyCommand.Path -Detailed; exit 0 }

$ORIGEN = "$env:USERPROFILE\.config\opencode"
$DESTINO = 'D:\Linux\Config\opencode-win\config'
$DESTINO_MEMORY = 'D:\Linux\Config\opencode-win\config\data\memory'
$PERFIL_ORIGEN = "$env:USERPROFILE\OneDrive\Documentos\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$PERFIL_DESTINO = 'D:\Linux\Config\opencode-win\perfil'

Write-Output '== 🔄 Sincronizando configuracion de OpenCode =='
Write-Output ''

if (-not (Test-Path $ORIGEN)) {
    Write-Error "No existe la carpeta de configuracion activa: $ORIGEN"
    exit 1
}

# Crear carpetas de destino si no existen (nunca borrar nada)
foreach ($dir in @($DESTINO, (Join-Path $DESTINO 'prompts'), $DESTINO_MEMORY, $PERFIL_DESTINO)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$copiados = @()

function Copy-Fichero {
    param([string]$Src, [string]$Dst)
    if (-not (Test-Path $Src)) {
        Write-Output "   ⏭️  Omitido (no existe): $Src"
        return
    }
    $dir = Split-Path $Dst -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Copy-Item -LiteralPath $Src -Destination $Dst -Force
    $script:copiados += $Src
    Write-Output "   ✅ $([System.IO.Path]::GetFileName($Src))"
}

Write-Output '📦 Configuracion principal:'
Copy-Fichero (Join-Path $ORIGEN 'opencode.jsonc')   (Join-Path $DESTINO 'opencode.jsonc')
Copy-Fichero (Join-Path $ORIGEN 'opencode-local.json') (Join-Path $DESTINO 'opencode-local.json')
Copy-Fichero (Join-Path $ORIGEN 'opencode-local-min.json') (Join-Path $DESTINO 'opencode-local-min.json')
Copy-Fichero (Join-Path $ORIGEN 'tui.json')          (Join-Path $DESTINO 'tui.json')
Copy-Fichero (Join-Path $ORIGEN 'AGENTS.md')         (Join-Path $DESTINO 'AGENTS.md')
Copy-Fichero (Join-Path $ORIGEN 'README.md')         (Join-Path $DESTINO 'README.md')
Copy-Fichero (Join-Path $ORIGEN 'package.json')      (Join-Path $DESTINO 'package.json')
Copy-Fichero (Join-Path $ORIGEN 'lmstudio-proxy.py') (Join-Path $DESTINO 'lmstudio-proxy.py')
Copy-Fichero (Join-Path $ORIGEN 'start-lmstudio.ps1') (Join-Path $DESTINO 'start-lmstudio.ps1')

Write-Output ''
Write-Output '📂 Carpeta prompts:'
$srcPrompts = Join-Path $ORIGEN 'prompts'
if (Test-Path $srcPrompts) {
    Get-ChildItem -LiteralPath $srcPrompts -File -Recurse | ForEach-Object {
        $rel = $_.FullName.Substring($srcPrompts.Length).TrimStart('\', '/')
        $dst = Join-Path (Join-Path $DESTINO 'prompts') $rel
        Copy-Fichero $_.FullName $dst
    }
} else {
    Write-Output '   ⏭️  Omitido (no existe): prompts'
}

Write-Output ''
Write-Output '🎤 Voz (scripts + plugin, excluyendo venv):'
foreach ($d in @('voice', 'opencode-voice-modified')) {
  $s = Join-Path $ORIGEN $d
  if (Test-Path $s) {
    Get-ChildItem -LiteralPath $s -File -Recurse | Where-Object { $_.FullName -notmatch '\\venv\\' } | ForEach-Object {
      $rel = $_.FullName.Substring($s.Length).TrimStart('\', '/')
      Copy-Fichero $_.FullName (Join-Path (Join-Path $DESTINO $d) $rel)
    }
  } else {
    Write-Output "   ⏭️  Omitido (no existe): $d"
  }
}

Write-Output ''
Write-Output '🖥️  Lanzadores .cmd:'
$binSrc = Join-Path $env:USERPROFILE '.local\bin'
$binDst = 'D:\Linux\Config\opencode-win\bin'
if (Test-Path $binSrc) {
  New-Item -ItemType Directory -Path $binDst -Force | Out-Null
  Get-ChildItem -LiteralPath $binSrc -Filter '*.cmd' -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Fichero $_.FullName (Join-Path $binDst $_.Name)
  }
} else {
  Write-Output '   ⏭️  Omitido (no existe): .local\bin'
}

Write-Output ''
Write-Output '🧠 Memoria (grafo):'
Copy-Fichero (Join-Path $ORIGEN 'data\memory\memory.jsonl') (Join-Path $DESTINO_MEMORY 'memory.jsonl')

Write-Output ''
Write-Output '🐚 Perfil de PowerShell:'
Copy-Fichero $PERFIL_ORIGEN (Join-Path $PERFIL_DESTINO 'Microsoft.PowerShell_profile.ps1')

Write-Output ''
Write-Output "== 📋 Resumen: $($copiados.Count) archivos copiados a $DESTINO =="
if ($copiados.Count -eq 0) {
    Write-Output '   (no se copio nada)'
}