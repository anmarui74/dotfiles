# Hardware del equipo de Antonio

| 🖥️ Sistema | 🐧 Kernel | 📐 Arquitectura |
|------------|----------|-----------------|
| CachyOS (Arch rolling) | 7.1.8-1-cachyos | x86_64 |

| 🖥️ Escritorio | 🐚 Shell | 🌍 Locale / Zona |
|---------------|----------|------------------|
| GNOME 50.3 (Wayland, GDM) | zsh | es_ES.UTF-8 · Europe/Madrid |

> 📊 **Información actualizada:** 16/08/2026 · Escaneada con `hardware-query.py scan`

---

## 🖥️ CPU

| Campo | Valor |
|---|---|
| Modelo | AMD Ryzen 9 7900 12-Core Processor |
| Arquitectura | Zen 4 (socket AM5) |
| Núcleos / hilos | 12 núcleos físicos / 24 hilos (2 por núcleo) |
| Frecuencia | Máx. 5485 MHz · Mín. 430 MHz |
| Caché | L1d 384 KiB · L1i 384 KiB · L2 12 MiB · L3 64 MiB |
| Microcode | 0xa60120c (familia 25, modelo 97, stepping 2) |
| Virtualización | AMD-V (SVM, avic, vgif, x2avic) |
| ISA | AVX-512 completo, AVX2, FMA3, BMI1/2, AES-NI, SHA-NI, VAES, GFNI, F16C |
| Vulnerabilidades | Casi todas "Not affected"; Spectre v1/v2 mitigadas (Enhanced/Automatic IBRS) |

## 💾 RAM

| Campo | Valor |
|---|---|
| Total | 64 GB (61,9 GiB usables) · 2 DIMMs de 32 GiB |
| Tipo | DDR5 @ 6000 MT/s (3000 MHz) · Dual-rank |
| Módulo | Corsair Vengeance CMK64GX5M2B6000Z30 |
| Slots | DIMMA2 y DIMMB2 ocupados (32 GiB c/u) · DIMMA1 y DIMMB1 vacíos |
| Swap | zram0 de 61,9 GiB (algoritmo zstd) |

## 🔌 Placa base

| Campo | Valor |
|---|---|
| Modelo | MSI MAG X870 TOMAHAWK WIFI (MS-7E51) |
| BIOS | American Megatrends 1.A70 (12/02/2025) · UEFI |
| Chipset | AMD X870 · Socket AM5 · Factor ATX |

## 🎮 GPU

| Campo | Valor |
|---|---|
| GPU dedicada | NVIDIA GeForce RTX 4070 Ti SUPER (Ada Lovelace, AD103) |
| VRAM | 16376 MiB (~16 GB GDDR6X) |
| Driver | nvidia 610.57.04 · CUDA 13.3 · Vulkan 1.4 · PCIe Gen4 x16 |
| iGPU integrada | AMD Radeon Raphael (RDNA2) · driver amdgpu |
| Uso CUDA | LM Studio (Qwen 3.8-9B) y whisper-cpp (transcripción ~0,85 s) |

## 🖥️ Monitores

| Conexión | Tamaño | Resolución activa | ¿Principal? |
|---|---|---|---|
| DP-1 | 27,2" (600×340 mm) | 5760×3240 (4K, escala 150%) · 60 Hz | No |
| DP-2 | 27,2" (600×340 mm) | 5760×3240 (4K, escala 150%) · 60 Hz | Sí |

## 💽 Almacenamiento

| Dispositivo | Modelo | Tamaño | Sistema de archivos | Montaje |
|---|---|---|---|---|
| nvme0n1 | Kingston SFYRS1000G | 1 TB | btrfs | `/` y `/home` |
| nvme1n1 | Kingston SFYRD4000G | 4 TB | NTFS | (particiones Windows) |
| sda | Crucial CT1000MX500SSD1 | 1 TB | btrfs | no montado |
| sdb | Toshiba HDWE140 | 3,6 TB | NTFS | no montado |
| sdc | Toshiba HDWE140 | 3,6 TB | NTFS | no montado |
| sdd | Seagate ST4000NM0035 | 3,6 TB | NTFS | `/run/media/antonio/SEAGATE` |
| zram0 | swap comprimido | 61,9 GiB | swap | `[SWAP]` |

> Contenedor Docker activo: **open-webui** (ghcr.io/open-webui/open-webui:main)

## 🌐 Red

### 📡 WiFi

| Campo | Valor |
|---|---|
| Chipset | Qualcomm WCN785x Wi-Fi 7 (802.11be), 320 MHz, 2×2 · FastConnect 7800 |
| Driver | ath12k_wifi7_pci · kernel module ath12k_wifi7 |
| Red conectada | ZIPE (BSSID 64:64:4a:bc:af:70) · canal 48 · 5240 MHz · ancho 160 MHz |
| Velocidades | RX 2161–2402 Mbps · TX 1921 Mbps (modo HE / Wi-Fi 6) |
| Señal | −32 a −35 dBm (excelente) |
| IP | 192.168.31.112/24 · MAC d8:b3:2f:2d:ff:09 · modo managed |

### 🔌 Ethernet y Bluetooth

| Interfaz | Detalle |
|---|---|
| enp8s0 | Realtek RTL8126 5GbE (driver r8169) · caída (se usa WiFi) · MAC 34:5a:60:52:b8:58 |
| Bluetooth | Qualcomm integrado en WCN785x · MAC D8:B3:2F:2D:FF:0A · arriba |

### 🌐 Redes virtuales

| Interfaz | IP | Uso |
|---|---|---|
| vmnet1 | 192.168.123.1/24 | VMware host |
| vmnet8 | 192.168.73.1/24 | VMware NAT |
| docker0 | 172.17.0.1/16 | Docker |

## 🌡️ Sensores (en reposo)

| Sensor | Valor |
|---|---|
| CPU Tctl | ~51–64 °C |
| CPU Tccd1 / Tccd2 | ~53 °C / ~51 °C |
| GPU NVIDIA | ~49–53 °C · consumo 13–28 W |
| iGPU AMD | ~55 °C · consumo 39 W |
| NVMe | Composite ~47–60 °C · Sensor 2 ~66–73 °C |
| WiFi / Ethernet | ~66 °C / ~56 °C |

---

## 🛠️ Cómo consultar el hardware

| Comando | Descripción |
|---|---|
| `source ~/.config/opencode/hardware-query.sh && hw_query status` | Resumen rápido |
| `hw_query cpu` / `hw_query gpu` / `hw_query ram` | Detalle de una sección |
| `python3 ~/.config/opencode/hardware-query.py scan` | Reescaneo completo (actualiza el índice) |
| `hw_query all` | Índice completo en JSON |
