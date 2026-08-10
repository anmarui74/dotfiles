=============================================

Comandos rápidos disponibles para información de hardware:
═══════════════════════════════════════════════

🖥️  CPU (Processor Info)
------------------------
```bash
grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //'
```
Resultado esperado: `AMD Ryzen 9 7900 12-Core Processor`

═══════════════════════════════════════════════


💾 MEMORY (RAM)
───────────────
```bash
awk '/MemTotal/{printf "%.2f GB", $2/1024/1024}' /proc/meminfo
```
Resultado: 64.85 GB total | Libre: ~32-50GB

═══════════════════════════════════════════════

🔌 MOTHERBOARD (Exact Model)
─────────────────────────────
```bash
cat /sys/devices/virtual/dmi/id/board_name
```
Resultado: `MAG X870 TOMAHAWK WIFI (MS-7E51)`

═══════════════════════════════════════════════


🎮 GPU NVIDIA Info
──────────────────
```bash
nvidia-smi --query-gpu=index,name,memory.total,memory.used,temperature.gpu,power.draw --format=csv,noheader,nounits  || \"AMD/Intel - usa lspci | grep -iE VGA|Display\"" 
```

═══════════════════════════════════════════════


📶 WI-FI CONTROLLER (PCI Express Vendor)
─────────────────────────────────────────
```bash
lspci | grep -iE 'wifi|wireless' || echo "Integrado WiFi (AM5 platform)"
```

═══════════════════════════════════════════════


🖧 NETWORK Interfaces
─────────────────────
```bash
ip link show | grep -oE '^[0-9]+[[:space:]]+[a-z]+' | sed 's/^[^[:space:]]*[[:space:]]*//'
```

═══════════════════════════════════════════════


💾 STORAGE (NVMe/SATA)
───────────────────────
```bash
lsblk -nd -o NAME,MODEL,SERIAL,size,KBYTES,MOUNTPOINT || true
```

═══════════════════════════════════════════════


📊 VRAM Status
─────────────────── 
```bash
nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv 2>/dev/null
```

═══════════════════════════════════════════════


⚙️  CPU Topology & Frequency
────────────────────────────
```bash  
grep 'processor' /proc/cpuinfo | wc -l && \
grep 'cpu MHz' /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //'  
```

═══════════════════════════════════════════════


📝 Notes
───────────────────
All commands output directly to terminal. Use `bash ~/.config/opencode/common-cmds.sh [cmd]` when script is functional. For individual info, execute each command from any terminal.

MDEOF && \
echo "✓ README-hardware.md creado en config/opencode/"</dev/null && head -50 ~/.config/opencode/hardware-info-status.txt || true 2>/dev/null || echo "--- ---"