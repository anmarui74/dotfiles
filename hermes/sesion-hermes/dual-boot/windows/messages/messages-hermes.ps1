param(
    [int]$Puerto = 9224,
    [switch]$Visible
)
# Lanzador de Mensajes de Google para el Hermes de Windows, sobre un PERFIL PROPIO DE WINDOWS
# (%LOCALAPPDATA%\hermes\messages-perfil-win). No usa nada del perfil de Chrome de Antonio.
#
# POR QUE NO SE COMPARTE CON LINUX (comprobado el 13/10/2026): la sesion de Mensajes NO es
# portable entre sistemas. El perfil vinculado en Linux funciona alli, pero en Windows pide
# iniciar sesion (messages.google.com/web/welcome), incluso con una copia integra en otro disco
# sano; Google ata el emparejamiento al navegador/sistema y Chrome cifra parte de los datos con
# la clave del SO (os_crypt). WhatsApp Web SI es portable.
# Por eso CADA SISTEMA TIENE SU PROPIO PERFIL: Linux usa ~/.local/share/hermes/messages-perfil y
# Windows este. El estado del envio semanal es compartido, asi que no se duplican mensajes.
#
# NORMA: se abre SIEMPRE OCULTO (sin ventana). Antonio usa su propio Chrome para la web de
# Mensajes; este perfil solo se levanta cuando Hermes necesita leer o enviar, y se cierra al
# terminar. La ventana visible es solo para vincular o desvincular.
#
# OJO: Google permite UN SOLO ordenador activo a la vez. Si Antonio abre
# messages.google.com/web en su Chrome, esta sesion se desconecta (y al reves).
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File messages-hermes.ps1            # oculto (leer/enviar)
#   powershell -ExecutionPolicy Bypass -File messages-hermes.ps1 -Visible   # con ventana (vincular)
#   powershell -ExecutionPolicy Bypass -File messages-hermes.ps1 -Puerto 9225
# Con el navegador abierto, la depuracion queda en http://127.0.0.1:<puerto> (solo local).

$ErrorActionPreference = 'Stop'

$perfil = Join-Path $env:LOCALAPPDATA 'hermes\messages-perfil-win'
New-Item -ItemType Directory -Force -Path $perfil | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $perfil 'Default'))) {
    Write-Output ('AVISO: el perfil de Mensajes de Windows aun no esta vinculado (' + $perfil + ')')
    Write-Output 'Para vincularlo: abre este lanzador con -Visible y empareja desde el movil.'
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
    # oculto: ventana virtual grande, para que la lista de conversaciones cargue entera
    $argumentos += '--headless=new'
    $argumentos += '--window-size=1400,1600'
}
$argumentos += 'https://messages.google.com/web'

Write-Output ('Chrome: ' + $chrome)
Write-Output ('Perfil: ' + $perfil)
Write-Output ('CDP:    http://127.0.0.1:' + $Puerto)
if ($Visible) { Write-Output 'Modo:   ventana visible (para vincular con el QR)' } else { Write-Output 'Modo:   oculto (--headless=new)' }

# Limpieza de restos de bloqueo: si un Chrome de este perfil queda colgado (p. ej. por un
# problema de disco), deja ficheros Singleton* que impiden abrir el puerto de depuracion.
# Se limpian solo si no hay procesos vivos de este perfil.
$enUso = @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandLine -like "*$perfil*" }).Count
if ($enUso -eq 0) {
    Get-ChildItem -Path $perfil -Filter 'Singleton*' -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

Start-Process -FilePath $chrome -ArgumentList $argumentos
exit 0
