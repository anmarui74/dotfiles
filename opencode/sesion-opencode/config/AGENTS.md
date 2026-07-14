# Reglas de Idioma
- Language: Always respond in Spanish.
- Idioma: Responde siempre en español, sin importar el idioma en el que te escriba el usuario.
- No cambies al inglés a menos que se te pida explícitamente traducir algo.
- Ignora emojis en la respuesta por voz

# Accesos Directos Web (PWAs de Chrome)
Chrome debe estar siempre corriendo en segundo plano con:
`nohup /opt/google/chrome/google-chrome --user-data-dir="/tmp/chrome-debug-profile" "--profile-directory=DebugProfile" --remote-debugging-port=9222 "--remote-allow-origins=*" about:blank > /dev/null 2>&1 &`

# Proxy Ollama-OpenCode (si se usa modelo local)
El proxy Python debe estar corriendo en segundo plano para traducir las llamadas de OpenCode a Ollama:
`python3 /home/antonio/.config/opencode/ollama-proxy.py 4000 > /tmp/ollama-proxy.log 2>&1 & disown`
El proxy escucha en `http://127.0.0.1:4000` y traduce al formato de Ollama. Si el proxy se cae, los mensajes en OpenCode se quedarán en "QUEUED". Verificar: `curl -s http://127.0.0.1:4000/v1/models`. Para reiniciar: matar proceso anterior y ejecutar el comando de arriba.

**Auto-search**: Cuando el modelo local responde con una negativa ("no sé", "no puedo", etc.), el proxy busca automáticamente en internet usando DuckDuckGo, extrae contenido de la primera página, inyecta los datos en el mensaje del usuario, y reintenta la llamada. Para consultas meteorológicas usa `wttr.in` directamente (formato JSON con previsión multi-día). Si el primer reintento sigue siendo negativa, hace un segundo reintento con instrucción más directa.

# Regla: solo abrir PWAs desde el escritorio
Cuando el usuario pida abrir una PWA, **NO** usar una lista fija de app-id.
En su lugar:
1. Leer el directorio `/home/antonio/Escritorio`
2. Buscar el archivo `chrome-<app-id>-Profile_2.desktop` que coincida con el nombre de la PWA (ej. "WhatsApp" → `chrome-hnpfjngllnobngcgfapefoaidbinmjnm-Profile_2.desktop`)
3. Leer la línea `Exec=` del .desktop para obtener el comando exacto
4. Ejecutar ese comando directamente (sin añadir `--remote-debugging-port` ni `--user-data-dir`, ya que la PWA usa el perfil real)

Para **cerrar** una PWA específica:
1. Listar páginas: `curl -s http://localhost:9222/json`
2. Cerrar por URL/title: `curl -s "http://localhost:9222/json/close/<ID>"`

Para **cerrar Chrome completamente**: Solo cuando el usuario diga "termina" o "cierra todo". Usar `pkill -f "chrome.*remote-debugging-port"`.

# Nota importante
Las PWAs están instaladas en el perfil real de Chrome (`~/.config/google-chrome/Profile 2`), NO usar `--user-data-dir`. El perfil "Profile 2" es el único perfil que usa Antonio (aunque Chrome no lo llame "Default").

# Lista de PWAs instaladas (para referencia al buscar en el escritorio)
Las PWAs están en /home/antonio/Escritorio como archivos `chrome-<app-id>-Profile_2.desktop`:
- YouTube Music → cinhimbnkkaeohfgghhklpknlkffjgod
- YouTube → agimnkijcaahngcdmfeangaknmldooml
- Gmail → fmgjjmmmlfnkbppncabfkddbjimcfncm
- X (Twitter) → lodlkdfmihgonocnmddehnfgiljnadcf
- Outlook → eigpmdhekjlgjgcppnanaanbdmnlnagl
- WhatsApp Web → hnpfjngllnobngcgfapefoaidbinmjnm
- Instagram → akpamiohjfcnimfljfndmaldlcfphjmp
- Facebook → kippjfofjhjlffjecoapiogbkgbpmgej
- Prime Video → pgodaempnpiodjbcjjeegihfamcgegpl
- HBO Max → gceffgdljemcloimdbaemadhllglhanj
- SkyShowtime → pgfiaejgplcongccgkcnkfjdcdjbdkkm
- Open WebUI → cpdpbfelifklonephgpieimdpcecgoen
- Qwen Studio → callopjomjkljkgpgnflciibleibpnbp
- Bloc de notas (Google Keep) → cfldoobibklmgfnagclljaaoiabejgjc

# Convenciones regionales (España)
- **Formato de fecha**: dd/mm/aaaa (día/mes/año)
- **Formato de hora**: 24h (ej. 14:30, 09:00)
- **Semana**: empieza el lunes (no el domingo)
- **Nombres de días**: Lun, Mar, Mié, Jue, Vie, Sáb, Dom
- **Sistema métrico**: km/h, °C, mm, km
- **Decimales**: coma (,) en lugar de punto, aunque en datos técnicos se puede usar punto
- **Moneda**: euros (€)
- **Idiomas**: español de España (no latinoamericano)

# Usuario
- El usuario se llama Antonio.
- Vive en Pechina (Almería, España).

