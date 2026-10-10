# 📝 Informe del sistema — procedimiento
Cómo generar un informe completo del equipo (hardware, SMART, btrfs, sensores) elevando privilegios con `pkexec`.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/10/2026 · rev. 10/10/2026 | Antonio |

> Procedimiento empleado para generar/revisar `~/informe-sistema.md` el **10/10/2026**, con volcado privilegiado verificado (1.463 líneas).

---

## 📑 Índice
1. [Requisitos previos](#requisitos-previos)
2. [El script `sysinfo-priv.sh`](#el-script-sysinfo-privsh)
3. [Ejecución con `pkexec`](#ejecución-con-pkexec)
4. [Qué recopila](#qué-recopila)
5. [Estructura del informe resultante](#estructura-del-informe-resultante)
6. [Detalles y avisos](#detalles-y-avisos)

---

## Requisitos previos

| Herramienta | Paquete | Uso |
|---|---|---|
| `inxi` | `inxi` | Resumen general (CPU, RAM, GPU, red, discos, sensores) |
| `dmidecode` | `dmidecode` | Placa base, BIOS y módulos DIMM (requiere root) |
| `smartctl` | `smartmontools` | Salud SMART de todos los discos (requiere root) |
| `nvidia-smi` | `nvidia-utils` | Estado y detalle de la GPU NVIDIA |
| `btrfs` | `btrfs-progs` | Uso, subvolúmenes y estado de scrub (requiere root) |
| `sensors` | `lm_sensors` | Temperaturas y vatios (CPU, GPU, NVMe, SPD…) |
| `pkexec` | `polkit` | Elevación gráfica de privilegios (agente → ventana de contraseña) |

> ⚠️ **`sudo` NO se usa como agente.** Como agente no hay terminal interactiva; se usa **`pkexec`**, que muestra una ventana gráfica de polkit. Los scripts que Antonio ejecuta a mano en su terminal sí pueden usar `sudo`.

---

## El script `sysinfo-priv.sh`

Script que agrupa **todos** los comandos privilegiados en una sola ejecución (una única petición de contraseña). Guardado durante la generación en `/tmp/opencode/sysinfo-priv.sh`:

```bash
#!/usr/bin/bash
# Reproduce los comandos privilegiados del informe del sistema.
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

echo "#################### INXI (root) ####################"
inxi -Fxxxza --no-host 2>&1

echo
echo "#################### DMIDECODE (0,1,2,16,17) ####################"
dmidecode -t 0,1,2,16,17 2>&1

echo
echo "#################### SMARTCTL -a (6 discos) ####################"
for d in nvme0n1 nvme1n1 sda sdb sdc sdd; do
  echo "===== /dev/$d ====="
  smartctl -a /dev/$d 2>&1
  echo
done

echo
echo "#################### NVIDIA-SMI ####################"
nvidia-smi 2>&1
echo "----- nvidia-smi -q -----"
nvidia-smi -q 2>&1

echo
echo "#################### BTRFS ####################"
echo "--- filesystem usage / ---"
btrfs filesystem usage / 2>&1
echo "--- filesystem show ---"
btrfs filesystem show 2>&1
echo "--- scrub status / ---"
btrfs scrub status / 2>&1

echo
echo "#################### SENSORS ####################"
sensors 2>&1
```

---

## Ejecución con `pkexec`

**Clave:** el agente no hereda la sesión gráfica, así que hay que **exportar el entorno de GNOME** antes de llamar a `pkexec`; de lo contrario este no alcanza al agente polkit y falla *«must be setuid root»* sin mostrar ventana.

```bash
chmod +x /tmp/opencode/sysinfo-priv.sh
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"
export XDG_RUNTIME_DIR="/run/user/1000"
pkexec /usr/bin/bash /tmp/opencode/sysinfo-priv.sh > /tmp/opencode/sysinfo-privado.txt 2>&1
echo "Exit: $?"
wc -l /tmp/opencode/sysinfo-privado.txt
```

- Aparece la **ventana de polkit** pidiendo la contraseña.
- El volcado completo queda en `/tmp/opencode/sysinfo-privado.txt`.
- Salida de referencia del 10/10/2026: **Exit 0**, **1.463 líneas**.

> 💡 El índice de hardware (`data/hardware/index.json`) se regenera con `python3 ~/.config/opencode/hardware-query.py scan` (usa `dmidecode` vía `pkexec`; necesita el mismo export del entorno GNOME).

---

## Qué recopila

| Bloque | Comando | Datos que aporta |
|---|---|---|
| **inxi** | `inxi -Fxxxza --no-host` | Sistema, placa, CPU, gráficas (EGL/OpenGL/Vulkan), audio, red, discos, particiones, swap, sensores |
| **dmidecode** | `dmidecode -t 0,1,2,16,17` | BIOS/firmware, placa base (S/N), array de memoria, módulos DIMM (marca, part number, velocidad, voltaje) |
| **smartctl** | `smartctl -a /dev/{nvme0n1,nvme1n1,sda,sdb,sdc,sdd}` | Salud SMART, horas, ciclos, unidades escritas, UDMA_CRC, sectores reasignados/pendientes |
| **nvidia-smi** | `nvidia-smi` + `nvidia-smi -q` | VRAM, temperatura, consumo, PCIe, VBIOS, UUID, procesos de la GPU |
| **btrfs** | `btrfs filesystem usage/show` + `scrub status` | Uso/asignación, perfiles (single/DUP), subvolúmenes y estado del scrub |
| **sensors** | `sensors` | Temperaturas y vatios de CPU, GPU, NVMe, SPD (RAM), WiFi, NIC, xHCI |

---

## Estructura del informe resultante

El informe (`~/informe-sistema.md`) sigue este orden, todo en **tablas Markdown nativas**:

1. **Resumen del equipo** · 2. **Sistema operativo y software** · 3. **CPU** (con vulnerabilidades) · 4. **Memoria RAM** (DIMMs + swap/zram) · 5. **Gráficas** (NVIDIA, iGPU, monitores) · 6. **Almacenamiento** (discos, particiones, SMART, btrfs) · 7. **Red** (WiFi/Ethernet/Bluetooth) · 8. **Audio** · 9. **Sensores** · 10. **Incidencias detectadas** · 11. **Recomendaciones** · **Anexo** con el método.

> 📌 Reglas de formato: fechas `dd/mm/aaaa`, hora 24 h, decimales con **coma**, unidades del sistema métrico (km/h, °C, GiB) y tablas Markdown (nunca bloques ASCII).

---

## Detalles y avisos

- **`inxi` como root sí obtiene las API gráficas** (EGL/OpenGL/Vulkan); con el sandbox del agente a veces no.
- **`inxi` agrega el BogoMIPS** sumando los hilos (p. ej. 7.399,88 × 24 ≈ 177.597); el valor real de `/proc/cpuinfo` es el **por hilo**.
- **Resolución de pantalla:** `xrandr` bajo **Xwayland** reporta un tamaño hinchado (×1,5); el escaneo `hardware-query.py scan` **ya lee `~/.config/monitors.xml`** para dar la resolución/escala reales (fuente alternativa: `/sys/class/drm/*/modes`).
- **Almacenamiento:** `hardware-query.py` usa `lsblk --json` (no texto) para no desalinear columnas vacías; así `fstype`/`mountpoint` reflejan el FS y los montajes reales y el modelo no acaba en la columna `fstype`.
- **Bluetooth:** el estado real se comprueba con `bluetoothctl show` (`Powered: yes/no`) o `btmgmt`; el servicio `bluetooth` puede estar `active` con el controlador apagado o al revés.
- **`index.json`:** al contrastar, sus campos de almacenamiento pueden venir desordenados (marca/modelo) — el volcado `pkexec` es la fuente fiable.
- El script `sysinfo-priv.sh` **no forma parte del instalador** `setup-opencode-completo.sh`; es una herramienta puntual. El manual `hardware-info.md` sí está embebido y su heredoc debe coincidir con el archivo activo (`check-setup-completo.sh`).

---

> 📁 `~/.config/opencode/documentacion/09-informe-sistema.md` · `~/Config/opencode/documentacion/09-informe-sistema.md`
> 🔧 Volcados de ejemplo: `/tmp/opencode/sysinfo-priv.sh` · `/tmp/opencode/sysinfo-privado.txt`
> 📊 Hardware del equipo: [hardware-info.md](hardware-info.md)
