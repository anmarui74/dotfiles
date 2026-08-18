#!/usr/bin/env python3
# ============================================================
# hardware-query.py — Auditoría completa de hardware (Linux)
#
# Uso:
#   hardware-query.py scan             → escanea TODO el hardware y
#                                        actualiza data/hardware/index.json
#   hardware-query.py status           → resumen legible del hardware
#   hardware-query.py <campo>          → imprime el JSON de un campo
#   hardware-query.py --campos         → lista los campos disponibles
#
# Campos: status, cpu, gpu, ram, motherboard, wifi, bluetooth,
#         all, os, storage, displays, audio, usb, sensors, network, ...
# (y cualquier otra clave presente en el index.json)
#
# El modo "scan" recolecta datos con las herramientas nativas del
# sistema (lscpu, lspci, lsusb, nvidia-smi, sensors, lsblk, dmidecode,
# iw, ip, xrandr, free, /proc...) y regenera el índice al completo.
# ============================================================
import datetime
import json
import os
import re
import subprocess
import sys
from typing import Any

DATA_DIR = "/home/antonio/.config/opencode/data/hardware"
HARDWARE_PATH = os.path.join(DATA_DIR, "index.json")

# Tipos auxiliares para dicts heterogéneos (JSON-like)
JsonDict = dict[str, Any]

CAMPOS_AYUDA = ("status", "cpu", "gpu", "ram", "motherboard", "wifi",
                "bluetooth", "all", "os", "storage", "displays", "audio",
                "usb", "sensors", "network", "pci", "bios")


