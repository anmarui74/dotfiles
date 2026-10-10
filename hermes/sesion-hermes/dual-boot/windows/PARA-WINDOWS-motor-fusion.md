# Para el Hermes de Windows — el import ya no se atasca con Hermes en marcha

Nota escrita desde **Linux (cachyos)** el 05/10/2026. Va dirigida a ti, Hermes de Windows
(`%LOCALAPPDATA%\hermes`), y explica un cambio **en el motor del dual boot** que está en la
carpeta compartida y que todavía **no está en tu copia local** (la que ejecutas).

## Por qué

Hoy (05/10) la sincronización Windows → Linux estuvo parada de 12:36 a 12:56: el motor se
negaba a importar con Hermes en marcha (`AVISO: Hermes está en marcha en este equipo; no
sustituyo la base de datos`) y, mientras hubiera estado de `cachyos` sin integrar, tampoco
publicaba (`ERROR: hay estado más nuevo de 'cachyos' sin integrar`).  Resultado: 10 intentos
bloqueados y ninguna publicación.

Ese freno era correcto —sustituir `state.db` con Hermes vivo la corrompe, pasó el 28/09—
pero dejaba la sincronización sin salida.  El arreglo: cuando Hermes está en marcha **no se
sustituye la base, se fusiona**.

## Qué hace ahora el motor

- Con Hermes **cerrado**: igual que siempre (sustituye `state.db`, copia los árboles).
- Con Hermes **en marcha**: `copiar-state.py --fusionar` añade a tu `state.db` las sesiones
  que le falten (con sus mensajes, prompts y datos de uso) **sin borrar nada tuyo** y sin
  sustituir el fichero; después copia `sessions/`, `memories/`, `skills/`, `cron/` y
  `SOUL.md`.  Así el import avanza, la publicación se desbloquea y no pierdes sesiones.
- `kanban.db` se deja para el próximo import con Hermes cerrado (es una base que el gateway
  puede tener abierta).  Mientras quede eso pendiente, `estado.json` lo anota:
  `"parcial": true, "pendientes": ["kanban.db"]`, y el motor lo completa solo en cuanto
  cierres Hermes.  Nada se repite cada 5 minutos mientras espera.

## Lo que tienes que hacer (dos comandos, sin administrador)

La copia que ejecutas es la tuya (`%LOCALAPPDATA%\hermes\dual-boot\hermes-dual-sync.ps1`),
no la de la carpeta compartida; es a propósito.  Para pasarte los arreglos publicados:

```powershell
# D: = letra del disco SEAGATE (búscala por <letra>:\HermesSync\.hermes-sync)
powershell -ExecutionPolicy Bypass -File D:\HermesSync\windows\actualizar-motor-local.ps1 -SoloEstado
powershell -ExecutionPolicy Bypass -File D:\HermesSync\windows\actualizar-motor-local.ps1
```

Actualiza `hermes-dual-sync.ps1` y `copiar-state.py` (dejando copia `.bak-<fecha>` de la
versión anterior) y, de paso, avisa si el lanzador de la carpeta Inicio ha dejado de importar
antes de arrancar el gateway (le pasa si `hermes gateway install` o una actualización lo
reescribe: se recupera con `registrar-tareas.cmd`).

## Verificar

```powershell
powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\hermes\dual-boot\hermes-dual-sync.ps1" -Accion estado
```

- `Última importación` con `(parcial; pendiente: kanban.db)` = fusión hecha, falta cerrar Hermes
  una vez para completarla.
- En `%LOCALAPPDATA%\hermes\.dual-sync\backups\<epoch>-parcial\` queda la copia previa.
- En el log de la carpeta compartida (`logs\PC-ANTONIO.log`) la importación por fusión sale
  como `Hermes está en marcha: importo por fusión (no sustituyo la base de datos).`

Si algo no cuadra, dilo en `NOTA-PARA-LINUX.md` con el error exacto y se reconcilia desde Linux.
