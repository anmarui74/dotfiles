# 💥 Incidencia GPU — Xid 79 (GPU caída del bus PCIe) en Windows
Registro del fallo de la GPU NVIDIA RTX 4070 Ti SUPER (caída del bus PCIe, Xid 79) y cómo detectarlo y tratarlo desde Windows.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 🔴 Incidencia · pendiente revisión de hardware | 22/09/2026 · rev. 10/10/2026 | Antonio |

> El evento **Xid 79** se detectó el **22/09/2026** arrancando **Linux** (el equipo se
> quedó bloqueado). Como es un fallo de **hardware compartido** (equipo dual boot), este
> manual documenta qué es, cómo se detecta **desde Windows** y qué medidas aplicar.

---

## 📑 Índice
1. [Qué es el Xid 79](#qué-es-el-xid-79)
2. [El incidente del 22/09/2026](#el-incidente-del-22092026)
3. [Cómo detectarlo en Windows](#cómo-detectarlo-en-windows)
4. [Causa raíz](#causa-raíz)
5. [Recomendaciones](#recomendaciones)
6. [Monitorización](#monitorización)
7. [Estado actual](#estado-actual)

---

## Qué es el Xid 79

`Xid 79` = **«GPU has fallen off the bus»**: la GPU deja de responder en el bus PCIe y el
driver no puede recuperarla. Es un error de **nivel de bus / hardware / firmware**, no del
software de usuario (aunque la primera señal suele ser que se caen las aplicaciones que usan
la GPU: LM Studio, el TTS con CUDA, el escritorio…).

En Linux el kernel lo registra así:

```text
NVRM: Xid (PCI:0000:01:00): 79, pid=5344, name=gnome-shell, GPU has fallen off the bus.
NVRM: GPU 0000:01:00.0: GPU has fallen off the bus.
```

En **Windows** el mismo fallo lo registra el driver NVIDIA (`nvlddmkm`) en el Visor de
eventos y suele provocar un **TDR** (Time-out Detection and Recovery) o la pérdida de la
señal de vídeo.

---

## El incidente del 22/09/2026

El equipo (mismo hardware que se usa en Windows) se bloqueó a las **06:20:52** mientras se
ejecutaba una auditoría **de solo lectura**:

| Hora | Evento |
|------|--------|
| 06:09:03 | Arranque del sistema (Linux) |
| 06:10:59 – ~06:15 | 🛡️ Auditoría de seguridad en curso (solo lectura) |
| **06:20:52** | 💥 **Xid 79: la GPU se cae del bus PCIe** |
| 06:20:55 | Aborta el TTS con CUDA (`speak-kokoro-gpu`) |
| 06:21:04 – 06:21:05 | Abortan el escritorio (`gnome-shell`, `Xwayland`, `kitty`) |
| 06:21:59 | 🔄 Reinicio manual · sistema operativo de nuevo |
| 06:22:00+ | ✅ Sistema y GPU funcionando con normalidad |

> 📌 En Windows el síntoma equivalente sería: **pantalla negra / señal perdida**, TDR
> repetido o cuelgue del escritorio, con eventos `nvlddmkm` en el Visor de eventos.

Causas probables, por orden de frecuencia:

1. 🔌 **Alimentación / contacto PCIe** (cable 12VHPWR/PCIe mal asentado, PSU justa ante picos).
2. 🧩 **Inestabilidad del enlace PCIe** (ASPM agresivo, riser, slot).
3. 🐞 **Bug de driver / firmware GSP**.
4. 🌡️ **Temperatura** o overclock/undervolt inestable.

---

## Cómo detectarlo en Windows

| Fuente | Cómo |
|--------|------|
| **Visor de eventos** | `Get-WinEvent -LogName System` filtrando por origen `nvlddmkm` / `Display` (busca eventos de reinicio del driver / TDR) |
| **TDR (driver timeout)** | Evento de sistema «El controlador de pantalla `nvlddmkm` dejó de responder y se ha recuperado» |
| **WHEA** | `Get-WinEvent -LogName System -ProviderName Microsoft-Windows-WHEA-Logger` — errores de bus PCIe/corrected-uncorrected |
| **nvidia-smi** | `nvidia-smi -q` → estado de la GPU, páginas retiradas (`Remapped rows` / `Retired pages`), errores ECC |
| **Monitor de confiabilidad** | «Monitor de confiabilidad» de Windows: caídas de `nvlddmkm`/aplicaciones con GPU |

```powershell
# Eventos del driver NVIDIA (últimos 50)
Get-WinEvent -LogName System -MaxEvents 2000 |
  Where-Object { $_.ProviderName -match 'nvlddmkm|Display|WHEA' } |
  Select-Object -First 50 TimeCreated, ProviderName, Id, LevelDisplayName, Message

# Errores de hardware de plataforma (PCIe) reportados por la CPU/chipset
Get-WinEvent -LogName System -ProviderName 'Microsoft-Windows-WHEA-Logger' -ErrorAction SilentlyContinue |
  Select-Object TimeCreated, Id, Message

# Estado/detalle de la GPU
nvidia-smi
nvidia-smi -q -d POWER
nvidia-smi --query-gpu=name,temperature.gpu,power.draw,clocks.sm,pcie.link.gen.current,pcie.link.width.current --format=csv
```

---

## Causa raíz

**Xid 79 = error de bus PCIe / hardware / firmware.** La GPU deja de responder y el driver
no la recupera (en Windows solo consigue recuperarla un reinicio).

| Dato | Valor |
|------|-------|
| GPU | NVIDIA GeForce RTX 4070 Ti SUPER (PCI `01:00.0`) |
| VRAM | ~16 GB (17 170 956 288 bytes) |
| Driver (Linux, incidente) | 615.71.09 (open kernel module) |
| Driver (Windows) | Consultar con `nvidia-smi` (debe ser **Game Ready / Studio** reciente) |
| Episodio previo | 16/09/2026 (Linux, causa no confirmada) |
| Carga en el fallo | LM Studio (11,4 GB VRAM) + TTS ONNX CUDA + escritorio |

> ✅ Se verificó que **no** fue la auditoría (solo lectura), ni OOM (61 GB de RAM con 7 GB
> usados), ni I/O de disco: Xid 79 es un fallo de bus.

---

## Recomendaciones

### 🔧 Hardware (prioritario)
1. Apagar, **reapretar la GPU** en el slot y **reconectar el cable de alimentación** hasta el clic.
2. Usar **cables PCIe/12VHPWR separados** (evitar daisy-chain).
3. Revisar la **potencia de la PSU** (una 4070 Ti SUPER con picos + CPU puede rozar el límite).
4. Medir **temperaturas bajo carga** (LM Studio + TTS a la vez): `nvidia-smi dmon` o `nvidia-smi --query-gpu=temperature.gpu,power.draw --format=csv -l 1`.
5. Si persiste, valorar **RMA/garantía**.

### 💻 Software (Windows, paliativos y reversibles)
| Medida | Cómo |
|--------|------|
| Desactivar ASPM PCIe | Plan de energía → «Administración de energía del estado de vínculo PCI Express» → **Desactivado** (tanto en «Enchufado» como «Con batería») |
| Limitar potencia GPU | `nvidia-smi -pl 250` (o crear una tarea programada al inicio que lo aplique) |
| Alejar el umbral TDR | Añadir `TdrDelay` (p. ej. 10 s) en `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` (evita reinicios del driver en picos, **no** arregla el Xid 79) |
| Evitar CUDA concurrente | no usar LM Studio y el TTS GPU a la vez (o el TTS en CPU) |
| Driver actualizado | instalar el último **Game Ready/Studio** de NVIDIA y, si el fallo empezó tras un driver, **revertir** |
| Registro persistente | activar el **Visor de eventos** con tamaño de log ampliado y **eventos de arranque** guardados |

---

## Monitorización

```powershell
# Estado y potencia de la GPU
nvidia-smi
nvidia-smi -q -d POWER
nvidia-smi dmon

# Monitor en vivo (temperatura, potencia, uso)
nvidia-smi --query-gpu=timestamp,name,temperature.gpu,power.draw,utilization.gpu,memory.used --format=csv -l 2

# Buscar Xid/TDR/driver NVIDIA en el Visor de eventos desde un arranque concreto
Get-WinEvent -LogName System |
  Where-Object { $_.ProviderName -match 'nvlddmkm|Display' } |
  Select-Object TimeCreated, ProviderName, Id, Message
```

> 💡 En un equipo dual boot conviene comprobar **también** el log del lado Linux
> (`journalctl -b -1 -k | grep -iE 'Xid|NVRM'`) para correlacionar: si el Xid aparece en
> ambos sistemas, es hardware con casi total seguridad.

---

## Estado actual

| Elemento | Estado |
|----------|--------|
| Sistema Windows | ✅ Operativo |
| GPU | ✅ Funcionando (RTX 4070 Ti SUPER) |
| Driver (Windows) | ✅ Consultar versión con `nvidia-smi` |
| Cambios aplicados | ❌ Ninguno (a la espera de revisar el hardware) |

---

> 📁 Este manual vive en `D:\Linux\Config\opencode-win\documentacion\08-incidencia-gpu-xid79.md` (backup)
> y se publica en Obsidian como `💻 Windows 08 Incidencia GPU Xid 79.md`.
> 📊 Hardware del equipo: [hardware-info.md](hardware-info.md) · 🔗 Herramientas: [README-hardware.md](README-hardware.md)
