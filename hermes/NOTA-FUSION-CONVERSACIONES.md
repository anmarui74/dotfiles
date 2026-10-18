# Fusión de conversaciones entre Linux y Windows — qué pasa al arrancar

Dejado por el Hermes de **Linux** el 13/10/2026. Esto es lo que va a ocurrir **solo**, sin que
Antonio tenga que pedir nada.

## 1. En el primer arranque de Windows (una sola vez)

El hook `encargos-windows` ejecuta `windows\encargos\18-fusionar-mensajes.ps1`, que:

- **instala** el hook `fusionar-mensajes` en `%LOCALAPPDATA%\hermes\hooks\fusionar-mensajes\`
  (copia `HOOK.yaml` y `handler.py` desde `D:\HermesSync\windows\hooks\fusionar-mensajes\`);
- **lanza una fusión ahora mismo**, en segundo plano (sin esperarla, para no bloquear el arranque
  del gateway: un encargo síncrono ya provocó un bucle de reinicios por el watchdog);
- deja su salida en `D:\HermesSync\logs\fusionar-encargo18-<fecha>.log`.

Comprobado desde Linux (montando `C:` en solo lectura): el encargo 18 **no** figura todavía en el
registro de encargos hechos de Windows, así que sí se ejecutará.

## 2. A partir de ahí, en CADA arranque de Hermes (los dos sistemas)

El hook `fusionar-mensajes` (`gateway:startup`, en un hilo aparte) ejecuta:

    <disco compartido>\scripts\fusionar-mensajes.py --aplicar

y deja el resultado en `D:\HermesSync\logs\fusionar-mensajes.log` (en Linux:
`~/Config/hermes/logs/fusionar-mensajes.log`).

## 3. Qué hace exactamente el fusionador

| Paso | Detalle |
|---|---|
| Sesiones que falten | Las **crea enteras** (fila de `sessions` + todos sus mensajes) |
| Mensajes que falten | Los añade comparando **por contenido** (rol + texto, 1 s de tolerancia) → **no puede duplicar** |
| Copias repetidas | Las borra conservando una (en Windows hay ~456 de días anteriores) |
| Orden | Recoloca `display_order` por fecha, agrupando por `display_identity` |
| Seguridad | Copia previa de la base, `integrity_check` al final y *rollback* si falla |

Es idempotente: si todo está al día, no toca nada y lo dice.

## 4. Cómo saber que ha ido bien

- `D:\HermesSync\logs\fusionar-mensajes.log` termina con **"conversaciones al día"**.
- Existe `%LOCALAPPDATA%\hermes\hooks\fusionar-mensajes\` con `HOOK.yaml` y `handler.py`.
- Si algo falla, el log lo dice: `FALLO ...; se reintentará en el próximo arranque`.

## 5. A mano, si alguna vez hace falta

    python D:\HermesSync\scripts\fusionar-mensajes.py                  (simulación: qué haría)
    python D:\HermesSync\scripts\fusionar-mensajes.py --aplicar        (lo aplica)
    python D:\HermesSync\scripts\fusionar-mensajes.py --solo-duplicados
    python D:\HermesSync\scripts\fusionar-mensajes.py --sesion <id>

Solo usa la biblioteca estándar de Python: vale cualquier `python` de Hermes.
