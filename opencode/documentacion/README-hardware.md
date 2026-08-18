# 🖥️ Comandos rápidos de hardware

> Guía de comandos para consultar la información del equipo.
> Para un escaneo completo y automático: `python3 ~/.config/opencode/hardware-query.py scan`

## ⚡ Consulta rápida (recomendado)

| Comando | Qué muestra |
|---|---|
| `source ~/.config/opencode/hardware-query.sh && hw_query status` | Resumen general (CPU, RAM, GPU, placa, kernel, WiFi, discos) |
| `hw_query cpu` | Detalle de la CPU (JSON) |
| `hw_query gpu` | GPU NVIDIA + iGPU AMD (JSON) |
| `hw_query ram` | Memoria + swap (JSON) |
| `hw_query wifi` | WiFi: chipset, conexión, señal (JSON) |
| `hw_query all` | Índice completo (JSON) |
| `python3 ~/.config/opencode/hardware-query.py scan` | Reescaneo completo del hardware |

## Comandos manuales equivalentes

### CPU

```bash
grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //'
```

Resultado esperado: `AMD Ryzen 9 7900 12-Core Processor`

### Memoria

```bash
awk '/MemTotal/{printf "%.2f GB", $2/1024/1024}' /proc/meminfo
```

Resultado: 64,85 GB total.

### Placa base

```bash
cat /sys/devices/virtual/dmi/id/board_name
```

Resultado: `MAG X870 TOMAHAWK WIFI (MS-7E51)`

### GPU NVIDIA

```bash
nvidia-smi --query-gpu=index,name,memory.total,memory.used,temperature.gpu,power.draw --format=csv,noheader,nounits
```

### WiFi

```bash
lspci | grep -iE 'wifi|wireless'
```

### Interfaces de red

```bash
ip link show | grep -oE '^[0-9]+[[:space:]]+[a-z]+' | sed 's/^[^[:space:]]*[[:space:]]*//'
```

### Almacenamiento

```bash
lsblk -nd -o NAME,MODEL,SERIAL,size,KBYTES,MOUNTPOINT
```

### Topología y frecuencia de la CPU

```bash
grep 'processor' /proc/cpuinfo | wc -l
grep 'cpu MHz' /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //'
```

## Notas

- Todos los comandos devuelven la salida directamente a terminal.
- El índice JSON vive en `~/.config/opencode/data/hardware/index.json`.
- Detalle completo del equipo: ver [hardware-info.md](hardware-info.md).
