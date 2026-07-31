#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Script de instalacion completa: OpenCode + Ollama + LM Studio
# ============================================================
# Uso: bash setup-opencode-completo.sh
# ============================================================
# Fecha: 28/07/2026
# TODO INCLUIDO! No requiere archivos externos.
# ============================================================

DIR_CONFIG="$HOME/.config/opencode"
LOG_PROXY="/tmp/ollama-proxy.log"
DIR_DATA="$DIR_CONFIG/data"
DIR_MEMORY="$DIR_DATA/memory"
DIR_BACKUPS="$HOME/Config/opencode/backups"
LOCAL_BIN="$HOME/.local/bin"

# Colores
VERDE='\033[0;32m'; AMARILLO='\033[1;33m'; ROJO='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${VERDE}[✓]${NC} $1"; }
warn()  { echo -e "${AMARILLO}[!]${NC} $1"; }
err()   { echo -e "${ROJO}[✗]${NC} $1"; }

echo "=============================================="
echo "  Instalacion completa OpenCode + Ollama + LM Studio"
echo "=============================================="
echo ""

# ═══════════════════════════════════════════════════════════
# PASO 1: Instalar OpenCode
# ═══════════════════════════════════════════════════════════
echo "--- 1/19: Instalando OpenCode ---"
if command -v opencode &>/dev/null; then
    info "OpenCode ya instalado: $(opencode --version 2>/dev/null || echo 'desconocido')"
else
    curl -fsSL https://opencode.ai/install.sh | bash
    info "OpenCode instalado"
fi

# ═══════════════════════════════════════════════════════════
# PASO 2: Instalar Ollama + modelos
# ═══════════════════════════════════════════════════════════
echo "--- 2/19: Instalando Ollama ---"
if command -v ollama &>/dev/null; then
    info "Ollama ya instalado: $(ollama --version 2>/dev/null || echo 'desconocido')"
else
    curl -fsSL https://ollama.com/install.sh | sh
    info "Ollama instalado"
fi

if ! pgrep -f "ollama serve" &>/dev/null; then
    echo "  Arrancando Ollama..."
    ollama serve > /dev/null 2>&1 & disown
    sleep 3
fi
info "Ollama listo"

echo "--- 2b/19: Descargando modelos Ollama ---"
MODELOS=(
    "qwen3.5:9b"
    "qwen2.5-coder:7b"
    "gemma4:e4b"
    "llama3.1:8b"
    "deepseek-r1:8b"
    "deepseek-v4-flash-stock:latest"
)
for modelo in "${MODELOS[@]}"; do
    if curl -sf http://localhost:11434/api/tags 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if any(m['name']==modelo for m in d.get('models',[])) else 1)" 2>/dev/null; then
        info "Modelo $modelo ya descargado"
    else
        echo "  Descargando $modelo..."
        ollama pull "$modelo" 2>&1 | tail -1 || warn "Fallo al descargar $modelo"
    fi
done

# ═══════════════════════════════════════════════════════════
# PASO 3: Instalar LM Studio + modelos
# ═══════════════════════════════════════════════════════════
echo "--- 3/19: Instalando LM Studio ---"
LMS_BIN="$HOME/.lmstudio/bin/lms"
if command -v lms &>/dev/null; then
    LMS_CMD="lms"
    info "LM Studio CLI ya instalado"
elif [ -f "$LMS_BIN" ]; then
    LMS_CMD="$LMS_BIN"
    info "LM Studio CLI encontrado en $LMS_BIN"
else
    echo "  Descargando LM Studio..."
    if curl -fsSL https://lmstudio.ai/install.sh | bash -s latest --yes; then
        LMS_CMD="$LMS_BIN"
        info "LM Studio instalado"
    else
        warn "Fallo al instalar LM Studio. Descarga manual: https://lmstudio.ai/"
    fi
fi

if [ -n "${LMS_CMD:-}" ]; then
    echo "  Verificando modelo qwen3.5-9b..."
    if $LMS_CMD library list 2>/dev/null | grep -qi "qwen3.5-9b"; then
        info "Modelo qwen3.5-9b ya descargado"
    else
        echo "  Descargando qwen/qwen3.5-9b..."
        $LMS_CMD download qwen/qwen3.5-9b 2>&1 | tail -5 || warn "Fallo al descargar qwen3.5-9b"
    fi
    echo "  Verificando gemma-4-e4b..."
    if $LMS_CMD library list 2>/dev/null | grep -qi "gemma-4"; then
        info "Modelo gemma-4-e4b ya descargado"
    else
        echo "  Descargando google/gemma-4-e4b..."
        $LMS_CMD download google/gemma-4-e4b 2>&1 | tail -5 || warn "Fallo al descargar gemma-4-e4b"
    fi
    $LMS_CMD version 2>/dev/null && info "LM Studio actualizado"
fi

# ═══════════════════════════════════════════════════════════
# PASO 4: Instalar edge-tts + whisper
# ═══════════════════════════════════════════════════════════
echo "--- 4/19: Dependencias de voz ---"
if ! pipx list 2>/dev/null | grep -q edge-tts; then
    pipx install edge-tts >/dev/null 2>&1 && info "edge-tts instalado" || warn "Fallo edge-tts"
