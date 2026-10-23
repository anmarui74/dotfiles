param(
    [int]$Puerto = 9222,
    [switch]$Visible
)
# Lanzador de WhatsApp Web para el Hermes de Windows, sobre un PERFIL PROPIO DE WINDOWS
# (%LOCALAPPDATA%\hermes\whatsapp-perfil-win). No usa nada del perfil de Chrome de Antonio.
#
# POR QUE ES LOCAL (13/10/2026): Antonio pidio que cada sistema tenga su copia y no depender del
# disco de intercambio. Es la MISMA sesion de WhatsApp (la copia vino del disco compartido), asi
# que NO hay que volver a escanear el QR. WhatsApp Web SI es portable entre sistemas (a diferencia
# de Mensajes de Google), pero ahora cada uno trabaja sobre su copia local.
#
# NORMA: se abre SIEMPRE OCULTO (sin ventana). Antonio usa su propio WhatsApp Web en su Chrome;
# este perfil solo se levanta cuando Hermes necesita leer o enviar, y se cierra al terminar.
# La ventana visible es solo para vincular o desvincular con un QR.
# Uso:
#   powershell -ExecutionPolicy Bypass -File whatsapp-hermes.ps1              # oculto (leer/enviar)
#   powershell -ExecutionPolicy Bypass -File whatsapp-hermes.ps1 -Visible     # con ventana (vincular)
#   powershell -ExecutionPolicy Bypass -File whatsapp-hermes.ps1 -Puerto 9223
# Con el navegador abierto, la depuracion queda en http://127.0.0.1:<puerto> (solo local).

$ErrorActionPreference = 'Stop'

$perfil = Join-Path $env:LOCALAPPDATA 'hermes\whatsapp-perfil-win'
New-Item -ItemType Directory -Force -Path $perfil | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $perfil 'Default'))) {
    Write-Output ('AVISO: el perfil de WhatsApp de Windows aun no existe (' + $perfil + ')')
    Write-Output 'Para crearlo: copia la sesion, o abre este lanzador con -Visible y escanea el QR.'
}

$candidatos = @()
if ($env:ProgramFiles) { $candidatos += (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe') }
if (${env:ProgramFiles(x86)}) { $candidatos += (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe') }
if ($env:LOCALAPPDATA) {
    $candidatos += (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
    $candidatos += (Join-Path $env:LOCALAPPDATA 'Chromium\Application\chrome.exe')
}

$chrome = $candidatos | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $chrome) { Write-Output 'ERROR: no encuentro chrome.exe'; exit 1 }

$argumentos = @(
    ('--user-data-dir=' + $perfil),
    '--profile-directory=Default',
    ('--remote-debugging-port=' + $Puerto),
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-sync',
    '--no-service-autorun'
)
if (-not $Visible) {
    # oculto: ventana virtual grande, para que la lista de chats cargue entera
    $argumentos += '--headless=new'
    $argumentos += '--window-size=1400,1600'
}
$argumentos += 'https://web.whatsapp.com'

Write-Output ('Chrome: ' + $chrome)
Write-Output ('Perfil: ' + $perfil)
Write-Output ('CDP:    http://127.0.0.1:' + $Puerto)
if ($Visible) { Write-Output 'Modo:   ventana visible (para escanear el QR)' } else { Write-Output 'Modo:   oculto (--headless=new)' }

# Limpieza de restos de bloqueo: si un Chrome de este perfil queda colgado, deja ficheros
# Singleton* que impiden abrir el puerto de depuracion. Se limpian (solo si no hay procesos
# vivos de este perfil) justo antes de arrancar.
$enUso = @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandLine -like "*$perfil*" }).Count
if ($enUso -eq 0) {
    Get-ChildItem -Path $perfil -Filter 'Singleton*' -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

Start-Process -FilePath $chrome -ArgumentList $argumentos
exit 0
