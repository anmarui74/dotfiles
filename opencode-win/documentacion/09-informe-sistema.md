# 📝 Informe del sistema — procedimiento (Windows)
Cómo generar un informe completo del equipo (hardware, discos, red, GPU, sensores) desde Windows con PowerShell y CIM.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/10/2026 · rev. 10/10/2026 | Antonio |

> Equivalente Windows del informe que en Linux se genera con `pkexec` + `inxi`
> (ver manual 09 de Linux). En Windows la elevación es **UAC**, y las herramientas
> nativas son **PowerShell 5.1 + CIM**.

---

## 📑 Índice
1. [Requisitos previos](#requisitos-previos)
2. [Herramienta base: `hardware-query.ps1`](#herramienta-base-hardware-queryps1)
3. [El script `sysinfo.ps1`](#el-script-sysinfops1)
4. [Ejecución con UAC](#ejecución-con-uac)
5. [Qué recopila](#qué-recopila)
6. [Estructura del informe resultante](#estructura-del-informe-resultante)
7. [Detalles y avisos](#detalles-y-avisos)

---

## Requisitos previos

| Herramienta | Origen | Uso |
|---|---|---|
| **PowerShell 5.1** | Windows | Motor de recopilación (CIM/WMI) |
| **`hardware-query.ps1`** | `…\.config\opencode\scripts\` | Resumen rápido: CPU, GPU, RAM, discos y red |
| **`nvidia-smi.exe`** | Driver NVIDIA (`C:\Windows\System32`) | Estado y detalle de la GPU |
| **`Get-PhysicalDisk`** | Módulo `Storage` (PowerShell) | Discos físicos, tipo de medio y salud |
| **`Get-NetAdapter`** | Módulo `NetAdapter` (PowerShell) | Adaptadores de red |
| **`Get-CimInstance`** | PowerShell | BIOS, placa base, módulos de RAM, monitores |
| **UAC** | Windows | Elevación de privilegios (agente → no interactivo) |

> ⚠️ **En Windows no hay `pkexec` ni `sudo`.** La elevación es **UAC**: el agente usa
> `Start-Process -Verb RunAs`; Antonio abre PowerShell **«como administrador»** para las
> consultas privilegiadas (BIOS, discos, SMART).

---

## Herramienta base: `hardware-query.ps1`

El script `C:\Users\evo01\.config\opencode\scripts\hardware-query.ps1` (también accesible
como `hw_query` desde el perfil) resume lo esencial sin privilegios:

```powershell
hw_query            # todo (CPU, GPU, RAM, discos, red)
hw_query gpu        # solo la GPU
hw_query disco      # solo discos y volúmenes
```

Salida en **tablas en español** con decimales en coma. Equivale al `hardware-query.sh`
de Linux.

---

## El script `sysinfo.ps1`

El script ya está **desplegado** en `C:\Users\evo01\.config\opencode\scripts\sysinfo.ps1`
(se copia también al respaldo con `sync-opencode.ps1`). Agrupa todos los bloques de abajo en
**una sola** ejecución (solo lectura) y admite `-OutFile`. Ejemplo resumido de su contenido:

```powershell
# sysinfo.ps1 — Volcado completo del sistema (Windows). Ejecutar como administrador.
$ErrorActionPreference = 'SilentlyContinue'

Write-Output '#################### SISTEMA / BIOS / PLACA ####################'
Get-CimInstance Win32_ComputerSystem  | Select-Object Manufacturer,Model,TotalPhysicalMemory | Format-List
Get-CimInstance Win32_BIOS            | Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate,SerialNumber | Format-List
Get-CimInstance Win32_BaseBoard       | Select-Object Manufacturer,Product,Version,SerialNumber | Format-List

Write-Output '#################### CPU ####################'
Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,Architecture | Format-List

Write-Output '#################### RAM (módulos) ####################'
Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel,DeviceLocator,Capacity,Speed,Manufacturer,PartNumber | Format-Table -AutoSize

Write-Output '#################### GPU ####################'
nvidia-smi
nvidia-smi -q

Write-Output '#################### DISCOS (físicos) ####################'
Get-PhysicalDisk | Select-Object FriendlyName,MediaType,BusType,Size,HealthStatus,OperationalStatus | Format-Table -AutoSize
Get-Disk         | Select-Object Number,FriendlyName,PartitionStyle,Size,HealthStatus | Format-Table -AutoSize
Get-Volume       | Select-Object DriveLetter,FileSystemLabel,FileSystem,SizeRemaining,Size | Format-Table -AutoSize

Write-Output '#################### RED ####################'
Get-NetAdapter   | Select-Object Name,InterfaceDescription,Status,LinkSpeed,MacAddress | Format-Table -AutoSize
ipconfig /all

Write-Output '#################### MONITORES ####################'
Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams
Get-CimInstance Win32_VideoController | Select-Object Name,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate | Format-Table -AutoSize
```

---

## Ejecución con UAC

**Clave:** las secciones de BIOS, discos y SMART necesitan elevación. El agente no tiene
terminal interactiva, así que se lanza pidiendo UAC:

```powershell
# Desde el agente: elevar y volcar a un fichero
Start-Process powershell -Verb RunAs -ArgumentList `
  '-NoProfile','-ExecutionPolicy','Bypass',`
  '-File','C:\Users\evo01\.config\opencode\scripts\sysinfo.ps1' `
  -RedirectStandardOutput 'C:\Users\evo01\informe-sistema-sysinfo.txt'
```

O bien Antonio abre **PowerShell como administrador** y ejecuta:

```powershell
& "$env:USERPROFILE\.config\opencode\scripts\sysinfo.ps1" | Tee-Object "$env:USERPROFILE\informe-sistema-sysinfo.txt"
```

- Aparece la **ventana de UAC** pidiendo confirmación.
- El volcado completo queda en `C:\Users\evo01\informe-sistema-sysinfo.txt`.

> 💡 Para SMART detallado de discos concretos hace falta **smartmontools para Windows**
> (`smartctl -a /dev/sdX` o `smartctl -a -d nvme …`), que no viene de serie.

---

## Qué recopila

| Bloque | Comando | Datos que aporta |
|---|---|---|
| **Sistema** | `Win32_ComputerSystem` · `Win32_BIOS` · `Win32_BaseBoard` | Fabricante/modelo, BIOS/SMBIOS y fecha, placa base y serie |
| **CPU** | `Win32_Processor` | Modelo, núcleos/hilos, frecuencia, arquitectura |
| **RAM** | `Win32_PhysicalMemory` | Módulos DIMM: banco, capacidad, velocidad, marca, part number |
| **GPU** | `nvidia-smi` + `nvidia-smi -q` | VRAM, temperatura, consumo, PCIe, VBIOS, UUID, procesos |
| **Discos** | `Get-PhysicalDisk` · `Get-Disk` · `Get-Volume` | Tipo de medio, bus, salud, particiones y espacio libre |
| **SMART** | `smartctl` (smartmontools, opcional) | Horas, ciclos, unidades escritas, sectores reasignados |
| **Red** | `Get-NetAdapter` · `ipconfig /all` | Adaptadores, estado, velocidad, MAC, IP/DNS |
| **Monitores** | `WmiMonitorBasicDisplayParams` · `Win32_VideoController` | Tamaño/resolución activa y refresco |

---

## Estructura del informe resultante

El informe (`C:\Users\evo01\informe-sistema.md`) sigue este orden, todo en **tablas
Markdown nativas**:

1. **Resumen del equipo** · 2. **Sistema operativo y software** · 3. **CPU** · 4. **Memoria RAM** (módulos + pagefile) · 5. **Gráficas** (NVIDIA, iGPU, monitores) · 6. **Almacenamiento** (discos, particiones, salud) · 7. **Red** (WiFi/Ethernet/Bluetooth) · 8. **Audio** · 9. **Sensores** · 10. **Incidencias detectadas** · 11. **Recomendaciones** · **Anexo** con el método.

> 📌 Reglas de formato: fechas `dd/mm/aaaa`, hora 24 h, decimales con **coma**, unidades del sistema métrico (°C, GB/GiB) y tablas Markdown (nunca bloques ASCII).

---

## Detalles y avisos

- **CPU en Windows:** no se exponen microcode ni mitigaciones como en `lscpu`; se consultan aparte (`HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0`).
- **Sensores:** Windows **no tiene `sensors` (lm-sensors)**. La temperatura de la GPU se lee con `nvidia-smi`; la de CPU requiere herramienta externa (HWiNFO, OpenHardwareMonitor).
- **`AdapterRAM` miente:** `Win32_VideoController.AdapterRAM` está limitado a 4 GB (es un `uint32`); para la VRAM real usar `nvidia-smi`.
- **Almacenamiento:** `Get-PhysicalDisk` da salud/tipo de medio; `Get-Volume` da el espacio real montado.
- **Bluetooth:** `Get-PnpDevice -Class Bluetooth` para el estado del adaptador.
- **`index.json`:** el índice de hardware `data\hardware\index.json` que existe en Linux **no se genera** en Windows; el equivalente es el volcado de `sysinfo.ps1` + `hardware-query.ps1`.
- El script `sysinfo.ps1` **no forma parte del instalador**: es una herramienta puntual (como `sysinfo-priv.sh` en Linux).

---

> 📁 `D:\Linux\Config\opencode-win\documentacion\09-informe-sistema.md` · 🔧 Volcados: `C:\Users\evo01\informe-sistema-sysinfo.txt`
> 📊 Hardware del equipo: [hardware-info.md](hardware-info.md) · 🔗 Comandos rápidos: [README-hardware.md](README-hardware.md)
