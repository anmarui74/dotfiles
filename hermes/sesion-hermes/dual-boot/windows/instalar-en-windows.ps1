<#
  instalar-en-windows.ps1 — Prepara Hermes en Windows para compartir estado con
  el Hermes de Linux (dual boot) usando la carpeta HermesSync del disco SEAGATE.

  Qué hace:
    1. Comprueba que Hermes está instalado (si no, te dice el comando exacto).
    2. Aplica la semilla que dejó Linux (config.yaml, .env, auth.json, SOUL.md),
       sólo la primera vez, y adapta la configuración de voz a Windows.
    3. Registra las tareas programadas que importan/publican el estado.
    4. Hace la primera importación del estado de Linux.

  Uso (PowerShell normal, SIN administrador):
    powershell -ExecutionPolicy Bypass -File E:\HermesSync\windows\instalar-en-windows.ps1
    ... -SaltarSemilla   (si quieres configurar Hermes a mano)
    ... -SoloTareas      (sólo registra las tareas programadas)
#>
[CmdletBinding()]
param(
    [switch]$SaltarSemilla,
    [switch]$SoloTareas,
    [string]$Comun = ''
)

function Join-Ruta {
    # Rutas escritas siempre con '/' y convertidas al separador nativo del sistema
    param([string]$Base, [string]$Hijo)
    return (Join-Path $Base ($Hijo -replace '/', [IO.Path]::DirectorySeparatorChar))
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME }
              elseif ($env:LOCALAPPDATA) { Join-Ruta $env:LOCALAPPDATA 'hermes' }
              else { throw 'No encuentro el directorio de datos de Hermes: define HERMES_HOME.' }
$Motor = Join-Ruta $ScriptDir 'hermes-dual-sync.ps1'
$MarcasSemilla = Join-Ruta $HermesHome '.dual-sync/semilla-aplicada.json'

function Paso($texto) { Write-Host "`n> $texto" -ForegroundColor Cyan }

if ($Comun -eq '') { $Comun = Split-Path -Parent $ScriptDir }
Write-Host "Carpeta compartida: $Comun"
Write-Host "Datos de Hermes   : $HermesHome"

# ------------------------------------------------------------------ 1. Hermes
Paso 'Comprobando la instalación de Hermes'
$hermes = Get-Command hermes -ErrorAction SilentlyContinue
if (-not $hermes) {
    Write-Host "Hermes no está en el PATH. Si aún no lo has instalado, abre PowerShell y ejecuta:" -ForegroundColor Yellow
    Write-Host '   iex (irm https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1)'
    Write-Host 'Después vuelve a lanzar este instalador (en una terminal nueva).'
    exit 1
}
Write-Host "  hermes: $($hermes.Source)"

# ------------------------------------------------------------------ 2. Semilla
if (-not $SaltarSemilla) {
    Paso 'Aplicando la semilla de configuración (sólo la primera vez)'
    if (Test-Path $MarcasSemilla) {
        Write-Host '  Ya se aplicó anteriormente; no se toca la configuración.'
    } elseif (-not (Test-Path (Join-Ruta $Comun 'semilla/config.yaml'))) {
        Write-Host '  No hay semilla en la carpeta compartida; se omite.' -ForegroundColor Yellow
    } else {
        if (Test-Path (Join-Ruta $HermesHome 'config.yaml')) {
            $respaldo = Join-Ruta $HermesHome ("config.yaml.antes-de-semilla-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Copy-Item (Join-Ruta $HermesHome 'config.yaml') $respaldo -Force
            Write-Host "  Configuración previa guardada en $respaldo"
        }
        foreach ($f in @('SOUL.md', 'config.yaml', '.env', 'auth.json')) {
            $origen = Join-Ruta $Comun "semilla/$f"
            if (Test-Path $origen) { Copy-Item $origen (Join-Ruta $HermesHome $f) -Force; Write-Host "  copiado $f" }
        }
        # La voz de Linux (Kokoro/whisper.cpp locales por comando) no existe en Windows:
        # se deja TTS con la voz de sistema y STT con el motor local de Windows.
        foreach ($orden in @(
            @('config', 'set', 'tts.provider', 'edge'),
            @('config', 'unset', 'tts.providers.kokoro'),
            @('config', 'unset', 'stt.providers.whispercpp'),
            @('config', 'set', 'stt.provider', 'local'),
            # el hook de publicación de Linux apunta a un script que aquí no existe:
            # en Windows la publicación la hace la tarea programada HermesSync-Publicar
            @('config', 'unset', 'hooks.on_session_end')
        )) {
            try { & hermes @orden *> $null } catch { Write-Host "  aviso: no se pudo aplicar 'hermes $($orden -join ' ')'" -ForegroundColor Yellow }
        }
        Write-Host '  Voz adaptada a Windows (TTS del sistema; STT local de Windows).'
        New-Item -ItemType Directory -Force -Path (Split-Path $MarcasSemilla) | Out-Null
        @{ aplicada = (Get-Date).ToString('s'); origen = $Comun } | ConvertTo-Json | Set-Content $MarcasSemilla -Encoding UTF8
        Write-Host '  Semilla aplicada. En el disco compartido puedes borrar la carpeta "semilla" si quieres.'
    }
}

if ($SoloTareas) { }

# ------------------------------------------------------------------ 3. Tareas
Paso 'Registrando las tareas programadas de sincronización'
$accionPublicar = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -Accion export -SoloSiCambia -Quiet' -f $Motor)
$accionImportar = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument ('-NoProfile -ExecutionPolicy Bypass -File "{0}" -Accion import -Quiet' -f $Motor)

$disparadorInicio = New-ScheduledTaskTrigger -AtLogOn
$disparadorInicio.Delay = 'PT20S'
$disparadorCada = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$ajustes = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

Register-ScheduledTask -TaskName 'HermesSync-Importar' -Action $accionImportar -Trigger $disparadorInicio `
    -Settings $ajustes -Description 'Importa el estado de Hermes publicado por Linux (dual boot)' -Force | Out-Null
Register-ScheduledTask -TaskName 'HermesSync-Publicar' -Action $accionPublicar -Trigger $disparadorCada `
    -Settings $ajustes -Description 'Publica el estado de Hermes para Linux (dual boot)' -Force | Out-Null
Write-Host '  Tareas "HermesSync-Importar" (al iniciar sesión) y "HermesSync-Publicar" (cada 5 min) registradas.'

# ------------------------------------------------------------------ 4. Primera importación
Paso 'Primera importación del estado de Linux'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Motor -Accion auto

Paso 'Listo'
Write-Host '  Comprueba el estado cuando quieras con:'
Write-Host ('  powershell -ExecutionPolicy Bypass -File "{0}" -Accion estado' -f $Motor)
