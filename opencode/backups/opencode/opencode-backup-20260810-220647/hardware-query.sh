#!/bin/bash
# Consulta rápida de hardware via index.json
# Uso: source ~/.config/opencode/hardware-query.sh && hw_query <campo>
# Campos: status, cpu, gpu, ram, motherboard, wifi, bluetooth, all

HARDWARE_PATH="/home/antonio/.config/opencode/data/hardware/index.json"

hw_query() {
    local query="$1"

    case "$query" in
        status)
            python3 -c "
import json, sys
d = json.load(open('$HARDWARE_PATH'))
print('═══════════════════════════════════════════')
print('  HARDWARE STATUS')
print('═══════════════════════════════════════════')
print(f'CPU:  {d[\"cpu\"][\"model\"]} ({d[\"cpu\"][\"cores\"]}C/{d[\"cpu\"][\"threads\"]}T)')
print(f'RAM:  DDR5 @ {d[\"ram\"][\"speed_mts\"]} MT/s  ({d[\"ram\"][\"total_gb\"]} GB)')
print(f'GPU:  NVIDIA {d[\"gpu_nvidia\"][\"model\"]}')
print(f'MB:   {d[\"motherboard\"][\"model\"]}')
print('───────────────────────────────────────────')
"
            ;;
        cpu)
            python3 -c "
import json, sys
d = json.load(open('$HARDWARE_PATH'))
print(json.dumps(d['cpu'], indent=2, default=str))
"
            ;;
        gpu)
            python3 -c "
import json, sys
d = json.load(open('$HARDWARE_PATH'))
print(json.dumps(d.get('gpu_nvidia', {}), indent=2, default=str))
print('--- iGPU ---')
print(json.dumps(d.get('gpu_amd_integrated', {}), indent=2, default=str))
"
            ;;
        ram)
            python3 -c "
import json, sys
d = json.load(open('$HARDWARE_PATH'))
print(json.dumps(d['ram'], indent=2, default=str))
"
            ;;
        motherboard)
            python3 -c "
import json, sys
d = json.load(open('$HARDWARE_PATH'))
print(json.dumps(d['motherboard'], indent=2, default=str))
"
            ;;
        wifi)
            python3 -c "
import json, sys
d = json.load(open('$HARDWARE_PATH'))
print(json.dumps(d.get('wifi', {}), indent=2, default=str))
"
            ;;
        bluetooth)
            python3 -c "
import json, sys
d = json.load(open('$HARDWARE_PATH'))
print(json.dumps(d.get('bluetooth', {}), indent=2, default=str))
"
            ;;
        all)
            python3 -c "
import json, sys
d = json.load(open('$HARDWARE_PATH'))
print(json.dumps(d, indent=2, default=str))
"
            ;;
        *)
            echo "Uso: source hardware-query.sh && hw_query <campo>"
            echo "Campos: status, cpu, gpu, ram, motherboard, wifi, bluetooth, all"
            ;;
    esac
}
