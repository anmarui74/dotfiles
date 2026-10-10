# HermesSync — estado compartido de Hermes entre Linux y Windows

> ⚠️ Las letras de unidad pueden cambiar entre sesiones: identifica el disco compartido por
> su **etiqueta (`SEAGATE`)**, no por la letra. En las últimas sesiones de Windows era `D:`
> (el `E:` de este equipo es el volumen espejo `TOSHIBA`).

Esta carpeta es el punto de encuentro de los dos sistemas que tienes en el mismo PC
(dual boot): el Hermes de Linux y el de Windows. Nunca están encendidos a la vez, así
que cada uno **publica** aquí su estado al terminar y **recoge** el del otro al arrancar.
El resultado: la misma memoria, las mismas skills y las mismas conversaciones en los dos
lados.

```
HermesSync/
├── LEEME.md              este documento
├── .hermes-sync          marcador (no borrar: es lo que localiza la carpeta)
├── estado/               lo último publicado (state.db, sessions, memories, skills, cron, kanban)
├── semilla/              configuración y claves (solo a petición; se borra cuando ya está aplicada)
├── historial/<equipo>/   copias de seguridad de publicaciones anteriores
├── logs/                 registro de cada sincronización, por equipo
└── windows/              scripts del lado Windows
```

## Primer arranque en Windows

1. Instala Hermes (PowerShell normal, sin administrador):

   ```powershell
   iex (irm https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1)
   ```

2. Abre una terminal **nueva** y lanza el instalador del esquema (ajusta la letra de unidad
   del disco SEAGATE si no es `E:`):

   ```powershell
   powershell -ExecutionPolicy Bypass -File D:\HermesSync\windows\instalar-en-windows.ps1
   ```

   Ese único comando:
   - aplica la semilla (`config.yaml`, `.env`, `auth.json`, `SOUL.md`) para que Hermes quede
     igual que en Linux — sólo la primera vez;
   - adapta la voz a Windows (TTS del sistema; el motor de voz local de Linux no existe aquí);
   - registra las tareas programadas de sincronización;
   - importa el estado publicado por Linux (conversaciones, memoria, skills).

3. Comprueba que todo está al día:

   ```powershell
   powershell -ExecutionPolicy Bypass -File D:\HermesSync\windows\hermes-dual-sync.ps1 -Accion estado
   ```

La carpeta `semilla` contiene claves de API en claro. Se genera **solo a petición**
(`hermes-dual-sync semilla` en Linux, `-Accion semilla` en Windows) y ya no se recrea sola
cuando falta. En cuanto el segundo sistema esté configurado, bórrala desde cualquiera de los
dos (Linux: `rm -rf /mnt/seagate/HermesSync/semilla`; Windows:
`Remove-Item D:\HermesSync\semilla -Recurse -Force`) y no volverá.

## Rutina diaria (automática)

| Momento | Qué pasa |
|---|---|
| Trabajas en Linux | Cada turno de conversación (y cada 10 min) se publica el estado aquí |
| Apagas Linux | Se publica una última vez antes de apagar |
| Arrancas Windows | Se importa lo de Linux antes de que arranque el gateway; luego cada 5 min publica lo suyo |
| Vuelves a Linux | Al arrancar se importa lo de Windows antes de arrancar el gateway |

## Comandos útiles

En Linux (terminal):

```bash
hermes-dual-sync estado              # qué hay publicado y qué tengo yo
hermes-dual-sync import              # traer lo del otro sistema (con Hermes cerrado)
hermes-dual-sync export              # publicar el estado de este equipo
hermes-dual-sync listar-historico    # copias guardadas
hermes-dual-sync restaurar <equipo> <epoch>
```

En Windows (PowerShell, dentro de `D:\HermesSync\windows`):

```powershell
powershell -ExecutionPolicy Bypass -File hermes-dual-sync.ps1 -Accion estado
powershell -ExecutionPolicy Bypass -File hermes-dual-sync.ps1 -Accion import
powershell -ExecutionPolicy Bypass -File hermes-dual-sync.ps1 -Accion export
```

## Si algo va mal

- **"state.db remota ilegible o dañada"**: la publicación llegó incompleta; se aborta el
  import sin tocar nada. Vuelve a publicar desde el otro sistema.
- **"Hermes está usando state.db en este equipo"**: cierra el gateway y las sesiones
  (`systemctl --user stop hermes-gateway`) o usa `--reiniciar-gateway`, y reintenta.
- **El disco compartido no aparece en Linux**: si Windows se apagó con **inicio rápido**
  activado, la partición queda marcada como "en uso" y Linux sólo la monta en lectura.
  Desactiva el inicio rápido en Windows (Panel de control → Opciones de energía →
  Elegir el comportamiento de los botones de inicio/apagado) o apaga con "Reiniciar".
- **He integrado algo que no quería**: las copias previas están en
  `historial/<equipo>/` y en `.dual-sync/backups/` dentro del directorio de datos de
  cada Hermes.

## Detalles técnicos

- Linux: `~/.hermes` es el directorio activo; scripts y unidades en `~/Config/hermes/dual-boot/`
  y `~/.config/systemd/user/hermes-dual-sync-*.{service,timer}`.
- Windows: el directorio activo es `%LOCALAPPDATA%\hermes`; tareas programadas
  `HermesSync-Importar` (al iniciar sesión) y `HermesSync-Publicar` (cada 5 min).
- Regla de oro: **el último que publica manda**. Antes de publicar, cada lado intenta
  integrar lo del otro; si no puede (Hermes abierto), archiva la copia ajena en el
  historial y publica igualmente para no quedarse atascado.
- Sólo viaja el estado: conversaciones (`state.db`), `sessions/`, `memories/`, `skills/`,
  `cron/`, `kanban.db` y `SOUL.md`. Nunca van los binarios, el clon del código ni las cachés.
