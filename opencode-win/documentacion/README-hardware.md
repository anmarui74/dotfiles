# 🖥️ Comandos rápidos de hardware (Windows)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

> Guía de comandos PowerShell para consultar la información del equipo.
> Para un escaneo completo y automático del proyecto Linux se usaba
> `python3 ~/.config/opencode/hardware-query.py scan`; en Windows ese script
> **todavía no está portado** (pendiente).

---

## ⚡ Consulta rápida (recomendado)

| Comando | Qué muestra |
|---|---|
| `Get-CimInstance Win32_Processor \| Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed` | CPU |
| `Get-CimInstance Win32_VideoController \| Select-Object Name,AdapterRAM,DriverVersion` | GPU(s) |
| `nvidia-smi` | GPU NVIDIA (VRAM, temperatura, consumo) |
| `"{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)` | RAM total |
| `Get-PSDrive -PSProvider FileSystem \| Select-Object Name,Used,Free` | Unidades y espacio libre |
| `Get-PhysicalDisk \| Select-Object FriendlyName,MediaType,Size,HealthStatus` | Discos físicos |
| `Get-NetAdapter \| Select-Object Name,InterfaceDescription,Status,LinkSpeed` | Adaptadores de red |
| `Get-CimInstance Win32_BaseBoard` / `Win32_BIOS` | Placa base y BIOS |

> ⚠️ **No aplica en Windows:** el script `hardware-query.py` y la función `hw_query`
> del proyecto Linux no están portados. Usar los cmdlets de la tabla.

## Comandos manuales equivalentes

### CPU

```powershell
(Get-CimInstance Win32_Processor).Name
```

Resultado esperado: `AMD Ryzen 9 7900 12-Core Processor`

### Memoria

```powershell
"{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)
```

Resultado: 63,1 GB total.

### Placa base

```powershell
(Get-CimInstance Win32_BaseBoard).Product
```

> ⚠️ **No aplica en Windows:** no hay un fichero `/sys/.../board_name`; el modelo se
> obtiene de `Win32_BaseBoard`. El valor concreto depende del equipo.

### GPU NVIDIA

```powershell
nvidia-smi --query-gpu=index,name,memory.total,memory.used,temperature.gpu,power.draw --format=csv,noheader,nounits
```

### WiFi

```powershell
Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-?Fi|Wireless' }
netsh wlan show interfaces
```

### Interfaces de red

```powershell
Get-NetAdapter | Select-Object Name,InterfaceDescription,Status,LinkSpeed
```

### Almacenamiento

```powershell
Get-PhysicalDisk | Select-Object FriendlyName,MediaType,Size,HealthStatus
Get-PSDrive -PSProvider FileSystem | Select-Object Name,Used,Free
```

### Topología y frecuencia de la CPU

```powershell
(Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
(Get-CimInstance Win32_Processor).MaxClockSpeed
```

## Notas

- Todos los comandos devuelven la salida directamente a la consola PowerShell 5.1.
- El índice JSON (cuando se porte el script) vivirá en
  `C:\Users\evo01\.config\opencode\data\hardware\index.json`.
- Detalle completo del equipo: ver [hardware-info.md](hardware-info.md).
