# 🖥️ Hardware del equipo de Antonio (Windows)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

| 🖥️ Sistema | 🪟 Kernel | 📐 Arquitectura |
|------------|-----------|-----------------|
| Windows 10/11 | Windows NT 10.0 | x86_64 (AMD64) |

| 🖥️ Escritorio | 🐚 Shell | 🌍 Locale / Zona |
|---------------|----------|------------------|
| Windows Shell (Explorer) | Windows PowerShell 5.1 | es-ES · Europe/Madrid |

> 📊 **Información actualizada:** 10/09/2026 · Datos reales del equipo Windows
> (CPU, GPU, RAM y almacenamiento). El resto de secciones indican cómo consultarlas.

---

## 🖥️ CPU

| Campo | Valor |
|---|---|
| Modelo | AMD Ryzen 9 7900 12-Core Processor |
| Arquitectura | Zen 4 (socket AM5) |
| Núcleos / hilos | 12 núcleos físicos / 24 hilos (2 por núcleo) |
| Frecuencia | Boost hasta ~5485 MHz (base 3700 MHz) |
| Caché | L1d 384 KiB · L1i 384 KiB · L2 12 MiB · L3 64 MiB |
| Virtualización | AMD-V (SVM) · compatible con Hyper-V / WSL2 |
| ISA | AVX-512 completo, AVX2, FMA3, BMI1/2, AES-NI, SHA-NI, VAES, GFNI, F16C |
| Microcode | Consultar (no expuesto directamente en Windows) |

> ⚠️ **No aplica en Windows:** los campos de microcode y de mitigaciones de
> vulnerabilidades que en Linux reportaba `lscpu` no tienen equivalente directo.
> Consultar con:
> ```powershell
> Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed
> Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -Name 'Update Revision'
> ```

## 💾 RAM

| Campo | Valor |
|---|---|
| Total | 63,1 GB (67 705 950 208 bytes) |
| Tipo | DDR5 |
| Slots | Consultar con `Get-CimInstance Win32_PhysicalMemory` |
| Swap | `pagefile.sys` (equivalente al swap de Linux) |

> ⚠️ **No aplica en Windows:** no existe `zram`. Windows gestiona la memoria de
> intercambio mediante el archivo de paginación (`pagefile.sys`).
> Consultar:
> ```powershell
> Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel,Capacity,Speed,Manufacturer
> "{0:N2} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)
> ```

## 🔌 Placa base

| Campo | Valor |
|---|---|
| Modelo | Consultar (no registrado en este documento) |
| BIOS | Consultar con `Get-CimInstance Win32_BIOS` |
| Firmware | UEFI |

> Consultar:
> ```powershell
> Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer,Product,Version
> Get-CimInstance Win32_BIOS | Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate
> ```

## 🎮 GPU

| Campo | Valor |
|---|---|
| GPU dedicada | NVIDIA GeForce RTX 4070 Ti SUPER |
| VRAM | 17 170 956 288 bytes (~15,99 GiB · 17,17 GB según LM Studio) |
| iGPU integrada | AMD Radeon(TM) Graphics |
| Backend IA | LM Studio detecta **CUDA 12.8** y llama.cpp |
| Uso CUDA | LM Studio (modelo `qwen3.8-9b`) |

> Consultar:
> ```powershell
> nvidia-smi
> Get-CimInstance Win32_VideoController | Select-Object Name,AdapterRAM,DriverVersion
> ```

## 🖥️ Monitores

| Conexión | Tamaño | Resolución activa | ¿Principal? |
|---|---|---|---|
| Consultar | — | — | — |

> ⚠️ **No aplica en Windows:** la topología de monitores que en Linux daba
> `xrandr` no se consulta igual. Usar:
> ```powershell
> Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams
> Get-CimInstance Win32_VideoController | Select-Object Name,CurrentHorizontalResolution,CurrentVerticalResolution
> ```

## 💽 Almacenamiento

| Unidad | Uso | Sistema de archivos | Notas |
|---|---|---|---|
| C: | Sistema | NTFS | Unidad del sistema operativo |
| D: | Datos | NTFS | Contiene `D:\Linux\modelos_ia` (modelos de IA) |

> No se registran capacidades exactas de disco en este documento. Consultar:
> ```powershell
> Get-PSDrive -PSProvider FileSystem | Select-Object Name,Used,Free
> Get-PhysicalDisk | Select-Object FriendlyName,MediaType,Size,HealthStatus
> ```

> ⚠️ **No aplica en Windows:** el contenedor Docker `open-webui` del equipo Linux
> no está presente de serie en Windows (solo con Docker Desktop).

## 🌐 Red

### 📡 WiFi

| Campo | Valor |
|---|---|
| Adaptador | Consultar con `Get-NetAdapter` |
| Red conectada | Consultar con `netsh wlan show interfaces` |
| IP | Consultar con `ipconfig` |

### 🔌 Ethernet y Bluetooth

| Interfaz | Detalle |
|---|---|
| Ethernet | Consultar con `Get-NetAdapter` |
| Bluetooth | Consultar con `Get-PnpDevice -Class Bluetooth` |

### 🌐 Redes virtuales

| Interfaz | IP | Uso |
|---|---|---|
| Consultar | — | Adaptadores `vEthernet` (WSL/Hyper-V) o VMware |

> ⚠️ **No aplica en Windows:** las interfaces `docker0`, `vmnet1`/`vmnet8` con esos
> nombres exactos no existen. En Windows aparecen como `vEthernet (WSL)`,
> `vEthernet (Default Switch)` o adaptadores VMware. Consultar:
> ```powershell
> Get-NetAdapter | Select-Object Name,InterfaceDescription,Status,LinkSpeed
> netsh wlan show interfaces
> ipconfig /all
> ```

## 🌡️ Sensores

| Sensor | Valor |
|---|---|
| GPU NVIDIA | Consultar con `nvidia-smi` |
| CPU | Consultar (requiere herramienta externa) |

> ⚠️ **No aplica en Windows:** no existe el comando `sensors` (LM-sensors).
> La temperatura de la GPU se lee con `nvidia-smi`; la de CPU no está expuesta
> de forma nativa y requiere herramientas externas (HWiNFO, OpenHardwareMonitor).
> ```powershell
> nvidia-smi --query-gpu=name,temperature.gpu,power.draw --format=csv
> ```

---

## 🛠️ Cómo consultar el hardware

> ⚠️ **No aplica en Windows:** el script `hardware-query.py` y la función de shell
> `hw_query` del proyecto Linux **no están portados todavía** a Windows (pendiente).
> Usar los cmdlets de PowerShell equivalentes:

| Comando | Descripción |
|---|---|
| `Get-CimInstance Win32_Processor \| Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed` | CPU |
| `Get-CimInstance Win32_PhysicalMemory \| Select-Object BankLabel,Capacity,Speed` | Módulos de RAM |
| `Get-CimInstance Win32_ComputerSystem \| Select-Object TotalPhysicalMemory` | RAM total |
| `Get-CimInstance Win32_VideoController` | GPU(s) |
| `nvidia-smi` | Detalle de la GPU NVIDIA |
| `Get-PSDrive -PSProvider FileSystem` | Unidades y espacio |
| `Get-PhysicalDisk` | Discos físicos |
| `Get-NetAdapter` | Adaptadores de red |
| `Get-CimInstance Win32_BaseBoard` / `Win32_BIOS` | Placa base y BIOS |

> 📁 Índice de hardware (cuando se porte el script): `C:\Users\evo01\.config\opencode\data\hardware\index.json`
