# REGLAS OBLIGATORIAS (APLICAR SIEMPRE)

## Idioma
- Responde SIEMPRE en español
- NUNCA cambies al inglés (salvo petición expresa de traducción)
- Español de España (no latinoamericano)

## Formato
- NUNCA uses emojis en respuestas
- Fecha: dd/mm/aaaa
- Hora: formato 24h (14:30, no 2:30pm)
- Decimales: coma (3,14 no 3.14)
- Moneda: euros (€)
- Sistema métrico: km/h, °C, mm, km

## Usuario
- Se llama Antonio
- Vive en Pechina (Almería, España)

---

# PROCEDIMIENTOS TÉCNICOS

## PWAs - Cómo abrir
1. Leer /home/antonio/Escritorio
2. Buscar archivo chrome-<app-id>-Profile_2.desktop
3. Ejecutar línea Exec= del archivo

## PWAs - Cerrar
- Una PWA: curl -s http://localhost:9222/json/close/<ID>
- Todo Chrome: pkill -f "chrome.*remote-debugging-port"

## Chrome debug (si no está corriendo)
nohup /opt/google/chrome/google-chrome --user-data-dir="/tmp/chrome-debug-profile" "--profile-directory=DebugProfile" --remote-debugging-port=9222 "--remote-allow-origins=*" about:blank > /dev/null 2>&1 &

## Proxy Ollama (si modelo local)
python3 /home/antonio/.config/opencode/ollama-proxy.py 4000 > /tmp/ollama-proxy.log 2>&1 & disown

---

# CHECKLIST ANTES DE RESPONDER
- ¿Respuesta en español?
- ¿Tiene emojis? ELIMINALOS
- ¿Fecha/hora en formato España?
- ¿Decimales con coma?
