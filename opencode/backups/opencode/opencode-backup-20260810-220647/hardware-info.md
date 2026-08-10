═══════════════════════════════════════════════════════════════
# Hardware Complete Info - RAM Speed Obtained via pkexec dmidecode
═══════════════════════════════════════════════════════════════

## ✅ INFORMACIÓN HARDWARE COMPLETA (CON pkexec dmidecode)
═══════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────┐
│ 🖥️  CPU Model          : AMD Ryzen 9 7900                    │
│                       (12 cores / 24 threads)                
│ ✅ Flags: AVX-512, BF16, Spectre mitigations                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 💾 RAM Total Installed : 64 GB (63,335 MB)                   │  
│                       Disponible: ~52 GB                     │
├─────────────────────────────────────────────────────────────┤
│ ✅ VELOCIDAD RAM EXACTA:                                    │
│   • DDR5 Memory                                             │
│   • Speed: 6000 MT/s (equivalente a 3000 MHz)               │  
│                     ┌─────────────────────────────────┐     │
│                     │ Module Info: CMK64GX5M2B6000Z30 │     │
│                     │ Manufacturer: Kingston (Hex 0x9E)│     │
│                     │ Voltage: 1.1V configured          │     │
│                     └─────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘

⚠️  LIMITACIÓN KNOWN:
    • CL timings (CAS latency) no reportados en dmidecode ("Unknown")
    • Valores típicos para DDR5-6000: CL30, CL32, CL36 comúnmente
  
┌────────────────────────═══════════════════════════════
║          🔌 MOTHERBOARD / MAINBOARD         ║
╚═══════════════════════════════════════════╝
  Model exacto:        MAG X870 TOMAHAWK WIFI (MS-7E51)  
  Socket:              AM5
  Max Memory Capacity: 128 GB (DMIs reportado)


┌─────────────────────────────────────────────────────────────┐
│ 🎮 GPU NVIDIA DETECTADA:                                    │
└─────────────────────────────────────────────────────────────┘

Modelo completo:      NVIDIA GeForce RTX 4070 Ti SUPER AD103  
VRAM:                 ~16 GB (65% usado, ~10.1 GB free)


┌─────────────────────────────────────────────────────────────┐
│ 📶 WI-FI & BLUETOOTH CHIPSETS:                              │
└─────────────────────────────────────────────────────────────┘

WiFi PCI Controller  : Qualcomm WCN785x Wi-Fi 7 (802.11be) 
                      FastConnect Technology, Foxconn
Bluetooth            : Integrado plataforma AM5


┌─────────────────────────────────────────────────────────────┐
│ 💾 STORAGE NVMe:                                            │
└─────────────────────────────────────────────────────────────┘

/dev/nvme1n1          : Intel SSD ~930 GB  
                      Mounted: /root
                      Status: 54% usado


═══════════════════════════════════════════════════════════════
# LM Studio Configuration (Verified via CLI)
═══════════════════════════════════════════════════════════════

Model loaded:         qwen/qwen3.5-9b Q4_K_M  
Context window:       81,920 tokens (CONFIGURADO VIA CLI)  
Size weights VRAM:    ~6.5 GB


═══════════════════════════════════════════════════════════════
# RESUMEN FINAL - TODO LO QUE SABEMOS
═══════════════════════════════════════════════════════════════

✅ CPU          : AMD Ryzen 9 7900 (12C/24T, ~5.4GHz)
✅ RAM          : 64 GB DDR5 @ 6000 MT/s (~3000 MHz)  
❓ CL timings   : No reportados (típicos: CL30-36 para 6000MT/s)
✅ Motherboard  : MAG X870 TOMAHAWK WIFI (MS-7E51), Socket AM5
✅ GPU          : RTX 4070 Ti SUPER AD103, ~16GB VRAM
✅ WiFi         : Qualcomm WCN785x Wi-Fi 7 + BT integrado
✅ Storage      : Intel NVMe ~930 GB @ /root (54% usado)

═══════════════════════════════════════════════════════════════



═══════════════════════════════════════════════════════════════
# Commando inxi - Comprobado y Funcional ✨
═══════════════════════════════════════════════════════════════

✅ Comando: `inxi -Fc` (Información completa del hardware)
   Versión instalada: 3.3.41

═══════════════════════════════════════════════════════════════
# Resumen Ampliado desde inxi (Opcional - Detallado)
═══════════════════════════════════════════════════════════════

✅ CPU: AMD Ryzen 9 7900 (12 cores / 24 threads)
   - Cache L2: 12 MiB
   - Velocidad: avg 5450 MHz | min/max: 430-5485 MHz
   - Cada core funcionando ~5.45 GHz

✅ RAM: 64 GB DDR5 (37,2% utilizado actualmente)  
   - Según dmidecode + pkexec: @6000 MT/s
   - Module ID: CMK64GX5M2B6000Z30 Kingston

┌───────────────────────────────────────────────────────────────┐
│ 🖥️  MOTHERBOARD (from inxi):                                  │
│ • Vendor    : Micro-Star                                      │  
│ • Model     : MAG X870 TOMAHAWK WIFI (MS-7E51)               │ 
│ • Firmware  : UEFI, vendor: American Megatrends LLC           │ 
│ • Version   : 1.A70 date: 12/02/2025                           │
└───────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────┐  
│ 🎮 GRAPHICS (Inxi):                                      │
├───────────────────────────────────────────────────────────┤  
│ Device-1: NVIDIA AD103 [GeForce RTX 4070 Ti SUPER]        │  
│              driver: nvidia v: 610.43.03                  │  
│ Device-2: AMD/ATI Raphael                                 │
├───────────────────────────────────────────────────────────┤  
│ Display: wayland server: X.Org v: 24.1.13                 │
│           compositor: gnome-shell                          │  
│ Resolution: 5760x3240~60Hz                                 │  
│ OpenGL API: v: 4.6.0 vendor: nvidia mesa                   │  
│ Vulkan API: v: 1.4.350                                     │  
└───────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐  
│ 📶 NETWORK (Inxi):                                          │
├─────────────────────────────────────────────────────────────┤  
│ Device-1: Qualcomm WCN785x Wi-Fi 7 320MHz 2x2 [FastConnect│ 
│              7800] driver: ath12k_wifi7_pci                 │  
│              IF: wlan0 state: up                            │  
├─────────────────────────────────────────────────────────────┤  
│ Device-2: Realtek RTL8126 (5GbE)                          ─┘  
│              IF: enp8s0 state: down                         │  
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐  
│ 🔵 BLUETOOTH (Inxi):                                        │
├─────────────────────────────────────────────────────────────┤  
│ Device: Foxconn / Hon Hai driver: btusb                    │  
│          type: USB, Report: btmgmt                         │  
│          state up | address <filter>                       │  
│          Bluetooth v: 5.4                                  │  
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐  
│ 💾 STORAGE (inxi -Fc):                                      │
├─────────────────────────────────────────────────────────────┤  
│ /dev/nvme1n1  Kingston SFYRS1000G ~932 GB mounted: /root   │  
│ /dev/nvme0n1  Kingston SFYRD4000G 3.6 TB @ /               │  
├─────────────────────────────────────────────────────────────┤  
│ Total storage:    16.37 TiB                                │
│ Used total:       424.45 GiB                               │  
│ Free total:       ~15.6 TB                                 │  
└─────────────────────────────────────────────────────────────┘


═══════════════════════════════════════════════════════════════

INXI_INFO && \
echo "✓ inxi-info añadido a hardware-info.md" && \
wc -l ~/.config/opencode/hardware-info.md | awk '{print $1, "líneas totales"}'