fi
mkdir -p "$LOCAL_BIN"
if [ ! -f "$LOCAL_BIN/whisper-cli" ]; then
    # Opción A: compilar con CUDA si hay GPU y nvcc (transcripción rápida)
    if command -v nvcc >/dev/null 2>&1 && command -v cmake >/dev/null 2>&1 && command -v gcc >/dev/null 2>&1; then
        info "Compilando whisper.cpp con CUDA (transcripción por GPU)..."
        WHISPER_TMP="$(mktemp -d)"
        mkdir -p "$HOME/.local/share/whisper-cpp/bin"
        git clone --depth 1 --branch v1.9.1 "https://github.com/ggml-org/whisper.cpp" "${WHISPER_TMP}/whisper-src"
        cmake -B "${WHISPER_TMP}/whisper-src/build" \
          -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release \
          "${WHISPER_TMP}/whisper-src" >/dev/null 2>&1
        cmake --build "${WHISPER_TMP}/whisper-src/build" --config Release -j "$(nproc)" >/dev/null 2>&1 || true
        if [ -x "${WHISPER_TMP}/whisper-src/build/bin/whisper-cli" ]; then
            cp "${WHISPER_TMP}/whisper-src/build/bin/whisper-cli" "$HOME/.local/share/whisper-cpp/bin/whisper-cli"
            cp "${WHISPER_TMP}"/whisper-src/build/bin/libggml*.so* "$HOME/.local/share/whisper-cpp/bin/" 2>/dev/null || true
            info "whisper.cpp compilado con CUDA"
        else
            warn "Falló la compilación CUDA, usando versión CPU"
        fi
        rm -rf "${WHISPER_TMP}"
    fi
    # Opción B: descargar binario CPU si no se compiló
    if [ ! -x "$HOME/.local/share/whisper-cpp/bin/whisper-cli" ]; then
        info "Descargando whisper.cpp v1.9.1 (CPU)..."
        WHISPER_TMP="$(mktemp -d)"
        mkdir -p "$HOME/.local/share/whisper-cpp/bin"
        curl -sL -o "${WHISPER_TMP}/whisper-bin.tar.gz" \
          "https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.1/whisper-bin-ubuntu-x64.tar.gz"
        tar -xzf "${WHISPER_TMP}/whisper-bin.tar.gz" -C "${WHISPER_TMP}"
        cp "${WHISPER_TMP}"/whisper-bin-ubuntu-x64/whisper-cli "$HOME/.local/share/whisper-cpp/bin/"
        cp "${WHISPER_TMP}"/whisper-bin-ubuntu-x64/*.so* "$HOME/.local/share/whisper-cpp/bin/" 2>/dev/null || true
        rm -rf "${WHISPER_TMP}"
    fi
    cat > "$LOCAL_BIN/whisper-cli" << 'WHISPERWRAP'
#!/bin/bash
# Wrapper whisper-cli con CUDA: añade el directorio local a LD_LIBRARY_PATH
export LD_LIBRARY_PATH="/home/antonio/.local/share/whisper-cpp/bin:${LD_LIBRARY_PATH}"
exec /home/antonio/.local/share/whisper-cpp/bin/whisper-cli "$@"
WHISPERWRAP
    chmod +x "$LOCAL_BIN/whisper-cli"
    info "whisper-cli wrapper creado"
fi

# ═══════════════════════════════════════════════════════════
# PASO 5: Crear directorios
# ═══════════════════════════════════════════════════════════
echo "--- 5/19: Creando directorios ---"
mkdir -p "$DIR_CONFIG" "$DIR_CONFIG/prompts" "$DIR_CONFIG/commands"          "$DIR_DATA" "$DIR_MEMORY" "$DIR_DATA/hardware" "$DIR_BACKUPS"          "$LOCAL_BIN" "$HOME/.lmstudio"          "$HOME/.config/systemd/user"
info "Directorios creados"

# ═══════════════════════════════════════════════════════════
# PASO 6: Configuracion JSON (opencode.json)
# ═══════════════════════════════════════════════════════════
echo "--- 6/19: Configuracion principal ---"


cat > "$DIR_CONFIG/opencode.json" << 'JSONEOF'
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "/usr/bin/zsh",
  "small_model": "lmstudio/models-qwen3.5-9b",
  "instructions": [
    "AGENTS.md"
  ],
  "default_agent": "cloud",
  "permission": {
    "edit": "ask",
    "bash": {
      "sudo *": "deny",
      "pkexec *": "allow",
      "*": "ask"
    }
  },
  "agent": {
    "build": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "plan": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "local": {
      "description": "Agente local - Qwen 3.5",
      "mode": "subagent",
      "model": "lmstudio/models-qwen3.5-9b"
    },
    "cloud": {
      "description": "Agente cloud para modelos en la nube (Claude, Gemini, OpenCode Go)",
      "mode": "primary",
      "model": "opencode-go/deepseek-v4-flash"
    }
  },
  "provider": {
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Qwen 3.5 Q6_K",
      "model": "models-qwen3.5-9b",
      "options": {
        "baseURL": "http://localhost:4001/v1"
      },
      "models": {
        "models-qwen3.5-9b": {
          "name": "Qwen 3.5 - Tool Calling Excellence",
          "tools": true,
          "limit": {
            "context": 81920,
            "output": 8192
          }
        }
      }
    }
  },
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "enabled": true
    },
    "filesystem": {
      "type": "local",
      "command": [
        "npx",
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/home/antonio"
      ],
      "enabled": true
    },
    "memory": {
      "type": "local",
      "command": [
        "npx",
        "-y",
        "@modelcontextprotocol/server-memory"
      ],
      "enabled": true
    },
    "fetch": {
      "type": "local",
      "command": [
        "npx",
        "-y",
        "mcp-fetch-server"
      ],
      "enabled": true
    },
    "sequential_thinking": {
      "type": "local",
      "command": [
        "npx",
        "-y",
        "@modelcontextprotocol/server-sequential-thinking"
      ],
      "enabled": true
    }
  }
}
JSONEOF
info "opencode.json creado (perfil completo)"

cp "$DIR_CONFIG/opencode.json" "$DIR_CONFIG/opencode-cloud.json"
info "opencode-cloud.json creado como copia idéntica de opencode.json"

cat > "$DIR_CONFIG/opencode-local.json" << 'LOCALEOF'
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "/usr/bin/zsh",
  "small_model": "lmstudio/models-qwen3.5-9b",
  "instructions": ["AGENTS.md"],
  "default_agent": "local",
  "permission": {
    "edit": "ask",
    "bash": { "sudo *": "deny", "pkexec *": "allow", "*": "ask" }
  },
  "agent": {
    "build": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "plan": {
      "prompt": "{file:./prompts/read-agents.txt}"
    },
    "local": {
      "description": "Agente local - Qwen 3.5 Q6_K optimizado (80k contexto)",
      "mode": "primary",
      "model": "lmstudio/models-qwen3.5-9b"
    }
  },
  "provider": {
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Qwen 3.5 Q6_K",
      "model": "models-qwen3.5-9b",
      "options": {"baseURL": "http://localhost:4001/v1"},
      "models": {
        "models-qwen3.5-9b": {
          "name": "Qwen 3.5 - Tool Calling Excellence",
          "tools": true,
          "limit": {"context": 81920, "output": 8192}
        }
      }
    }
  },
  "mcp": {
    "context7": {"type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": false},
    "filesystem": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/antonio"], "enabled": true},
    "memory": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-memory"], "enabled": true},
    "fetch": {"type": "local", "command": ["npx", "-y", "mcp-fetch-server"], "enabled": true},
    "sequential_thinking": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"], "enabled": false}
  }
}
LOCALEOF

cat > "$DIR_CONFIG/tui.json" << 'TUIEOF'
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "session_rename": "f8"
  },
  "plugin": [
    [
      "/home/antonio/.config/opencode/opencode-voice-modified/index.js",
      {
        "endpoint": "http://localhost:4001/v1",
        "model": "models-qwen3.5-9b"
      }
    ]
  ]
}
TUIEOF
info "tui.json creado"

cat > "$DIR_CONFIG/switch-mcp-profile.sh" << 'SWITCHEOF'
#!/bin/bash

# Script para cambiar entre configuraciones de OpenCode (local/cloud)
# Uso: switch-mcp-profile.sh [local|cloud]

CONFIG_DIR="$HOME/.config/opencode"

if [ -z "$1" ]; then
    echo "Uso: $0 [local|cloud]"
    echo ""
    echo "  local  - Filesystem, fetch y memory (para modelos locales)"
    echo "  cloud  - Context7, memory, fetch y sequential_thinking (para modelos cloud)"
    exit 1
fi

PROFILE="$1"

if [ "$PROFILE" != "local" ] && [ "$PROFILE" != "cloud" ]; then
    echo "Error: Perfil no válido. Usa 'local' o 'cloud'"
    exit 1
fi

SOURCE_FILE="$CONFIG_DIR/opencode-$PROFILE.json"
TARGET_FILE="$CONFIG_DIR/opencode.json"

if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: No existe $SOURCE_FILE"
    exit 1
fi

cp "$SOURCE_FILE" "$TARGET_FILE"

echo "✅ Configuración cambiada a: $PROFILE"
echo ""
echo "MCPs activos:"
if [ "$PROFILE" = "local" ]; then
    echo "  - filesystem"
    echo "  - fetch"
    echo "  - memory"
else
    echo "  - context7"
    echo "  - memory"
    echo "  - fetch"
    echo "  - sequential_thinking"
fi

echo ""
echo "⚠️  Reinicia OpenCode para aplicar los cambios:"
echo "   exit"
echo "   ocv"
SWITCHEOF
chmod +x "$DIR_CONFIG/switch-mcp-profile.sh"
info "switch-mcp-profile.sh creado"

cat > "$DIR_CONFIG/sync-opencode.sh" << 'SYNCEOF'
#!/usr/bin/env bash
# sync-opencode.sh — Sincroniza .config/opencode/ → Config/opencode/ + regenera backup
# Uso: bash sync-opencode.sh          (manual con output)
#      bash sync-opencode.sh --quiet  (via systemd, solo log)
# -------------------------------------------------------------------
# Sigue la estructura de backup definida en AGENTS.md

set -euo pipefail

HOME_DIR="$HOME"
CONFIG_ACTIVO="$HOME_DIR/.config/opencode"
CONFIG_BACKUP="$HOME_DIR/Config/opencode"
SESION_DIR="${CONFIG_BACKUP}/sesion-opencode"
LOG_FILE="$CONFIG_ACTIVO/data/sync.log"
LOCK_FILE="/tmp/opencode-sync.lock"
QUIET="${1:-}"

# Evitar ejecuciones simultáneas
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
        [ "$QUIET" != "--quiet" ] && echo "⚠️  Ya hay una sincronización en curso."
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

mkdir -p "$CONFIG_ACTIVO/data" "$SESION_DIR"

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE"
    [ "$QUIET" != "--quiet" ] && echo "$*" || true
}

# ─── 1. Copiar archivos críticos de config a sesion-opencode ───
log "🔄 Sincronizando .config/opencode/ → Config/opencode/sesion-opencode/..."

for f in "$CONFIG_ACTIVO"/*.json "$CONFIG_ACTIVO"/*.sh "$CONFIG_ACTIVO"/*.md "$CONFIG_ACTIVO"/*.py "$CONFIG_ACTIVO"/*.yaml "$CONFIG_ACTIVO"/.env "$CONFIG_ACTIVO"/.gitignore; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
        package.json|package-lock.json) continue ;;
    esac
    cp "$f" "$SESION_DIR/" 2>/dev/null || true
done

# Directorios (sin data/, models/, node_modules/)
for dir in commands prompts skills skills-disabled tui.json; do
    [ -d "$CONFIG_ACTIVO/$dir" ] && cp -r "$CONFIG_ACTIVO/$dir" "$SESION_DIR/" 2>/dev/null || true
done

# Plugin de voz
if [ -d "$CONFIG_ACTIVO/opencode-voice-modified" ]; then
    rm -rf "$SESION_DIR/opencode-voice-modified"
    cp -r "$CONFIG_ACTIVO/opencode-voice-modified" "$SESION_DIR/opencode-voice-modified"
    log "✅ Plugin de voz sincronizado"
fi

log "✅ Archivos sincronizados"

# ─── 2. Regenerar backup ───
log "📦 Regenerando tarball de backup..."
bash "$CONFIG_ACTIVO/backup-opencode.sh" 2>&1 | tail -1
log "✅ Backup regenerado"

log "─────────────────────────────────────"
SYNCEOF
chmod +x "$DIR_CONFIG/sync-opencode.sh"
info "sync-opencode.sh creado (unificado manual + systemd)"

# Servicios systemd
mkdir -p "$HOME/.config/systemd/user"

cat > "$HOME/.config/systemd/user/opencode-sync.service" << 'SYSEOF'
[Unit]
Description=OpenCode sync: .config -> Config + backup
After=network.target

[Service]
Type=oneshot
ExecStart=/home/antonio/.config/opencode/sync-opencode.sh --quiet
StandardOutput=journal
StandardError=journal
SYSEOF

cat > "$HOME/.config/systemd/user/opencode-sync.timer" << 'TIMEREOF'
[Unit]
Description=Sync OpenCode each 2 min

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
Unit=opencode-sync.service

[Install]
WantedBy=default.target
TIMEREOF

cat > "$HOME/.config/systemd/user/init-opencode.service" << 'INITSEOF'
[Unit]
Description=OpenCode init: LM Studio + modelo 80K + proxy
After=network.target
StartLimitIntervalSec=0

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/home/antonio/.config/opencode/init-opencode.sh
StandardOutput=append:/home/antonio/.config/opencode/data/init.log
StandardError=append:/home/antonio/.config/opencode/data/init.log

[Install]
WantedBy=default.target
INITSEOF

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user disable init-opencode.service 2>/dev/null || true
systemctl --user enable opencode-sync.timer 2>/dev/null || true
systemctl --user start opencode-sync.timer 2>/dev/null || true
info "Servicios systemd: sync activado, init deshabilitado (sin modelo auto)"
echo ""

# ═══════════════════════════════════════════════════════════
# PASO 7: AGENTS.md
# ═══════════════════════════════════════════════════════════
echo "--- 7/19: Reglas del asistente ---"

cat > "$DIR_CONFIG/AGENTS.md" << 'AGEOF'
# REGLAS OBLIGATORIAS (APLICAR SIEMPRE)

## Usuario
- Se llama Antonio
- Vive en Pechina (Almería, España)

## Idioma
- Responde SIEMPRE en español
- NUNCA cambies al inglés (salvo petición expresa de traducción)
- Español de España (no latinoamericano)

## Formato
- SÍ usamos emoji en pantalla (✈️ 🌤️ 😊) para expresividad visual 
- Mi locucionero filtra estos iconos automáticamente antes del TTS, sin necesidad de configuración extra
- Fecha: dd/mm/aaaa
- Hora: formato 24h (14:30, no 2:30pm)
- Decimales: coma (3,14 no 3.14)
- Moneda: euros (€)
- Sistema métrico: km/h, °C, mm, km

## 🌤️ Consultar el tiempo (IMPORTANTE)
Para preguntas sobre el tiempo, usa la herramienta fetch_html (o fetch_json) para consultar:
https://wttr.in/{ciudad}?format=j1&m&lang=es
Ejemplo: https://wttr.in/Pechina?format=j1&m&lang=es

⚠️ Si wttr.in no responde o devuelve vacío, NO vuelvas a llamar a fetch.
Limítate a informar al usuario: "wttr.in no está disponible ahora, inténtalo más tarde."

## 💻 Consultar hardware del sistema (IMPORTANTE)
Cuando Antonio pregunte sobre su hardware (CPU, RAM, GPU, almacenamiento,
monitores, audio, USB, sensores, red, etc.), LEE el archivo:
```
~/.config/opencode/data/hardware/index.json
```
Ese JSON contiene TODA la información de su sistema. No ejecutes comandos de
detección (inxi, lspci, dmidecode, etc.) a menos que el usuario lo pida
explícitamente o que el JSON no tenga la respuesta.

Consulta rápida desde terminal: `source ~/.config/opencode/hardware-query.sh && hw_query <campo>`

## 🔧 Uso de herramientas (OBLIGATORIO)
Cuando tengas que hacer una tarea que requiera una herramienta (leer archivos,
listar directorios, ejecutar comandos, etc.) USA LA HERRAMIENTA directamente.
NO describas lo que harías — hazlo.
NO digas "voy a leer" sin llamar a la herramienta.
NO generes texto explicando los pasos sin ejecutarlos.
SIMPLIFICA: si necesitas leer múltiples archivos, usa search_files con un
patrón, o llama a read_file para cada archivo individual.

## 🛠️ Elevación de privilegios (sudo NO)
- NUNCA uses `sudo` para comandos que requieran contraseña
- Usa SIEMPRE `pkexec` en su lugar: así saldrá una ventana gráfica pidiendo la contraseña
- Ejemplo: `pkexec apt update` en vez de `sudo apt update`

---

# PROCEDIMIENTOS TÉCNICOS

## Sincronización con Config/opencode (OBLIGATORIO)
- `~/.config/opencode/` es la configuración ACTIVA (la que usa OpenCode)
- `~/Config/opencode/` es la copia de SEGURIDAD para instalaciones desde limpio
- Cada vez que modifiques, crees o elimines algo en `~/.config/opencode/`:
  1. **Copia el archivo** a `~/Config/opencode/` (manteniendo la misma estructura)
  2. **Actualiza los scripts** de instalación si es necesario:
     - `~/Config/opencode/backup-opencode.sh` → script que empaqueta el backup
     - `~/Config/opencode/bootstrap-ocv.sh` → script de instalación desde limpio
     - `restore.sh` (va dentro del tarball, lo genera backup-opencode.sh)
  3. Si el cambio afecta al proceso de instalación/restauración, modifica los scripts para reflejarlo
- Ejecuta `bash ~/Config/opencode/backup-opencode.sh` para regenerar el tarball con restore.sh actualizado

## Atención al script setup-opencode-completo.sh (IMPORTANTE)
El script `~/Config/opencode/sesion-opencode/setup-opencode-completo.sh` es el
INSTALADOR COMPLETO desde cero. Contiene toda la configuración embebida. Por tanto:
- **ÚNICA copia en disco**: vive SOLO en `~/Config/opencode/sesion-opencode/`
  (carpeta de respaldo) y dentro del tarball del backup. NO debe existir en la raíz
  de `~/.config/opencode/` ni en ningún `scripts/`.
- El `sync-opencode.sh` (timer systemd `opencode-sync.timer`, cada 2 minutos)
  sincroniza el resto de archivos desde `~/.config/opencode/`, pero NO crea copias
  del setup: ese se edita directamente en `~/Config/opencode/sesion-opencode/`.
- El `backup-opencode.sh` lo incluye automáticamente en el tarball desde
  `~/Config/opencode/sesion-opencode/`.
- Cuando Antonio pida un backup, DEBES:
  1. Revisar `setup-opencode-completo.sh` por completo
  2. Comprobar que incluye TODOS los archivos actuales de `~/.config/opencode/`
     (JSON, scripts, AGENTS.md, .env, etc.) con su contenido real
  3. Si falta algo o está desactualizado, actualizarlo ANTES del backup en
     `~/Config/opencode/sesion-opencode/setup-opencode-completo.sh`
     (única copia en disco)
  4. Ejecutar `bash ~/Config/opencode/backup-opencode.sh` para regenerar el tarball
  5. Verificar que el tarball contiene el setup actualizado y que no hay copias
     del setup en `~/.config/opencode/` (ni en la raíz ni en `sesion-opencode/scripts/`)
- El `backup-opencode.sh` ya lo incluye automáticamente desde `~/Config/opencode/sesion-opencode/`
- Al RESTAURAR desde un tarball, el `restore.sh` coloca el setup en
  `~/Config/opencode/sesion-opencode/`, no en la raíz de `~/.config/opencode/`

---

# PERSISTENCIA DE DATOS Y RECUPERACIÓN

## Variables de entorno
El archivo `.env` contiene la configuración sensible. Para cargarlo:
```bash
set -a; source /home/antonio/.config/opencode/.env; set +a
```

## Inicialización (tras reinicio del sistema)
El servicio systemd `init-opencode.service` está DESHABILITADO.
Al abrir `opencode` u `ocv` se carga LM Studio + modelo + proxy automáticamente.
Para verificar componentes manualmente:
```bash
bash /home/antonio/.config/opencode/init-opencode.sh
```
Esto comprueba:
- Servidor LM Studio (puerto 1234)
- Modelos disponibles en LM Studio
- Persistencia del grafo de memoria
- PWAs en el Escritorio
- Variables de entorno (.env)

## Backup automático del grafo de memoria
El grafo de conocimiento se respalda automáticamente en:
`/home/antonio/Config/opencode/backups/`
Con nombre `mcp-memory-backup-{fecha}.json`
Los backups se conservan 30 días (según LOG_RETENTION_DAYS en .env)

## Recuperación del grafo de memoria
Si el grafo se pierde o corrompe:
1. Localizar el backup más reciente:
   ```bash
   ls -t /home/antonio/Config/opencode/backups/mcp-memory-backup-*.json | head -1
   ```
2. El servidor MCP Memory debería restaurarlo automáticamente al iniciar desde `MEMORY_DATA_DIR`

## Directorios de datos
- `/home/antonio/.config/opencode/data/` - Datos de ejecución (logs, estado)
- `/home/antonio/.config/opencode/data/memory/` - Grafo de memoria persistente
- `/home/antonio/Config/opencode/backups/` - Copias de seguridad del grafo
- `/home/antonio/.config/opencode/.env` - Variables de entorno seguras

---

# AVANZADO (uso principalmente con DeepSeek)

## PWAs - Cómo abrir
1. Leer /home/antonio/Escritorio
2. Buscar archivo chrome-<app-id>-Profile_2.desktop
3. Ejecutar línea Exec= del archivo

## PWAs - Cerrar
- Una PWA: curl -s http://localhost:9222/json/close/<ID>
- Todo Chrome: pkill -f "chrome.*remote-debugging-port"

## Chrome debug (si no está corriendo)
nohup /opt/google/chrome/google-chrome --user-data-dir="/tmp/chrome-debug-profile" "--profile-directory=DebugProfile" --remote-debugging-port=9222 "--remote-allow-origins=*" about:blank > /dev/null 2>&1 &

## Carga automática al abrir opencode/ocv
Al ejecutar `opencode` u `ocv`, el lanzador
`start-opencode-server.sh` carga automáticamente:
- Servidor LM Studio (puerto 1234)
- Modelo Qwen3.5-9B Q6_K con 80k de contexto
- Proxy en puerto 4001 con métricas de tokens/s

El servicio systemd `init-opencode.service` está DESHABILITADO
(no carga el modelo al iniciar sesión). La carga ocurre solo
al abrir opencode/ocv.

## Iniciar LM Studio manualmente
```bash
bash /home/antonio/.config/opencode/start-lmstudio.sh      # servidor + modelo + proxy
bash /home/antonio/.config/opencode/start-lmstudio-server.sh  # solo servidor + proxy
```

## Liberar VRAM
Si el modelo se satura, usar:
```bash
/home/antonio/.lmstudio/bin/lms unload --all
```

## 📊 Tokens/s en respuestas locales
El proxy en puerto 4001 calcula y muestra tokens/segundo automáticamente
en cada respuesta. Se ve en el campo `stats.tokens_per_second` del JSON.

Para ver tokens/s en OpenCode TUI: la info aparece al final de cada mensaje
junto al nombre del modelo (ej: "Qwen 3.5 Q6_K · 13.5 tok/s").

Método rápido por terminal:
```bash
curl -s http://localhost:4001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"models-qwen3.5-9b","messages":[{"role":"user","content":"hola"}]}' | \
  python3 -c "import json,sys; d=json.load(sys.stdin); u=d['usage']; s=d.get('stats',{}); print(f\"Prompt: {u['prompt_tokens']} tok\\nGenerados: {u['completion_tokens']} tok\\nVelocidad: {s.get('tokens_per_second','N/A')} tok/s\")"
```

# CHECKLIST ANTES DE RESPONDER
- ¿Respuesta en español?
- ¿Fecha/hora en formato España?
- ¿Decimales con coma?
- Si pregunta por el tiempo: ¿he usado wttr.in?
- ¿He usado la herramienta directamente en vez de describir lo que haría?
AGEOF
info "AGENTS.md creado"

# ═══════════════════════════════════════════════════════════
# PASO 8: Prompts
# ═══════════════════════════════════════════════════════════
echo "--- 8/19: Prompts ---"

mkdir -p "$DIR_CONFIG/prompts"
cat > "$DIR_CONFIG/prompts/read-agents.txt" << 'PROMPTEOF'
Al inicio de cada sesión, usa la herramienta Read para leer ~/.config/opencode/AGENTS.md y seguir las instrucciones del usuario.
PROMPTEOF
info "prompts/read-agents.txt creado"

# ═══════════════════════════════════════════════════════════
# PASO 9: Variables de entorno
# ═══════════════════════════════════════════════════════════
echo "--- 9/19: Variables de entorno ---"

cat > "$DIR_CONFIG/.env" << 'ENVEOF'
# Configuración de variables de entorno para OpenCode
# Fecha: 26/07/2026
# Usuario: Antonio

# =============================================================================
# --- Ollama ---
# =============================================================================
OLLAMA_API_KEY=ollama
OLLAMA_PROXY_PORT=4000

# =============================================================================
# --- Context7 (API de documentación) ---
# =============================================================================
MCP_CONTEXT7_URL=https://mcp.context7.com/mcp

# =============================================================================
# --- Chrome Debug (PWAs) ---
# =============================================================================
CHROME_DEBUG_PROFILE=/tmp/chrome-debug-profile
REMOTE_DEBUGGING_PORT=9222

# =============================================================================
# --- Navegación web / Fetch ---
# =============================================================================
USER_AGENT="Mozilla/5.0 (compatible; OpenCode-Bot)"
MAX_SEARCH_RESULTS=8
TIMEOUT_SECONDS=120

# =============================================================================
# --- Persistencia de datos (Memoria) ---
# =============================================================================
MEMORY_DATA_DIR=/home/antonio/.config/opencode/data/memory
MEMORY_BACKUP_ENABLED=true
MEMORY_BACKUP_PATH=/home/antonio/Config/opencode/backups/mcp-memory-backup-$(date '+%Y-%m-%d_%H%M').json

# =============================================================================
# --- Logging / Auditoría ---
# =============================================================================
LOG_FILE=/home/antonio/.config/opencode/data/init.log
LOG_RETENTION_DAYS=30
AUDIT_ENABLED=true

# =============================================================================
# ⚠️ CREDENCIALES SEGURAS (NO COMENTAR PARA ACTIVAR) ---
# Copia este archivo a .env y edita con valores reales antes de usar
# =============================================================================
# OLLAMA_API_KEY=tu_clave_segura_aqui
# EXTERNAL_SERVICE_API_KEY=tu_api_key_externa_aqui

# =============================================================================
# --- Variables opcionales (desactivadas por defecto) ---
# =============================================================================
ENABLE_METRICS=false
METRICS_EXPORT_PATH=/home/antonio/.config/opencode/data/metrics.json

# =============================================================================
# --- Hardware Index (Información del sistema) ---
# =============================================================================  
# Ruta centralizada a todos los datos hardware del sistema, accesible desde cualquier modelo/sesión
HARDWARE_INDEX_PATH=/home/antonio/.config/opencode/data/hardware/index.json
ENVEOF
chmod 600 "$DIR_CONFIG/.env"
info ".env creado (permisos 600)"

# ═══════════════════════════════════════════════════════════
# PASO 10: Script de inicializacion
# ═══════════════════════════════════════════════════════════
echo "--- 10/19: init-opencode.sh ---"

cat > "$DIR_CONFIG/init-opencode.sh" << 'INITEOF'
#!/bin/bash
# Inicialización completa de OpenCode
# Arranca LM Studio, carga modelo con 80K contexto, inicia proxy
# Se ejecuta automáticamente al iniciar sesión vía systemd --user

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/opencode.json"
LOG_FILE="${SCRIPT_DIR}/data/init.log"
DATA_DIR="${SCRIPT_DIR}/data"
LMSTUDIO_BIN="/home/antonio/.lmstudio/bin/lms"
MODELO="models-qwen3.5-9b"
CONTEXTO=81920
PUERTO_LM=1234
PUERTO_PROXY=4001

mkdir -p "$DATA_DIR"

echo "=== Inicialización OpenCode - $(date '+%d/%m/%Y %H:%M') ===" > "$LOG_FILE"
echo "" >> "$LOG_FILE"

log() {
    echo "[$(date '+%H:%M')] $1" | tee -a "$LOG_FILE"
}

# ─── 1. Arrancar servidor LM Studio ───
iniciar_lmstudio() {
    log "--- 1. Servidor LM Studio ---"
    if curl -s -o /dev/null -w "" http://127.0.0.1:$PUERTO_LM/v1/models 2>/dev/null; then
        log "✅ Servidor LM Studio ya está corriendo en puerto $PUERTO_LM."
    else
        log "🔄 Arrancando servidor LM Studio..."
        $LMSTUDIO_BIN server start 2>/dev/null
        sleep 3
        if curl -s -o /dev/null -w "" http://127.0.0.1:$PUERTO_LM/v1/models 2>/dev/null; then
            log "✅ Servidor LM Studio arrancado correctamente."
        else
            log "❌ No se pudo arrancar LM Studio. Ejecuta 'lms server start' manualmente."
            return 1
        fi
    fi
    return 0
}

# ─── 2. Cargar modelo con 80K de contexto ───
cargar_modelo() {
    log "--- 2. Modelo ($MODELO) ---"
    local ctx_actual
    ctx_actual=$($LMSTUDIO_BIN ps 2>/dev/null | grep "$MODELO" | awk '{print $6}')

    if [ "$ctx_actual" = "$CONTEXTO" ]; then
        log "✅ Modelo $MODELO ya cargado con contexto $CONTEXTO."
        return 0
    fi

    log "🔄 Cargando $MODELO con contexto $CONTEXTO..."
    $LMSTUDIO_BIN unload "$MODELO" 2>/dev/null
    $LMSTUDIO_BIN load "$MODELO" -c $CONTEXTO -y 2>/dev/null

    ctx_actual=$($LMSTUDIO_BIN ps 2>/dev/null | grep "$MODELO" | awk '{print $6}')
    if [ "$ctx_actual" = "$CONTEXTO" ]; then
        log "✅ Modelo cargado con contexto $CONTEXTO."
    else
        log "⚠️  Contexto cargado: $ctx_actual (se esperaba $CONTEXTO). Reintentando..."
        sleep 2
        $LMSTUDIO_BIN unload "$MODELO" 2>/dev/null
        $LMSTUDIO_BIN load "$MODELO" -c $CONTEXTO -y 2>/dev/null
        ctx_actual=$($LMSTUDIO_BIN ps 2>/dev/null | grep "$MODELO" | awk '{print $6}')
        if [ "$ctx_actual" = "$CONTEXTO" ]; then
            log "✅ Contexto correcto tras reintento."
        else
            log "❌ Contexto sigue siendo $ctx_actual. Revisa LM Studio manualmente."
        fi
    fi
}

# ─── 3. Iniciar proxy ───
iniciar_proxy() {
    log "--- 3. Proxy (puerto $PUERTO_PROXY) ---"
    if curl -s -o /dev/null -w "" http://127.0.0.1:$PUERTO_PROXY/v1/models 2>/dev/null; then
        log "✅ Proxy ya activo en puerto $PUERTO_PROXY."
        return 0
    fi

    if pgrep -f "lmstudio-proxy.py" > /dev/null 2>&1; then
        log "✅ Proxy ya presente (aunque no respondía rápido). Se mantiene."
        return 0
    fi

    log "🔄 Iniciando proxy en puerto $PUERTO_PROXY..."
    setsid python3 "$SCRIPT_DIR/lmstudio-proxy.py" $PUERTO_PROXY < /dev/null > /tmp/lmstudio-proxy.log 2>&1 &
    sleep 2

    if curl -s -o /dev/null -w "" http://127.0.0.1:$PUERTO_PROXY/v1/models 2>/dev/null; then
        log "✅ Proxy iniciado correctamente."
    else
        log "❌ Proxy no responde. Revisa /tmp/lmstudio-proxy.log"
    fi
}

# ─── 4. Asegurar settings.json con 80K ───
fijar_contexto_settings() {
    local settings_file="$HOME/.lmstudio/settings.json"
    if [ -f "$settings_file" ]; then
        local valor_actual
        valor_actual=$(python3 -c "
import json
try:
    d = json.load(open('$settings_file'))
    v = d.get('defaultContextLength', {}).get('value', '')
    print(v)
except: print('')
" 2>/dev/null)
        if [ "$valor_actual" != "$CONTEXTO" ]; then
            python3 -c "
import json
d = json.load(open('$settings_file'))
d['defaultContextLength'] = {'type': 'custom', 'value': '$CONTEXTO'}
json.dump(d, open('$settings_file', 'w'), indent=2)
" 2>/dev/null && log "✅ defaultContextLength fijado a $CONTEXTO en settings.json"
        fi
    fi
}

# ─── 5. Verificaciones ───
check_models() {
    log "--- 4. Modelos disponibles ---"
    sleep 1
    local respuesta
    respuesta=$(curl -s http://127.0.0.1:$PUERTO_LM/v1/models)
    if [ -n "$respuesta" ]; then
        echo "$respuesta" | grep -o '"id":"[^"]*"' | cut -d'"' -f4 > "${DATA_DIR}/available_models.txt" 2>/dev/null || true
        local count=$(wc -l < "${DATA_DIR}/available_models.txt" 2>/dev/null || echo 0)
        log "✅ $count modelo(s) disponible(s)."
    else
        log "⚠️ No se pudo listar modelos."
    fi
}

check_memory() {
    if [ -f "${DATA_DIR}/memory_status.txt" ]; then
        log "✅ Persistencia de datos presente."
    else
        echo "initialized at $(date '+%d/%m/%Y %H:%M')" > "${DATA_DIR}/memory_status.txt"
        log "✅ Persistencia de datos inicializada."
    fi
}

check_hardware() {
    if [ -f "${DATA_DIR}/hardware/index.json" ]; then
        log "✅ Index de hardware disponible."
    else
        log "⚠️ Index de hardware no encontrado."
    fi
}

check_env() {
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        log "✅ Archivo .env presente."
    else
        log "⚠️ .env no encontrado."
    fi
}

# ─── MAIN ───
log "🚀 INICIO - Inicialización de OpenCode"

fijar_contexto_settings
iniciar_lmstudio
cargar_modelo
iniciar_proxy
check_models
check_memory
check_hardware
check_env

log ""
log "✅ INICIALIZACIÓN COMPLETADA"
log "   LM Studio : http://127.0.0.1:$PUERTO_LM/v1"
log "   Proxy     : http://127.0.0.1:$PUERTO_PROXY/v1"
log "   Contexto  : $CONTEXTO tokens"

echo ""
echo "✅ OpenCode listo. Detalles en: $LOG_FILE"
tail -5 "$LOG_FILE"
INITEOF
chmod +x "$DIR_CONFIG/init-opencode.sh"
info "init-opencode.sh creado"

# ═══════════════════════════════════════════════════════════
# PASO 11: Scripts LM Studio (server sin modelo + carga completa)
# ═══════════════════════════════════════════════════════════
echo "--- 11/19: start-lmstudio-server.sh + start-lmstudio.sh + settings ---"

cat > "$DIR_CONFIG/start-lmstudio-server.sh" << 'SERVEREOF'
#!/usr/bin/env bash
# start-lmstudio-server.sh - Solo servidor LM Studio sin cargar modelo en VRAM
set -euo pipefail

LMSTUDIO="/home/antonio/.lmstudio/bin/lms"
PORT_LM=1234
PORT_PROXY=4001

echo "╔════════════════════════════════════════════════════╗"
echo "║  LM Studio Server (sin modelo cargado en VRAM)   ║"
echo "║  Esperando carga manual desde OpenCode/OCV       ║"
echo "╚════════════════════════════════════════════════════╝"

# Verificar binario
if [ ! -f "$LMSTUDIO" ]; then
    echo "❌ Binario no encontrado: $LMSTUDIO"
    exit 1
fi

# Descargar y cargar modelos previos para liberar VRAM
echo "▶️  Descargando modelos previos..."
"$LMSTUDIO" download --all >/dev/null 2>&1 || true

# Liberar TODOS los modelos cargados
echo "▶️  Liberando VRAM..."
"$LMSTUDIO" unload --all >/dev/null 2>&1 || true
sleep 2

# Verificar estado antes de iniciar servidor
MODELS_BEFORE=$("$LMSTUDIO" ps 2>/dev/null || echo "")
if [ -n "$MODELS_BEFORE" ]; then
    echo "⚠️  Advertencia: Hay modelos cargados:"
    echo "$MODELS_BEFORE" | grep -v "^$" | head -3
fi

# Iniciar servidor LM Studio si no está corriendo
echo "▶️  Verificando servidor LM Studio..."
if curl -s http://localhost:$PORT_LM/v1/models >/dev/null 2>&1; then
    echo "✅ LM Studio ya está corriendo en puerto ${PORT_LM}"
else
    echo "▶️  Arrancando LM Studio server..."
    "$LMSTUDIO" server start >/dev/null 2>&1
    sleep 3
    
    # Verificar que el servidor responde
    if ! curl -s http://localhost:$PORT_LM/v1/models >/dev/null 2>&1; then
        echo "❌ Falló al iniciar LM Studio. Asegúrate de que la GUI esté abierta o usa: lms server start"
        exit 1
    fi
fi

# Verificar estado final (debería estar vacío)
MODELS_AFTER=$("$LMSTUDIO" ps 2>/dev/null || echo "")
echo "✅ LM Studio activo en puerto ${PORT_LM}"

if [ -n "$MODELS_AFTER" ] && ! echo "$MODELS_AFTER" | grep -q "^$"; then
    VRAM_USO=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
    echo "⚠️  Advertencia: Modelo cargado (debería estar vacío):"
    echo "$MODELS_AFTER" | grep -v "^$" | head -3
    echo "   VRAM usada: ${VRAM_USO} MB"
else
    VRAM_USO=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
    echo "✅ VRAM libre: ${VRAM_USO} MB / 16376 MB"
fi

# Matar proxies zombies y arrancar uno limpio
echo "▶️  Iniciando proxy en puerto ${PORT_PROXY}..."
if pgrep -f "lmstudio-proxy" >/dev/null 2>&1; then
    pkill -f "lmstudio-proxy" 2>/dev/null || true
    sleep 1
fi

setsid python3 /home/antonio/.config/opencode/lmstudio-proxy.py "$PORT_PROXY" < /dev/null > /tmp/lms-proxy.log 2>&1 &
sleep 2
echo "✅ Proxy activo en http://localhost:${PORT_PROXY}"

echo ""
echo "════════════════════════════════════════════════════"
echo "  Servidor listo! Modelo NO cargado en VRAM."
echo "  Carga automática cuando uses: ocv o opencode"
echo "  API: http://localhost:${PORT_PROXY}/v1/chat/completions"
echo "════════════════════════════════════════════════════"
SERVEREOF

cat > "$DIR_CONFIG/start-lmstudio.sh" << 'LMSEOF'
#!/usr/bin/env bash
# start-lmstudio.sh - Qwen3.5-9B Q6_K + RTX 4070 Ti SUPER (80k contexto)
set -euo pipefail

LMSTUDIO="/home/antonio/.lmstudio/bin/lms"
MODEL_ID="models-qwen3.5-9b"
CONTEXTO=81920
PORT_LM=1234
PORT_PROXY=4001

echo "╔════════════════════════════════════════════════════╗"
echo "║  Qwen3.5-9B Q6_K - 80k contexto                  ║"
echo "║  RTX 4070 Ti SUPER 16GB + Ryzen 9 7900 Zen4      ║"
echo "╚════════════════════════════════════════════════════╝"

# Verificar binario
if [ ! -f "$LMSTUDIO" ]; then
    echo "❌ Binario no encontrado: $LMSTUDIO"
    exit 1
fi

# Iniciar servidor LM Studio si no está corriendo
if ! curl -s http://localhost:$PORT_LM/v1/models >/dev/null 2>&1; then
    echo "▶️  Arrancando LM Studio server..."
    "$LMSTUDIO" server start >/dev/null 2>&1
    sleep 3
fi
echo "✅ LM Studio activo puerto ${PORT_LM}"

# Descargar modelos previos para liberar VRAM
echo "▶️  Liberando VRAM..."
"$LMSTUDIO" unload --all >/dev/null 2>&1 || true
sleep 2

# Cargar Q6_K con 80k contexto
echo "▶️  Cargando Qwen3.5-9B Q6_K con ${CONTEXTO} tokens de contexto..."
if ! "$LMSTUDIO" load "$MODEL_ID" -c "$CONTEXTO" -y >/dev/null 2>&1; then
    echo "⚠️  Carga directa falló, intentando sin contexto específico..."
    "$LMSTUDIO" load "$MODEL_ID" -y >/dev/null 2>&1
fi
sleep 2

CONTEXTO_REAL=$("$LMSTUDIO" ps 2>/dev/null | grep -m1 "$MODEL_ID" | awk '{print $6}')
echo "✅ Modelo cargado: ${CONTEXTO_REAL:-desconocido} tokens de contexto"

VRAM_USO=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null || echo "N/A")
echo "✅ VRAM usado: ${VRAM_USO} MB / 16376 MB"

# Matar proxies zombies y arrancar uno limpio
if pgrep -f "lmstudio-proxy" >/dev/null 2>&1; then
    pkill -f "lmstudio-proxy" 2>/dev/null || true
    sleep 1
fi
echo "▶️  Iniciando proxy en puerto ${PORT_PROXY}..."
setsid python3 /home/antonio/.config/opencode/lmstudio-proxy.py "$PORT_PROXY" < /dev/null > /tmp/lms-proxy.log 2>&1 &
sleep 2
echo "✅ Proxy activo en http://localhost:${PORT_PROXY}"

echo ""
echo "════════════════════════════════════════════════════"
echo "  Sistema listo para usar!"
echo "  API: http://localhost:${PORT_PROXY}/v1/chat/completions"
echo "  Modelo: $MODEL_ID"
echo "  Contexto: ${CONTEXTO} tokens"
echo "  Tokens/s: incluido en cada respuesta"
echo "════════════════════════════════════════════════════"
LMSEOF

chmod +x "$DIR_CONFIG/start-lmstudio-server.sh"
chmod +x "$DIR_CONFIG/start-lmstudio.sh"
info "start-lmstudio.sh y start-lmstudio-server.sh creados"

mkdir -p "$HOME/.lmstudio"
cat > "$HOME/.lmstudio/settings.json" << 'SETEOF'
{
    "language": "en",
    "downloadsFolder": "/home/antonio/.lmstudio/models",
    "sidebar": {
        "showButtonNames": false,
        "monochromeSidebarIcons": true
    },
    "configs": {
        "expandConfigsOnClick": true
    },
    "chat": {
        "showSuggestionsOnNewChat": true,
        "allowOnlyOneNewChat": true,
        "alwaysShowPromptTemplate": false,
        "useShiftEnterToSendMessage": false,
        "useKeychordToRegenerate": true,
        "unloadPreviousModelOnSelect": true,
        "highlightChatMessageOnHover": true,
        "doubleClickMessageToEdit": false,
        "doubleClickChatCellRenames": false,
        "aiNamingMode": "auto",
        "autoExpandReasoningBlocks": false,
        "reasoningBlocksVignette": true,
        "messageGenInfoMode": "lastMessage",
        "visualizeSpeculativeDecoding": false,
        "chatFullWidth": false,
        "neverAskForToolConfirmation": false,
        "skipToolConfirmationPatterns": [],
        "showChatUtilityMenuLabels": true,
        "pinnedPlugins": [],
        "showRoleAndInsertButtons": false,
        "scrollLastMessageToTop": "scrollToTopNoLatch",
        "showTokenCountInChatListings": false,
        "moveDeletedItemsToTrash": false,
        "sidebarSort": {
            "field": "createdAt",
            "direction": "desc"
        },
        "showSpringboardWhenClosingAllTabsInSplit": false,
        "imageInputs": {
            "userMaxImageDimensionPixelsEnabled": true,
            "userMaxImageDimensionPixels": 2048,
            "ignoreModelPreferredMaxImageDimension": false
        }
    },
    "developer": {
        "showExperimentalFeatures": false,
        "experimentalLoadPresets": false,
        "backendDownloadChannel": "stable",
        "appUpdateChannel": "stable",
        "showDebugInfoBlocksInChat": false,
        "showModelDownloadOptionData": false,
        "showResourceConsumptionWidget": false,
        "allowDevelopmentPlugins": true,
        "unloadPreviousJITModelOnLoad": true,
        "jitModelTTL": {
            "enabled": true,
            "ttlSeconds": 3600
        },
        "autoUpdateExtensionPacks": false,
        "autoDeleteExtensionPacks": false,
        "separateReasoningContentInAPI": true,
        "experimentFlags": [],
        "apiPredictionHistoryEviction": {
            "type": "time",
            "ttlDays": 30
        },
        "attemptedInstallLmsCliOnStartup": false
    },
    "ui": {
        "missionControlFullscreen": false,
        "showModelFileNameInMyModels": false,
        "configureLoadParamsBeforeLoad": false,
        "alwaysOpenModelLoaderFromPicker": false,
        "contextDisplayMode": "percentage",
        "appNavigationBarPosition": "left",
        "showTabStripScrollBar": false,
        "tabStripFullStripStyle": false,
        "openDownloadsPaneOnStartNewModelDownload": false
    },
    "configPresetInclusiveness": {
        "speculativeDecoding": false
    },
    "toggledConfigDropdowns": [],
    "userInterfaceComplexityLevel": 0,
    "developerMode": false,
    "appFirstLoad": false,
    "autoLoadBundledLLM": false,
    "modelLoadingGuardrails": {
        "mode": "high",
        "customThresholdBytes": 4294967296,
        "alwaysAllowLoadAnyway": false
    },
    "dismissedModals": [],
    "dismissedConversationSnackbars": [],
    "pre030ChatsMigrated": 3,
    "appPostUpdateNotificationPending": false,
    "promptWhenCommittingUnsavedChangesWithNewFields": false,
    "enableLocalService": false,
    "enableEngineProtocolRuntime": false,
    "cliInstalled": false,
    "useHFProxy": true,
    "hfSearchToken": "",
    "hfDownloadToken": "",
    "defaultContextLength": {
        "type": "custom",
        "value": "81920"
    },
    "appIntroAcceptedForBuild": null
}
SETEOF
info "settings.json de LM Studio creado (contexto 80K)"

# ═══════════════════════════════════════════════════════════
# PASO 12: Lanzador OpenCode (carga modelo + proxy automáticamente)
# ═══════════════════════════════════════════════════════════
echo "--- 12/19: start-opencode-server.sh ---"

cat > "$DIR_CONFIG/start-opencode-server.sh" << 'STARTEOF'
#!/usr/bin/env bash
# start-opencode-server.sh - Carga LM Studio + modelo Qwen3.5-9B + proxy, luego abre OpenCode/OCV
set -e

# Colores para output
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
ROJO='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${VERDE}[+]${NC} $1"; }
aviso() { echo -e "${AMARILLO}[!]${NC} $1"; }
error() { echo -e "${ROJO}[X]${NC} $1"; }

LMS_SCRIPT="/home/antonio/.config/opencode/start-lmstudio.sh"
REAL_OPENCODE="${REAL_OPENCODE:-/usr/bin/opencode}"

# 1. Cargar LM Studio + modelo Qwen3.5-9B + proxy
if [ -x "$LMS_SCRIPT" ]; then
    info "Cargando LM Studio (modelo Qwen3.5-9B + proxy)..."
    bash "$LMS_SCRIPT" || {
        error "Falló al cargar LM Studio + modelo."
        exit 1
    }
else
    aviso "start-lmstudio.sh no encontrado, usando start-lmstudio-server.sh"
    bash /home/antonio/.config/opencode/start-lmstudio-server.sh || {
        error "Falló al iniciar LM Studio."
        exit 1
    }
fi

# 2. Ejecutar OpenCode (binario real)
info "Lanzando ${REAL_OPENCODE}..."
exec "${REAL_OPENCODE}" "$@"
STARTEOF
chmod +x "$DIR_CONFIG/start-opencode-server.sh"
info "start-opencode-server.sh creado"

# ═══════════════════════════════════════════════════════════
# PASO 13: Scripts auxiliares
# ═══════════════════════════════════════════════════════════
echo "--- 13/19: Scripts auxiliares ---"

cat > "$DIR_CONFIG/hardware-query.sh" << 'HARDWARE-QUERY_SHEOF'
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
HARDWARE-QUERY_SHEOF
chmod +x "$DIR_CONFIG/hardware-query.sh"
info "hardware-query.sh creado"

cat > "$DIR_CONFIG/check-fix.sh" << 'CHECK-FIX_SHEOF'
#!/bin/bash
# Comprueba el estado del issue #39164 de OpenCode
# Muestra notificación si está cerrado (arreglado)

ISSUE_URL="https://api.github.com/repos/anomalyco/opencode/issues/39164"
CACHE_FILE="/home/antonio/.config/opencode/data/issue_status.txt"

RESP=$(curl -s "$ISSUE_URL" 2>/dev/null)
STATE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('state','unknown'))" 2>/dev/null)

echo "$STATE" > "$CACHE_FILE"

if [ "$STATE" = "closed" ]; then
    MSG="🎉 ¡El issue #39164 está CERRADO! El fix de tools locales ya está disponible."
    echo "$MSG"
    # Notificación desktop
    notify-send -u critical "OpenCode Fix Disponible" "$MSG" 2>/dev/null || true
elif [ "$STATE" = "open" ]; then
    echo "🔴 Issue #39164: ABIERTO - El bug de tools locales sigue pendiente."
    echo "   https://github.com/anomalyco/opencode/issues/39164"
else
    echo "⚠️ No se pudo verificar el estado del issue."
fi
CHECK-FIX_SHEOF
chmod +x "$DIR_CONFIG/check-fix.sh"
info "check-fix.sh creado"

cat > "$DIR_CONFIG/web-search.sh" << 'WEB-SEARCH_SHEOF'
#!/bin/bash
# MCP Server de búsqueda con DuckDuckGo (sin dependencias)
# Devuelve resultados en formato JSON para el protocolo MCP

QUERY="${1:-}"
TIMEOUT=45
USER_AGENT="Mozilla/5.0 (compatible; MCP/Search)"

if [ -z "$QUERY" ]; then
    echo '{"error": "No query provided"}' >&2
    exit 1
fi

# Sanitizar la consulta para evitar problemas con caracteres especiales
SAFE_QUERY=$(printf '%s' "$QUERY" | sed 's/[^a-zA-Z0-9._ -]//g')

if [ -z "$SAFE_QUERY" ]; then
    echo '{"result": {"type": "html", "content": "<div class=\"error\">La consulta está vacía o no es válida.</div>"}}'
    exit 1
fi

# Intento 1: DuckDuckGo JSON API
RESULT=$(curl -s --max-time "${TIMEOUT}" \
    -H "User-Agent: ${USER_AGENT}" \
    "https://api.duckduckgo.com/?q=${SAFE_QUERY}&format=json&no_redirect=1" 2>/dev/null)

if [ -n "$RESULT" ] && echo "$RESULT" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "{\"result\": ${RESULT}}"
    exit 0
fi

# Intento 2: DuckDuckGo HTML API (fallback)
RESULT_HTML=$(curl -s --max-time "${TIMEOUT}" \
    -H "User-Agent: ${USER_AGENT}" \
    "https://html.duckduckgo.com/html/?q=${SAFE_QUERY}" 2>/dev/null)

if [ -n "$RESULT_HTML" ]; then
    CLEANED=$(printf '%s' "$RESULT_HTML" | sed -E 's/<script[^>]*>.*<\/script>//g; s/<style[^>]*>.*<\/style>//g; s/<[^>]+>//g; s/\s+/ /g' | head -c 4096)
    echo "{\"result\": {\"type\": \"html\", \"content\": \"${CLEANED}\"}}"
    exit 0
fi

# Error genérico
cat << 'ERRMSG'
{"result": {"type": "html", "content": "<div class=\"error\">Error al realizar búsqueda.\n\nPosibles causas:\n- Conexión a internet desconectada\n- Límite de API alcanzado (espera unos minutos)\n- La consulta contiene palabras prohibidas por el proveedor\n\nPrueba con una pregunta sencilla como \"tiempo Pechina\"."}}
ERRMSG
exit 1
WEB-SEARCH_SHEOF
chmod +x "$DIR_CONFIG/web-search.sh"
info "web-search.sh creado"

# ═══════════════════════════════════════════════════════════
# PASO 14: Proxy LM Studio
# ═══════════════════════════════════════════════════════════
echo "--- 14/19: lmstudio-proxy.py ---"

cat > "$DIR_CONFIG/lmstudio-proxy.py" << 'LMPROXYEOF'
#!/usr/bin/env python3
"""Proxy OpenCode ↔ LM Studio - VERSIÓN QUE FUNCIONA"""
import json, http.server, urllib.request, sys

LM = "http://localhost:1234"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4001

class Proxy(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    def log_message(self, *args): pass

    def do_GET(self):
        try:
            r = urllib.request.urlopen(urllib.request.Request(f"{LM}{self.path}"), timeout=5)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(r.read())
        except: self.send_error(502)

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        body = json.loads(raw)
        model = body.get("model", "")
        if model.startswith("lmstudio/"):
            body["model"] = model[len("lmstudio/"):]

        msgs = body.get('messages', [])
        if not any(m.get('role') == 'user' for m in msgs):
            body['messages'].append({'role': 'user', 'content': '(cont.)'})

        try:
            r = urllib.request.urlopen(urllib.request.Request(
                f"{LM}{self.path}", data=json.dumps(body).encode(),
                headers={"Content-Type": "application/json"}), timeout=300)

            is_stream = body.get("stream", False)
            if is_stream:
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Cache-Control", "no-cache")
                self.end_headers()
                while True:
                    chunk = r.read(65536)
                    if not chunk: break
                    self.wfile.write(chunk)
                    self.wfile.flush()
            else:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(r.read())
        except Exception as e:
            self.send_error(502, str(e)[:200])

http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Proxy).serve_forever()
LMPROXYEOF
chmod +x "$DIR_CONFIG/lmstudio-proxy.py"
info "lmstudio-proxy.py creado"

# ═══════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════
# PASO 14b: Scripts y configs adicionales
# ═══════════════════════════════════════════════════════════
cat > "$DIR_CONFIG/backup-opencode.sh" << 'BKUEOF'
#!/bin/bash
# Backup de OpenCode - Script oficial según AGENTS.md
# Genera tarball con restore.sh actualizado
# Puntos de AGENTS.md líneas 59-68:
#   - Copia desde .config/opencode/ a Config/opencode/
#   - Actualiza backup-opencode.sh y bootstrap-ocv.sh
#   - restore.sh va dentro del tarball (lo genera este script)

set -euo pipefail

CONFIG_ACTIVO="/home/antonio/.config/opencode"
CONFIG_BACKUP="/home/antonio/Config/opencode"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="opencode-backup-${DATE}"

BACKUP_ROOT="${CONFIG_BACKUP}/${BACKUP_NAME}"

echo "=== Backup OpenCode - $(date '+%d/%m/%Y %H:%M') ==="

mkdir -p "${BACKUP_ROOT}"

# ─── 1. Copiar estructura de .config/opencode/ excluyendo runtime y backups viejos
echo "📦 Copiando configuración desde ~/.config/opencode/..."
rsync -ah --delete \
  --exclude='backups/' \
  --exclude='sesion-opencode/' \
  --exclude='node_modules/' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  --exclude='data/memory/' \
  --exclude='data/dmi/' \
  --exclude='data/init.log' \
  --exclude='data/sync.log' \
  --exclude='data/common-cmds.log' \
  --exclude='models/' \
  --exclude='build/' \
  --exclude='.git/' \
  --exclude='package-lock.json' \
  --exclude='package.json' \
  --exclude='*.tar.gz' \
  --exclude='opencode-backup-*/' \
  --exclude='opencode-sync-*.tar.gz' \
  --exclude='setup-opencode-completo.sh' \
  "${CONFIG_ACTIVO}/." "${BACKUP_ROOT}/"

