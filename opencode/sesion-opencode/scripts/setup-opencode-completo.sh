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
    cat > "$LOCAL_BIN/whisper-cli" << 'WHISPERWRAP'
#!/usr/bin/env bash
exec /usr/bin/whisper-cli -l es "$@"
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
    },
    "cloud": {
      "description": "Agente cloud para modelos en la nube (Claude, Gemini, OpenCode Go)",
      "mode": "fallback",
      "model": "opencode-go/deepseek-v4-flash"
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
    },
    "anthropic": {
      "npm": "@ai-sdk/anthropic",
      "name": "Claude Sonnet 4",
      "model": "claude-sonnet-4-20250514",
      "options": {"apiKey": "ANTHROPIC_API_KEY"},
      "models": {
        "claude-sonnet-4-20250514": {
          "name": "Claude Sonnet 4 - Reasoning Superior",
          "tools": true,
          "limit": {"context": 200000, "output": 8192}
        }
      }
    },
    "google": {
      "npm": "@ai-sdk/google",
      "name": "Gemini Advanced",
      "model": "gemini-2.0-flash-exp",
      "options": {"apiKey": "GOOGLE_API_KEY"},
      "models": {
        "gemini-2.0-flash-exp": {
          "name": "Gemini 2.0 Flash - Multimodal Excellence",
          "tools": true,
          "limit": {"context": 1000000, "output": 8192}
        }
      }
    },
    "opencode-go": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "OpenCode Go",
      "options": {"baseURL": "https://opencode.ai/zen/go/v1"},
      "models": {
        "deepseek-v4-flash": {
          "name": "DeepSeek V4 Flash via OpenCode Go",
          "tools": true,
          "limit": {"context": 128000, "output": 8192}
        },
        "deepseek-v4-pro": {
          "name": "DeepSeek V4 Pro via OpenCode Go",
          "tools": true,
          "limit": {"context": 128000, "output": 8192}
        },
        "qwen3.7-plus": {
          "name": "Qwen 3.7 Plus via OpenCode Go",
          "tools": true,
          "limit": {"context": 256000, "output": 8192}
        },
        "kimi-k2.7-code": {
          "name": "Kimi K2.7 Code via OpenCode Go",
          "tools": true,
          "limit": {"context": 128000, "output": 8192}
        },
        "glm-5.2": {
          "name": "GLM-5.2 via OpenCode Go",
          "tools": true,
          "limit": {"context": 128000, "output": 8192}
        }
      }
    }
  },
  "mcp": {
    "context7": {"type": "remote", "url": "https://mcp.context7.com/mcp", "enabled": true},
    "filesystem": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/home/antonio"], "enabled": true},
    "memory": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-memory"], "enabled": true},
    "fetch": {"type": "local", "command": ["npx", "-y", "mcp-fetch-server"], "enabled": true},
    "sequential_thinking": {"type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"], "enabled": true}
  }
}
JSONEOF
info "opencode.json creado (perfil completo)"

