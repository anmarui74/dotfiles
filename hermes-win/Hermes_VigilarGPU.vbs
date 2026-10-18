'
' ---------------------------------------------------------------------------
' Hermes Agent - lanzador del vigia de GPU
'
' Arranca al iniciar sesion el registro continuo de temperatura, potencia y
' estado de la GPU (script %LOCALAPPDATA%\hermes\diagnostico\vigilar-gpu.ps1),
' sin mostrar ninguna ventana. Sirve para tener datos del momento exacto en
' que la GPU se cuelga (volcados WATCHDOG en C:\Windows\LiveKernelReports).
'
' Se instala copiandolo a la carpeta Inicio como Hermes_VigilarGPU.vbs.
' ---------------------------------------------------------------------------
Option Explicit
Dim fso, sh, q, script
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
q = Chr(34)
script = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\hermes\diagnostico\vigilar-gpu.ps1"

If Not fso.FileExists(script) Then WScript.Quit 0
sh.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " & q & script & q, 0, False