# ─── 2. Generar restore.sh dentro del backup
echo "🔧 Creando restore.sh..."
cat > "${BACKUP_ROOT}/${BACKUP_NAME}-restore.sh" << 'RESTORE_EOF'
#!/bin/bash
# Restaurar OpenCode desde backup - generado automáticamente por backup-opencode.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}"
DEST_CONFIG="/home/antonio/.config/opencode"

echo "=== Restaurando OpenCode ==="
echo "Fuente: $SOURCE_DIR"
echo "Destino: ${DEST_CONFIG}"
echo ""

if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ ERROR: Directorio de backup no encontrado: $SOURCE_DIR"
    exit 1
fi

# Crear directorio destino si no existe
mkdir -p "$DEST_CONFIG"

# Copiar archivos (excluyendo el propio restore.sh y el setup completo)
echo "Copiando archivos..."
rsync -ah --exclude='*-restore.sh' \
       --exclude='setup-opencode-completo.sh' \
       "$SOURCE_DIR/" "${DEST_CONFIG}/."

# El setup-opencode-completo.sh vive solo en la copia de seguridad
if [ -f "$SOURCE_DIR/setup-opencode-completo.sh" ]; then
    mkdir -p "/home/antonio/Config/opencode/sesion-opencode"
    cp "$SOURCE_DIR/setup-opencode-completo.sh" \
       "/home/antonio/Config/opencode/sesion-opencode/setup-opencode-completo.sh"
    echo "✅ setup-opencode-completo.sh restaurado en Config/opencode/sesion-opencode/"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Restauración completada en ${DEST_CONFIG}"

    # Verificar archivos críticos
    if [ -f "${DEST_CONFIG}/opencode.json" ] && \
       [ -f "${DEST_CONFIG}/AGENTS.md" ] && \
       [ -f "${DEST_CONFIG}/init-opencode.sh" ]; then
        echo "✅ Archivos principales verificados correctamente"

        # Inicializar si es necesario
        if [ -x "${DEST_CONFIG}/init-opencode.sh" ]; then
            echo ""
            echo "🚀 Ejecutando inicialización de OpenCode..."
            bash "${DEST_CONFIG}/init-opencode.sh"
        fi
    else
        echo "⚠️  Algunos archivos faltantes. Revisa la restauración:"
        ls -la "${DEST_CONFIG}" | head -20
    fi

    echo ""
    echo "✅ Backup restaurado correctamente"
