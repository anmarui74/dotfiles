@echo off
rem Lanzador del WhatsApp de Hermes sobre el perfil compartido del dual boot.
rem NORMA: se abre OCULTO por defecto (sin ventana); Antonio usa su propio WhatsApp en su Chrome.
rem   whatsapp-hermes.cmd            -> oculto (para leer por CDP con wa-leer.py)
rem   whatsapp-hermes.cmd -Visible   -> con ventana (solo para escanear el QR)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0whatsapp-hermes.ps1" %*
