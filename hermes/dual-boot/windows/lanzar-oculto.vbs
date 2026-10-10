'
' lanzar-oculto.vbs - ejecuta un .cmd/.bat sin mostrar ninguna ventana.
'
' Uso (como accion de una tarea programada):
'   wscript.exe "C:\...\lanzar-oculto.vbs" "C:\...\loquesea.cmd"
'
' Las tareas de Hermes en Windows (HermesSync-Publicar, HermesBackup-Win) lanzaban
' el .cmd directamente: el Programador de tareas le crea una consola y la ventana
' aparece en cada ejecucion (cada 5 y cada 30 minutos).  wscript.exe no tiene
' consola, y sh.Run con la ventana a 0 la oculta por completo.  El codigo de salida
' del .cmd se devuelve como codigo de salida del wscript para que el Programador
' siga registrando el resultado real.
'
Option Explicit
Dim fso, sh, q, cmd, rc
If WScript.Arguments.Count = 0 Then WScript.Quit 2
q = Chr(34)
cmd = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
If Not fso.FileExists(cmd) Then WScript.Quit 3
Set sh = CreateObject("WScript.Shell")
rc = sh.Run("cmd.exe /c " & q & cmd & q, 0, True)
If IsEmpty(rc) Then WScript.Quit 0
If rc < 0 Or rc > 255 Then WScript.Quit 1
WScript.Quit rc