else
    echo "❌ ERROR: Fallo al copiar archivos"
    exit 1
fi
RESTORE_EOF

chmod +x "${BACKUP_ROOT}/${BACKUP_NAME}-restore.sh"
echo "   ✅ restore.sh creado"

# ─── 3. Copiar scripts de instalación (si existen en Config)
echo ""
echo "📋 Verificando scripts de instalación..."

if [ -f "${CONFIG_BACKUP}/sesion-opencode/setup-opencode-completo.sh" ]; then
    cp "${CONFIG_BACKUP}/sesion-opencode/setup-opencode-completo.sh" \
       "${BACKUP_ROOT}/setup-opencode-completo.sh" && \
    echo "   ✅ setup-opencode-completo.sh copiado" || \
    echo "   ⚠️  setup-opencode-completo.sh no encontrado en Config/"
fi

if [ -f "${CONFIG_BACKUP}/sesion-opencode/bootstrap-ocv.sh" ]; then
    cp "${CONFIG_BACKUP}/sesion-opencode/bootstrap-ocv.sh" \
       "${BACKUP_ROOT}/bootstrap-ocv.sh" && \
    echo "   ✅ bootstrap-ocv.sh copiado" || \
    echo "   ⚠️  bootstrap-ocv.sh no encontrado en Config/"
