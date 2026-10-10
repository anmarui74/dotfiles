@echo off
REM Atajo: auditoría del manual de Hermes en Windows (gemelo de hermes-auditoria-manual en Linux).
REM Contrasta AGENTS-WIN.md y SISTEMA-WINDOWS.md con la configuración viva.
REM Uso:  hermes-auditoria-win [-Json]
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\Linux\Config\Hermes-Win\hermes-auditoria-manual.ps1" %*