# ─────────────────────────────────────────────────────────────
# Utilidades de ejecución
# ─────────────────────────────────────────────────────────────
def run(cmd, timeout=15):
    """Ejecuta un comando y devuelve su stdout (str) o '' si falla."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=timeout, errors="replace")
        return r.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return ""


def run_root(cmd, timeout=20):
    """Ejecuta con pkexec (ventana gráfica de contraseña) si es necesario."""
    try:
        r = subprocess.run(["pkexec"] + cmd, capture_output=True, text=True,
                           timeout=timeout, errors="replace")
        return r.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return ""


def leer_proc(path):
    """Lee un archivo de /proc. Devuelve str o ''."""
    try:
        with open(path) as f:
            return f.read()
    except (OSError, FileNotFoundError):
        return ""


def json_ok(texto):
    """True si el texto es JSON parseable."""
    try:
        json.loads(texto)
        return True
    except (json.JSONDecodeError, TypeError):
        return False


# ─────────────────────────────────────────────────────────────
# Recolección de cada sección
# ─────────────────────────────────────────────────────────────
def seccion_os():
    os_data = {}
    # Distribución
    etc = leer_proc("/etc/os-release")
    for line in etc.splitlines():
        if line.startswith("PRETTY_NAME="):
            os_data["distribution"] = line.split("=", 1)[1].strip('"')
        elif line.startswith("ID="):
            os_data["distro_id"] = line.split("=", 1)[1].strip('"')
    if "distribution" not in os_data:
        os_data["distribution"] = run(["cat", "/etc/os-release"])[:80]

    os_data["kernel"] = run(["uname", "-r"])
    os_data["kernel_type"] = run(["uname", "-v"])[:40]
    os_data["arch"] = run(["uname", "-m"])
    os_data["hostname"] = run(["hostname"])
    os_data["shell"] = os.environ.get("SHELL", "")

    # Desktop / sesión
    xdg = os.environ.get("XDG_CURRENT_DESKTOP", "")
    os_data["desktop"] = xdg if xdg else run(["echo", "$XDG_CURRENT_DESKTOP"])
    os_data["display_server"] = os.environ.get("XDG_SESSION_TYPE", "")

    # Tiempo / carga
    os_data["uptime"] = run(["uptime", "-p"])
    os_data["boot_time"] = run(["uptime", "-s"])
    try:
        with open("/proc/loadavg") as f:
            os_data["load_avg"] = [float(x) for x in f.read().split()[:3]]
    except (OSError, ValueError):
        pass

    # Localización
    os_data["locale"] = run(["locale"]).splitlines()[0] if run(["locale"]) else ""
    tz = run(["timedatectl", "show", "-p", "TimeZone", "--value"])
    if not tz:
        try:
            tz = os.path.realpath("/etc/localtime").replace("/usr/share/zoneinfo/", "")
        except OSError:
            tz = ""
    os_data["timezone"] = tz
    return os_data


def seccion_cpu():
    salida = run(["lscpu"])
    cpu = {}
    map_es = {
        "Nombre del modelo": "model",
        "Model name": "model",
        "Fabricante": "vendor",
        "Vendor ID": "vendor",
        "Arquitectura": "arch",
        "Architecture": "arch",
        "CPU(s)": "threads",
        "Hilo(s) de procesamiento por núcleo": "threads_per_core",
        "Thread(s) per core": "threads_per_core",
        "Núcleo(s) por socket": "cores_per_socket",
        "Núcleo(s) por «socket»": "cores_per_socket",
        "Core(s) per socket": "cores_per_socket",
        "Socket(s)": "sockets",
        "Familia de CPU": "familia",
        "CPU family": "familia",
        "Modelo": "modelo",
        "Model": "modelo",
        "Virtualización": "virtualization",
        "Virtualization": "virtualization",
        "Caché L1d": "cache_l1d",
        "L1d cache": "cache_l1d",
        "Caché L1i": "cache_l1i",
        "L1i cache": "cache_l1i",
        "Caché L2": "cache_l2",
        "L2 cache": "cache_l2",
        "Caché L3": "cache_l3",
        "L3 cache": "cache_l3",
        "CPU MHz máx.": "speed_max_mhz",
        "CPU max MHz": "speed_max_mhz",
        "CPU MHz mín.": "speed_min_mhz",
        "CPU min MHz": "speed_min_mhz",
        "Modo(s) NUMA": "numa_nodes",
        "NUMA node(s)": "numa_nodes",
    }
    for line in salida.splitlines():
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip()
        if key in map_es:
            campo = map_es[key]
            if campo == "threads":
                cpu["threads"] = int(val.split()[0])
            elif campo == "cores_per_socket":
                cpu["cores"] = int(val.split()[0])
            elif campo == "speed_max_mhz":
                try:
                    cpu["speed_max_mhz"] = round(float(val.split()[0]), 2)
                except ValueError:
                    pass
            elif campo == "speed_min_mhz":
                try:
                    cpu["speed_min_mhz"] = round(float(val.split()[0]), 2)
                except ValueError:
                    pass
            else:
                cpu[campo] = val

    # /proc/cpuinfo para vendor, stepping, microcode, bogomips
    info = leer_proc("/proc/cpuinfo")
    if "vendor_id" in info:
        for line in info.splitlines():
            if ":" not in line:
                continue
            k, _, v = line.partition(":")
            k, v = k.strip(), v.strip()
            if k == "vendor_id" and "vendor" not in cpu:
                cpu["vendor"] = v
            elif k == "stepping" and "stepping" not in cpu:
                cpu["stepping"] = v
            elif k == "microcode" and "microcode" not in cpu:
                cpu["microcode"] = v
            elif k == "bogomips" and "bogomips" not in cpu:
                cpu["bogomips"] = float(v.split()[0])

    # Vulnerabilidades
    vuln = {}
    for line in info.splitlines():
        if ":" not in line:
            continue
        k, _, v = line.partition(":")
        k, v = k.strip(), v.strip()
        if k in ("Vulnerability", "Vulnerabilidad"):
            continue
        if k.startswith("Vulnerability") or "mitigation" in v.lower() or "affected" in v.lower():
            vuln[k] = v
    # Mejor: leer de /sys/devices/system/cpu/vulnerabilities
    vulns_dir = "/sys/devices/system/cpu/vulnerabilities"
    if os.path.isdir(vulns_dir):
        vuln = {}
        for name in sorted(os.listdir(vulns_dir)):
            try:
                with open(os.path.join(vulns_dir, name)) as f:
                    vuln[name] = f.read().strip()
            except OSError:
                pass
    if vuln:
        cpu["vulnerabilities"] = vuln

    # Flags ISA (instrucciones soportadas)
    flags = []
    if "flags" in info:
        for line in info.splitlines():
            if line.startswith("flags"):
                flags = line.split(":", 1)[1].split()
                break
    if flags:
        cpu["flags_isa"] = flags
    return cpu


def seccion_ram():
    ram = {}
    try:
        with open("/proc/meminfo") as f:
            mem = f.read()
        m = re.search(r"MemTotal:\s+(\d+) kB", mem)
        if m:
            ram["total_kb"] = int(m.group(1))
            ram["total_gb"] = round(int(m.group(1)) / 1048576, 1)
        m = re.search(r"MemAvailable:\s+(\d+) kB", mem)
        if m:
            ram["available_gb"] = round(int(m.group(1)) / 1048576, 1)
        m = re.search(r"SwapTotal:\s+(\d+) kB", mem)
        if m:
            ram["swap_total_gb"] = round(int(m.group(1)) / 1048576, 1)
    except OSError:
        pass

    if ram.get("total_gb"):
        ram["usage_percent"] = round(
            (ram["total_gb"] - ram.get("available_gb", 0)) / ram["total_gb"] * 100, 1)

    # Dmidecode (RAM detallada) — requiere root
    dmi = run_root(["dmidecode", "-t", "memory"])
    if dmi:
        speed = re.search(r"Configured Memory Speed:\s*(\d+) MT/s", dmi)
        if speed:
            ram["speed_mts"] = int(speed.group(1))
        mod = re.search(r"Part Number:\s*(\S+)", dmi)
        if mod:
            ram["module_id"] = mod.group(1)
        # Parsear por BLOQUES de Memory Device (cada bloque = un slot,
        # con su propio Size — así no se saltan los slots vacíos)
        dimms = []
        for bloque in re.split(r"\n\s*Memory Device\n", dmi):
            loc = re.search(r"Locator:\s*(DIMM\w+)", bloque)
            if not loc:
                continue
            tam = re.search(r"Size:\s*(\d+)\s*GiB", bloque)
            if tam:
                dimms.append({"slot": loc.group(1),
                              "size_gb": int(tam.group(1)),
                              "installed": True})
            else:
                dimms.append({"slot": loc.group(1),
                              "size_gb": 0,
                              "installed": False})
        ram["dimms"] = dimms
        ram["dimms_count"] = sum(1 for d in dimms if d["installed"])
        ram["dimms_total_slots"] = len(dimms)
        ranks = re.findall(r"Rank:\s*(\d+)", dmi)
        if ranks:
            ram["rank"] = int(ranks[0])

    # Zram (swap comprimido)
    if os.path.exists("/sys/block/zram0/disksize"):
        try:
            with open("/sys/block/zram0/disksize") as f:
                size = int(f.read().strip()) / 1073741824
            ram["swap"] = {
                "type": "zram",
                "device": "/dev/zram0",
                "size_gb": round(size, 1),
            }
            try:
                with open("/sys/block/zram0/comp_algorithm") as f:
                    ram["swap"]["algorithm"] = f.read().strip()
            except OSError:
                pass
        except (OSError, ValueError):
            pass
    return ram


def seccion_motherboard():
    mb = {}
    dmi = run_root(["dmidecode", "-t", "baseboard", "-t", "bios"])
    if not dmi:
        # Fallback sin root
        dmi = run(["dmidecode", "-t", "baseboard", "-t", "bios"])
    m = re.search(r"Manufacturer:\s*(.+)", dmi)
    if m:
        mb["vendor"] = m.group(1).strip()
    m = re.search(r"Product Name:\s*(.+)", dmi)
    if m:
        mb["model"] = m.group(1).strip()
        mb["product_name"] = m.group(1).strip()
    m = re.search(r"Version:\s*(\S+)", dmi)
    if m:
        mb["firmware_version"] = m.group(1).strip()
    m = re.search(r"BIOS Revision:\s*(.+)", dmi)
    if m:
        mb["bios_revision"] = m.group(1).strip()
    m = re.search(r"Release Date:\s*(.+)", dmi)
    if m:
        mb["bios_date"] = m.group(1).strip()
    m = re.search(r"Chassis Type:\s*(.+)", dmi)
    if m:
        mb["chassis_type"] = m.group(1).strip()
    mb["uefi"] = os.path.isdir("/sys/firmware/efi")
    return mb


def seccion_gpu_nvidia():
    gpu = {}
    smi = run(["nvidia-smi",
               "--query-gpu=name,driver_version,memory.total,memory.used,"
               "memory.free,temperature.gpu,power.draw,utilization.gpu,"
               "uuid,pcie.link.gen.current,pcie.link.width.current",
               "--format=csv,noheader,nounits"])
    if smi:
        parts = [p.strip() for p in smi.split(",")]
        if len(parts) >= 8:
            gpu["model"] = parts[0]
            gpu["driver"] = f"nvidia v{parts[1]}"
            gpu["driver_version"] = parts[1]
            try:
                gpu["vram_mib"] = int(parts[2])
                gpu["vram_gb"] = round(int(parts[2]) / 1024, 1)
                gpu["vram_used_mib"] = int(parts[3])
                gpu["vram_free_mib"] = int(parts[4])
                if int(parts[2]) > 0:
                    gpu["vram_usage_percent"] = round(
                        int(parts[3]) / int(parts[2]) * 100, 1)
                gpu["temperature_celsius"] = int(parts[5])
                gpu["power_watts"] = round(float(parts[6]), 2)
                gpu["utilization_percent"] = int(parts[7])
            except ValueError:
                pass
            if len(parts) >= 9:
                gpu["gpu_uuid"] = parts[8]
            if len(parts) >= 11:
                gpu["pcie_gen"] = parts[9]
                gpu["pcie_lanes"] = parts[10]

    # Arquitectura vía lspci
    lspci = run(["lspci"])
    for line in lspci.splitlines():
        if "VGA" in line and ("NVIDIA" in line or "AD10" in line):
            gpu["pci_line"] = line
            m = re.search(r"\[(AD\d+)\]", line)
            if m:
                gpu["device_id"] = m.group(1)
            m = re.search(r"\[([0-9a-f]{4}:[0-9a-f]{4})\]", line)
            if m:
                gpu["pci_id"] = m.group(1)
            break

    # Vulkan / CUDA
    nvcc = run(["nvcc", "--version"])
    m = re.search(r"release\s+([\d.]+)", nvcc)
    if m:
        gpu["cuda_version"] = m.group(1)
    # fallback: version.json
    if "cuda_version" not in gpu and os.path.exists("/opt/cuda/version.json"):
        try:
            with open("/opt/cuda/version.json") as f:
                gpu["cuda_version"] = json.load(f)["cuda"]["version"]
        except Exception:
            pass
    return gpu


def seccion_gpu_amd():
    gpu = {}
    lspci = run(["lspci"])
    for line in lspci.splitlines():
        if "VGA" in line and "AMD" in line:
            gpu["model"] = "AMD Radeon Graphics (integrated)"
            m = re.search(r"\[(1002:[0-9a-f]{4})\]", line)
            if m:
                gpu["pci_id"] = m.group(1)
            if "Raphael" in line:
                gpu["device_id"] = "Raphael"
            break
    gpu["driver"] = "amdgpu kernel"
    return gpu


def seccion_displays():
    displays: list[JsonDict] = []
    xrandr = run(["xrandr"], timeout=5)
    for line in xrandr.splitlines():
        if " connected" not in line:
            continue
        parts = line.split()
        conn = parts[0]
        # Resolución activa: "5760x3240+0+0" o "3840x2160+0+0"
        res = ""
        geom = next((p for p in parts if re.match(r"\d+x\d+\+\d+\+\d+", p)), "")
        if geom:
            res = geom.split("+")[0]
        d: JsonDict = {"interface": conn, "active_resolution": res}
        m = re.search(r"(\d+)mm x (\d+)mm", line)
        if m:
            w_cm, h_cm = int(m.group(1)) / 10, int(m.group(2)) / 10
            d["size_cm"] = f"{w_cm:.0f}x{h_cm:.0f}"
            diag = (w_cm ** 2 + h_cm ** 2) ** 0.5 / 2.54
            d["size_inches"] = round(diag, 1)
        d["primary"] = "primary" in line
        d["active_resolution"] = res
        displays.append(d)
    # Fallback: /sys/class/drm
    if not displays:
        for conn in sorted(os.listdir("/sys/class/drm")):
            if not conn.startswith("card") or "-" not in conn:
                continue
            try:
                with open(f"/sys/class/drm/{conn}/status") as f:
                    if f.read().strip() == "connected":
                        displays.append({"interface": conn.split("-", 1)[1]})
            except OSError:
                pass
    return displays


def seccion_storage():
    discos = []
    salida = run(["lsblk", "-b", "-o", "NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL"])
    actual = None
    for line in salida.splitlines()[1:]:
        nombre, resto = line.split(maxsplit=1) if line.strip() else ("", "")
        if nombre and not nombre.startswith(("└", "├", "`", "|")):
            # Disco físico
            parts = line.split()
            if len(parts) >= 3:
                model = " ".join(parts[5:]) if len(parts) > 5 else ""
                discos.append({
                    "name": parts[0],
                    "size_bytes": int(parts[1]),
                    "size_tb": round(int(parts[1]) / 1099511627776, 2),
                    "type": parts[2],
                    "fstype": parts[3] if len(parts) > 3 else "",
                    "mountpoint": parts[4] if len(parts) > 4 else "",
                    "model": model,
                })
    return discos


def seccion_network():
    red: JsonDict = {}

    # ── Información del CHIP WiFi (lspci) ──
    chip: JsonDict = {}
    lspci_out = run(["lspci", "-nn"])
    for line in lspci_out.splitlines():
        if "Network controller" in line and ("Qualcomm" in line or "802.11" in line or "WCN" in line):
            chip["pci_line"] = line
            m = re.search(r"Qualcomm Technologies, Inc (.+?)\s*\[", line)
            if m:
                chip["model"] = m.group(1).strip()
            m = re.search(r"\[([0-9a-f]{4}:[0-9a-f]{4})\]\s*\(rev (\d+)\)", line)
            if m:
                chip["pci_id"] = m.group(1)
                chip["revision"] = m.group(2)
            break
    # Subsistema (fabricante de la tarjeta instalada)
    sub = run(["lspci", "-nn", "-v", "-s", "07:00.0"])
    m = re.search(r"Subsystem: (.+?)\s*\[", sub)
    if m:
        chip["subsystem"] = m.group(1).strip()
    m = re.search(r"Kernel modules:\s*(\S+)", sub)
    if m:
        chip["kernel_module"] = m.group(1)

    # ── WiFi (estado actual) ──
    wifi: JsonDict = {}
    link = run(["iw", "dev", "wlan0", "link"])
    if link:
        for line in link.splitlines():
            line = line.strip()
            if line.startswith("SSID:"):
                wifi["connected_ssid"] = line.split(":", 1)[1].strip()
            elif "freq:" in line:
                wifi["frequency_mhz"] = int(float(line.split("freq:", 1)[1].split()[0]))
            elif "signal:" in line:
                wifi["signal_dbm"] = int(line.split("signal:", 1)[1].split()[0])
            elif "tx bitrate:" in line:
                parts = line.split("tx bitrate:", 1)[1].split()
                try:
                    wifi["tx_bitrate_mbps"] = float(parts[0])
                except ValueError:
                    pass
                m = re.search(r"(\d+)MHz", line)
                if m:
                    wifi["channel_width_mhz"] = int(m.group(1))
                m = re.search(r"(HE|VHT|HT)-\w+", line)
                if m:
                    wifi["phy_mode"] = m.group(0)
            elif "rx bitrate:" in line:
                parts = line.split("rx bitrate:", 1)[1].split()
                try:
                    wifi["rx_bitrate_mbps"] = float(parts[0])
                except ValueError:
                    pass
    if wifi:
        wifi["interface"] = "wlan0"
        wifi["driver"] = run(["sh", "-c", "readlink /sys/class/net/wlan0/device/driver | xargs basename"])
        # MAC + modo + wiphy
        info = run(["iw", "dev", "wlan0", "info"])
        m = re.search(r"addr\s+([0-9a-f:]+)", info)
        if m:
            wifi["mac"] = m.group(1)
        m = re.search(r"type\s+(\S+)", info)
        if m:
            wifi["mode"] = m.group(1)
        m = re.search(r"wiphy\s+(\d+)", info)
        if m:
            wifi["wiphy"] = int(m.group(1))
        # IP
        ip = run(["ip", "-4", "addr", "show", "wlan0"])
        m = re.search(r"inet\s+(\S+)", ip)
        if m:
            wifi["ip"] = m.group(1)
        # Bytes transmitidos/recibidos
        try:
            with open("/sys/class/net/wlan0/statistics/rx_bytes") as f:
                wifi["rx_bytes"] = int(f.read().strip())
            with open("/sys/class/net/wlan0/statistics/tx_bytes") as f:
                wifi["tx_bytes"] = int(f.read().strip())
        except OSError:
            pass
        # Señal mín/máx recientes (iwinfo o /proc)
        if chip:
            wifi["chipset"] = chip
        red["wifi"] = wifi

    # Ethernet
    eth = run(["ethtool", "enp8s0"])
    red["ethernet"] = {
        "interface": "enp8s0",
        "state": "down" if not eth or "Link detected: no" in eth else "up",
    }
    m = re.search(r"Speed:\s*(\d+\w+)", eth)
    if m:
        red["ethernet"]["speed"] = m.group(1)

    # Bluetooth
    bt = run(["bluetoothctl", "show"])
    if bt:
        m = re.search(r"Controller\s+([0-9A-F:]+)\s+(.+)", bt)
        if m:
            red["bluetooth"] = {
                "controller_mac": m.group(1),
                "name": m.group(2).strip(),
                "state": "up" if "Powered: yes" in bt else "down",
            }

    # Interfaces virtuales (docker/vmware)
    virtual = {}
    for iface in ("vmnet1", "vmnet8", "docker0"):
        ip = run(["ip", "-4", "addr", "show", iface])
        m = re.search(r"inet\s+(\S+)", ip)
        if m:
            virtual[iface] = {"ip": m.group(1)}
    if virtual:
        red["virtual"] = virtual
    return red


def seccion_sensors():
    sens = {}
    out = run(["sensors"])
    # Mapeo heurístico de los sensores más comunes
    patrones = {
        "Tctl": "cpu_tctl_celsius",
        "Tccd1": "cpu_tccd1_celsius",
        "Tccd2": "cpu_tccd2_celsius",
        "Composite": "nvme_composite_celsius",
        "edge": "gpu_amd_edge_celsius",
        "temp1": "temp1_celsius",
    }
    for line in out.splitlines():
        m = re.match(r"(\w+):\s+\+?([\d.]+)°C", line)
        if m:
            key, val = m.group(1), float(m.group(2))
            campo = patrones.get(key)
            if campo:
                sens[campo] = val
    # GPU NVIDIA
    smi = run(["nvidia-smi", "--query-gpu=temperature.gpu,power.draw",
               "--format=csv,noheader,nounits"])
    if smi:
        parts = [p.strip() for p in smi.split(",")]
        if len(parts) == 2:
            try:
                sens["gpu_nvidia_celsius"] = int(parts[0])
                sens["gpu_nvidia_power_watts"] = round(float(parts[1]), 2)
            except ValueError:
                pass
    return sens


def seccion_usb():
    dispositivos = []
    out = run(["lsusb"])
    for line in out.splitlines():
        m = re.match(r"Bus (\d+) Device (\d+): ID ([0-9a-f]{4}:[0-9a-f]{4})\s+(.+)", line)
        if m:
            vid_pid = m.group(3)
            nombre = m.group(4).strip()
            # Acortar nombres muy largos
            if len(nombre) > 60:
                nombre = nombre[:60] + "..."
            dispositivos.append({"id": vid_pid, "product": nombre})
    return dispositivos


def seccion_audio():
    audio: JsonDict = {"server": "pipewire" if run(["pactl", "info"]).count("PipeWire") else "pulseaudio"}
    sinks = run(["pactl", "list", "short", "sinks"])
    audio["sinks"] = [l.split("\t")[1] for l in sinks.splitlines() if l.strip()]
    sources = run(["pactl", "list", "short", "sources"])
    audio["sources"] = [l.split("\t")[1] for l in sources.splitlines() if l.strip()]
    return audio


def seccion_kernel_boot():
    kb = {}
    cmdline = leer_proc("/proc/cmdline")
    if cmdline:
        kb["cmdline"] = cmdline.strip()
    return kb


# ─────────────────────────────────────────────────────────────
# Generación del índice
# ─────────────────────────────────────────────────────────────
def escanear():
    """Recolecta todo el hardware y actualiza index.json."""
    print("🔍 Escaneando hardware...")
    datos = {}

    datos["meta"] = {
        "generated": datetime.datetime.now().strftime("%d/%m/%Y %H:%M %Z"),
        "source": "hardware-query.py scan (16/08/2026)",
        "note": "Índice regenerado automáticamente con hardware-query.py",
    }

    print("  • Sistema operativo...")
    datos["os"] = seccion_os()
    print("  • CPU...")
    datos["cpu"] = seccion_cpu()
    print("  • RAM...")
    datos["ram"] = seccion_ram()
    print("  • Placa base...")
    datos["motherboard"] = seccion_motherboard()
    print("  • GPU NVIDIA...")
    datos["gpu_nvidia"] = seccion_gpu_nvidia()
    print("  • GPU AMD integrada...")
    datos["gpu_amd_integrated"] = seccion_gpu_amd()
    print("  • Monitores...")
    datos["displays"] = seccion_displays()
    print("  • Almacenamiento...")
    datos["storage_devices"] = seccion_storage()
    print("  • Red...")
    datos["network"] = seccion_network()
    print("  • Sensores...")
    datos["sensors"] = seccion_sensors()
    print("  • USB...")
    datos["usb_devices"] = seccion_usb()
    print("  • Audio...")
    datos["audio"] = seccion_audio()
    print("  • Kernel/boot...")
    datos["kernel_boot"] = seccion_kernel_boot()

    # Guardar
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(HARDWARE_PATH, "w") as f:
        json.dump(datos, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print("")
    print(f"✅ Índice actualizado: {HARDWARE_PATH}")
    print(f"   ({len(datos)} secciones, {datetime.datetime.now().strftime('%H:%M:%S')})")
    return datos


# ─────────────────────────────────────────────────────────────
# Consultas
# ─────────────────────────────────────────────────────────────
def cargar_datos():
    try:
        with open(HARDWARE_PATH, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"❌ No existe {HARDWARE_PATH}", file=sys.stderr)
        print("   Ejecuta primero: hardware-query.py scan", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ {HARDWARE_PATH} no es JSON válido: {e}", file=sys.stderr)
        sys.exit(1)


def mostrar_status(d):
    def get(*keys, default="?"):
        node = d
        for k in keys:
            if not isinstance(node, dict) or k not in node:
                return default
            node = node[k]
        return node

    cpu = d.get("cpu", {})
    ram = d.get("ram", {})
    gpu = d.get("gpu_nvidia", {})
    mb = d.get("motherboard", {})
    net = d.get("network", {}).get("wifi", {})
    discos = d.get("storage_devices", [])

    print("═══════════════════════════════════════════")
    print("  HARDWARE STATUS")
    print("═══════════════════════════════════════════")
    print(f'CPU:  {cpu.get("model", "?")} ({cpu.get("cores", "?")}C/{cpu.get("threads", "?")}T)')
    print(f'RAM:  DDR5 @ {ram.get("speed_mts", "?")} MT/s  ({ram.get("total_gb", "?")} GB)')
    print(f'GPU:  NVIDIA {gpu.get("model", "?")}')
    print(f'MB:   {mb.get("model", "?")}')
    print(f'Kernel: {d.get("os", {}).get("kernel", "?")}')
    print(f'WiFi: {net.get("connected_ssid", "?")} ({net.get("signal_dbm", "?")} dBm)')
    print(f'Discos: {len(discos)} físicos')
    print("───────────────────────────────────────────")


def mostrar_campos(d):
    print("Campos de consulta:")
    for campo in CAMPOS_AYUDA:
        print(f"  - {campo}")
    print("\nSecciones del índice:")
    for k in d.keys():
        print(f"  - {k}")


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print((__doc__ or "hardware-query.py <comando>").strip())
        return 0

    comando = sys.argv[1]

    if comando == "scan":
        escanear()
        return 0

    if comando == "--campos":
        d = cargar_datos()
        mostrar_campos(d)
        return 0

    d = cargar_datos()

    if comando == "status":
        mostrar_status(d)
        return 0

    if comando == "all":
        print(json.dumps(d, indent=2, default=str))
        return 0

    # Campos derivados (compatibilidad)
    if comando == "gpu":
        print(json.dumps(d.get("gpu_nvidia", {}), indent=2, default=str))
        print("--- iGPU ---")
        print(json.dumps(d.get("gpu_amd_integrated", {}), indent=2, default=str))
        return 0

    if comando in ("wifi", "bluetooth"):
        net = d.get("network", {})
        if comando == "bluetooth":
            bt = net.get("bluetooth", {})
            if bt:
                print(json.dumps(bt, indent=2, default=str))
            else:
                print("ℹ️  El índice no contiene datos de bluetooth.", file=sys.stderr)
                return 1
        else:
            wifi = net.get("wifi", {})
            if wifi:
                print(json.dumps(wifi, indent=2, default=str))
            else:
                print("ℹ️  El índice no contiene datos de wifi.", file=sys.stderr)
                return 1
        return 0

    if comando in ("storage", "discos"):
        print(json.dumps(d.get("storage_devices", []), indent=2, default=str))
        return 0

    if comando in ("usb", "usb_devices"):
        print(json.dumps(d.get("usb_devices", []), indent=2, default=str))
        return 0

    if comando in ("os", "sistema"):
        print(json.dumps(d.get("os", {}), indent=2, default=str))
        return 0

    if comando == "displays" or comando == "monitores":
        print(json.dumps(d.get("displays", []), indent=2, default=str))
        return 0

    if comando == "audio":
        print(json.dumps(d.get("audio", {}), indent=2, default=str))
        return 0

    if comando == "sensors":
        print(json.dumps(d.get("sensors", {}), indent=2, default=str))
        return 0

    if comando == "network":
        print(json.dumps(d.get("network", {}), indent=2, default=str))
        return 0

    if comando == "pci":
        print(json.dumps(d.get("pci_devices", {}), indent=2, default=str))
        return 0

    if comando == "bios":
        print(json.dumps(d.get("motherboard", {}), indent=2, default=str))
        return 0

    # Cualquier otra clave directa del índice
    if comando in d:
        print(json.dumps(d[comando], indent=2, default=str))
        return 0

    print(f"❌ Campo desconocido: {comando}", file=sys.stderr)
    print(f"   Campos: {', '.join(CAMPOS_AYUDA)}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