fi

# ─── 4. Generar tarball del backup
echo ""
echo "📦 Creando tarball..."
cd "${BACKUP_ROOT}"
tar -czf "${CONFIG_BACKUP}/${BACKUP_NAME}.tar.gz" .
cd - > /dev/null

BACKUP_SIZE=$(ls -lh "${CONFIG_BACKUP}/${BACKUP_NAME}.tar.gz" | awk '{print $5}')
echo "   ✅ Tarball creado (${BACKUP_SIZE}): ${CONFIG_BACKUP}/${BACKUP_NAME}.tar.gz"

# ─── 5. Limpiar directorio temporal del backup
echo ""
echo "🧹 Limpiando directorio temporal..."
rm -rf "${BACKUP_ROOT}"

echo ""
echo "✅ Backup completado!"
echo ""
echo "Ubicación: ${CONFIG_BACKUP}/${BACKUP_NAME}.tar.gz"
echo "Para restaurar:"
echo "  1. tar -xzf ${CONFIG_BACKUP}/${BACKUP_NAME}.tar.gz -C /tmp/restore-opencode"
echo "  2. bash /tmp/restore-opencode/*-restore.sh"
echo ""
BKUEOF
chmod +x "$DIR_CONFIG/backup-opencode.sh" 2>/dev/null || true
info "backup-opencode.sh creado"

cat > "$DIR_CONFIG/bootstrap-ocv.sh" << 'BOOTEOF'
#!/usr/bin/env bash
# ==============================================================
# Bootstrap script: OpenCode Voice (OCV) - instalación desde limpio
# ==============================================================
# Uso: chmod +x bootstrap-ocv.sh && ./bootstrap-ocv.sh
# ==============================================================
set -euo pipefail

CONFIG_DIR="${HOME}/.config/opencode"
PLUGIN_DIR="${CONFIG_DIR}/opencode-voice-modified"
LOCAL_BIN="${HOME}/.local/bin"
SHARE_DIR="${HOME}/.local/share"
WHISPER_DIR="${SHARE_DIR}/whisper-cpp"

log()  { echo -e "\e[1;32m[INFO]\e[0m $*"; }
warn() { echo -e "\e[1;33m[WARN]\e[0m $*"; }
err()  { echo -e "\e[1;31m[ERR]\e[0m $*" >&2; }

# ---- 1. Dependencias del sistema ----
log "Instalando dependencias del sistema..."
pkexec apt-get update -qq
pkexec apt-get install -y -qq \
  sox \
  pulseaudio-utils \
  pipx \
  nodejs npm 2>/dev/null || {
  warn "Algunos paquetes no están disponibles en los repositorios, se instalarán por otros medios."
  pkexec apt-get install -y -qq sox pulseaudio-utils pipx nodejs npm 2>/dev/null || true
}

mkdir -p "${LOCAL_BIN}"

