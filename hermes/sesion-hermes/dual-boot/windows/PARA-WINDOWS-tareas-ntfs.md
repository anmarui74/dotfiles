# 🪟 PARA-WINDOWS — Tareas pendientes de NTFS, espejo e inicio rápido

| ⚙️ Estado | 📅 Fecha | 👤 Origen |
|---|---|---|
| ⏳ pendiente | 10/10/2026 | Hermes en Linux (`cachyos`) |

> Encargo del Hermes de **Linux** al Hermes de **Windows**. Al arrancar Windows: leer esto, ejecutar
> las tareas y **dejar constancia al final en `HermesSync/NOTA-PARA-LINUX.md`** (sección nueva).

---

## Contexto

- El **10/10/2026 a las 14:29** el Linux de este equipo cayó de golpe (driver NVIDIA:
  `GPU lost from the bus`, sin secuencia de apagado). **No fue un apagado limpio.**
- Lo que ya se ha hecho desde Linux, para no repetirlo:
  - El NTFS del **disco compartido** (etiqueta `SEAGATE`, el que contiene `\HermesSync`) quedó sucio
    y **con daño real**: `ntfsfix -d` encontró un desajuste `$MFTMirr` ≠ `$MFT`, lo corrigió, vació el
    journal y limpió el flag. Volvió a montar en lectura-escritura y el dual-sync reanudó sus
    publicaciones (14:45, 78 sesiones / 7.869 mensajes). Pero **`ntfsfix` no es `chkdsk`**.
  - Se ha **mapeado por primera vez el volumen dinámico espejo** (paquete `libldm` → `ldmtool`,
    servicio `ldmtool.service` habilitado) y se ha dejado en `/etc/fstab` como `/mnt/toshiba`, en
    lectura-escritura. El mapeo es un **dm-raid1 real** (`draid status: raid raid1 2 AA … idle`: las
    dos patas activas y sincronizadas) y desde Linux solo se hizo **una escritura mínima de prueba**
    (crear y borrar un fichero).
- Salud de los discos: los seis **PASSED**, 0 sectores reasignados, 0 pendientes.

---

## Tareas, por orden

### 1. Averiguar las letras reales — no fiarse de las documentadas

```powershell
Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,HealthStatus,Size,SizeRemaining | Format-Table -AutoSize
Get-Partition | Select-Object DiskNumber,PartitionNumber,DriveLetter,Size | Format-Table -AutoSize
```

- **Disco compartido** = el etiquetado **`SEAGATE`** (contiene `\HermesSync`). Es el de los backups y
  el estado de Hermes entre los dos equipos. En las últimas sesiones de Windows era **`D:`**.
- **Volumen espejo** = el etiquetado **`TOSHIBA`**: volumen **dinámico espejo (RAID1)** sobre los dos
  discos de 4 TB (`TOSHIBA HDWE140`). Sus metadatos LDM llevan la pista de letra **`E:`**.
- ⚠️ **Las letras pueden cambiar entre sesiones: identifica cada volumen por su ETIQUETA, no por la
  letra.** (El manual del lado Linux decía `E:\HermesSync` para la carpeta compartida — era un error:
  `E:` es el espejo. Ya está corregido; si aun así no cuadra, anótalo al final.)

### 2. `chkdsk` del disco compartido (prioridad)

```powershell
chkdsk <letra-del-SEAGATE>: /f
```

Si avisa de que el volumen está en uso (la propia sincronización de Hermes), aceptar programarlo al
siguiente arranque, o detener antes las tareas `HermesSync-*`. **Anotar si encontró errores.**

### 3. Revisar el espejo del volumen `TOSHIBA`

- Abrir `diskmgmt.msc` y mirar el estado del volumen y de los dos discos.
- Si Windows pide **verificar / regenerar / resincronizar** el espejo, dejarlo terminar: es lo
  esperable tras haber escrito Linux en él, y **no hay pérdida de datos** (las dos patas quedaron
  sincronizadas).
- Opcional: pasar también `chkdsk <letra-del-TOSHIBA>: /f`.
- ❌ **No** convertir, reactivar ni «importar discos»: los metadatos del grupo dinámico los ha
  llevado siempre Windows; Linux solo los mapea en memoria.

### 4. «Inicio rápido» — causa recurrente de NTFS sucio

```powershell
powercfg /a
```

Panel de control → Opciones de energía → *Elegir el comportamiento de los botones de apagado* →
**desmarcar «Activar inicio rápido»** si estuviera activo. Anotar cómo queda.

### 5. Comprobar que la sincronización sigue viva

```powershell
<letra-compartida>:\HermesSync\windows\hermes-dual-sync.ps1 -Accion estado
```

Debe decir que la carpeta común es accesible, y el import de arranque debe haber traído la
publicación de Linux de las **14:45** (78 sesiones / ~7.869 mensajes).

### 6. Dejar constancia (obligatorio)

Añadir una sección nueva **al final de `HermesSync/NOTA-PARA-LINUX.md`** con:

- Letras reales de cada volumen (y si el manual hay que corregirlo).
- Resultado de los `chkdsk` (errores encontrados y reparados).
- Estado del espejo y de los dos discos.
- Estado del «inicio rápido».
- Cualquier otra cosa que hayas tenido que arreglar.

---

## Referencias

- Esquema y traspaso: `HermesSync/LEEME.md` · `windows/LEEME-comun.md` · `windows/LEEME-WINDOWS.md`
- Inventario del equipo Linux (discos, SMART, espejo, fstab): `~/Config/hermes/SISTEMA-CACHYOS.md`
  (secciones 6 y 7).
