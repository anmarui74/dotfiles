@echo off
REM Lanzador de la tarea programada HermesBackup-Win (generado por registrar-tareas.ps1)
setlocal
set "AQUI=%~dp0"
set "AQUI=%AQUI:~0,-1%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%AQUI%\sync-hermes.ps1" -Quiet
endlocal