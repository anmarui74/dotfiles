# WhatsApp de Hermes — herramientas del dispositivo dedicado

Este directorio guarda las herramientas del **dispositivo dedicado de Hermes para WhatsApp Web**.
No tiene nada que ver con el perfil de Chrome de Antonio: es un perfil propio, vacío, vinculado UNA
vez escaneando un QR.

## Dónde vive la sesión: LOCAL en cada sistema (13/10/2026)

Antonio pidió que cada sistema tenga **su propia copia** y no depender del disco de intercambio. Es
**la misma sesión** en los dos (el perfil se copió), así que no hay que volver a escanear el QR.
WhatsApp Web sí es portable entre sistemas.

```
Linux:    ~/.local/share/hermes/whatsapp-perfil        lanzador: ~/.local/bin/whatsapp-hermes
Windows:  %LOCALAPPDATA%\hermes\whatsapp-perfil-win   lanzador: whatsapp-hermes.ps1
```

Nunca deben usarlo los dos sistemas a la vez (no están encendidos a la vez, así que no pasa) y solo
uno debe tener el navegador abierto sobre el perfil en cada momento.

## Cómo se usa

**Norma:** se abre **oculto** (sin ventana) y se cierra al terminar. Antonio usa su propio WhatsApp
Web en su Chrome; la ventana visible es solo para vincular o desvincular.

**Linux:**

```bash
whatsapp-hermes                # oculto (--headless=new), puerto CDP 9222
whatsapp-hermes --visible      # con ventana (solo para escanear el QR)
python3 ~/Config/hermes/dual-boot/windows/whatsapp/wa-leer.py            # lista de chats
python3 .../wa-leer.py --abrir Papa -n 20                                # últimos mensajes
# cerrar: pkill -TERM -f 'user-data-dir=.*whatsapp-perfil'
```

**Windows:**

```powershell
powershell -ExecutionPolicy Bypass -File whatsapp-hermes.ps1           # oculto (leer/enviar)
powershell -ExecutionPolicy Bypass -File whatsapp-hermes.ps1 -Visible  # con ventana (vincular)
python wa-leer.py --abrir Papa -n 20
```

La depuración (CDP) queda en `http://127.0.0.1:9222` mientras el navegador está abierto, solo en
local. `wa-leer.py` necesita `websocket-client`.

## Reglas

- Si pide **QR**, avisar antes de escanearlo (crearía otro dispositivo emparejado).
- Leer mensajes desde aquí **marca como leídos** y deja de avisar en el móvil.
- Automatizar WhatsApp Web va contra sus condiciones de uso: riesgo bajo pero real. Usarlo para
  lecturas y envíos puntuales.
- Antes de copiar el perfil, cerrar el navegador (los LevelDB no se copian en caliente).
