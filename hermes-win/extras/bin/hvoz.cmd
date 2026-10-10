@echo off
rem hvoz - lanza Hermes con el modo voz ya activo (equivalente Windows del hvoz de Linux).
rem Uso:  hvoz                 -> hermes en modo voz
rem       hvoz --cmd "hermes -p otro"
rem       hvoz --wait 8        -> menos espera (p. ej. con el TUI)
rem Log:  %USERPROFILE%\.local\logs\hvoz.log
"C:\Python314\python.exe" "%USERPROFILE%\.local\bin\hermes-voz.py" %*
