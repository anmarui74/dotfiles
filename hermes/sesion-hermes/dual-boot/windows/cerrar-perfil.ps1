param(
    [Parameter(Mandatory=$true)][string]$Perfil
)
# Cierra SOLO el Chrome del perfil dedicado indicado (nunca el Chrome de Antonio).
# Uso: powershell -ExecutionPolicy Bypass -File cerrar-perfil.ps1 -Perfil whatsapp-perfil
$ErrorActionPreference = 'Stop'
$procs = Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
         Where-Object { $_.CommandLine -like "*$Perfil*" }
if (-not $procs) { Write-Output ("No hay procesos de " + $Perfil); exit 0 }
foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Output ("Cerrados " + @($procs).Count + " procesos de " + $Perfil)