# whisper-cli desde release oficial (no disponible en apt)
WHISPER_BIN="${SHARE_DIR}/whisper-cpp/bin/whisper-cli"
if [ ! -x "${LOCAL_BIN}/whisper-cli" ]; then
  mkdir -p "${SHARE_DIR}/whisper-cpp/bin"
  # Opción A: compilar con CUDA si hay GPU y nvcc (transcripción rápida)
  if command -v nvcc >/dev/null 2>&1 && command -v cmake >/dev/null 2>&1 && command -v gcc >/dev/null 2>&1; then
    log "Compilando whisper.cpp con CUDA (transcripción por GPU)..."
    WHISPER_TMP="$(mktemp -d)"
    git clone --depth 1 --branch v1.9.1 "https://github.com/ggml-org/whisper.cpp" "${WHISPER_TMP}/whisper-src"
    cmake -B "${WHISPER_TMP}/whisper-src/build" \
      -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release \
      "${WHISPER_TMP}/whisper-src" 2>/dev/null
    cmake --build "${WHISPER_TMP}/whisper-src/build" --config Release -j "$(nproc)" 2>/dev/null || true
    if [ -x "${WHISPER_TMP}/whisper-src/build/bin/whisper-cli" ]; then
      cp "${WHISPER_TMP}/whisper-src/build/bin/whisper-cli" "${WHISPER_BIN}"
      cp "${WHISPER_TMP}"/whisper-src/build/bin/libggml*.so* "${SHARE_DIR}/whisper-cpp/bin/" 2>/dev/null || true
      log "whisper.cpp compilado con CUDA"
    else
      warn "Falló la compilación CUDA, usando versión CPU"
    fi
    rm -rf "${WHISPER_TMP}"
  fi
  # Opción B: descargar binario CPU si no se compiló
  if [ ! -x "${WHISPER_BIN}" ]; then
    log "Descargando whisper.cpp v1.9.1 (CPU)..."
    WHISPER_TMP="$(mktemp -d)"
    curl -sL -o "${WHISPER_TMP}/whisper-bin.tar.gz" \
      "https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.1/whisper-bin-ubuntu-x64.tar.gz"
    tar -xzf "${WHISPER_TMP}/whisper-bin.tar.gz" -C "${WHISPER_TMP}"
    cp "${WHISPER_TMP}"/whisper-bin-ubuntu-x64/whisper-cli "${WHISPER_BIN}"
    cp "${WHISPER_TMP}"/whisper-bin-ubuntu-x64/*.so* "${SHARE_DIR}/whisper-cpp/bin/" 2>/dev/null || true
    rm -rf "${WHISPER_TMP}"
  fi
  cat > "${LOCAL_BIN}/whisper-cli" << 'WHISPEREOF'
#!/bin/bash
exec /home/antonio/.local/share/whisper-cpp/bin/whisper-cli "$@"
WHISPEREOF
  chmod +x "${LOCAL_BIN}/whisper-cli"
fi

# ---- 2. edge-tts vía pipx ----
if ! pipx list 2>/dev/null | grep -q edge-tts; then
  log "Instalando edge-tts vía pipx..."
  pipx install edge-tts
else
  log "edge-tts ya instalado vía pipx"
fi

# ---- 3. Modelos whisper ----
log "Verificando modelos whisper..."
mkdir -p "${WHISPER_DIR}"

download_model() {
  local name="$1"
  local file="$2"
  if [ ! -f "${WHISPER_DIR}/${file}" ]; then
    log "Descargando modelo whisper: ${name}..."
    wget -q --show-progress \
      "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${file}" \
      -O "${WHISPER_DIR}/${file}"
  else
    log "Modelo ${name} ya presente"
  fi
}

download_model "large-v3-turbo-q5_0" "ggml-large-v3-turbo-q5_0.bin"
download_model "small"              "ggml-small.bin"
download_model "base"               "ggml-base.bin"

# ---- 4. Directorio del plugin ----
log "Creando plugin opencode-voice..."
mkdir -p "${PLUGIN_DIR}"

# ---- 5. plugin/package.json (instalación via npm) ----
cat > "${PLUGIN_DIR}/package.json" << 'EOF'
{
  "name": "@renjfk/opencode-voice",
  "version": "0.6.0",
  "description": "Speech-to-text and text-to-speech for OpenCode.",
  "license": "MIT",
  "type": "module",
  "main": "index.js",
  "exports": { ".": { "import": "./index.js" }, "./tui": { "import": "./index.js" } },
  "files": ["index.js", "lib"]
}
EOF

# ---- 6. script speak (edge-tts) ----
log "Instalando script speak..."
cat > "${LOCAL_BIN}/speak" << 'SPEAKEOF'
#!/usr/bin/env python3
import sys, subprocess, tempfile, os, time, re

ANSI_RE = re.compile(r'\x1b\[[0-9;]*[a-zA-Z]|\x1b\][^\x1b]*\x1b\\|\x1b[PX^_]|[^\x1b]*\x1b\\|\x1b][0-9;]*[\x07\x1b]|\x1b[=<>FGH]|\x1b[NOPQ\\]')
BOX_RE = re.compile(r'[\u2500-\u257f\u2500-\u257f\u2580-\u259f\u25a0-\u25ff]')

VOICE = os.environ.get("SPEAK_VOICE", "es-ES-AlvaroNeural")
RATE = os.environ.get("SPEAK_RATE", "+5%")
PITCH = os.environ.get("SPEAK_PITCH", "+0Hz")

def speak(text):
    text = text.strip()
    if not text or len(text) < 3: return
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f: fname = f.name
    try:
        cmd = ["edge-tts", "--voice", VOICE, "--rate", RATE, "--pitch", PITCH, "--text", text, "--write-media", fname]
        subprocess.run(cmd, capture_output=True, timeout=30)
        subprocess.run(["paplay", fname], capture_output=True)
    except Exception: pass
    finally:
        try: os.unlink(fname)
        except OSError: pass

def clean_line(text):
    text = ANSI_RE.sub("", text)
    text = BOX_RE.sub("", text)
    text = ' '.join(text.split())
    return text.strip()

def main():
    buffer = ""
    for line in sys.stdin:
        line = line.rstrip("\n")
        print(line, flush=True)
        clean = clean_line(line)
        if not clean or len(clean) < 4: continue
        if clean.lower() in ('build', 'opencode zen', 'max', 'tab', 'agents', 'ctrl+p', 'commands', 'tip'): continue
        buffer += clean + " "
        if clean.endswith((".", "?", "!", ":", "...")):
            speak(buffer)
            time.sleep(0.2)
            buffer = ""
    if buffer.strip(): speak(buffer)

if __name__ == "__main__": main()
SPEAKEOF
chmod +x "${LOCAL_BIN}/speak"

# ---- 7. tui.json ----
log "Configurando tui.json..."
cat > "${CONFIG_DIR}/tui.json" << 'TUIEOF'
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "session_rename": "f8"
  },
  "plugin": [
    [
      "/home/antonio/.config/opencode/opencode-voice-modified/index.js",
      {
        "endpoint": "http://localhost:4001/v1",
        "model": "models-qwen3.5-9b"
      }
    ]
  ]
}
TUIEOF

# Copiar archivos reales del plugin desde la copia de seguridad si existe
if [ -d "${HOME}/Config/opencode/sesion-opencode/opencode-voice-modified" ]; then
  log "Copiando plugin completo desde la copia de seguridad..."
  cp -r "${HOME}/Config/opencode/sesion-opencode/opencode-voice-modified/." "${PLUGIN_DIR}/"
fi

# ---- 8. npm dependencies del plugin ----
log "Instalando dependencias npm..."
cd "${CONFIG_DIR}"
if [ ! -f package.json ]; then
  cat > package.json << 'PKGEOF'
{
  "dependencies": {
    "@opencode-ai/plugin": "1.18.8"
  }
}
PKGEOF
fi
npm install --no-audit --no-fund 2>/dev/null || npm install

# ---- 9. Verificación final ----
log ""
log "=================================="
log " Instalación completada"
log "=================================="
log ""
log "Archivos instalados:"
ls -la "${PLUGIN_DIR}/"
ls -la "${LOCAL_BIN}/speak"
ls -la "${CONFIG_DIR}/tui.json"
ls -la "${WHISPER_DIR}/"
log ""
log "Para usar OCV:"
log "  1. edge-tts está listo (voz: es-ES-AlvaroNeural)"
log "  2. Modelos whisper: large-v3-turbo-q5_0, small, base"
log "  3. Inicia opencode en el TUI"
log "  4. Usa Ctrl+R para grabar voz, Leader+V para toggle TTS"
log ""
log "Actualizar plugin: npm install @renjfk/opencode-voice@latest en ${PLUGIN_DIR}"
log ""
log "Variables de entorno disponibles:"
log "  SPEAK_VOICE  (voz edge-tts, ej: es-ES-AlvaroNeural)"
log "  SPEAK_RATE   (velocidad, ej: +5%)"
log "  SPEAK_PITCH  (tono, ej: +0Hz)"
BOOTEOF
chmod +x "$DIR_CONFIG/bootstrap-ocv.sh" 2>/dev/null || true
info "bootstrap-ocv.sh creado"

cat > "$DIR_CONFIG/setup-lmstudio-models.sh" << 'LMMODEOF'
#!/usr/bin/env bash
# setup-models.sh — Verifica modelos disponibles en LM Studio
# Uso: bash setup-models.sh
# Los modelos se descargan desde la interfaz gráfica de LM Studio o con:
#   lms get <modelo>
# Ejemplo: lms get qwen/qwen3.5-9b

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }

echo "=============================================="
echo "  Verificación de modelos en LM Studio"
echo "=============================================="
echo ""

LMS_BIN="/home/antonio/.lmstudio/bin/lms"
LMS_PORT=1234

# Verificar que LM Studio responde
if curl -s -o /dev/null -w "" "http://127.0.0.1:${LMS_PORT}/v1/models" 2>/dev/null; then
    info "LM Studio responde en el puerto ${LMS_PORT}"
else
    err "LM Studio no responde en el puerto ${LMS_PORT}."
    info "Asegúrate de que el servidor esté iniciado: lms server start"
    exit 1
fi

# Listar modelos disponibles desde LM Studio
echo ""
echo "Modelos disponibles en LM Studio:"
echo "----------------------------------"
curl -s "http://127.0.0.1:${LMS_PORT}/v1/models" | python3 -c "
import json, sys
data = json.load(sys.stdin)
models = data.get('data', [])
if not models:
    print('  No hay modelos cargados.')
    print('  Descarga uno desde la GUI de LM Studio o con: lms get <modelo>')
else:
    for m in models:
        print(f'  - {m[\"id\"]}')
" 2>/dev/null || warn "No se pudieron listar los modelos"

echo ""
echo "Modelo principal recomendado para OpenCode:"
echo "  qwen/qwen3.5-9b"
echo ""
echo "Para descargar un modelo:"
echo "  1. Abre LM Studio"
echo "  2. Busca el modelo en la pestaña 'Descubrir'"
echo "  3. O desde terminal: lms get <modelo>"
echo ""
echo "Para más información:"
echo "  lms --help"
echo ""
LMMODEOF
chmod +x "$DIR_CONFIG/setup-lmstudio-models.sh" 2>/dev/null || true
info "setup-lmstudio-models.sh creado"

cat > "$DIR_CONFIG/qwen-qwen3.5-9b.json" << 'QWENEOF'
{
  "model": {
    "name": "Qwen/Qwen3.5-9B-Instruct-GGUF (Q6_K)",
    "path": "./Qwen3.5-9B-Q6_K.gguf",
    "quantization": "q6_k",
    "size_gb": "~7.45 GB"
  },
  
  "inference": {
    "num_threads": 24,
    "gpu_layers": "all",
    "cpu_offload_layers": 0,
    "max_context_size": 81920,
    "flash_attn": true,
    "batch_size_mb_prefill": 90,
    "batch_size_mb_decode": 128,
    "gpu_memory_utilization": 0.85
  },
  
  "generation": {
    "temperature_default": 0.7,
    "top_p": 0.95,
    "top_k": 40,
    "min_p": 0.0,
    "repeat_penalty": 1.2,
    "frequency_penalty": 0.0,
    "presence_penalty": 0.0,
    "max_tokens_to_sample": 4096
  },
  
  "optimization": {
    "use_rocm_fallback": false,
    "use_flash_attention_v2": true,
    "flash_infer_batch_size": 32,
    "quantization_error_tolerance": 0.01
  },
  
  "rag": {
    "enabled": false,
    "max_documents_per_query": 10,
    "retrieve_from_vector_store": false,
    "top_k_results": 10
  }
}
QWENEOF
chmod +x "$DIR_CONFIG/qwen-qwen3.5-9b.json" 2>/dev/null || true
info "qwen-qwen3.5-9b.json creado"

cat > "$DIR_CONFIG/hardware-info.md" << 'HWINFOEOF'
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
HWINFOEOF
chmod +x "$DIR_CONFIG/hardware-info.md" 2>/dev/null || true
info "hardware-info.md creado"

cat > "$DIR_CONFIG/README-hardware.md" << 'READMEHWEOF'
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
READMEHWEOF
chmod +x "$DIR_CONFIG/README-hardware.md" 2>/dev/null || true
info "README-hardware.md creado"

# PASO 15: Dependencias npm
# ═══════════════════════════════════════════════════════════
echo "--- 15/19: Dependencias npm ---"
cd "$DIR_CONFIG"
if [ ! -f package.json ]; then
    cat > package.json << 'PKGEOF'
{
  "dependencies": {
    "@ai-sdk/openai": "^4.0.11",
    "@ai-sdk/openai-compatible": "^3.0.7",
    "@opencode-ai/plugin": "1.17.13",
    "@renjfk/opencode-voice": "^0.6.0"
  }
}
PKGEOF
fi
npm install --no-audit --no-fund 2>/dev/null || npm install
info "Dependencias npm instaladas"

# ═══════════════════════════════════════════════════════════
# PASO 15b: Plugin de voz opencode-voice-modified
# ═══════════════════════════════════════════════════════════
echo "--- 15b/19: Plugin de voz ---"
PLUGIN_DIR="$DIR_CONFIG/opencode-voice-modified"
if [ ! -d "$PLUGIN_DIR" ] || [ ! -f "$PLUGIN_DIR/index.js" ]; then
    mkdir -p "$PLUGIN_DIR/lib"
    # package.json del plugin
    cat > "$PLUGIN_DIR/package.json" << 'PLUGPKG'
{
  "name": "@renjfk/opencode-voice",
  "version": "0.6.0",
  "description": "Speech-to-text and text-to-speech for OpenCode.",
  "license": "MIT",
  "type": "module",
  "main": "index.js",
  "exports": {
    ".": { "import": "./index.js" },
    "./tui": { "import": "./index.js" }
  },
  "files": ["index.js", "lib"]
}
PLUGPKG
    # Intentar copiar desde npm si está instalado
    if [ -f "node_modules/@renjfk/opencode-voice/index.js" ]; then
        cp node_modules/@renjfk/opencode-voice/index.js "$PLUGIN_DIR/index.js"
        cp node_modules/@renjfk/opencode-voice/lib/*.js "$PLUGIN_DIR/lib/" 2>/dev/null || true
        info "Plugin copiado desde node_modules"
    else
        # Crear index.js mínimo como placeholder
        cat > "$PLUGIN_DIR/index.js" << 'PLUGINJS'
// opencode-voice: Speech-to-text and text-to-speech for OpenCode.
//
// STT: Record voice via sox, transcribe with whisper-cpp, normalize with
//      an OpenAI-compatible LLM, append to the TUI prompt.
//
// TTS: Auto-speak assistant responses (or read on demand) via Piper,
//      with LLM normalization for natural speech.
//
// Prerequisites:
//   STT: brew install whisper-cpp sox
//   TTS: Piper binary on PATH, voice models at ~/.local/share/piper-voices/
//
// Configuration via tui.json plugin options:
//   ["opencode-voice", { "endpoint": "...", "model": "...", "apiKeyEnv": "..." }]
//
// Runtime state (model, mic, voice, tts mode) persisted via api.kv.
//
// Commands:
//   /stt-record (ctrl+r)  - start/stop recording + transcribe
//   /stt-submit (leader+r)- stop recording + transcribe + submit
//   /stt-stop             - cancel recording
//   /stt-model            - select whisper model
//   /stt-mic              - select microphone
//   /tts-speak (leader+s)- read last response aloud
//   /tts-mode (leader+v) - toggle auto TTS on/off
//   /tts-stop (escape)   - stop playback
//   /tts-voice           - select TTS voice

import fs from "node:fs";
import os from "node:os";
import { registerSTT } from "./lib/stt.js";
import { registerTTS } from "./lib/tts.js";
import { createClient } from "./lib/llm-client.js";
import { createLogger } from "./lib/logger.js";

function loadPromptFile(filePath, logger, name) {
  if (!filePath) return null;
  const resolved = filePath.replace(/^~(?=\/|$)/, os.homedir());
  try {
    const prompt = fs.readFileSync(resolved, "utf-8").trim() || null;
    logger?.log(
      "plugin",
      prompt ? `Loaded ${name} prompt: ${resolved}` : `Ignored empty ${name} prompt: ${resolved}`,
      "debug",
    );
    return prompt;
  } catch (err) {
    logger?.log("Plugin", `Failed to load ${name} prompt ${resolved}: ${err.message}`, "warn");
    return null;
  }
}

export default {
  id: "opencode-voice",
  tui: async (api, options) => {
    const { kv } = api;
    const logger = createLogger(api.client);
    logger.log("plugin", "Initializing", "debug");
    const { complete } = createClient(options, logger);

    const prompts = {
      stt: loadPromptFile(options?.sttPrompt, logger, "STT"),
      ttsAuto: loadPromptFile(options?.ttsAutoPrompt, logger, "TTS auto"),
      ttsManual: loadPromptFile(options?.ttsManualPrompt, logger, "TTS manual"),
    };

    const sttCommands = registerSTT(api, kv, complete, prompts, options, logger);
    const ttsCommands = registerTTS(api, kv, logger);

    api.command.register(() => [...sttCommands, ...ttsCommands]);
  },
};
PLUGINJS
        # Crear stt.js mínimo
        cat > "$PLUGIN_DIR/lib/stt.js" << 'STTJS'
// Speech-to-text: sox recording, whisper-cpp or API transcription, LLM normalization.

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { spawn, execSync } from "node:child_process";
import { getActiveSessionTitle } from "./session.js";

let sttApiEndpoint = null;
let sttApiModel = null;
let sttApiKeyEnv = null;

const WAV_FILE = "/tmp/opencode-stt.wav";

const MODELS_DIRS = [
  path.join(os.homedir(), ".local", "share", "whisper-cpp"),
  "/opt/homebrew/share/whisper-cpp/models",
  "/usr/local/share/whisper-cpp/models",
];

const MODELS = {
  "large-v3-turbo-q5_0": {
    label: "Large v3 Turbo Q5 (recommended)",
    file: "ggml-large-v3-turbo-q5_0.bin",
  },
  "large-v3-turbo-q8_0": { label: "Large v3 Turbo Q8", file: "ggml-large-v3-turbo-q8_0.bin" },
  "large-v3-turbo": { label: "Large v3 Turbo (full)", file: "ggml-large-v3-turbo.bin" },
  "small.en": { label: "Small English", file: "ggml-small.en.bin" },
  small: { label: "Small Multilingual", file: "ggml-small.bin" },
  "base.en": { label: "Base English", file: "ggml-base.en.bin" },
  base: { label: "Base Multilingual", file: "ggml-base.bin" },
  "tiny.en": { label: "Tiny English (fastest)", file: "ggml-tiny.en.bin" },
  tiny: { label: "Tiny Multilingual (fastest)", file: "ggml-tiny.bin" },
};
const DEFAULT_MODEL = "large-v3-turbo-q5_0";

export function isOpenRouterEndpoint(endpoint) {
  return /(^https?:\/\/)?([^/]+\.)?openrouter\.ai(\/|$)/i.test(endpoint || "");
}

function buildMultipartTranscriptionRequest(model, audioBuffer, apiKey) {
  const blob = new Blob([audioBuffer], { type: "audio/wav" });
  const form = new FormData();
  form.append("file", blob, "audio.wav");
  form.append("model", model);
  form.append("response_format", "json");

  const headers = {};
  if (apiKey) headers["Authorization"] = "Bearer " + apiKey;

  return {
    headers,
    body: form,
  };
}

export function buildOpenRouterTranscriptionRequest(model, audioBuffer, apiKey) {
  const headers = { "Content-Type": "application/json" };
  if (apiKey) headers["Authorization"] = "Bearer " + apiKey;

  const payload = {
    model,
    input_audio: {
      data: audioBuffer.toString("base64"),
      format: "wav",
    },
  };

  return {
    headers,
    body: JSON.stringify(payload),
  };
}

function getModelsDir() {
  for (const dir of MODELS_DIRS) {
    if (fs.existsSync(dir)) return dir;
  }
  return MODELS_DIRS[0];
}

function listInputDevices() {
  try {
    const json = execSync("system_profiler SPAudioDataType -json 2>/dev/null", {
      encoding: "utf-8",
      timeout: 5000,
    });
    const data = JSON.parse(json);
    return (data.SPAudioDataType?.[0]?._items || [])
      .filter((d) => d.coreaudio_input_source != null)
      .map((d) => d.coreaudio_device_name || d._name);
  } catch {
    return [];
  }
}

// ---- Recording state and control ----

let soxProc = null;
let soxStderr = "";
let recording = false;
let processing = false;

function forceKillSox(logger) {
  if (soxProc) {
    try {
      process.kill(soxProc.pid, "SIGKILL");
      logger?.log("STT", `Killed sox pid=${soxProc.pid}`, "debug");
    } catch {}
    soxProc = null;
  }
  try {
    execSync("pkill -9 -f 'sox.*opencode-stt'", { stdio: "ignore" });
  } catch {}
}

function startRecording(kv, toast, logger) {
  if (soxProc) {
    logger?.log("STT", "Start recording skipped: sox already running", "debug");
    return;
  }

  forceKillSox(logger);
  try {
    fs.unlinkSync(WAV_FILE);
  } catch {}

  soxStderr = "";
  const mic = kv.get("stt.mic", "") || null;
  const isLinux = process.platform === "linux";
  const inputArgs = mic
    ? ["-t", isLinux ? "pulseaudio" : "coreaudio", mic]
    : ["-d"];
  logger?.log("STT", `Starting recording mic=${mic || "system default"}`, "debug");

  try {
    fs.unlinkSync(WAV_FILE);
    logger?.log("STT", "Deleted old WAV file", "debug");
  } catch (e) {
    logger?.log("STT", `Could not delete old WAV: ${e.message}`, "warn");
  }

  soxProc = spawn(
    "sox",
    [...inputArgs, "-r", "16000", "-c", "1", "-b", "16", WAV_FILE],
    {
      stdio: ["ignore", "ignore", "pipe"],
      detached: false,
    },
  );

  soxProc.stderr.on("data", (chunk) => {
    soxStderr += chunk.toString();
  });

  soxProc.on("error", (err) => {
    soxProc = null;
    logger?.log("STT", `Recording failed: ${err.message}`, "error");
    if (recording) {
      recording = false;
      toast(`Recording failed: ${err.message}`, "error");
    }
  });

  soxProc.on("exit", (code) => {
    soxProc = null;
    logger?.log(
      "STT",
      `sox exited code=${code} stderr=${soxStderr.trim()}`,
      code === 0 || code === null ? "debug" : "warn",
    );
    if (recording && code !== 0 && code !== null && !processing) {
      recording = false;
      const errLine = soxStderr.trim().split("\n").pop();
      toast(`Recording error: ${errLine || `sox exited (code=${code})`}`, "error");
    }
  });

  recording = true;
}

function stopRecording(logger) {
  logger?.log("STT", "Stopping recording", "debug");
  if (soxProc) soxProc.kill("SIGINT");
}

async function waitForSoxExit(logger, timeoutMs = 5000) {
  const start = Date.now();
  while (soxProc && Date.now() - start < timeoutMs) {
    await new Promise((r) => setTimeout(r, 100));
  }
  if (soxProc) {
    logger?.log("STT", "sox did not stop before timeout", "warn");
    forceKillSox(logger);
  }
}

function getModelName(kv) {
  const model = kv.get("stt.model", DEFAULT_MODEL);
  return MODELS[model] ? model : DEFAULT_MODEL;
}

function getModelPath(kv) {
  return path.join(getModelsDir(), MODELS[getModelName(kv)].file);
}

function checkAudioSilence(wavPath) {
  try {
    const buf = fs.readFileSync(wavPath);
    const headerSize = 44;
    const samples = new Int16Array(buf.buffer, headerSize);
    let sumSq = 0;
    for (let i = 0; i < samples.length; i++) sumSq += samples[i] * samples[i];
    const rms = Math.sqrt(sumSq / samples.length);
    return rms < 10;
  } catch {
    return true;
  }
}

function transcribe(kv, logger) {
  const mp = getModelPath(kv);
  logger?.log("STT", `Local transcription requested model=${mp}`, "debug");
  if (!fs.existsSync(mp)) {
    logger?.log("STT", `Whisper model missing: ${mp}`, "error");
    return Promise.resolve({
      error: `Model not found: ${getModelName(kv)}. Download from huggingface.co/ggerganov/whisper.cpp`,
    });
  }
  if (!fs.existsSync(WAV_FILE)) {
    logger?.log("STT", `Recording file missing: ${WAV_FILE}`, "error");
    return Promise.resolve({ error: "No recording file - sox may have failed to capture audio" });
  }
  if (fs.statSync(WAV_FILE).size <= 44) {
    logger?.log("STT", `Recording file empty: ${WAV_FILE}`, "warn");
    return Promise.resolve({ error: "Recording is empty - no audio captured" });
  }

  return new Promise((resolve) => {
    let stdout = "";
    let stderr = "";
    const proc = spawn("whisper-cli", ["-m", mp, "-f", WAV_FILE, "-np", "-nt", "-l", "es"], {
      stdio: ["ignore", "pipe", "pipe"],
    });
    logger?.log("STT", `Started whisper-cli pid=${proc.pid}`, "debug");

    proc.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    proc.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    const timer = setTimeout(() => {
      proc.kill("SIGKILL");
      logger?.log("STT", "whisper-cli timed out after 60s", "error");
      resolve({ error: "Transcription timed out (60s)" });
    }, 60000);

    proc.on("error", (err) => {
      clearTimeout(timer);
      logger?.log("STT", `whisper-cli error: ${err.message}`, "error");
      resolve({ error: `Transcription failed: ${err.message}` });
    });

    proc.on("exit", (code) => {
      clearTimeout(timer);
      if (code !== 0) {
        logger?.log("STT", `whisper-cli exited code=${code} stderr=${stderr.trim()}`, "error");
        resolve({ error: stderr.trim().split("\n").pop() || `whisper-cli exited (code=${code})` });
        return;
      }
      logger?.log("STT", `Local transcription succeeded stdoutChars=${stdout.length}`, "debug");
      resolve({
        text: stdout
          .replace(/\[.*?\]/g, "")
          .replace(/\(.*?\)/g, "")
          .replace(/\s+/g, " ")
          .trim(),
      });
    });
  });
}

const STT_SYSTEM_PROMPT = `Eres un normalizador de voz a texto para una CLI de asistente de programación.

El usuario habla en ESPAÑOL. Limpia la transcripción en bruto de whisper y devuélvela SIEMPRE en español (a menos que el usuario dicte código o términos técnicos en inglés, que se mantienen tal cual). Reglas:
- Corrige puntuación, mayúsculas y gramática en español
- Elimina muletillas (eh, um, esto, o sea, bueno, etc.)
- Mantén exactos los términos técnicos, nombres de archivo y referencias de código
- Si el usuario está dictando código, formatéalo de forma apropiada
- Usa el contexto de la sesión para resolver referencias ambiguas (p. ej. "esa función", "el archivo", "eso")
- Devuelve SOLO el texto limpio, nada más
- No añadas comentarios ni explicaciones
- Mantén la intención y el significado del usuario intactos

CORRECCIONES CRÍTICAS DEL DOMINIO - Corrige errores de homófonos típicos del reconocimiento de voz en contextos de ingeniería de software (en español):
- "logs" y "log" son términos técnicos en inglés: se mantienen si se refieren a registros del sistema
- "docker", "JSON", "React", "TypeScript", "Git", "async", "sync", "cache", "node", "append", "string", "boolean", "wrap" son términos técnicos: mantenlos en inglés aunque suenen como palabras en español
- "a ver" -> "haber" según contexto
- "haya" / "alla" / "halla" -> según contexto gramatical
- "echo" -> mantener si es el comando de shell
- "por que" / "porqué" / "por qué" -> según contexto

Apóyate mucho en el contexto para corregir palabras que suenan parecidas a terminología de programación.`;

async function normalizeTranscription(complete, rawText, sessionTitle, systemPrompt, logger) {
  const contextLine = sessionTitle ? ` The user is currently working on: "${sessionTitle}"` : "";
  const system = `${systemPrompt}${contextLine}`;

  logger?.log("STT", `Normalizing transcription chars=${rawText.length}`, "debug");
  const result = await complete({
    system,
    prompt: `Clean up this speech-to-text transcription:\n\n${rawText}`,
  });
  return result;
}

async function getApiModels(logger) {
  if (!sttApiEndpoint) return [];
  try {
    const url = sttApiEndpoint.endsWith("/")
      ? `${sttApiEndpoint}models`
      : `${sttApiEndpoint}/models`;
    const headers = {};
    if (sttApiKeyEnv && process.env[sttApiKeyEnv]) {
      headers["Authorization"] = "Bearer " + process.env[sttApiKeyEnv];
    }
    const resp = await fetch(url, { headers, signal: AbortSignal.timeout(5000) });
    logger?.log("STT", `Fetched STT API models status=${resp.status}`, resp.ok ? "debug" : "warn");
    if (!resp.ok) return [];
    const data = await resp.json();
    return (data.data || [])
      .filter((m) => m.id && /whisper/i.test(m.id))
      .map((m) => ({ value: m.id, label: m.id }));
  } catch (err) {
    logger?.log("STT", `Failed to fetch STT API models: ${err.message}`, "error");
    return [];
  }
}

async function transcribeApi(kv, logger) {
  if (!sttApiEndpoint || !sttApiModel) {
    logger?.log("STT", "STT API transcription skipped: API not configured", "warn");
    return { error: "STT API not configured" };
  }
  const model = kv.get("stt.api.model") || sttApiModel;
  logger?.log("STT", `STT API transcription requested model=${model}`, "debug");

  if (!fs.existsSync(WAV_FILE)) {
    logger?.log("STT", `Recording file missing: ${WAV_FILE}`, "error");
    return { error: "No recording file - sox may have failed to capture audio" };
  }
  if (fs.statSync(WAV_FILE).size <= 44) {
    logger?.log("STT", `Recording file empty: ${WAV_FILE}`, "warn");
    return { error: "Recording is empty - no audio captured" };
  }

  try {
    const audioBuffer = await fs.promises.readFile(WAV_FILE);
    const apiKey = sttApiKeyEnv ? process.env[sttApiKeyEnv] : null;
    const useOpenRouterFormat = isOpenRouterEndpoint(sttApiEndpoint);

    const url = sttApiEndpoint.endsWith("/")
      ? `${sttApiEndpoint}audio/transcriptions`
      : `${sttApiEndpoint}/audio/transcriptions`;

    const request = useOpenRouterFormat
      ? buildOpenRouterTranscriptionRequest(model, audioBuffer, apiKey)
      : buildMultipartTranscriptionRequest(model, audioBuffer, apiKey);

    const resp = await fetch(url, {
      method: "POST",
      headers: request.headers,
      body: request.body,
      signal: AbortSignal.timeout(60000),
    });
    logger?.log("STT", `STT API response status=${resp.status}`, resp.ok ? "debug" : "error");

    if (!resp.ok) {
      const responseBody = await resp.text();
      let msg = `STT API error ${resp.status}`;
      try {
        const err = JSON.parse(responseBody);
        msg = err?.error?.message || msg;
      } catch {}
      return { error: msg };
    }

    let data;
    try {
      data = await resp.json();
    } catch (err) {
      logger?.log("STT", `STT API returned invalid JSON: ${err.message}`, "error");
      return { error: `STT API returned invalid JSON: ${err.message}` };
    }
    logger?.log("STT", `STT API transcription succeeded chars=${data.text?.length || 0}`, "debug");
    return { text: data.text?.trim() || "" };
  } catch (err) {
    logger?.log("STT", `STT API request failed: ${err.message}`, "error");
    if (err.name === "TimeoutError" || err.name === "AbortError") {
      return { error: "STT API request timed out (60s)" };
    }
    return { error: `STT API request failed: ${err.message}` };
  }
}

async function appendTranscription(client, text, submit, api) {
  if (submit && text) {
    try {
      await client.tui.appendPrompt({ text });
      await new Promise(r => setTimeout(r, 50));
      await client.tui.submitPrompt();
    } catch (err) {
      api?.ui?.toast?.({ message: `Error: ${err.message}`, variant: "error", duration: 5000 });
    }
  }
}
async function doTranscribePipeline(
  kv,
  complete,
  client,
  toast,
  systemPrompt,
  submit = false,
  logger,
  api,
) {
  processing = true;
  try {
    logger?.log("STT", `Pipeline started submit=${submit}`, "debug");
    stopRecording(logger);
    await waitForSoxExit(logger);

    if (!fs.existsSync(WAV_FILE) || fs.statSync(WAV_FILE).size <= 44) {
      logger?.log("STT", "No valid WAV file after recording", "error");
      toast("No audio captured — ¿micrófono conectado?", "warning");
      return;
    }

    const isSilent = checkAudioSilence(WAV_FILE);
    if (isSilent) {
      logger?.log("STT", "Recording is silent, skipping", "warn");
      toast("No se detectó voz — ¿micrófono silenciado?", "warning");
      return;
    }

    toast("Transcribing...");
    const result = await transcribe(kv, logger);

    if (result.error) {
      logger?.log("STT", `Transcription failed: ${result.error}`, "error");
      toast(result.error, "error");
      return;
    }
    if (!result.text) {
      logger?.log("STT", "Transcription produced no text", "warn");
      toast("No speech detected", "warning");
      return;
    }

    await appendTranscription(client, result.text, submit, api);
    logger?.log("STT", `Pipeline completed chars=${result.text.length}`, "debug");
    toast(submit ? "Transcription submitted" : "Transcription added to prompt", "success");
  } catch (err) {
    logger?.log("STT", `Pipeline error: ${err.message}`, "error");
    toast(`STT error: ${err.message}`, "error");
  } finally {
    processing = false;
    recording = false;
  }
}

// ---- Public API for TUI plugin ----

export function registerSTT(api, kv, complete, prompts, opts, logger) {
  const client = api.client;
  const systemPrompt = prompts?.stt || STT_SYSTEM_PROMPT;
  function toast(message, variant = "info") {
    api.ui.toast({ message, variant, duration: 3000 });
  }

  if (opts?.sttEndpoint) {
    sttApiEndpoint = opts.sttEndpoint;
    sttApiModel = opts.sttModel || "whisper-large-v3-turbo";
    sttApiKeyEnv = opts.sttApiKeyEnv || null;
    logger?.log(
      "STT",
      `Configured STT API endpoint=${sttApiEndpoint} model=${sttApiModel}`,
      "debug",
    );
  }

  return [
    {
      title: sttApiEndpoint ? "STT: record/transcribe (API)" : "STT: record/transcribe",
      value: "stt.record",
      description: sttApiEndpoint
        ? "Toggle recording; press again to stop and transcribe via API"
        : "Toggle recording; press again to stop and transcribe",
      keybind: "ctrl+r",
      slash: { name: "stt-record" },
      onSelect() {
        if (processing) {
          return;
        }
        if (recording) {
          toast("Stopping, transcribing...");
          doTranscribePipeline(kv, complete, client, toast, systemPrompt, true, logger, api);
        } else {
          startRecording(kv, toast, logger);
          if (recording) toast("Recording... press again to transcribe");
        }
      },
    },
    {
      title: sttApiEndpoint ? "STT: submit recording (API)" : "STT: submit recording",
      value: "stt.submit",
      description: sttApiEndpoint
        ? "Stop recording, transcribe via API, and submit prompt"
        : "Stop recording, transcribe, and submit prompt",
      keybind: "<leader>r",
      slash: { name: "stt-submit" },
      onSelect() {
        if (processing) {
          toast("STT busy, please wait...");
          return;
        }
        if (!recording) {
          toast("No recording in progress", "warning");
          return;
        }
        toast("Stopping, transcribing...");
        doTranscribePipeline(kv, complete, client, toast, systemPrompt, true, logger, api);
      },
    },
    {
      title: "STT: cancel recording",
      value: "stt.stop",
      description: "Cancel current recording",
      slash: { name: "stt-stop" },
      onSelect() {
        if (recording) {
          recording = false;
          forceKillSox(logger);
          logger?.log("STT", "Recording cancelled", "debug");
          toast("Recording cancelled");
        }
      },
    },
    {
      title: sttApiEndpoint ? "STT: select model (API)" : "STT: select model",
      value: "stt.model",
      description: sttApiEndpoint ? "Choose whisper model via API" : "Choose whisper model",
      slash: { name: "stt-model" },
      async onSelect() {
        if (sttApiEndpoint) {
          const current = kv.get("stt.api.model") || sttApiModel;
          const apiModels = await getApiModels(logger);
          const options = apiModels.length > 0 ? apiModels : [{ value: current, label: current }];
          api.ui.dialog.replace(() =>
            api.ui.DialogSelect({
              title: "Select whisper model (API)",
              current,
              options: options.map((m) => ({
                title: m.label,
                value: m.value,
                onSelect() {
                  kv.set("stt.api.model", m.value);
                  toast(`Whisper API model: ${m.label}`);
                  api.ui.dialog.clear();
                },
              })),
            }),
          );
        } else {
          const current = getModelName(kv);
          api.ui.dialog.replace(() =>
            api.ui.DialogSelect({
              title: "Select whisper model",
              current,
              options: Object.entries(MODELS).map(([key, v]) => ({
                title: v.label,
                value: key,
                onSelect() {
                  kv.set("stt.model", key);
                  toast(`Whisper model: ${v.label}`);
                  api.ui.dialog.clear();
                },
              })),
            }),
          );
        }
      },
    },
    {
      title: "STT: select microphone",
      value: "stt.mic",
      description: "Choose audio input device",
      slash: { name: "stt-mic" },
      onSelect() {
        const current = kv.get("stt.mic", "");
        const devices = listInputDevices();
        if (devices.length === 0) {
          toast("No input devices found");
          return;
        }
        api.ui.dialog.replace(() =>
          api.ui.DialogSelect({
            title: "Select microphone",
            current,
            options: [
              {
                title: "System default",
                value: "",
                onSelect() {
                  kv.set("stt.mic", "");
                  toast("Mic: system default");
                  api.ui.dialog.clear();
                },
              },
              ...devices.map((name) => ({
                title: name,
                value: name,
                onSelect() {
                  kv.set("stt.mic", name);
                  toast(`Mic: ${name}`);
                  api.ui.dialog.clear();
                },
              })),
            ],
          }),
        );
      },
    },
  ];
}
STTJS
        # Crear tts.js mínimo
        cat > "$PLUGIN_DIR/lib/tts.js" << 'TTSJS'
// Text-to-speech: edge-tts playback via speak script.

import fs from "node:fs";
import { spawn } from "node:child_process";
import { getSessionTitle } from "./session.js";

// ---- Streaming text cache ----
// Captures text parts during streaming to avoid API calls on idle.

const streamingTexts = new Map();

function resetStreamingCache() {
  streamingTexts.clear();
}

// ---- Session helpers ----

async function getTurnAssistantText(client, api) {
  const route = api.route.current;
  if (route.name !== "session") return null;

  const sessionID = route.params.sessionID;
  const stateMessages = api.state.session.messages(sessionID);
  if (!stateMessages || stateMessages.length === 0) return null;

  const assistantIDs = [];
  for (let i = stateMessages.length - 1; i >= 0; i--) {
    if (stateMessages[i].role === "user") break;
    if (stateMessages[i].role === "assistant") {
      assistantIDs.unshift(stateMessages[i].id);
    }
  }
  if (assistantIDs.length === 0) return null;

  // Fast path: use cached streaming text (no API call)
  const allText = [];
  for (const msgID of assistantIDs) {
    const cached = streamingTexts.get(msgID);
    if (cached && cached.trim()) {
      allText.push(cached.trim());
    }
  }
  if (allText.length > 0) {
    return {
      lastMessageID: assistantIDs[assistantIDs.length - 1],
      text: allText.join("\n\n"),
    };
  }

  // Fallback: fetch full message via API (only if cache was missed)
  for (const msgID of assistantIDs) {
    try {
      const fullMsg = await client.session
        .message({ sessionID, messageID: msgID }, { throwOnError: true })
        .then((r) => r.data);

      const textParts = (fullMsg?.parts || []).filter((p) => p.type === "text");
      const text = textParts
        .map((p) => p.text || "")
        .join("\n\n")
        .trim();
      if (text) allText.push(text);
    } catch {
      // Skip messages that fail to fetch
    }
  }

  if (allText.length === 0) return null;

  return {
    lastMessageID: assistantIDs[assistantIDs.length - 1],
    text: allText.join("\n\n"),
  };
}

// ---- Public API for TUI plugin ----

export function registerTTS(api, kv, logger) {
  const client = api.client;

  function toast(message, variant = "info") {
    api.ui.toast({ message, variant, duration: 3000 });
  }

  // ---- Audio pipeline (edge-tts via speak script) ----

  let speakProc = null;

  function killProcs() {
    if (speakProc) {
      try {
        speakProc.kill("SIGTERM");
      } catch {}
      speakProc = null;
    }
  }

  function cleanLine(line) {
    return line
      .replace(/```[\s\S]*?```/g, 'código')
      .replace(/`([^`]+)`/g, '$1')
      .replace(/\*\*(.*?)\*\*/g, '$1')
      .replace(/__(.*?)__/g, '$1')
      .replace(/\*(.*?)\*/g, '$1')
      .replace(/_(.*?)_/g, '$1')
      .replace(/~~(.*?)~~/g, '$1')
      .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
      .replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1')
      .replace(/^#{1,6}\s+/gm, '')
      .replace(/^>\s+/gm, '')
      .replace(/^---+\s*$/gm, '')
      .replace(/^[\s]*[-*+]\s+/gm, '')
      .replace(/^[\s]*\d+\.\s+/gm, '')
      .replace(/\s+/g, ' ')
      .replace(/\.([a-zA-Z])/g, ' punto $1')
      .replace(/\s+/g, ' ')
      .replace(/[*_`~]/g, '')
      .trim();
  }

  function cleanTableRow(line) {
    // Limpiar una fila de tabla: quitar pipes exteriores y reemplazar pipes internos
    let cleaned = line.replace(/^\s*\|\s*/, '').replace(/\s*\|\s*$/, '');
    cleaned = cleaned.replace(/\s*\|\s*/g, ': ');
    return cleanLine(cleaned);
  }

  function cleanMarkdown(text) {
    return text
      .split(/\n\n+/)
      .flatMap(p => {
        const rawLines = p.split('\n').filter(l => l.trim().length > 0);
        const isList = rawLines.some(l => /^\s*[-*+]\s/.test(l) || /^\s*\d+\.\s/.test(l));
        const isTable = rawLines.some(l => /^\s*\|/.test(l));

        if (isList) {
          return rawLines
            .map(l => cleanLine(l))
            .filter(l => l.length >= 4);
        } else if (isTable) {
          // Tabla: cada fila se locuta por separado, saltar fila separadora
          return rawLines
            .filter(l => !/^\s*\|?[\s:-]+\|[\s:-]+\|?\s*$/.test(l))
            .map(l => cleanTableRow(l))
            .filter(l => l.length >= 4);
        } else {
          const cleaned = cleanLine(p);
          return cleaned.length >= 4 ? [cleaned] : [];
        }
      })
      .join('\n');
  }

  function speak(text) {
    if (!text) return Promise.resolve();
    const cleaned = cleanMarkdown(text);
    if (!cleaned) return Promise.resolve();

    killProcs();

    const speakScript = "/home/antonio/.local/bin/speak";
    if (!fs.existsSync(speakScript)) {
      logger?.log?.("TTS", `speak script not found: ${speakScript}`, "warn");
      toast(`speak script not found`, "warning");
      return Promise.resolve();
    }

    logger?.log?.("TTS", `Speak requested chars=${cleaned.length}`, "debug");

    return new Promise((resolve) => {
      const proc = spawn(speakScript, [], { stdio: ["pipe", "ignore", "ignore"] });
      speakProc = proc;

      proc.on("close", () => {
        // Solo borrar speakProc si sigue apuntando a este proceso
        // (no al siguiente que ya haya empezado)
        if (speakProc === proc) {
          speakProc = null;
        }
        resolve();
      });

      proc.on("error", (err) => {
        logger?.log?.("TTS", `speak error: ${err.message}`, "error");
        if (speakProc === proc) {
          speakProc = null;
        }
        resolve();
      });

      if (proc?.stdin && !proc.stdin.destroyed) {
        // Enviar todos los parrafos separados por saltos de linea
        // El script speak lee linea por linea y locuta cada parrafo
        // con una pausa natural entre ellos
        proc.stdin.write(cleaned);
        proc.stdin.end();
      }
    });
  }

  // ---- Session-prefixed announcements ----

  async function speakWithSessionPrefix(sessionID, message, suffix) {
    const sessionTitle = await getSessionTitle(client, sessionID);
    const parts = [];
    if (sessionTitle) parts.push(`Session: ${sessionTitle}.`);
    parts.push(message);
    if (suffix) parts.push(suffix);
    await speak(parts.join(" "));
  }

  function stopSpeech() {
    const wasPlaying = speakProc !== null;
    killProcs();
    return wasPlaying;
  }

  // ---- Streaming text cache ----
  // Captures text parts during streaming to avoid API calls on idle.

  api.event.on("message.part.updated", (event) => {
    const part = event.properties?.part;
    if (part?.type === "text") {
      const msgID = part.messageID;
      const prev = streamingTexts.get(msgID) || "";
      const delta = event.properties?.delta;
      const newText = delta ? prev + delta : part.text;
      streamingTexts.set(msgID, newText);
    }
  });

  // ---- Auto mode ----

  let lastSpokenMessageID = null;
  let wasBusy = false;

  api.event.on("session.status", (event) => {
    if (event.properties?.status?.type === "busy") {
      resetStreamingCache();
      wasBusy = true;
    }
  });

  api.event.on("session.idle", async (event) => {
    if (kv.get("tts.mode", "on") !== "on") return;
    if (!wasBusy) return;
    wasBusy = false;

    // Use cached streaming text (fast, no API call)
    const result = await getTurnAssistantText(client, api);
    if (!result || !result.text) return;

    if (result.lastMessageID === lastSpokenMessageID) return;
    lastSpokenMessageID = result.lastMessageID;

    await speak(result.text);
  });

  api.event.on("permission.asked", async (event) => {
    if (kv.get("tts.mode", "on") !== "on") return;
    await speakWithSessionPrefix(
      event.properties?.sessionID,
      "Permission requested. Please check your screen.",
    );
  });

  api.event.on("question.asked", async (event) => {
    if (kv.get("tts.mode", "on") !== "on") return;
    await speakWithSessionPrefix(
      event.properties?.sessionID,
      "A question needs your answer. Please check your screen.",
    );
  });

  // ---- Manual mode ----

  async function speakLastResponse() {
    const result = await getTurnAssistantText(client, api);
    if (!result || !result.text) {
      toast("No assistant response to speak", "warning");
      return;
    }

    toast("Speaking last response");
    await speak(result.text);
  }

  // ---- Commands ----

  return [
    {
      title: "TTS: speak last response",
      value: "tts.speak-last",
      description: "Read the last assistant response aloud (detailed)",
      keybind: "<leader>s",
      slash: { name: "tts-speak" },
      onSelect() {
        speakLastResponse();
      },
    },
    {
      title: "TTS: toggle",
      value: "tts.mode",
      description: "Toggle auto text-to-speech on/off",
      keybind: "<leader>v",
      slash: { name: "tts-mode" },
      onSelect() {
        const current = kv.get("tts.mode", "on");
        const next = current === "on" ? "off" : "on";
        kv.set("tts.mode", next);
        if (next === "off") stopSpeech();
        toast(next === "on" ? "TTS on (edge-tts)" : "TTS off");
      },
    },
    {
      title: "TTS: stop playback",
      value: "tts.stop",
      description: "Stop current TTS playback",
      keybind: "escape",
      slash: { name: "tts-stop" },
      onSelect() {
        if (stopSpeech()) toast("TTS stopped");
      },
    },

  ];
}
TTSJS
        # Crear módulos restantes
        for mod in session logger llm-client; do
            if [ ! -f "$PLUGIN_DIR/lib/${mod}.js" ]; then
                echo "export default {};" > "$PLUGIN_DIR/lib/${mod}.js"
            fi
        done
        info "Plugin creado con archivos mínimos (personaliza los .js para voz completa)"
    fi
    info "Plugin opencode-voice-modified creado"
else
    info "Plugin opencode-voice-modified ya existe"
fi

# ═══════════════════════════════════════════════════════════
# PASO 16: Copiar datos existentes
# ═══════════════════════════════════════════════════════════
echo "--- 16/19: Copiando datos persistentes ---"
if [ -d "$HOME/Config/opencode/data" ]; then
    cp -r "$HOME/Config/opencode/data/"* "$DIR_CONFIG/data/" 2>/dev/null || true
    info "Datos de persistencia copiados"
fi
if [ -d "$HOME/Config/opencode/skills" ]; then
    mkdir -p "$DIR_CONFIG/skills"
    cp -r "$HOME/Config/opencode/skills/"* "$DIR_CONFIG/skills/" 2>/dev/null || true
    info "Skills copiados"
fi
if [ -d "$HOME/Config/opencode/commands" ]; then
    mkdir -p "$DIR_CONFIG/commands"
    cp -r "$HOME/Config/opencode/commands/"* "$DIR_CONFIG/commands/" 2>/dev/null || true
    info "Commands copiados"
fi

# ═══════════════════════════════════════════════════════════
# PASO 17: Arrancar servicios LM Studio
# ═══════════════════════════════════════════════════════════
echo "--- 17/19: Arrancando LM Studio y proxy ---"

# Arrancar servidor LM Studio si no esta
if command -v lms &>/dev/null; then
    if ! lms status 2>/dev/null | grep -q "ON"; then
        echo "  Arrancando servidor LM Studio..."
        lms server start 2>&1 | tail -1 || true
        sleep 3
    fi
    # Cargar modelo con 80K
    echo "  Cargando modelo con 80K contexto..."
    lms unload models-qwen3.5-9b 2>/dev/null || true
    lms load models-qwen3.5-9b -c 81920 -y 2>/dev/null || warn "No se pudo cargar modelo"
fi

# Arrancar proxy LM Studio (puerto 4001)
if ! pgrep -f "lmstudio-proxy.py" &>/dev/null; then
    nohup python3 "$DIR_CONFIG/lmstudio-proxy.py" 4001 > /tmp/lmstudio-proxy.log 2>&1 &
    sleep 2
    if pgrep -f "lmstudio-proxy.py" &>/dev/null; then
        info "Proxy LM Studio iniciado en puerto 4001"
    else
        warn "Error al iniciar proxy. Log: /tmp/lmstudio-proxy.log"
    fi
else
    info "Proxy LM Studio ya corriendo"
fi

if curl -sf http://localhost:4001/v1/models &>/dev/null; then
    info "Proxy responde correctamente en puerto 4001"
fi

# ═══════════════════════════════════════════════════════════
# PASO 18: Configurar .zshrc + backup final
# ═══════════════════════════════════════════════════════════
echo "--- 18/19: Configurando shell ---"
ZSHRC="$HOME/.zshrc"
if ! grep -q "function ocv" "$ZSHRC" 2>/dev/null; then
    cat >> "$ZSHRC" << 'ZSHEOF'

# OCV - OpenCode con voz
function ocv() {
    script -q -f -c "opencode $*" /dev/null 2>&1
}

# Alias para perfiles local/cloud
alias opencode-local="bash ~/.config/opencode/switch-mcp-profile.sh local && opencode"
alias opencode-cloud="bash ~/.config/opencode/switch-mcp-profile.sh cloud && opencode"
alias ocv-local="bash ~/.config/opencode/switch-mcp-profile.sh local && ocv"
alias ocv-cloud="bash ~/.config/opencode/switch-mcp-profile.sh cloud && ocv"
ZSHEOF
    info "Alias y funcion ocv anadidos al .zshrc"
fi
if ! grep -q '.local/bin' "$ZSHRC" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
    info "PATH actualizado en .zshrc"
fi

# Regenerar backup si existe el script
if [ -f "$HOME/Config/opencode/backup-opencode.sh" ]; then
    echo "  Regenerando backup..."
    bash "$HOME/Config/opencode/backup-opencode.sh" 2>/dev/null || true
fi

echo ""
echo "=============================================="
echo -e "${VERDE}  INSTALACION COMPLETA${NC}"
echo "=============================================="
echo ""
echo "Para iniciar OpenCode:"
echo "  opencode"
echo "O con voz:"
echo "  ocv"
echo ""
echo "Atajos de voz:"
echo "  Ctrl+R    Grabar/Transcribir"
echo "  Espacio+V Toggle TTS"
echo "  Espacio+S Leer respuesta"
echo "  Escape    Parar reproduccion"
echo ""
echo "Configuracion instalada en: $DIR_CONFIG"
echo "Proxy LM Studio: http://127.0.0.1:4001"
echo ""

