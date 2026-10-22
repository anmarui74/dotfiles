'
' Hermes Agent - lanzador del aviso de cierre por Telegram
'
' Lo copia el encargo 23 a la carpeta Inicio como Hermes_CierreNotify.vbs.
' Lanza el vigilante oculto: espera a que el gateway arranque y avisa cuando
' se cierra. No abre ninguna ventana y no requiere administrador.
' ---------------------------------------------------------------------------
Option Explicit
Dim fso, sh, q, base, script
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
q = Chr(34)
base = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\hermes")
script = base & "\gateway-service\hermes-cierre-notify.ps1"
If Not fso.FileExists(script) Then WScript.Quit 0
sh.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " & q & script & q, 0, False
