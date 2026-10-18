param(
    [int]$Puerto = 9224,
    [switch]$Visible
)
# Lanzador de Mensajes de Google para el Hermes de Windows, sobre el PERFIL COMPARTIDO
# del dual boot (<letra>:\HermesSync\messages-perfil), el mismo que usa Linux.
# Es un perfil propio de Hermes, vacio: no usa nada del perfil de Chrome de Antonio.
# NORMA: se abre SIEMPRE OCULTO (sin ventana). Antonio usa su propio Chrome para la web
# de Mensajes; este perfil solo se levanta cuando Hermes necesita leer algo, y se cierra
# al terminar. La ventana visible es solo para vincular o desvincular con un QR.
#
# OJO: Google permite UN SOLO ordenador activo a la vez. Si Antonio abre
# messages.google.com/web en su Chrome, esta sesion se desconecta (y al reves).
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File messages-hermes.ps1            # oculto (para leer por CDP)
#   powershell -ExecutionPolicy Bypass -File messages-hermes.ps1 -Visible   # con ventana (solo para el QR)
#   powershell -ExecutionPolicy Bypass -File messages-hermes.ps1 -Puerto 9225
# Con el navegador abierto, la depuracion queda en http://127.0.0.1:<puerto> (solo local).

$ErrorActionPreference = 'Stop'

$comun = $null
foreach ($l in [char[]]'DEFGHIJKLMNOPQRSTUVWXYZ') {
    if (Test-Path -LiteralPath "${l}:\HermesSync\.hermes-sync") { $comun = "${l}:\HermesSync"; break }
}
if (-not $comun) { Write-Output 'ERROR: no encuentro la carpeta compartida (marcador HermesSync\.hermes-sync)'; exit 1 }

$perfil = Join-Path $comun 'messages-perfil'
if (-not (Test-Path -LiteralPath (Join-Path $perfil 'Default'))) {
    Write-Output ('ERROR: no encuentro el perfil compartido de Mensajes en ' + $perfil)
    exit 1
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

Start-Process -FilePath $chrome -ArgumentList $argumentos
exit 0
