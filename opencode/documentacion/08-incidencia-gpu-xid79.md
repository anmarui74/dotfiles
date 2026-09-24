# 💥 Incidencia GPU — Xid 79 (GPU caída del bus PCIe)
Registro del cuelgue del equipo del 22/09/2026 por caída de la GPU NVIDIA del bus PCIe (Xid 79).

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 🔴 Incidencia · pendiente revisión de hardware | 22/09/2026 · rev. 22/09/2026 | Antonio |

> El equipo se quedó bloqueado (sesión gráfica muerta) durante una auditoría de
> seguridad. El análisis de los logs demuestra que la causa fue la **GPU
> (Xid 79, "GPU has fallen off the bus")**, no la auditoría ni falta de memoria.

---

## 📑 Índice
1. [Resumen](#resumen)
2. [Cronología del incidente](#cronología-del-incidente)
3. [Evidencia en los logs](#evidencia-en-los-logs)
4. [Causa raíz](#causa-raíz)
5. [Qué NO fue (verificación)](#qué-no-fue-verificación)
6. [Recomendaciones](#recomendaciones)
7. [Monitorización y comandos útiles](#monitorización-y-comandos-útiles)
8. [Estado actual](#estado-actual)

---

## Resumen

El **22/09/2026 a las 06:20:52**, mientras se ejecutaba una auditoría de seguridad
(de solo lectura), la GPU **NVIDIA GeForce RTX 4070 Ti SUPER** (PCI `0000:01:00.0`)
se cayó del bus PCIe y el kernel emitió:

```
NVRM: Xid (PCI:0000:01:00): 79, pid=5344, name=gnome-shell, GPU has fallen off the bus.
NVRM: GPU 0000:01:00.0: GPU has fallen off the bus.
```

Al perderse la GPU, abortaron todos los procesos que usaban `libnvidia-eglcore`
(`gnome-shell`, `Xwayland`, `kitty`) y el TTS `speak-kokoro-gpu` (ONNX Runtime CUDA).
Sin servidor gráfico, la sesión quedó inutilizable → reinicio manual a las 06:21:59.

---

## Cronología del incidente

| Hora | Evento |
|------|--------|
| 06:09:03 | Arranque del sistema (kernel 7.2.6-1-cachyos) |
| 06:10:59 – ~06:15 | 🛡️ Auditoría de seguridad en curso (**solo lectura**, carga de CPU/disco) |
| **06:20:52** | 💥 **Xid 79: la GPU se cae del bus PCIe** |
| 06:20:55 | Aborta `speak-kokoro-gpu` (ONNX Runtime CUDA) — core de 242,6 MB |
| 06:21:04 – 06:21:05 | Abortan `gnome-shell`, `Xwayland` y `kitty` (`libnvidia-eglcore`) |
| 06:21:59 | 🔄 Reinicio manual → sistema operativo de nuevo |
| 06:22:00+ | ✅ Sistema y GPU funcionando con normalidad |

> 📌 En el journal del arranque afectado hay **5904 mensajes NVRM/Xid**, todos en
> cascada del único evento Xid 79 inicial.

---

## Evidencia en los logs

| Comprobación | Resultado |
|--------------|-----------|
| `NVRM: Xid ... 79 ... GPU has fallen off the bus` | ✅ Presente (22/09/2026 06:20:52) |
| Coredumps `SIGABRT` | `speak-kokoro-gpu`, `gnome-shell`, `Xwayland`, `kitty` (06:20:55–06:21:05) |
| OOM / `out of memory` / `hung task` | ❌ Ninguno (61 GB RAM, 7 GB usados) |
| `last` del arranque afectado | `antonio tty2 06:09 - crash (00:12)` |
| Coredumps previos | Solo los 4 de este incidente |

Backtraces relevantes (todos terminan en la biblioteca NVIDIA):

```
speak-kokoro-gpu: ... libonnxruntime_providers_cuda.so ... abort (SIGABRT)
gnome-shell:      ... libnvidia-eglcore.so.615.71.09 ... abort (SIGABRT)
Xwayland:         ... libnvidia-eglcore.so.615.71.09 ... abort (SIGABRT)
kitty:            ... libEGL_nvidia.so.0 / libnvidia-eglcore.so.615.71.09 ... abort
```

---

## Causa raíz

**Xid 79 = "GPU has fallen off the bus"**: error de nivel de bus PCIe / hardware /
firmware. La GPU deja de responder y el driver no puede recuperarla.

| Dato | Valor |
|------|-------|
| GPU | NVIDIA GeForce RTX 4070 Ti SUPER (PCI `01:00.0`, VBIOS 95.03.45.C0.10) |
| Driver | **615.71.09** (open kernel module), instalado el 11/09/2026 |
| Firmware GSP | `linux-firmware-nvidia 1:20260916-1` (actualizado el 19/09/2026) |
| `EnableGpuFirmware` | 18 → GSP activado |
| ASPM PCIe | `default` |
| Límite de potencia | 285 W |
| Episodio previo | `crash` el 16/09/2026 17:15 (logs ya rotados, causa no confirmada) |
| Carga en el momento del fallo | LM Studio (11,4 GB VRAM) + TTS ONNX CUDA + escritorio |

Causas probables, por orden de frecuencia:

1. 🔌 **Alimentación / contacto PCIe** (cable 12VHPWR/PCIe mal asentado, PSU justa ante picos transitorios).
2. 🧩 **Inestabilidad del enlace PCIe** (ASPM agresivo, riser, slot).
3. 🐞 **Bug de driver / firmware GSP**.
4. 🌡️ **Temperatura** o overclock/undervolt inestable.

---

## Qué NO fue (verificación)

| Hipótesis | Veredicto | Motivo |
|-----------|-----------|--------|
| La auditoría de seguridad | ❌ Descartada | Fue 100 % de solo lectura; no usó la GPU ni tocó kernel/servicios/sysctl. Los únicos ficheros creados (`/tmp/opencode/`) los borró el reinicio (`/tmp` es tmpfs). |
| Falta de memoria (OOM) | ❌ Descartada | Sin mensajes OOM; 61 GB de RAM con solo 7 GB usados. |
| Bloqueo por I/O del `find`/`grep` | ❌ Descartada | No hubo `hung task` ni `blocked for more than`; Xid 79 es un fallo de bus, no de disco. |

> ✅ Conclusión: el fallo es de **hardware/driver de la GPU**. La coincidencia
> temporal con la auditoría es casual.

---

## Recomendaciones

### 🔧 Hardware (prioritario)
1. Apagar, **reapretar la GPU** en el slot y **reconectar el cable de alimentación** hasta el clic.
2. Usar **cables PCIe/12VHPWR separados** (evitar daisy-chain).
3. Revisar la **potencia de la PSU** (una 4070 Ti SUPER con picos + CPU puede rozar el límite).
4. Medir **temperaturas bajo carga** (LM Studio + TTS a la vez) con `nvidia-smi dmon`.
5. Si persiste, valorar **RMA/garantía**.

### 💻 Software (paliativos, reversibles)
| Medida | Comando / cambio |
|--------|------------------|
| Desactivar ASPM PCIe | añadir `pcie_aspm=off` a la línea del kernel |
| Revertir firmware GSP | volver a `linux-firmware-nvidia 1:20260910-1` |
| Limitar potencia GPU | `nvidia-smi -pl 250` (o servicio al arranque) |
| Evitar CUDA concurrente | no usar LM Studio y TTS GPU a la vez (o TTS en CPU) |
| Journal persistente | activar `Storage=persistent` en `journald.conf` |
| Vigilante de Xid | script + timer que registre cualquier `Xid`/`NVRM` |

---

## Monitorización y comandos útiles

```bash
# Ver Xid/NVRM del arranque actual
journalctl -b -k | grep -iE 'Xid|NVRM|fallen off'

# Ver Xid/NVRM de un arranque anterior (p. ej. el que cascó)
journalctl -b -1 -k | grep -iE 'Xid|NVRM'

# Coredumps recientes
coredumpctl list
coredumpctl info <PID>

# Estado y potencia de la GPU
nvidia-smi
nvidia-smi -q -d POWER
nvidia-smi dmon            # monitor en vivo (temp, potencia, uso)

# Versión de driver y firmware
cat /proc/driver/nvidia/version
cat /proc/driver/nvidia/params | grep -iE 'EnableGpuFirmware|PreserveVideoMemory'
```

---

## Estado actual

| Elemento | Estado |
|----------|--------|
| Sistema | ✅ Operativo (reiniciado a las 06:21:59) |
| GPU | ✅ Funcionando (RTX 4070 Ti SUPER, 47 °C en reposo) |
| Driver | ✅ 615.71.09 cargado |
| Cambios aplicados | ❌ Ninguno (a la espera de revisar el hardware) |

---

> 📁 Este manual vive en `~/.config/opencode/documentacion/08-incidencia-gpu-xid79.md`
> (activo) y `~/Config/opencode/documentacion/08-incidencia-gpu-xid79.md` (backup).
> Se sincroniza automáticamente con `sync-opencode.sh`.
