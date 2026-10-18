@echo off
rem Lanzador de Mensajes de Google de Hermes sobre el perfil compartido del dual boot.
rem NORMA: se abre OCULTO por defecto (sin ventana); Antonio usa su propia web de Mensajes.
rem   messages-hermes.cmd            -> oculto (para leer por CDP con messages-leer.py)
rem   messages-hermes.cmd -Visible   -> con ventana (solo para vincular con el QR)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0messages-hermes.ps1" %*
