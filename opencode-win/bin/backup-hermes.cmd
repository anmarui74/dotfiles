@echo off
rem backup-hermes - copia de seguridad de Hermes en Windows (esquema del dual boot).
rem Uso:  backup-hermes                 -> backup en <unidad>:\HermesSync\backups\hermes
rem       backup-hermes saneado         -> solo la copia saneada (sin claves)
rem       backup-hermes estado          -> que hay en la carpeta de backups
rem Log/detalle: salida del propio script.
setlocal
set PS1=%LOCALAPPDATA%\hermes\backup\backup-hermes.ps1
set DEST=%LOCALAPPDATA%\hermes\backup\saneado

if /i "%~1"=="estado" (
    powershell -NoProfile -Command "Get-ChildItem 'D:\HermesSync\backups\hermes\*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10 | ForEach-Object { '{0}  {1:N0} KB' -f $_.LastWriteTime.ToString('dd/MM/yyyy HH:mm'), ($_.Length/1KB) }"
    goto :fin
)
if /i "%~1"=="saneado" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -SoloSaneado
    goto :fin
)
if /i "%~1"=="completo" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ConConversaciones
    goto :fin
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
:fin
endlocal