cat > "$DIR_CONFIG/opencode-local.json" << 'LOCALEOF'
{
  "$schema": "https://opencode.ai/config.json",
  "small_model": "lmstudio/models-qwen3.5-9b",
  "instructions": ["AGENTS.md"],
  "default_agent": "local",
  "permission": {
    "edit": "ask",
    "bash": { "sudo *": "deny", "pkexec *": "allow", "*": "ask" }
  },
  "agent": {
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
info "opencode-local.json creado (solo local)"

cat > "$DIR_CONFIG/opencode-cloud.json" << 'CLOUDEOF'
{
  "$schema": "https://opencode.ai/config.json",
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
      "mode": "fallback",
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
    },
    "anthropic": {
      "npm": "@ai-sdk/anthropic",
      "name": "Claude Sonnet 4",
      "model": "claude-sonnet-4-20250514",
      "options": {
        "apiKey": "ANTHROPIC_API_KEY"
      },
      "models": {
        "claude-sonnet-4-20250514": {
          "name": "Claude Sonnet 4 - Reasoning Superior",
          "tools": true,
          "limit": {
            "context": 200000,
            "output": 8192
          }
        }
      }
    },
    "google": {
      "npm": "@ai-sdk/google",
      "name": "Gemini Advanced",
      "model": "gemini-2.0-flash-exp",
      "options": {
        "apiKey": "GOOGLE_API_KEY"
      },
      "models": {
        "gemini-2.0-flash-exp": {
          "name": "Gemini 2.0 Flash - Multimodal Excellence",
          "tools": true,
          "limit": {
            "context": 1000000,
            "output": 8192
          }
        }
      }
    },
    "opencode-go": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "OpenCode Go",
      "options": {
        "baseURL": "https://opencode.ai/zen/go/v1"
      },
      "models": {
        "deepseek-v4-flash": {
          "name": "DeepSeek V4 Flash via OpenCode Go",
          "tools": true,
          "limit": {
            "context": 128000,
            "output": 8192
          }
        },
        "deepseek-v4-pro": {
          "name": "DeepSeek V4 Pro via OpenCode Go",
          "tools": true,
          "limit": {
            "context": 128000,
            "output": 8192
          }
        },
        "qwen3.7-plus": {
          "name": "Qwen 3.7 Plus via OpenCode Go",
          "tools": true,
          "limit": {
            "context": 256000,
            "output": 8192
          }
        },
        "kimi-k2.7-code": {
          "name": "Kimi K2.7 Code via OpenCode Go",
          "tools": true,
          "limit": {
            "context": 128000,
            "output": 8192
          }
        },
        "glm-5.2": {
          "name": "GLM-5.2 via OpenCode Go",
          "tools": true,
          "limit": {
            "context": 128000,
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
      "enabled": false
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
      "type": "remote",
      "url": "https://mcp-fetch-server.vercel.app",
      "enabled": true
    },
    "sequential_thinking": {
      "type": "local",
      "command": [
        "npx",
        "-y",
        "@modelcontextprotocol/server-sequential-thinking"
      ],
      "enabled": false
    }
  }
}
CLOUDEOF
info "opencode-cloud.json creado (perfil con proveedores cloud)"

cat > "$DIR_CONFIG/opencode.jsonc" << 'JSONCEOF'
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "/usr/bin/zsh"
}
JSONCEOF
info "opencode.jsonc creado"

cat > "$DIR_CONFIG/tui.json" << 'TUIEOF'
{
  "$schema": "https://opencode.ai/tui.json",
  "keybinds": {
    "session_rename": "f8"
  },
  "plugin": [
    "/home/antonio/.config/opencode/opencode-voice-modified"
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
    [ "$QUIET" != "--quiet" ] && echo "$*"
}

# ─── 1. Copiar archivos críticos de config a sesion-opencode ───
log "🔄 Sincronizando .config/opencode/ → Config/opencode/sesion-opencode/..."

for f in "$CONFIG_ACTIVO"/*.json "$CONFIG_ACTIVO"/*.sh "$CONFIG_ACTIVO"/*.md "$CONFIG_ACTIVO"/.env; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
        package.json|package-lock.json) continue ;;
    esac
    cp "$f" "$SESION_DIR/" 2>/dev/null || true
done

# Directorios (sin data/, models/, node_modules/)
for dir in commands prompts skills tui.json; do
    [ -d "$CONFIG_ACTIVO/$dir" ] && cp -r "$CONFIG_ACTIVO/$dir" "$SESION_DIR/" 2>/dev/null || true
done

# ─── 2. Sincronizar copias espejo de setup-opencode-completo.sh ───
if [ -f "$SESION_DIR/setup-opencode-completo.sh" ]; then
    mkdir -p "$SESION_DIR/scripts"
    cp "$SESION_DIR/setup-opencode-completo.sh" "$SESION_DIR/scripts/setup-opencode-completo.sh"
    # Copia a .config/opencode/sesion-opencode/scripts/
    mkdir -p "$CONFIG_ACTIVO/sesion-opencode/scripts"
    cp "$SESION_DIR/setup-opencode-completo.sh" "$CONFIG_ACTIVO/sesion-opencode/scripts/setup-opencode-completo.sh"
    log "✅ Copias espejo de setup-opencode-completo.sh sincronizadas"
fi

log "✅ Archivos sincronizados"

# ─── 3. Regenerar backup ───
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
systemctl --user enable init-opencode.service 2>/dev/null || true
systemctl --user enable opencode-sync.timer 2>/dev/null || true
systemctl --user start opencode-sync.timer 2>/dev/null || true
info "Servicios systemd activados (init + sync)"
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
 El script `~/Config/opencode/sesion-opencode/setup-opencode-completo.sh` (y su copia en
 `scripts/`) es el INSTALADOR COMPLETO desde cero. Contiene toda la configuración
 embebida. Por tanto:
 - Cada vez que modifiques cualquier archivo en `~/.config/opencode/`, el
   `setup-opencode-completo.sh` debe actualizarse para reflejar esos cambios
 - Además, existe una copia espejo en `~/.config/opencode/sesion-opencode/scripts/`
   que debe estar SIEMPRE idéntica a la de `~/Config/opencode/sesion-opencode/`
   (ya sea copiándola manualmente o ejecutando el backup)
 - Cuando Antonio pida un backup, DEBES:
   1. Revisar `setup-opencode-completo.sh` por completo
   2. Comprobar que incluye TODOS los archivos actuales de `~/.config/opencode/`
      (JSON, scripts, AGENTS.md, .env, etc.) con su contenido real
   3. Si falta algo o está desactualizado, actualizarlo antes del backup
   4. Copiarlo a `~/Config/opencode/sesion-opencode/` (ambas copias: raíz y scripts/)
   5. **Copiar también** a `~/.config/opencode/sesion-opencode/scripts/` para mantener la copia espejo sincronizada
 - El `backup-opencode.sh` ya lo incluye automáticamente desde `~/Config/opencode/sesion-opencode/`
 
 ---

# PERSISTENCIA DE DATOS Y RECUPERACIÓN

## Variables de entorno
El archivo `.env` contiene la configuración sensible. Para cargarlo:
```bash
set -a; source /home/antonio/.config/opencode/.env; set +a
```

## Inicialización (tras reinicio del sistema)
Ejecutar el script de inicialización que verifica todos los componentes:
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

## Iniciar LM Studio + Qwen3.5-9B Q6_K (80k contexto)
```bash
bash /home/antonio/.config/opencode/start-lmstudio.sh
```
Esto arranca el servidor, carga el modelo Q6_K con 80k de contexto
y lanza el proxy en el puerto 4001 con métricas de tokens/s.

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

---

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
# PASO 11: Scripts LM Studio
# ═══════════════════════════════════════════════════════════
echo "--- 11/19: start-lmstudio.sh + settings ---"

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
chmod +x "$DIR_CONFIG/start-lmstudio.sh"
info "start-lmstudio.sh creado"

mkdir -p "$HOME/.lmstudio"
cat > "$HOME/.lmstudio/settings.json" << 'SETEOF'
{
  "language": "es",
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
    "showDebugInfoBlocksInChat": false,
    "showModelDownloadOptionData": false,
    "appUpdateChannel": "stable",
    "unloadPreviousJITModelOnLoad": true,
    "jitModelTTL": {
      "enabled": true,
      "ttlSeconds": 3600
    },
    "autoUpdateExtensionPacks": true,
    "autoDeleteExtensionPacks": true,
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
  "developerMode": true,
  "userInterfaceComplexityLevel": 0,
  "appFirstLoad": false,
  "autoLoadBundledLLM": true,
  "modelLoadingGuardrails": {
    "mode": "high",
    "customThresholdBytes": 4294967296,
    "alwaysAllowLoadAnyway": false
  },
  "dismissedModals": [
    "LM Link Sidebar Button Popover",
    "Trash Deletion Onboarding"
  ],
  "dismissedConversationSnackbars": [],
  "pre030ChatsMigrated": 3,
  "appPostUpdateNotificationPending": false,
  "promptWhenCommittingUnsavedChangesWithNewFields": false,
  "enableLocalService": true,
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
# PASO 12: Lanzador OpenCode
# ═══════════════════════════════════════════════════════════
echo "--- 12/19: start-opencode.sh ---"

cat > "$DIR_CONFIG/start-opencode.sh" << 'STARTEOF'
#!/usr/bin/env bash
# Lanzador de OpenCode: verifica/arranca LM Studio, luego abre OpenCode
set -e

# Colores para output
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
ROJO='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${VERDE}[+]${NC} $1"; }
aviso() { echo -e "${AMARILLO}[!]${NC} $1"; }
error() { echo -e "${ROJO}[X]${NC} $1"; }

LMS_BIN="/home/antonio/.lmstudio/bin/lms"
LM_PORT=1234

# 1. Verificar / arrancar LM Studio (servidor API en puerto 1234)
if curl -s -o /dev/null -w "" "http://127.0.0.1:${LM_PORT}/v1/models" 2>/dev/null; then
    info "LM Studio ya está corriendo en el puerto ${LM_PORT}"
else
    aviso "Servidor de LM Studio no responde en el puerto ${LM_PORT}. Iniciándolo..."
    if command -v lms &>/dev/null; then
        lms server start
    elif [ -x "$LMS_BIN" ]; then
        "$LMS_BIN" server start
    else
        error "No se encuentra el comando 'lms' ni en PATH ni en ${LMS_BIN}"
        exit 1
    fi
    # Esperar a que responda
    for i in $(seq 1 15); do
        if curl -s -o /dev/null -w "" "http://127.0.0.1:${LM_PORT}/v1/models" 2>/dev/null; then
            info "LM Studio arrancado correctamente"
            break
        fi
        sleep 1
    done
    if ! curl -s -o /dev/null -w "" "http://127.0.0.1:${LM_PORT}/v1/models" 2>/dev/null; then
        error "No se pudo arrancar el servidor de LM Studio."
        error "Asegúrate de que LM Studio (GUI) esté abierto o ejecuta manualmente: lms server start"
        exit 1
    fi
fi

# 2. Ejecutar OpenCode (binario real)
REAL_OPENCODE="${REAL_OPENCODE:-/usr/bin/opencode}"
info "Lanzando ${REAL_OPENCODE}..."
exec "${REAL_OPENCODE}" "$@"
STARTEOF
chmod +x "$DIR_CONFIG/start-opencode.sh"
info "start-opencode.sh creado"

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
  "exports": { ".": { "import": "./index.js" }, "./tui": { "import": "./index.js" } },
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
import fs from "node:fs";
import os from "node:os";
import { registerSTT } from "./lib/stt.js";
import { registerTTS } from "./lib/tts.js";
import { createClient } from "./lib/llm-client.js";
import { createLogger } from "./lib/logger.js";

export default function init(api) {
  const logger = createLogger(api);
  const llmClient = createClient(api);
  registerSTT(api, logger, llmClient);
  registerTTS(api, logger, llmClient);
}
PLUGINJS
        # Crear stt.js mínimo
        cat > "$PLUGIN_DIR/lib/stt.js" << 'STTJS'
export function registerSTT(api, logger, llmClient) {
  api.registerPluginCommand("stt-record", { key: "ctrl+r" }, async () => {});
  api.registerPluginCommand("stt-submit", { key: "leader+r" }, async () => {});
  api.registerPluginCommand("stt-stop", {}, async () => {});
}
STTJS
        # Crear tts.js mínimo
        cat > "$PLUGIN_DIR/lib/tts.js" << 'TTSJS'
export function registerTTS(api, logger, llmClient) {
  api.registerPluginCommand("tts-speak", { key: "leader+s" }, async () => {});
  api.registerPluginCommand("tts-mode", { key: "leader+v" }, async () => {});
  api.registerPluginCommand("tts-stop", { key: "escape" }, async () => {});
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

