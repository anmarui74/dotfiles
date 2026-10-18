# Mensajes de Google de Hermes — herramientas del perfil dedicado

Este directorio guarda las herramientas del **perfil dedicado de Hermes para la web de Mensajes
de Google (SMS)**. No tiene nada que ver con el perfil de Chrome de Antonio: es un perfil propio y
vacío, vinculado UNA vez.

Google **no ofrece API** para leer SMS/RCS personales (*RCS Business Messaging* es solo para que
las empresas envíen a sus clientes): la web `messages.google.com/web` es la única vía.

## Dónde vive la sesión: LOCAL en cada sistema (13/10/2026)

La sesión de Mensajes **NO es portable entre sistemas**: Google la ata al navegador que hizo el
emparejamiento y Chrome cifra parte de los datos con la clave del SO (`os_crypt`). Comprobado el
13/10/2026: el perfil vinculado en Linux **no reconoce la sesión en Windows** (pide iniciar sesión),
ni siquiera con una copia íntegra en otro disco. Por eso **cada sistema tiene su propia vinculación
y su perfil local**, fuera del disco de intercambio:

```
Linux:    ~/.local/share/hermes/messages-perfil        lanzador: ~/.local/bin/messages-hermes
Windows:  %LOCALAPPDATA%\hermes\messages-perfil-win   lanzador: messages-hermes.ps1
```

(WhatsApp sí es portable: allí la sesión se copió y los dos sistemas usan la misma.)

## Cómo se usa

**Norma:** se abre **oculto** (sin ventana) y se cierra al terminar. Antonio usa su propio Chrome
para la web de Mensajes; este perfil solo se levanta cuando Hermes necesita leer o enviar. La
ventana visible es solo para vincular o desvincular.

**Linux:**

```bash
messages-hermes                 # oculto (--headless=new), puerto CDP 9224
messages-hermes --visible       # con ventana (solo para vincular con el QR)
python3 ~/Config/hermes/dual-boot/windows/messages/messages-leer.py      # estado
python3 .../messages-leer.py --conversaciones 20 / --buscar TEXTO / --abrir "NOMBRE" --leer 6
# cerrar: pkill -TERM -f 'user-data-dir=.*messages-perfil'
```

**Windows:**

```powershell
powershell -ExecutionPolicy Bypass -File messages-hermes.ps1          # oculto (leer/enviar)
powershell -ExecutionPolicy Bypass -File messages-hermes.ps1 -Visible # con ventana (vincular)
python messages-leer.py            # estado y no leídos
```

La depuración (CDP) queda en `http://127.0.0.1:9224` mientras el navegador está abierto, solo en
local. `messages-leer.py` necesita `websocket-client`.

## Limitaciones y reglas

- **Google permite UN SOLO ordenador activo a la vez.** Si Antonio abre la web en su Chrome, esta
  sesión se desconecta (y al revés). Avisar antes de dejarla levantada.
- Los SMS salen por el móvil: debe estar encendido y con conexión.
- Leer desde aquí **marca como leído** y deja de avisar en el móvil.
- Antes de copiar el perfil a otro sitio, cerrar el navegador: los LevelDB del perfil
  (IndexedDB/Local Storage) no se deben copiar en caliente.
- El perfil **no entra en los backups** de Hermes.
- Si pide **QR**, avisar antes de escanear.

Referencias: skill `google-messages-hermes` (llega a Windows por el sync del estado) y la nota
`NOTA-MENSAJES-HERMES.md` de la carpeta compartida.
