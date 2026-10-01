# Sincronización dual boot en Windows — notas de este equipo

Esta carpeta (`%LOCALAPPDATA%\hermes\dual-boot`) es **solo del lado Windows**: no viaja
en la sincronización (el disco compartido sincroniza `config.yaml`, `.env`, `auth.json`,
`SOUL.md`, `state.db`, `sessions/`, `memories/`, `skills/`, `cron/` y `kanban.db`, no esto).

## Motor: copia local canónica

`hermes-sync.cmd` ejecuta el motor de esta misma carpeta:

```
%LOCALAPPDATA%\hermes\dual-boot\hermes-dual-sync.ps1   (+ copiar-state.py al lado)
```

En la carpeta compartida hay otra copia (`D:\HermesSync\windows\...`) que sirve de
distribución y que Linux republica desde `~/Config/hermes/dual-boot/windows/`. Desde el
28/09/2026 Windows **no** la usa: así una republicación desde Linux no puede revertir los
arreglos del motor de Windows (uno de ellos evita corromper `state.db`). Si tocas el
motor, cambia las dos copias o, como mínimo, la local, que es la que se ejecuta.

## Qué hay aquí

| Fichero | Para qué |
|---|---|
| `hermes-sync.cmd` | Busca `HermesSync` en D:..Z: (por si cambia la letra del disco) y llama al motor con los argumentos que le pases. |
| `importar.cmd` | Integra a mano lo publicado por el otro sistema. **Con Hermes cerrado.** |
| `publicar.cmd` | Lo que ejecuta la tarea programada cada 5 minutos. |
| `registrar-tareas.cmd` | Deja montada la sincronización (tarea + arranque). Reejecutable. |
| `arranque-hermes.vbs` | Lanzador que se copia a la carpeta Inicio: importa y luego arranca el gateway. |
| `Hermes_Gateway.vbs.original` | Copia del lanzador que había instalado Hermes, por si quieres volver atrás. |

## Comandos

```cmd
"%LOCALAPPDATA%\hermes\dual-boot\hermes-sync.cmd" estado
"%LOCALAPPDATA%\hermes\dual-boot\importar.cmd"
```
o el motor directamente:

```powershell
powershell -ExecutionPolicy Bypass -File D:\HermesSync\windows\hermes-dual-sync.ps1 -Accion estado
```

## Por qué no lo hizo el instalador solo

`windows\instalar-en-windows.ps1` usa `Register-ScheduledTask`, que en este equipo
devuelve **Acceso denegado** (y `schtasks /sc onlogon` también: crear un disparador “al
iniciar sesión” exige permisos de administrador). Con permisos de usuario normal sí
funciona una tarea cada N minutos, así que:

- **Publicar cada 5 min** → tarea programada `HermesSync-Publicar` (registrada con
  `schtasks /create /sc minute /mo 5`), que llama a `publicar.cmd`.
- **Importar al iniciar sesión** → la carpeta Inicio de Windows no admite “antes de que
  arranque el gateway”, así que el lanzador `Hermes_Gateway.vbs` de la carpeta Inicio se
  sustituye por uno que **primero importa y después arranca el gateway**. El gateway no
  debe estar en marcha cuando se importa: el motor se niega a sustituir `state.db` si lo
  está, y con razón.

Se ejecuta `registrar-tareas.cmd` una vez y ya está (es idempotente).

## Avisos

- Si algún día lanzas `hermes gateway install` (o una actualización lo hace por ti),
  Hermes vuelve a escribir su lanzador en la carpeta Inicio y la importación previa
  desaparece: vuelve a lanzar `registrar-tareas.cmd`.
- La tarea de publicar usa `-SinImport`: si hay una publicación del otro sistema sin
  integrar, **no publica encima de ella** (antes sí lo hacía y destruía el estado
  pendiente del otro sistema). Cuando la importación se haga, vuelve a publicar normal.
- El disco compartido se publica con `-SoloSiCambia`: si nada ha cambiado, no reescribe.
- Copias de seguridad: antes de cada importación, el estado anterior queda en
  `%LOCALAPPDATA%\hermes\.dual-sync\backups\<epoch>\`. El historial del disco compartido
  está en `D:\HermesSync\historial\<equipo>\`.
- **Nunca sustituir `state.db` con Hermes abierto.** El motor lo comprueba dos veces
  (al empezar y justo antes de copiar, mirando cualquier proceso de Hermes, no solo el
  pid del gateway) y verifica la integridad después; si algo falla, restaura la copia
  previa y deja la importación pendiente.

## Incidente del 28/09/2026 (state.db corrupta) y recuperación

La importación de arranque de las 21:59 coincidió con la apertura de Hermes (sesión CLI
de las 21:59:09) y `state.db` quedó `database disk image is malformed`. Reparación:

1. Se apartó la base corrupta: `state.db.corrupta-20260928-220759`.
2. Se restauró la publicación sana de CachyOS (12 sesiones, 1044 mensajes) desde
   `D:\HermesSync\estado\state.db` con copia consistente (API `.backup` de SQLite).
3. Se comprobó `integrity_check` antes y después de colocarla.
4. Se arrancó el gateway, que había quedado caído tras el incidente.

Para repetirlo (siempre con Hermes cerrado): parar Hermes, copiar
`D:\HermesSync\estado\state.db` sobre `%LOCALAPPDATA%\hermes\state.db` con
`copiar-state.py` y verificar con `copiar-state.py --integridad`. El detalle del incidente
quedó también en `D:\HermesSync\PENDIENTE-EN-LINUX.md`.
