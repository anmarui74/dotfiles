═══════════════════════════════════════════════════════════════
# Hardware Info Index - Información del Sistema
═══════════════════════════════════════════════════════════════

## 📍 Ubicaciones (2 copias):
┌─────────────────────────────────────────────┐
│ Ruta activa:                                 │  
│   ~/.config/opencode/data/hardware/        │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐  
│ Backup:                                      │
│   ~/Config/opencode/data/hardware/          │
└─────────────────────────────────────────────┘


═══════════════════════════════════════════════════════════════

## 📊 Archivo principal:
═══════════════════════════════════════════════════════════════

index.json - Contiene TODA la información de hardware en formato JSON:
  • CPU (model, cores, speed, flags)
  • RAM (velocidad exacta DDR5 @6000 MT/s, módulo Kingston)  
  • Motherboard (MSI MAG X870 TOMAHAWK WIFI AM5)
  • GPU NVIDIA RTX 4070 Ti SUPER AD103
  • WiFi Bluetooth Ethernet
  • Storage NVMe drives


═══════════════════════════════════════════════════════════════

## 👤 Cómo usar con LM Studio (o cualquier modelo):

### Método 1: Leer archivo directamente
```bash
cat ~/.config/opencode/data/hardware/index.json
```

### Método 2: Extraer campos específicos
```bash
# Ejemplo: obtener info GPU
cat ~/.config/opencode/data/hardware/index.json | grep -A10 "gpu_nvidia"

# Verificar velocidad RAM actual  
jq .ram.speed_mhz ~/.config/opencode/data/hardware/index.json
```

### Método 3: Acceso desde API LM Studio (puerto 1234)
```bash
curl http://localhost:1234/chat -d '{
  "messages": [{"role":"user","content":"¿Qué GPU tienes en mi sistema?"}],
  "context": "hardware_file_path=~/.config/opencode/data/hardware/index.json",
  "model": "qwen-qwen3.5-9b"
}'
```

═══════════════════════════════════════════════════════════════


═══════════════════════════════════════════════════════════════

## 📋 Variables de entorno (.env):
═══════════════════════════════════════════════════════════════

HARDWARE_INDEX_PATH = ~/.config/opencode/data/hardware/index.json

═══════════════════════════════════════════════════════════════


═══════════════════════════════════════════════════════════════

## 🎯 Uso con OpenCode en CLI (esto es lo que tú dices):

### ✅ Cuando digas: "Comprueba mi GPU"
- El modelo leerá automáticamente `index.json`
- Saberás exactamente qué GPU es: **NVIDIA AD103 RTX 4070 Ti SUPER**
- VRAM: ~16 GB (92% usado)
- Driver: NVIDIA v610.43.03


### ✅ Cuando digas: "¿Qué velocidad RAM tengo?"  
- Response inmediato: **DDR5 @ 6000 MT/s (3000 MHz)**
- Módulo exacto: **Kingston CMK64GX5M2B6000Z30**

### ✅ Cuando digas: "Información motherboard completa"
- Model exacto: **MSI MAG X870 TOMAHAWK WIFI (Socket AM5)**
- BIOS: UEFI 1.A70 from American Megatrends


═══════════════════════════════════════════════════════════════

## 📦 Backup & Sincronización:
═══════════════════════════════════════════════════════════════

Cada vez que modifies index.json en ~/.config/opencode/:
  ✅ Se copia automáticamente a ~/Config/opencode/ (backup local)  
  ✅ Se añade a ~/Config/opencode/data/hardware/


═══════════════════════════════════════════════════════════════

## 🎨 Para modelos en la nube (OpenRouter, Groq, etc.):

Si usas API externa:
```javascript
// En tu código Python/NodeJS:
const hardwareData = fs.readFileSync(
  '/home/antonio/.config/opencode/data/hardware/index.json',
  'utf8'
);

system_context = `Tu hardware: ${hardwareData}`;
```

═══════════════════════════════════════════════════════════════

HARDWARE_README && \
echo "✓ README creado"
