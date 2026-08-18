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
# LOG_PROXY="/tmp/ollama-proxy.log"  # En desuso (config de Ollama archivada 09/08/2026).
# Se conserva comentada por si en el futuro se reactiva Ollama como proveedor.
# shellcheck disable=SC2034
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

# Crear symlink libggml-cpu.so.0 (whisper-cli lo necesita en runtime)
setup_ggml_cpu_symlink() {
    local BIN_DIR="$HOME/.local/share/whisper-cpp/bin"
    local VARIANT=""
    for cand in zen4 alderlake skylakex icelake haswell cascadelake x64 sse42; do
        if [ -f "${BIN_DIR}/libggml-cpu-${cand}.so" ]; then
            VARIANT="${cand}"
            break
        fi
    done
    if [ -n "${VARIANT}" ] && [ -f "${BIN_DIR}/libggml-cpu-${VARIANT}.so" ]; then
        ln -sf "libggml-cpu-${VARIANT}.so" "${BIN_DIR}/libggml-cpu.so.0"
        ln -sf "libggml-cpu-${VARIANT}.so" "${BIN_DIR}/libggml-cpu.so"
        info "Symlink libggml-cpu.so.0 -> libggml-cpu-${VARIANT}.so"
    else
        warn "No se encontró variante libggml-cpu-*.so para crear el symlink"
    fi
}

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
    if pipx install edge-tts >/dev/null 2>&1; then
        info "edge-tts instalado"
    else
        warn "Fallo edge-tts"
    fi
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
            cp -dP "${WHISPER_TMP}"/whisper-src/build/bin/libggml*.so* "$HOME/.local/share/whisper-cpp/bin/" 2>/dev/null || true
            setup_ggml_cpu_symlink
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
        setup_ggml_cpu_symlink
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
# PASO 4b: Servidores LSP (basedpyright, tsserver, gopls, rust-analyzer, clangd)
# ═══════════════════════════════════════════════════════════
echo "--- 4b/19: Servidores LSP ---"
# Python: basedpyright (mejor rendimiento que pyright)
if ! command -v basedpyright-langserver >/dev/null 2>&1; then
    if pipx install basedpyright >/dev/null 2>&1; then
        info "basedpyright instalado"
    else
        warn "Fallo basedpyright (instala: pipx install basedpyright)"
    fi
else
    info "basedpyright ya instalado"
fi
# TypeScript/JavaScript: typescript-language-server (requiere npm con prefix ~/.npm-global)
if ! command -v typescript-language-server >/dev/null 2>&1; then
    npm config set prefix "$HOME/.npm-global" >/dev/null 2>&1 || true
    if npm install -g typescript-language-server typescript >/dev/null 2>&1; then
        info "typescript-language-server instalado"
    else
        warn "Fallo tsserver (instala: npm i -g typescript-language-server typescript)"
    fi
else
    info "typescript-language-server ya instalado"
fi
# JSON: vscode-json-language-server (del paquete vscode-langservers-extracted)
if ! command -v vscode-json-language-server >/dev/null 2>&1; then
    if npm install -g vscode-langservers-extracted >/dev/null 2>&1; then
        info "vscode-json-language-server instalado"
    else
        warn "Fallo json-lsp (instala: npm i -g vscode-langservers-extracted)"
    fi
else
    info "vscode-json-language-server ya instalado"
fi
# YAML: yaml-language-server
if ! command -v yaml-language-server >/dev/null 2>&1; then
    if npm install -g yaml-language-server >/dev/null 2>&1; then
        info "yaml-language-server instalado"
    else
        warn "Fallo yaml-lsp (instala: npm i -g yaml-language-server)"
    fi
else
    info "yaml-language-server ya instalado"
fi
# Bash/Zsh: bash-language-server + shellcheck + shfmt
if ! command -v bash-language-server >/dev/null 2>&1; then
    if npm install -g bash-language-server >/dev/null 2>&1; then
        info "bash-language-server instalado"
    else
        warn "Fallo bash-lsp (instala: npm i -g bash-language-server)"
    fi
else
    info "bash-language-server ya instalado"
fi
if ! command -v shellcheck >/dev/null 2>&1; then
    if command -v pacman >/dev/null 2>&1; then
        if pkexec pacman -S --needed --noconfirm shellcheck >/dev/null 2>&1; then
            info "shellcheck instalado"
        else
            warn "Fallo shellcheck"
        fi
    else
        warn "shellcheck no instalado (linting bash desactivado)"
    fi
else
    info "shellcheck ya instalado"
fi
if ! command -v shfmt >/dev/null 2>&1; then
    if command -v pacman >/dev/null 2>&1; then
        if pkexec pacman -S --needed --noconfirm shfmt >/dev/null 2>&1; then
            info "shfmt instalado"
        else
            warn "Fallo shfmt"
        fi
    else
        warn "shfmt no instalado (formateo bash desactivado)"
    fi
else
    info "shfmt ya instalado"
fi
# Markdown: marksman (LSP de Markdown, binario autónomo)
if ! command -v marksman >/dev/null 2>&1; then
    if command -v pacman >/dev/null 2>&1; then
        if pkexec pacman -S --needed --noconfirm marksman >/dev/null 2>&1; then
            info "marksman instalado"
        else
            warn "Fallo marksman (instala: pkexec pacman -S marksman)"
        fi
    else
        warn "marksman no instalado (descarga binario desde github.com/artempyanykh/marksman)"
    fi
else
    info "marksman ya instalado"
fi
# Go: gopls (requiere Go instalado)
if command -v go >/dev/null 2>&1; then
    if [ ! -x "$HOME/go/bin/gopls" ]; then
        if go install golang.org/x/tools/gopls@latest >/dev/null 2>&1; then
            info "gopls instalado"
        else
            warn "Fallo gopls (instala: go install golang.org/x/tools/gopls@latest)"
        fi
    else
        info "gopls ya instalado"
    fi
else
    warn "Go no está instalado, gopls se omitirá"
fi
# Rust: rust-analyzer (componente de rustup)
if command -v rustup >/dev/null 2>&1; then
    RA_REAL="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rust-analyzer"
    if [ ! -x "$RA_REAL" ]; then
        if rustup component add rust-analyzer >/dev/null 2>&1; then
            info "rust-analyzer instalado"
        else
            warn "Fallo rust-analyzer (instala: rustup component add rust-analyzer)"
        fi
    else
        info "rust-analyzer ya instalado"
    fi
else
    warn "rustup no está instalado, rust-analyzer se omitirá"
fi
# C/C++: clangd (vía gestor de paquetes)
if ! command -v clangd >/dev/null 2>&1; then
    if command -v pacman >/dev/null 2>&1; then
        if pkexec pacman -S --needed --noconfirm clang >/dev/null 2>&1; then
            info "clangd instalado (pacman)"
        else
            warn "Fallo clangd (instala: pkexec pacman -S clang)"
        fi
    else
        warn "clangd no instalado (instala el paquete clang de tu distro)"
    fi
else
    info "clangd ya instalado"
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
      "prompt": "{file:./prompts/read-agents.txt}",
      "model": "opencode-go/deepseek-v4-flash"
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
    },
    "nvidia": {
      "description": "Agente NVIDIA - Nemotron 3 Ultra 550B A55B",
      "mode": "primary",
      "model": "nvidia/nvidia/nemotron-3-ultra-550b-a55b"
    }
  },
  "provider": {
    "nvidia": {
      "whitelist": [
        "minimaxai/minimax-m3",
        "z-ai/glm-5.2",
        "openai/gpt-oss-20b",
        "openai/gpt-oss-120b",
        "stepfun-ai/step-3.7-flash",
        "thinkingmachines/inkling",
        "meta/llama-3.1-8b-instruct",
        "meta/llama-3.1-70b-instruct",
        "meta/llama-3.2-11b-vision-instruct",
        "meta/llama-3.3-70b-instruct",
        "meta/muse-glimmer-30b",
        "nvidia/llama-3.3-nemotron-super-49b-v1",
        "nvidia/llama-3.3-nemotron-super-49b-v1.5",
        "nvidia/nemotron-3-nano-30b-a3b",
        "nvidia/nemotron-3-super-120b-a12b",
        "nvidia/nemotron-3-ultra-550b-a55b",
        "nvidia/nemotron-3.5-lightning-30b-a3b",
        "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning",
        "nvidia/nemotron-mini-4b-instruct",
        "nvidia/nemotron-nano-12b-v2-vl",
        "nvidia/nvidia-nemotron-nano-9b-v2",
        "nvidia/llama-3.1-nemotron-nano-vl-8b-v1"
      ]
    },
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
  "lsp": {
    "python": {
      "command": [
        "/home/antonio/.local/bin/basedpyright-langserver",
        "--stdio"
      ],
      "extensions": [
        ".py",
        ".pyw"
      ]
    },
    "c": {
      "command": [
        "/usr/bin/clangd"
      ],
      "extensions": [
        ".c",
        ".h"
      ]
    },
    "cpp": {
      "command": [
        "/usr/bin/clangd"
      ],
      "extensions": [
        ".cpp",
        ".hpp",
        ".cc",
        ".cxx"
      ]
    },
    "rust": {
      "command": [
        "/home/antonio/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rust-analyzer"
      ],
      "extensions": [
        ".rs"
      ]
    },
    "typescript": {
      "command": [
        "/home/antonio/.npm-global/bin/typescript-language-server",
        "--stdio"
      ],
      "extensions": [
        ".ts",
        ".tsx",
        ".js",
        ".jsx",
        ".mjs",
        ".cjs"
      ]
    },
    "go": {
      "command": [
        "/home/antonio/go/bin/gopls"
      ],
      "extensions": [
        ".go"
      ]
    },
    "json": {
      "command": [
        "/home/antonio/.npm-global/bin/vscode-json-language-server",
        "--stdio"
      ],
      "extensions": [
        ".json",
        ".jsonc"
      ]
    },
    "yaml": {
      "command": [
        "/home/antonio/.npm-global/bin/yaml-language-server",
        "--stdio"
      ],
      "extensions": [
        ".yaml",
        ".yml"
      ]
    },
    "bash": {
      "command": [
        "/home/antonio/.npm-global/bin/bash-language-server",
        "start"
      ],
      "extensions": [
        ".sh",
        ".bash"
      ]
    },
    "zsh": {
      "command": [
        "/home/antonio/.npm-global/bin/bash-language-server",
        "start"
      ],
      "extensions": [
        ".zsh",
        ".zshrc"
      ]
    },
    "markdown": {
      "command": [
        "/usr/bin/marksman"
      ],
      "extensions": [
        ".md",
        ".markdown"
      ]
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
      "environment": {
        "MEMORY_FILE_PATH": "/home/antonio/.config/opencode/data/memory/memory.jsonl"
      },
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

cat > "$DIR_CONFIG/opencode-cloud.json" << 'CLOUDEOF'
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
      "prompt": "{file:./prompts/read-agents.txt}",
      "model": "opencode-go/deepseek-v4-flash"
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
    },
    "nvidia": {
      "description": "Agente NVIDIA - Nemotron 3 Ultra 550B A55B",
      "mode": "primary",
      "model": "nvidia/nvidia/nemotron-3-ultra-550b-a55b"
    }
  },
  "provider": {
    "nvidia": {
      "whitelist": [
        "minimaxai/minimax-m3",
        "z-ai/glm-5.2",
        "openai/gpt-oss-20b",
        "openai/gpt-oss-120b",
        "stepfun-ai/step-3.7-flash",
        "thinkingmachines/inkling",
        "meta/llama-3.1-8b-instruct",
        "meta/llama-3.1-70b-instruct",
        "meta/llama-3.2-11b-vision-instruct",
        "meta/llama-3.3-70b-instruct",
        "meta/muse-glimmer-30b",
        "nvidia/llama-3.3-nemotron-super-49b-v1",
        "nvidia/llama-3.3-nemotron-super-49b-v1.5",
        "nvidia/nemotron-3-nano-30b-a3b",
        "nvidia/nemotron-3-super-120b-a12b",
        "nvidia/nemotron-3-ultra-550b-a55b",
        "nvidia/nemotron-3.5-lightning-30b-a3b",
        "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning",
        "nvidia/nemotron-mini-4b-instruct",
        "nvidia/nemotron-nano-12b-v2-vl",
        "nvidia/nvidia-nemotron-nano-9b-v2",
        "nvidia/llama-3.1-nemotron-nano-vl-8b-v1"
      ]
    },
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
  "lsp": {
    "python": {
      "command": [
        "/home/antonio/.local/bin/basedpyright-langserver",
        "--stdio"
      ],
      "extensions": [
        ".py",
        ".pyw"
      ]
    },
    "c": {
      "command": [
        "/usr/bin/clangd"
      ],
      "extensions": [
        ".c",
        ".h"
      ]
    },
    "cpp": {
      "command": [
        "/usr/bin/clangd"
      ],
      "extensions": [
        ".cpp",
        ".hpp",
        ".cc",
        ".cxx"
      ]
    },
    "rust": {
      "command": [
        "/home/antonio/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rust-analyzer"
      ],
      "extensions": [
        ".rs"
      ]
    },
    "typescript": {
      "command": [
        "/home/antonio/.npm-global/bin/typescript-language-server",
        "--stdio"
      ],
      "extensions": [
        ".ts",
        ".tsx",
        ".js",
        ".jsx",
        ".mjs",
        ".cjs"
      ]
    },
    "go": {
      "command": [
        "/home/antonio/go/bin/gopls"
      ],
      "extensions": [
        ".go"
      ]
    },
    "json": {
      "command": [
        "/home/antonio/.npm-global/bin/vscode-json-language-server",
        "--stdio"
      ],
      "extensions": [
        ".json",
        ".jsonc"
      ]
    },
    "yaml": {
      "command": [
        "/home/antonio/.npm-global/bin/yaml-language-server",
        "--stdio"
      ],
      "extensions": [
        ".yaml",
        ".yml"
      ]
    },
    "bash": {
      "command": [
        "/home/antonio/.npm-global/bin/bash-language-server",
        "start"
      ],
      "extensions": [
        ".sh",
        ".bash"
      ]
    },
    "zsh": {
      "command": [
        "/home/antonio/.npm-global/bin/bash-language-server",
        "start"
      ],
      "extensions": [
        ".zsh",
        ".zshrc"
      ]
    },
    "markdown": {
      "command": [
        "/usr/bin/marksman"
      ],
      "extensions": [
        ".md",
        ".markdown"
      ]
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
      "environment": {
        "MEMORY_FILE_PATH": "/home/antonio/.config/opencode/data/memory/memory.jsonl"
      },
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
CLOUDEOF
info "opencode-cloud.json creado (perfil cloud)"

cat > "$DIR_CONFIG/opencode-local.json" << 'LOCALEOF'
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "/usr/bin/zsh",
  "small_model": "lmstudio/models-qwen3.5-9b",
  "instructions": [
    "AGENTS.md"
  ],
  "default_agent": "local",
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
      "prompt": "{file:./prompts/read-agents.txt}",
      "model": "opencode-go/deepseek-v4-flash"
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
      "mode": "primary",
      "model": "opencode-go/deepseek-v4-flash"
    },
    "nvidia": {
      "description": "Agente NVIDIA - Nemotron 3 Ultra 550B A55B",
      "mode": "primary",
      "model": "nvidia/nvidia/nemotron-3-ultra-550b-a55b"
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
  "lsp": {
    "python": {
      "command": [
        "/home/antonio/.local/bin/basedpyright-langserver",
        "--stdio"
      ],
      "extensions": [
        ".py",
        ".pyw"
      ]
    },
    "c": {
      "command": [
        "/usr/bin/clangd"
      ],
      "extensions": [
        ".c",
        ".h"
      ]
    },
    "cpp": {
      "command": [
        "/usr/bin/clangd"
      ],
      "extensions": [
        ".cpp",
        ".hpp",
        ".cc",
        ".cxx"
      ]
    },
    "rust": {
      "command": [
        "/home/antonio/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rust-analyzer"
      ],
      "extensions": [
        ".rs"
      ]
    },
    "typescript": {
      "command": [
        "/home/antonio/.npm-global/bin/typescript-language-server",
        "--stdio"
      ],
      "extensions": [
        ".ts",
        ".tsx",
        ".js",
        ".jsx",
        ".mjs",
        ".cjs"
      ]
    },
    "go": {
      "command": [
        "/home/antonio/go/bin/gopls"
      ],
      "extensions": [
        ".go"
      ]
    },
    "json": {
      "command": [
        "/home/antonio/.npm-global/bin/vscode-json-language-server",
        "--stdio"
      ],
      "extensions": [
        ".json",
        ".jsonc"
      ]
    },
    "yaml": {
      "command": [
        "/home/antonio/.npm-global/bin/yaml-language-server",
        "--stdio"
      ],
      "extensions": [
        ".yaml",
        ".yml"
      ]
    },
    "bash": {
      "command": [
        "/home/antonio/.npm-global/bin/bash-language-server",
        "start"
      ],
      "extensions": [
        ".sh",
        ".bash"
      ]
    },
    "zsh": {
      "command": [
        "/home/antonio/.npm-global/bin/bash-language-server",
        "start"
      ],
      "extensions": [
        ".zsh",
        ".zshrc"
      ]
    },
    "markdown": {
      "command": [
        "/usr/bin/marksman"
      ],
      "extensions": [
        ".md",
        ".markdown"
      ]
    }
  },
  "mcp": {
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "enabled": false
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
      "environment": {
        "MEMORY_FILE_PATH": "/home/antonio/.config/opencode/data/memory/memory.jsonl"
      },
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
      "enabled": false
    }
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
Description=Sync OpenCode each 30 min

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
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

# ─── Vigilancia del fix del timeline (PR #26861) ───
cat > "$DIR_CONFIG/check-timeline-fix.sh" << 'TIMELINE-FIX_SHEOF'
#!/usr/bin/env bash
# ============================================================
# check-timeline-fix.sh — Vigila el PR #26861 de OpenCode
# (fix del timeline: historial completo en la TUI)
#
# Consulta el estado del PR en GitHub. Si está MERGEADO,
# avisa para que podamos retirar el script timeline-completo.
# Se ejecuta automáticamente vía systemd timer.
# ============================================================

LOG_FILE="$HOME/.config/opencode/data/timeline-fix.log"
PR_URL="https://api.github.com/repos/anomalyco/opencode/pulls/26861"

log() {
    echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Consultar el estado del PR
STATUS=$(curl -s --max-time 10 "$PR_URL" 2>/dev/null | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
    state = d.get('state', 'unknown')
    merged = d.get('merged_at')
    title = d.get('title', '')
    if merged:
        print(f'MERGEADO|{merged}|{title}')
    else:
        print(f'{state}|-|{title}')
except Exception:
    print('ERROR|-|-')
" 2>/dev/null)

if [ -z "$STATUS" ] || [ "$STATUS" = "ERROR|-|-" ]; then
    log "⚠️ No se pudo consultar GitHub (sin conexión o API caída)"
    exit 0
fi

STATE="${STATUS%%|*}"
REST="${STATUS#*|}"
MERGED="${REST%%|*}"

case "$STATE" in
    MERGEADO)
        log "🎉 ¡EL PR #26861 SE HA MERGEADO! Fecha: $MERGED"
        log "👉 Ya se puede retirar el script timeline-completo."
        log "👉 Comprobar si la nueva versión de OpenCode incluye el fix."
        # Notificación de escritorio (opcional, si hay notify-send)
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u normal "OpenCode: fix del timeline mergeado" \
                "El PR #26861 se ha mergeado ($MERGED). Ya puedes dejar de usar timeline-completo." 2>/dev/null || true
        fi
        ;;
    open)
        log "🔍 PR #26861 sigue ABIERTO (sin mergear). Se mantiene timeline-completo."
        ;;
    closed)
        log "ℹ️ PR #26861 CERRADO sin mergear. Se mantiene timeline-completo."
        ;;
    *)
        log "⚠️ Estado desconocido del PR: $STATE"
        ;;
esac
TIMELINE-FIX_SHEOF
chmod +x "$DIR_CONFIG/check-timeline-fix.sh"

# ─── check-setup-completo: verificación OBLIGATORIA del setup antes de backup ───
cat > "$DIR_CONFIG/check-setup-completo.sh" << 'CHECK-SETUP_SHEOF'
#!/usr/bin/env bash
# ============================================================
# check-setup-completo.sh — Verificación OBLIGATORIA del
# setup-opencode-completo.sh ANTES de cada backup.
#
# Comprueba que el setup:
#  1. Tiene sintaxis válida (bash -n)
#  2. Pasa shellcheck sin errores reales (SC2016 en heredocs = OK)
#  3. TODOS los heredocs embebidos == archivos activos (uno a uno)
#  4. Contiene la estructura completa de pasos (1-19 + sub-pasos)
#  5. Los comandos que usa existen en el sistema
#
# Este script se ejecuta AUTOMÁTICAMENTE desde backup-opencode.sh.
# Si falla algún punto, el backup se ABORTA (no se genera tarball).
# ============================================================

SETUP="$HOME/Config/opencode/sesion-opencode/setup-opencode-completo.sh"
ACTIVO="$HOME/.config/opencode"
LOG="$HOME/.config/opencode/data/setup-check.log"

log() { echo "[$(date '+%d/%m/%Y %H:%M:%S')] $*" | tee -a "$LOG"; }

ERRORS=0
WARNINGS=0

mkdir -p "$(dirname "$LOG")"
log "═══════════ VERIFICACIÓN DEL SETUP ═══════════"
log "Setup: $SETUP"

# ─── 1. ¿Existe el setup? ───
if [ ! -f "$SETUP" ]; then
    log "❌ ERROR: No existe $SETUP"
    log "El backup se ABORTA."
    exit 1
fi
log "✅ Setup encontrado ($(wc -l < "$SETUP") líneas)"

# ─── 2. Sintaxis (bash -n) ───
if bash -n "$SETUP" 2>/dev/null; then
    log "✅ Sintaxis válida (bash -n)"
else
    log "❌ ERROR: Sintaxis inválida"
    ERRORS=$((ERRORS+1))
fi

# ─── 3. Shellcheck (solo errores/warnings reales; SC2016 info = OK) ───
SC_OUT=$(shellcheck "$SETUP" 2>&1 | grep -E "SC[0-9]+" || true)
SC_INFO=$(echo "$SC_OUT" | grep -c "SC2016" || true)
SC_OTHER=$(echo "$SC_OUT" | grep -vE "SC2016" | grep -c "SC[0-9]+" || true)
if [ "$SC_OTHER" -gt 0 ] 2>/dev/null; then
    log "❌ ERROR: shellcheck reporta $SC_OTHER avisos no-SC2016"
    ERRORS=$((ERRORS+1))
else
    log "✅ Shellcheck limpio (${SC_INFO:-0} notas SC2016 intencionales, 0 errores)"
fi

# ─── 4. Estructura de pasos (1-19 + sub-pasos) ───
PASOS=$(grep -c '# PASO' "$SETUP")
if [ "$PASOS" -ge 19 ] 2>/dev/null; then
    log "✅ Estructura completa ($PASOS pasos)"
else
    log "❌ ERROR: Solo $PASOS pasos (esperado >= 19)"
    ERRORS=$((ERRORS+1))
fi

# ─── 5. Heredocs embebidos vs archivos activos (UNO A UNO) ───
# Usamos python3 para comparar byte a byte
HERE_RESULT=$(python3 - "$SETUP" "$ACTIVO" << 'PYEOF'
import re, json, sys

setup_path = sys.argv[1]
activo_dir = sys.argv[2]

with open(setup_path) as f:
    c = f.read()

def extract(delim):
    marker = f"<< '{delim}'\n"
    if marker not in c: return None
    start = c.index(marker) + len(marker)
    end = c.index(f"\n{delim}", start)
    return c[start:end+1]

def norm(s): return json.dumps(json.loads(s), sort_keys=True)

# Mapeo archivo -> delimitador (TODOS los embebidos)
archivos = {
    'opencode.json': 'JSONEOF', 'opencode-local.json': 'LOCALEOF', 'tui.json': 'TUIEOF',
    'AGENTS.md': 'AGEOF', '.env': 'ENVEOF',
    'switch-mcp-profile.sh': 'SWITCHEOF', 'sync-opencode.sh': 'SYNCEOF',
    'init-opencode.sh': 'INITEOF', 'start-lmstudio-server.sh': 'SERVEREOF',
    'start-lmstudio.sh': 'LMSEOF', 'start-opencode-server.sh': 'STARTEOF',
    'start-opencode.sh': 'OPENCODEEOF', 'hardware-query.sh': 'HARDWARE-QUERY_SHEOF',
    'check-fix.sh': 'CHECK-FIX_SHEOF', 'check-timeline-fix.sh': 'TIMELINE-FIX_SHEOF',
    'web-search.sh': 'WEB-SEARCH_SHEOF', 'lmstudio-proxy.py': 'LMPROXYEOF',
    'backup-opencode.sh': 'BKUEOF', 'bootstrap-ocv.sh': 'BOOTEOF',
    'settings.lmstudio.json': 'LMSETEOF',
}

ok = 0
fails = []
for fname, delim in archivos.items():
    emb = extract(delim)
    act_path = f"{activo_dir}/{fname}"
    if emb is None:
        fails.append(f"{fname} (heredoc {delim} no encontrado)")
        continue
    try:
        with open(act_path) as f:
            act = f.read()
    except FileNotFoundError:
        fails.append(f"{fname} (no existe en activo)")
        continue
    if fname.endswith('.json'):
        match = norm(emb) == norm(act)
    else:
        match = emb == act
    if match:
        ok += 1
    else:
        fails.append(f"{fname} (DIFIERE: activo {len(act)} vs embebido {len(emb)} chars)")

print(f"OK:{ok}")
for f in fails:
    print(f"FAIL:{f}")
PYEOF
)

HERE_OK=$(echo "$HERE_RESULT" | grep "^OK:" | cut -d: -f2)
HERE_FAILS=$(echo "$HERE_RESULT" | grep "^FAIL:" | sed 's/^FAIL://')

if [ -n "$HERE_FAILS" ]; then
    log "❌ ERROR: ${HERE_FAILS}"
    ERRORS=$((ERRORS+1))
else
    log "✅ Heredocs embebidos: ${HERE_OK}/20 coinciden con el activo"
fi

# ─── 6. Comandos que usa el setup existen ───
MISSING=""
for cmd in pkexec pacman pipx npm rustup go curl git sqlite3 systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING="$MISSING $cmd"
    fi
done
if [ -n "$MISSING" ]; then
    log "❌ ERROR: Comandos faltantes:$MISSING"
    ERRORS=$((ERRORS+1))
else
    log "✅ Comandos necesarios presentes (pkexec, pacman, pipx, npm, rustup, go, curl, git, sqlite3, systemctl)"
fi

# ─── Resultado final ───
if [ "$ERRORS" -gt 0 ]; then
    log "❌❌❌ VERIFICACIÓN FALLIDA ($ERRORS errores) — EL BACKUP SE ABORTA ❌❌❌"
    exit 1
else
    log "✅✅✅ VERIFICACIÓN COMPLETA: SETUP CORRECTO — SE PUEDE HACER EL BACKUP ✅✅✅"
    exit 0
fi
CHECK-SETUP_SHEOF
chmod +x "$DIR_CONFIG/check-setup-completo.sh"
info "check-setup-completo.sh creado (verifica el setup antes de cada backup)"
info "check-timeline-fix.sh creado (vigila PR #26861)"

cat > "$HOME/.config/systemd/user/check-timeline-fix.service" << 'TLSERVEOF'
[Unit]
Description=Check OpenCode PR #26861 (timeline fix) status

[Service]
Type=oneshot
ExecStart=/home/antonio/.config/opencode/check-timeline-fix.sh
TLSERVEOF

cat > "$HOME/.config/systemd/user/check-timeline-fix.timer" << 'TLTIMEREOF'
[Unit]
Description=Check OpenCode timeline fix (PR #26861) every 3 days

[Timer]
OnCalendar=*-*-* 10:00:00
OnUnitActiveSec=3d
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
TLTIMEREOF

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user disable init-opencode.service 2>/dev/null || true
systemctl --user enable opencode-sync.timer 2>/dev/null || true
systemctl --user start opencode-sync.timer 2>/dev/null || true
systemctl --user enable --now check-timeline-fix.timer 2>/dev/null || true
info "Servicios systemd: sync activado, init deshabilitado, check-timeline-fix activado"
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

Para REGENERAR el índice con los datos reales actuales del hardware:
```bash
python3 ~/.config/opencode/hardware-query.py scan
```
(Escanea lscpu, lspci, lsusb, nvidia-smi, sensors, lsblk, dmidecode, iw,
xrandr, free, /proc... y actualiza data/hardware/index.json. Usa pkexec
para dmidecode: saldrá una ventana pidiendo contraseña la primera vez.)

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

## 📖 Consultar documentación oficial ante problemas (OBLIGATORIO)
Cuando algo te esté dando problemas (herramientas que fallan, configuraciones que no
funcionan, errores desconocidos, etc.):
1. **Accede PRIMERO a la documentación/wiki oficial** de la herramienta afectada
2. Busca información en la web (issues, foros, stackoverflow)
3. NO te quedes dando vueltas probando a ciegas: si tras 2-3 intentos propios no
   lo resuelves, consulta fuentes externas
4. Para OpenCode: https://opencode.ai/docs (y el esquema https://opencode.ai/config.json)
5. Para LSPs concretos: consulta la wiki del servidor (ej. github del proyecto)
Anota siempre la solución encontrada en la memoria.

---

# PROCEDIMIENTOS TÉCNICOS

## Sincronización con Config/opencode (OBLIGATORIO)
- `~/.config/opencode/` es la configuración ACTIVA (la que usa OpenCode)
- `~/Config/opencode/` es la copia de SEGURIDAD para instalaciones desde limpio
- Estructura ordenada de `~/Config/opencode/`:
  - `backups/opencode/` → tarballs de backup de OpenCode (`opencode-backup-*.tar.gz`)
  - `backups/` (raíz) → backups del grafo de memoria (`mcp-memory-backup-*.jsonl`)
  - `data/` → datos auxiliares (p. ej. `onlyoffice-ai/`)
  - `documentacion/` → documentación en Markdown
  - `sesion-opencode/` → setup completo desde limpio + scripts sincronizados
  - `respaldo-config/` → snapshot antiguo de la configuración
  - `legacy/` → scripts y carpetas obsoletos
  - En la raíz solo viven: `AGENTS.md`, `backup-opencode.sh`, `bootstrap-ocv.sh`, `sync-opencode.sh`
    y el enlace simbólico `setup-opencode-completo.sh` → `sesion-opencode/setup-opencode-completo.sh`
- Cada vez que modifiques, crees o elimines algo en `~/.config/opencode/`:
  1. **Copia el archivo** a `~/Config/opencode/` (manteniendo la misma estructura)
  2. **Actualiza los scripts** de instalación si es necesario:
     - `~/Config/opencode/backup-opencode.sh` → script que empaqueta el backup
     - `~/Config/opencode/bootstrap-ocv.sh` → script de instalación desde limpio
     - `restore.sh` (va dentro del tarball, lo genera backup-opencode.sh)
  3. Si el cambio afecta al proceso de instalación/restauración, modifica los scripts para reflejarlo
- Ejecuta `bash ~/Config/opencode/backup-opencode.sh` para regenerar el tarball con restore.sh actualizado
- El tarball se genera en `~/Config/opencode/backups/opencode/`

## Atención al script setup-opencode-completo.sh (IMPORTANTE)
El script `~/Config/opencode/sesion-opencode/setup-opencode-completo.sh` es el
INSTALADOR COMPLETO desde cero. Contiene toda la configuración embebida. Por tanto:
- **ÚNICA copia en disco**: vive SOLO en `~/Config/opencode/sesion-opencode/`
  (carpeta de respaldo) y dentro del tarball del backup. NO debe existir en la raíz
  de `~/.config/opencode/` ni en ningún `scripts/`.
- **Acceso directo**: en la raíz de `~/Config/opencode/` hay un ENLACE SIMBÓLICO
  `setup-opencode-completo.sh` → `sesion-opencode/` para tenerlo a mano SIN duplicarlo.
- El `sync-opencode.sh` (timer systemd `opencode-sync.timer`, cada 30 minutos)
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

  ### ✅ CHECKLIST OBLIGATORIO del punto 1 (revisar el setup POR COMPLETO):
  - [ ] `bash -n` del setup (sintaxis)
  - [ ] `shellcheck` del setup (sin warnings/errors reales; SC2016 en heredocs = OK)
  - [ ] TODOS los heredocs embebidos == archivos activos, comparando UNO A UNO
        (opencode.json, opencode-local.json, tui.json, AGENTS.md, .env, y TODOS
        los scripts: switch-mcp-profile, sync, init, start-*, hardware-query,
        check-fix, check-timeline-fix, hardware-query.py, lmstudio-proxy.py,
        backup-opencode, bootstrap-ocv, timeline-completo) — no solo los JSON
  - [ ] Comandos usados existen en el sistema (pkexec, pacman, pipx, npm, etc.)
  - [ ] Estructura completa (pasos 1-19, sin saltos ni duplicados)

  ### ⚡ VERIFICACIÓN AUTOMÁTICA (NO DEPENDE DE MI MEMORIA):
  El script `~/.config/opencode/check-setup-completo.sh` hace TODO el checklist
  automáticamente (sintaxis, shellcheck, heredocs uno a uno, estructura, comandos).
  Está INTEGRADO en `backup-opencode.sh`: se ejecuta SIEMPRE al hacer un backup y
  si el setup no está correcto, el backup se ABORTA. NO es opcional ni manual.
  Si Antonio pide un backup, simplemente ejecuta `bash ~/Config/opencode/backup-opencode.sh`
  — la verificación ocurre sola. Si algo falla, el script dirá exactamente qué corregir.
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
Con nombre `mcp-memory-backup-{fecha}.jsonl`
Los backups se conservan 30 días (según LOG_RETENTION_DAYS en .env)
## Recuperación del grafo de memoria
Si el grafo se pierde o corrompe:
1. Localizar el backup más reciente:
   ```bash
   ls -t /home/antonio/Config/opencode/backups/mcp-memory-backup-*.jsonl | head -1
   ```
2. Copiarlo a la ruta de memoria activa:
   ```bash
   cp /home/antonio/Config/opencode/backups/mcp-memory-backup-*.jsonl /home/antonio/.config/opencode/data/memory/memory.jsonl
   ```
3. Reiniciar OpenCode: el servidor MCP Memory cargará el grafo desde `MEMORY_FILE_PATH`
   (definido vía `environment` en el bloque `mcp.memory` de los 3 perfiles JSON).
   ⚠️ El servidor usa `MEMORY_FILE_PATH` (NO `MEMORY_DATA_DIR`).

## ⚠️ Recordatorio MCP memory (IMPORTANTE)
Al usar la herramienta `memory_add_observations` (o `memory_delete_observations`),
CADA observación del array DEBE incluir el campo `entityName` junto a `contents`:
```json
{"observations": [
  {"entityName": "Nombre de la entidad", "contents": ["observación 1", "observación 2"]}
]}
```
Si falta `entityName` el MCP devuelve error `-32602` (Input validation error).
Mismo formato para `memory_create_relations`: cada relación necesita `from`, `to`, `relationType`.

## 🕐 Timeline completo de sesiones (script timeline-completo)
El timeline de la TUI de OpenCode (Ctrl+X G) SOLO muestra las últimas ~6 peticiones
(límite hardcodeado; el PR #26861 que lo arregla sigue abierto, sin mergear).
Para ver el historial COMPLETO de cualquier sesión, usar el script:
```
~/.local/bin/timeline-completo
```
- `timeline-completo` → historial completo de la sesión actual (todas las peticiones con fecha/hora)
- `timeline-completo <id_sesión>` → historial de una sesión concreta
- `timeline-completo --sesiones` → lista las sesiones recientes con su título
- `timeline-completo --buscar "<texto>"` → busca peticiones en TODAS las sesiones
Lee directamente de `~/.local/share/opencode/opencode.db` (sqlite3).
TODAS las peticiones de Antonio están guardadas ahí aunque la TUI no las muestre.
Cuando Antonio pregunte por su historial/timeline de peticiones, usa este script.

## 👁️ Vigilancia del fix del timeline (timer systemd)
El script `~/.config/opencode/check-timeline-fix.sh` comprueba si el PR #26861
de OpenCode (fix del timeline) se ha mergeado. Se ejecuta automáticamente cada
3 días vía el timer systemd `check-timeline-fix.timer` y registra el resultado
en `~/.config/opencode/data/timeline-fix.log`.
- Si el PR se mergea: se avisa (log + notificación) para retirar timeline-completo.
- Consultar el log si Antonio pregunta por el estado del fix.

## Directorios de datos
- `/home/antonio/.config/opencode/data/` - Datos de ejecución (logs, estado)
- `/home/antonio/.config/opencode/data/memory/` - Grafo de memoria persistente (`memory.jsonl`, vía `MEMORY_FILE_PATH`)
- `/home/antonio/Config/opencode/backups/` - Backups del grafo de memoria (`mcp-memory-backup-*.jsonl`)
- `/home/antonio/Config/opencode/backups/opencode/` - Tarballs de backup de OpenCode
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
# Variable REAL que usa el servidor @modelcontextprotocol/server-memory
# (se inyecta vía "environment" en el bloque mcp.memory de opencode.json)
MEMORY_FILE_PATH=/home/antonio/.config/opencode/data/memory/memory.jsonl
MEMORY_DATA_DIR=/home/antonio/.config/opencode/data/memory
MEMORY_BACKUP_ENABLED=true
MEMORY_BACKUP_PATH=/home/antonio/Config/opencode/backups/mcp-memory-backup-$(date '+%Y-%m-%d_%H%M').jsonl

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

# ── settings.lmstudio.json: copia de respaldo de la config de LM Studio ──
cat > "$DIR_CONFIG/settings.lmstudio.json" << 'LMSETEOF'
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
    "alwaysShowPromptTemplate": false,
    "useShiftEnterToSendMessage": false,
    "showChatUtilityMenuLabels": false,
    "aiNamingMode": "auto",
    "neverAskForToolConfirmation": false,
    "pinnedPlugins": [],
    "chatFullWidth": false,
    "scrollLastMessageToTop": "scrollToTopNoLatch"
  },
  "developer": {
    "showExperimentalFeatures": false,
    "appUpdateChannel": "stable",
    "autoUpdateExtensionPacks": true
  },
  "ui": {
    "missionControlFullscreen": false,
    "contextDisplayMode": "percentage",
    "appNavigationBarPosition": "left"
  },
  "configPresetInclusiveness": {
    "speculativeDecoding": false
  },
  "developerMode": true,
  "userInterfaceComplexityLevel": 0,
  "autoLoadBundledLLM": true,
  "modelLoadingGuardrails": {
    "mode": "high"
  }
}
LMSETEOF
info "settings.lmstudio.json de respaldo creado"

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

# ── start-opencode.sh: lanzador que verifica/arranca LM Studio y abre OpenCode ──
cat > "$DIR_CONFIG/start-opencode.sh" << 'OPENCODEEOF'
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
OPENCODEEOF
chmod +x "$DIR_CONFIG/start-opencode.sh"
info "start-opencode.sh creado"

# ═══════════════════════════════════════════════════════════
# PASO 13: Scripts auxiliares
# ═══════════════════════════════════════════════════════════
echo "--- 13/19: Scripts auxiliares ---"

cat > "$DIR_CONFIG/hardware-query.sh" << 'HARDWARE-QUERY_SHEOF'
#!/bin/bash
# ============================================================
# hardware-query.sh — Wrapper de hardware-query.py
# (consulta rápida de hardware via index.json)
#
# Uso: source ~/.config/opencode/hardware-query.sh && hw_query <campo>
# Campos: status, cpu, gpu, ram, motherboard, wifi, bluetooth, all
# ============================================================

HW_PY="/home/antonio/.config/opencode/hardware-query.py"

hw_query() {
    if [ -x "$HW_PY" ]; then
        python3 "$HW_PY" "$1"
    else
        echo "❌ No se encontró $HW_PY"
        return 1
    fi
}
HARDWARE-QUERY_SHEOF
chmod +x "$DIR_CONFIG/hardware-query.sh"
info "hardware-query.sh creado (wrapper)"

cat > "$DIR_CONFIG/hardware-query.py" << 'HARDWARE-QUERY_PYEOF'
#!/usr/bin/env python3
# ============================================================
# hardware-query.py — Auditoría completa de hardware (Linux)
#
# Uso:
#   hardware-query.py scan             → escanea TODO el hardware y
#                                        actualiza data/hardware/index.json
#   hardware-query.py status           → resumen legible del hardware
#   hardware-query.py <campo>          → imprime el JSON de un campo
#   hardware-query.py --campos         → lista los campos disponibles
#
# Campos: status, cpu, gpu, ram, motherboard, wifi, bluetooth,
#         all, os, storage, displays, audio, usb, sensors, network, ...
# (y cualquier otra clave presente en el index.json)
#
# El modo "scan" recolecta datos con las herramientas nativas del
# sistema (lscpu, lspci, lsusb, nvidia-smi, sensors, lsblk, dmidecode,
# iw, ip, xrandr, free, /proc...) y regenera el índice al completo.
# ============================================================
import datetime
import json
import os
import re
import subprocess
import sys
from typing import Any

DATA_DIR = "/home/antonio/.config/opencode/data/hardware"
HARDWARE_PATH = os.path.join(DATA_DIR, "index.json")

# Tipos auxiliares para dicts heterogéneos (JSON-like)
JsonDict = dict[str, Any]

CAMPOS_AYUDA = ("status", "cpu", "gpu", "ram", "motherboard", "wifi",
                "bluetooth", "all", "os", "storage", "displays", "audio",
                "usb", "sensors", "network", "pci", "bios")


# ─────────────────────────────────────────────────────────────
# Utilidades de ejecución
# ─────────────────────────────────────────────────────────────
def run(cmd, timeout=15):
    """Ejecuta un comando y devuelve su stdout (str) o '' si falla."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=timeout, errors="replace")
        return r.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return ""


def run_root(cmd, timeout=20):
    """Ejecuta con pkexec (ventana gráfica de contraseña) si es necesario."""
    try:
        r = subprocess.run(["pkexec"] + cmd, capture_output=True, text=True,
                           timeout=timeout, errors="replace")
        return r.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return ""


def leer_proc(path):
    """Lee un archivo de /proc. Devuelve str o ''."""
    try:
        with open(path) as f:
            return f.read()
    except (OSError, FileNotFoundError):
        return ""


def json_ok(texto):
    """True si el texto es JSON parseable."""
    try:
        json.loads(texto)
        return True
    except (json.JSONDecodeError, TypeError):
        return False


# ─────────────────────────────────────────────────────────────
# Recolección de cada sección
# ─────────────────────────────────────────────────────────────
def seccion_os():
    os_data = {}
    # Distribución
    etc = leer_proc("/etc/os-release")
    for line in etc.splitlines():
        if line.startswith("PRETTY_NAME="):
            os_data["distribution"] = line.split("=", 1)[1].strip('"')
        elif line.startswith("ID="):
            os_data["distro_id"] = line.split("=", 1)[1].strip('"')
    if "distribution" not in os_data:
        os_data["distribution"] = run(["cat", "/etc/os-release"])[:80]

    os_data["kernel"] = run(["uname", "-r"])
    os_data["kernel_type"] = run(["uname", "-v"])[:40]
    os_data["arch"] = run(["uname", "-m"])
    os_data["hostname"] = run(["hostname"])
    os_data["shell"] = os.environ.get("SHELL", "")

    # Desktop / sesión
    xdg = os.environ.get("XDG_CURRENT_DESKTOP", "")
    os_data["desktop"] = xdg if xdg else run(["echo", "$XDG_CURRENT_DESKTOP"])
    os_data["display_server"] = os.environ.get("XDG_SESSION_TYPE", "")

    # Tiempo / carga
    os_data["uptime"] = run(["uptime", "-p"])
    os_data["boot_time"] = run(["uptime", "-s"])
    try:
        with open("/proc/loadavg") as f:
            os_data["load_avg"] = [float(x) for x in f.read().split()[:3]]
    except (OSError, ValueError):
        pass

    # Localización
    os_data["locale"] = run(["locale"]).splitlines()[0] if run(["locale"]) else ""
    tz = run(["timedatectl", "show", "-p", "TimeZone", "--value"])
    if not tz:
        try:
            tz = os.path.realpath("/etc/localtime").replace("/usr/share/zoneinfo/", "")
        except OSError:
            tz = ""
    os_data["timezone"] = tz
    return os_data


def seccion_cpu():
    salida = run(["lscpu"])
    cpu = {}
    map_es = {
        "Nombre del modelo": "model",
        "Model name": "model",
        "Fabricante": "vendor",
        "Vendor ID": "vendor",
        "Arquitectura": "arch",
        "Architecture": "arch",
        "CPU(s)": "threads",
        "Hilo(s) de procesamiento por núcleo": "threads_per_core",
        "Thread(s) per core": "threads_per_core",
        "Núcleo(s) por socket": "cores_per_socket",
        "Núcleo(s) por «socket»": "cores_per_socket",
        "Core(s) per socket": "cores_per_socket",
        "Socket(s)": "sockets",
        "Familia de CPU": "familia",
        "CPU family": "familia",
        "Modelo": "modelo",
        "Model": "modelo",
        "Virtualización": "virtualization",
        "Virtualization": "virtualization",
        "Caché L1d": "cache_l1d",
        "L1d cache": "cache_l1d",
        "Caché L1i": "cache_l1i",
        "L1i cache": "cache_l1i",
        "Caché L2": "cache_l2",
        "L2 cache": "cache_l2",
        "Caché L3": "cache_l3",
        "L3 cache": "cache_l3",
        "CPU MHz máx.": "speed_max_mhz",
        "CPU max MHz": "speed_max_mhz",
        "CPU MHz mín.": "speed_min_mhz",
        "CPU min MHz": "speed_min_mhz",
        "Modo(s) NUMA": "numa_nodes",
        "NUMA node(s)": "numa_nodes",
    }
    for line in salida.splitlines():
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip()
        if key in map_es:
            campo = map_es[key]
            if campo == "threads":
                cpu["threads"] = int(val.split()[0])
            elif campo == "cores_per_socket":
                cpu["cores"] = int(val.split()[0])
            elif campo == "speed_max_mhz":
                try:
                    cpu["speed_max_mhz"] = round(float(val.split()[0]), 2)
                except ValueError:
                    pass
            elif campo == "speed_min_mhz":
                try:
                    cpu["speed_min_mhz"] = round(float(val.split()[0]), 2)
                except ValueError:
                    pass
            else:
                cpu[campo] = val

    # /proc/cpuinfo para vendor, stepping, microcode, bogomips
    info = leer_proc("/proc/cpuinfo")
    if "vendor_id" in info:
        for line in info.splitlines():
            if ":" not in line:
                continue
            k, _, v = line.partition(":")
            k, v = k.strip(), v.strip()
            if k == "vendor_id" and "vendor" not in cpu:
                cpu["vendor"] = v
            elif k == "stepping" and "stepping" not in cpu:
                cpu["stepping"] = v
            elif k == "microcode" and "microcode" not in cpu:
                cpu["microcode"] = v
            elif k == "bogomips" and "bogomips" not in cpu:
                cpu["bogomips"] = float(v.split()[0])

    # Vulnerabilidades
    vuln = {}
    for line in info.splitlines():
        if ":" not in line:
            continue
        k, _, v = line.partition(":")
        k, v = k.strip(), v.strip()
        if k in ("Vulnerability", "Vulnerabilidad"):
            continue
        if k.startswith("Vulnerability") or "mitigation" in v.lower() or "affected" in v.lower():
            vuln[k] = v
    # Mejor: leer de /sys/devices/system/cpu/vulnerabilities
    vulns_dir = "/sys/devices/system/cpu/vulnerabilities"
    if os.path.isdir(vulns_dir):
        vuln = {}
        for name in sorted(os.listdir(vulns_dir)):
            try:
                with open(os.path.join(vulns_dir, name)) as f:
                    vuln[name] = f.read().strip()
            except OSError:
                pass
    if vuln:
        cpu["vulnerabilities"] = vuln

    # Flags ISA (instrucciones soportadas)
    flags = []
    if "flags" in info:
        for line in info.splitlines():
            if line.startswith("flags"):
                flags = line.split(":", 1)[1].split()
                break
    if flags:
        cpu["flags_isa"] = flags
    return cpu


def seccion_ram():
    ram = {}
    try:
        with open("/proc/meminfo") as f:
            mem = f.read()
        m = re.search(r"MemTotal:\s+(\d+) kB", mem)
        if m:
            ram["total_kb"] = int(m.group(1))
            ram["total_gb"] = round(int(m.group(1)) / 1048576, 1)
        m = re.search(r"MemAvailable:\s+(\d+) kB", mem)
        if m:
            ram["available_gb"] = round(int(m.group(1)) / 1048576, 1)
        m = re.search(r"SwapTotal:\s+(\d+) kB", mem)
        if m:
            ram["swap_total_gb"] = round(int(m.group(1)) / 1048576, 1)
    except OSError:
        pass

    if ram.get("total_gb"):
        ram["usage_percent"] = round(
            (ram["total_gb"] - ram.get("available_gb", 0)) / ram["total_gb"] * 100, 1)

    # Dmidecode (RAM detallada) — requiere root
    dmi = run_root(["dmidecode", "-t", "memory"])
    if dmi:
        speed = re.search(r"Configured Memory Speed:\s*(\d+) MT/s", dmi)
        if speed:
            ram["speed_mts"] = int(speed.group(1))
        mod = re.search(r"Part Number:\s*(\S+)", dmi)
        if mod:
            ram["module_id"] = mod.group(1)
        # Parsear por BLOQUES de Memory Device (cada bloque = un slot,
        # con su propio Size — así no se saltan los slots vacíos)
        dimms = []
        for bloque in re.split(r"\n\s*Memory Device\n", dmi):
            loc = re.search(r"Locator:\s*(DIMM\w+)", bloque)
            if not loc:
                continue
            tam = re.search(r"Size:\s*(\d+)\s*GiB", bloque)
            if tam:
                dimms.append({"slot": loc.group(1),
                              "size_gb": int(tam.group(1)),
                              "installed": True})
            else:
                dimms.append({"slot": loc.group(1),
                              "size_gb": 0,
                              "installed": False})
        ram["dimms"] = dimms
        ram["dimms_count"] = sum(1 for d in dimms if d["installed"])
        ram["dimms_total_slots"] = len(dimms)
        ranks = re.findall(r"Rank:\s*(\d+)", dmi)
        if ranks:
            ram["rank"] = int(ranks[0])

    # Zram (swap comprimido)
    if os.path.exists("/sys/block/zram0/disksize"):
        try:
            with open("/sys/block/zram0/disksize") as f:
                size = int(f.read().strip()) / 1073741824
            ram["swap"] = {
                "type": "zram",
                "device": "/dev/zram0",
                "size_gb": round(size, 1),
            }
            try:
                with open("/sys/block/zram0/comp_algorithm") as f:
                    ram["swap"]["algorithm"] = f.read().strip()
            except OSError:
                pass
        except (OSError, ValueError):
            pass
    return ram


def seccion_motherboard():
    mb = {}
    dmi = run_root(["dmidecode", "-t", "baseboard", "-t", "bios"])
    if not dmi:
        # Fallback sin root
        dmi = run(["dmidecode", "-t", "baseboard", "-t", "bios"])
    m = re.search(r"Manufacturer:\s*(.+)", dmi)
    if m:
        mb["vendor"] = m.group(1).strip()
    m = re.search(r"Product Name:\s*(.+)", dmi)
    if m:
        mb["model"] = m.group(1).strip()
        mb["product_name"] = m.group(1).strip()
    m = re.search(r"Version:\s*(\S+)", dmi)
    if m:
        mb["firmware_version"] = m.group(1).strip()
    m = re.search(r"BIOS Revision:\s*(.+)", dmi)
    if m:
        mb["bios_revision"] = m.group(1).strip()
    m = re.search(r"Release Date:\s*(.+)", dmi)
    if m:
        mb["bios_date"] = m.group(1).strip()
    m = re.search(r"Chassis Type:\s*(.+)", dmi)
    if m:
        mb["chassis_type"] = m.group(1).strip()
    mb["uefi"] = os.path.isdir("/sys/firmware/efi")
    return mb


def seccion_gpu_nvidia():
    gpu = {}
    smi = run(["nvidia-smi",
               "--query-gpu=name,driver_version,memory.total,memory.used,"
               "memory.free,temperature.gpu,power.draw,utilization.gpu,"
               "uuid,pcie.link.gen.current,pcie.link.width.current",
               "--format=csv,noheader,nounits"])
    if smi:
        parts = [p.strip() for p in smi.split(",")]
        if len(parts) >= 8:
            gpu["model"] = parts[0]
            gpu["driver"] = f"nvidia v{parts[1]}"
            gpu["driver_version"] = parts[1]
            try:
                gpu["vram_mib"] = int(parts[2])
                gpu["vram_gb"] = round(int(parts[2]) / 1024, 1)
                gpu["vram_used_mib"] = int(parts[3])
                gpu["vram_free_mib"] = int(parts[4])
                if int(parts[2]) > 0:
                    gpu["vram_usage_percent"] = round(
                        int(parts[3]) / int(parts[2]) * 100, 1)
                gpu["temperature_celsius"] = int(parts[5])
                gpu["power_watts"] = round(float(parts[6]), 2)
                gpu["utilization_percent"] = int(parts[7])
            except ValueError:
                pass
            if len(parts) >= 9:
                gpu["gpu_uuid"] = parts[8]
            if len(parts) >= 11:
                gpu["pcie_gen"] = parts[9]
                gpu["pcie_lanes"] = parts[10]

    # Arquitectura vía lspci
    lspci = run(["lspci"])
    for line in lspci.splitlines():
        if "VGA" in line and ("NVIDIA" in line or "AD10" in line):
            gpu["pci_line"] = line
            m = re.search(r"\[(AD\d+)\]", line)
            if m:
                gpu["device_id"] = m.group(1)
            m = re.search(r"\[([0-9a-f]{4}:[0-9a-f]{4})\]", line)
            if m:
                gpu["pci_id"] = m.group(1)
            break

    # Vulkan / CUDA
    nvcc = run(["nvcc", "--version"])
    m = re.search(r"release\s+([\d.]+)", nvcc)
    if m:
        gpu["cuda_version"] = m.group(1)
    # fallback: version.json
    if "cuda_version" not in gpu and os.path.exists("/opt/cuda/version.json"):
        try:
            with open("/opt/cuda/version.json") as f:
                gpu["cuda_version"] = json.load(f)["cuda"]["version"]
        except Exception:
            pass
    return gpu


def seccion_gpu_amd():
    gpu = {}
    lspci = run(["lspci"])
    for line in lspci.splitlines():
        if "VGA" in line and "AMD" in line:
            gpu["model"] = "AMD Radeon Graphics (integrated)"
            m = re.search(r"\[(1002:[0-9a-f]{4})\]", line)
            if m:
                gpu["pci_id"] = m.group(1)
            if "Raphael" in line:
                gpu["device_id"] = "Raphael"
            break
    gpu["driver"] = "amdgpu kernel"
    return gpu


def seccion_displays():
    displays: list[JsonDict] = []
    xrandr = run(["xrandr"], timeout=5)
    for line in xrandr.splitlines():
        if " connected" not in line:
            continue
        parts = line.split()
        conn = parts[0]
        # Resolución activa: "5760x3240+0+0" o "3840x2160+0+0"
        res = ""
        geom = next((p for p in parts if re.match(r"\d+x\d+\+\d+\+\d+", p)), "")
        if geom:
            res = geom.split("+")[0]
        d: JsonDict = {"interface": conn, "active_resolution": res}
        m = re.search(r"(\d+)mm x (\d+)mm", line)
        if m:
            w_cm, h_cm = int(m.group(1)) / 10, int(m.group(2)) / 10
            d["size_cm"] = f"{w_cm:.0f}x{h_cm:.0f}"
            diag = (w_cm ** 2 + h_cm ** 2) ** 0.5 / 2.54
            d["size_inches"] = round(diag, 1)
        d["primary"] = "primary" in line
        d["active_resolution"] = res
        displays.append(d)
    # Fallback: /sys/class/drm
    if not displays:
        for conn in sorted(os.listdir("/sys/class/drm")):
            if not conn.startswith("card") or "-" not in conn:
                continue
            try:
                with open(f"/sys/class/drm/{conn}/status") as f:
                    if f.read().strip() == "connected":
                        displays.append({"interface": conn.split("-", 1)[1]})
            except OSError:
                pass
    return displays


def seccion_storage():
    discos = []
    salida = run(["lsblk", "-b", "-o", "NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL"])
    actual = None
    for line in salida.splitlines()[1:]:
        nombre, resto = line.split(maxsplit=1) if line.strip() else ("", "")
        if nombre and not nombre.startswith(("└", "├", "`", "|")):
            # Disco físico
            parts = line.split()
            if len(parts) >= 3:
                model = " ".join(parts[5:]) if len(parts) > 5 else ""
                discos.append({
                    "name": parts[0],
                    "size_bytes": int(parts[1]),
                    "size_tb": round(int(parts[1]) / 1099511627776, 2),
                    "type": parts[2],
                    "fstype": parts[3] if len(parts) > 3 else "",
                    "mountpoint": parts[4] if len(parts) > 4 else "",
                    "model": model,
                })
    return discos


def seccion_network():
    red: JsonDict = {}

    # ── Información del CHIP WiFi (lspci) ──
    chip: JsonDict = {}
    lspci_out = run(["lspci", "-nn"])
    for line in lspci_out.splitlines():
        if "Network controller" in line and ("Qualcomm" in line or "802.11" in line or "WCN" in line):
            chip["pci_line"] = line
            m = re.search(r"Qualcomm Technologies, Inc (.+?)\s*\[", line)
            if m:
                chip["model"] = m.group(1).strip()
            m = re.search(r"\[([0-9a-f]{4}:[0-9a-f]{4})\]\s*\(rev (\d+)\)", line)
            if m:
                chip["pci_id"] = m.group(1)
                chip["revision"] = m.group(2)
            break
    # Subsistema (fabricante de la tarjeta instalada)
    sub = run(["lspci", "-nn", "-v", "-s", "07:00.0"])
    m = re.search(r"Subsystem: (.+?)\s*\[", sub)
    if m:
        chip["subsystem"] = m.group(1).strip()
    m = re.search(r"Kernel modules:\s*(\S+)", sub)
    if m:
        chip["kernel_module"] = m.group(1)

    # ── WiFi (estado actual) ──
    wifi: JsonDict = {}
    link = run(["iw", "dev", "wlan0", "link"])
    if link:
        for line in link.splitlines():
            line = line.strip()
            if line.startswith("SSID:"):
                wifi["connected_ssid"] = line.split(":", 1)[1].strip()
            elif "freq:" in line:
                wifi["frequency_mhz"] = int(float(line.split("freq:", 1)[1].split()[0]))
            elif "signal:" in line:
                wifi["signal_dbm"] = int(line.split("signal:", 1)[1].split()[0])
            elif "tx bitrate:" in line:
                parts = line.split("tx bitrate:", 1)[1].split()
                try:
                    wifi["tx_bitrate_mbps"] = float(parts[0])
                except ValueError:
                    pass
                m = re.search(r"(\d+)MHz", line)
                if m:
                    wifi["channel_width_mhz"] = int(m.group(1))
                m = re.search(r"(HE|VHT|HT)-\w+", line)
                if m:
                    wifi["phy_mode"] = m.group(0)
            elif "rx bitrate:" in line:
                parts = line.split("rx bitrate:", 1)[1].split()
                try:
                    wifi["rx_bitrate_mbps"] = float(parts[0])
                except ValueError:
                    pass
    if wifi:
        wifi["interface"] = "wlan0"
        wifi["driver"] = run(["sh", "-c", "readlink /sys/class/net/wlan0/device/driver | xargs basename"])
        # MAC + modo + wiphy
        info = run(["iw", "dev", "wlan0", "info"])
        m = re.search(r"addr\s+([0-9a-f:]+)", info)
        if m:
            wifi["mac"] = m.group(1)
        m = re.search(r"type\s+(\S+)", info)
        if m:
            wifi["mode"] = m.group(1)
        m = re.search(r"wiphy\s+(\d+)", info)
        if m:
            wifi["wiphy"] = int(m.group(1))
        # IP
        ip = run(["ip", "-4", "addr", "show", "wlan0"])
        m = re.search(r"inet\s+(\S+)", ip)
        if m:
            wifi["ip"] = m.group(1)
        # Bytes transmitidos/recibidos
        try:
            with open("/sys/class/net/wlan0/statistics/rx_bytes") as f:
                wifi["rx_bytes"] = int(f.read().strip())
            with open("/sys/class/net/wlan0/statistics/tx_bytes") as f:
                wifi["tx_bytes"] = int(f.read().strip())
        except OSError:
            pass
        # Señal mín/máx recientes (iwinfo o /proc)
        if chip:
            wifi["chipset"] = chip
        red["wifi"] = wifi

    # Ethernet
    eth = run(["ethtool", "enp8s0"])
    red["ethernet"] = {
        "interface": "enp8s0",
        "state": "down" if not eth or "Link detected: no" in eth else "up",
    }
    m = re.search(r"Speed:\s*(\d+\w+)", eth)
    if m:
        red["ethernet"]["speed"] = m.group(1)

    # Bluetooth
    bt = run(["bluetoothctl", "show"])
    if bt:
        m = re.search(r"Controller\s+([0-9A-F:]+)\s+(.+)", bt)
        if m:
            red["bluetooth"] = {
                "controller_mac": m.group(1),
                "name": m.group(2).strip(),
                "state": "up" if "Powered: yes" in bt else "down",
            }

    # Interfaces virtuales (docker/vmware)
    virtual = {}
    for iface in ("vmnet1", "vmnet8", "docker0"):
        ip = run(["ip", "-4", "addr", "show", iface])
        m = re.search(r"inet\s+(\S+)", ip)
        if m:
            virtual[iface] = {"ip": m.group(1)}
    if virtual:
        red["virtual"] = virtual
    return red


def seccion_sensors():
    sens = {}
    out = run(["sensors"])
    # Mapeo heurístico de los sensores más comunes
    patrones = {
        "Tctl": "cpu_tctl_celsius",
        "Tccd1": "cpu_tccd1_celsius",
        "Tccd2": "cpu_tccd2_celsius",
        "Composite": "nvme_composite_celsius",
        "edge": "gpu_amd_edge_celsius",
        "temp1": "temp1_celsius",
    }
    for line in out.splitlines():
        m = re.match(r"(\w+):\s+\+?([\d.]+)°C", line)
        if m:
            key, val = m.group(1), float(m.group(2))
            campo = patrones.get(key)
            if campo:
                sens[campo] = val
    # GPU NVIDIA
    smi = run(["nvidia-smi", "--query-gpu=temperature.gpu,power.draw",
               "--format=csv,noheader,nounits"])
    if smi:
        parts = [p.strip() for p in smi.split(",")]
        if len(parts) == 2:
            try:
                sens["gpu_nvidia_celsius"] = int(parts[0])
                sens["gpu_nvidia_power_watts"] = round(float(parts[1]), 2)
            except ValueError:
                pass
    return sens


def seccion_usb():
    dispositivos = []
    out = run(["lsusb"])
    for line in out.splitlines():
        m = re.match(r"Bus (\d+) Device (\d+): ID ([0-9a-f]{4}:[0-9a-f]{4})\s+(.+)", line)
        if m:
            vid_pid = m.group(3)
            nombre = m.group(4).strip()
            # Acortar nombres muy largos
            if len(nombre) > 60:
                nombre = nombre[:60] + "..."
            dispositivos.append({"id": vid_pid, "product": nombre})
    return dispositivos


def seccion_audio():
    audio: JsonDict = {"server": "pipewire" if run(["pactl", "info"]).count("PipeWire") else "pulseaudio"}
    sinks = run(["pactl", "list", "short", "sinks"])
    audio["sinks"] = [l.split("\t")[1] for l in sinks.splitlines() if l.strip()]
    sources = run(["pactl", "list", "short", "sources"])
    audio["sources"] = [l.split("\t")[1] for l in sources.splitlines() if l.strip()]
    return audio


def seccion_kernel_boot():
    kb = {}
    cmdline = leer_proc("/proc/cmdline")
    if cmdline:
        kb["cmdline"] = cmdline.strip()
    return kb


# ─────────────────────────────────────────────────────────────
# Generación del índice
# ─────────────────────────────────────────────────────────────
def escanear():
    """Recolecta todo el hardware y actualiza index.json."""
    print("🔍 Escaneando hardware...")
    datos = {}

    datos["meta"] = {
        "generated": datetime.datetime.now().strftime("%d/%m/%Y %H:%M %Z"),
        "source": "hardware-query.py scan (16/08/2026)",
        "note": "Índice regenerado automáticamente con hardware-query.py",
    }

    print("  • Sistema operativo...")
    datos["os"] = seccion_os()
    print("  • CPU...")
    datos["cpu"] = seccion_cpu()
    print("  • RAM...")
    datos["ram"] = seccion_ram()
    print("  • Placa base...")
    datos["motherboard"] = seccion_motherboard()
    print("  • GPU NVIDIA...")
    datos["gpu_nvidia"] = seccion_gpu_nvidia()
    print("  • GPU AMD integrada...")
    datos["gpu_amd_integrated"] = seccion_gpu_amd()
    print("  • Monitores...")
    datos["displays"] = seccion_displays()
    print("  • Almacenamiento...")
    datos["storage_devices"] = seccion_storage()
    print("  • Red...")
    datos["network"] = seccion_network()
    print("  • Sensores...")
    datos["sensors"] = seccion_sensors()
    print("  • USB...")
    datos["usb_devices"] = seccion_usb()
    print("  • Audio...")
    datos["audio"] = seccion_audio()
    print("  • Kernel/boot...")
    datos["kernel_boot"] = seccion_kernel_boot()

    # Guardar
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(HARDWARE_PATH, "w") as f:
        json.dump(datos, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print("")
    print(f"✅ Índice actualizado: {HARDWARE_PATH}")
    print(f"   ({len(datos)} secciones, {datetime.datetime.now().strftime('%H:%M:%S')})")
    return datos


# ─────────────────────────────────────────────────────────────
# Consultas
# ─────────────────────────────────────────────────────────────
def cargar_datos():
    try:
        with open(HARDWARE_PATH, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"❌ No existe {HARDWARE_PATH}", file=sys.stderr)
        print("   Ejecuta primero: hardware-query.py scan", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ {HARDWARE_PATH} no es JSON válido: {e}", file=sys.stderr)
        sys.exit(1)


def mostrar_status(d):
    def get(*keys, default="?"):
        node = d
        for k in keys:
            if not isinstance(node, dict) or k not in node:
                return default
            node = node[k]
        return node

    cpu = d.get("cpu", {})
    ram = d.get("ram", {})
    gpu = d.get("gpu_nvidia", {})
    mb = d.get("motherboard", {})
    net = d.get("network", {}).get("wifi", {})
    discos = d.get("storage_devices", [])

    print("═══════════════════════════════════════════")
    print("  HARDWARE STATUS")
    print("═══════════════════════════════════════════")
    print(f'CPU:  {cpu.get("model", "?")} ({cpu.get("cores", "?")}C/{cpu.get("threads", "?")}T)')
    print(f'RAM:  DDR5 @ {ram.get("speed_mts", "?")} MT/s  ({ram.get("total_gb", "?")} GB)')
    print(f'GPU:  NVIDIA {gpu.get("model", "?")}')
    print(f'MB:   {mb.get("model", "?")}')
    print(f'Kernel: {d.get("os", {}).get("kernel", "?")}')
    print(f'WiFi: {net.get("connected_ssid", "?")} ({net.get("signal_dbm", "?")} dBm)')
    print(f'Discos: {len(discos)} físicos')
    print("───────────────────────────────────────────")


def mostrar_campos(d):
    print("Campos de consulta:")
    for campo in CAMPOS_AYUDA:
        print(f"  - {campo}")
    print("\nSecciones del índice:")
    for k in d.keys():
        print(f"  - {k}")


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print((__doc__ or "hardware-query.py <comando>").strip())
        return 0

    comando = sys.argv[1]

    if comando == "scan":
        escanear()
        return 0

    if comando == "--campos":
        d = cargar_datos()
        mostrar_campos(d)
        return 0

    d = cargar_datos()

    if comando == "status":
        mostrar_status(d)
        return 0

    if comando == "all":
        print(json.dumps(d, indent=2, default=str))
        return 0

    # Campos derivados (compatibilidad)
    if comando == "gpu":
        print(json.dumps(d.get("gpu_nvidia", {}), indent=2, default=str))
        print("--- iGPU ---")
        print(json.dumps(d.get("gpu_amd_integrated", {}), indent=2, default=str))
        return 0

    if comando in ("wifi", "bluetooth"):
        net = d.get("network", {})
        if comando == "bluetooth":
            bt = net.get("bluetooth", {})
            if bt:
                print(json.dumps(bt, indent=2, default=str))
            else:
                print("ℹ️  El índice no contiene datos de bluetooth.", file=sys.stderr)
                return 1
        else:
            wifi = net.get("wifi", {})
            if wifi:
                print(json.dumps(wifi, indent=2, default=str))
            else:
                print("ℹ️  El índice no contiene datos de wifi.", file=sys.stderr)
                return 1
        return 0

    if comando in ("storage", "discos"):
        print(json.dumps(d.get("storage_devices", []), indent=2, default=str))
        return 0

    if comando in ("usb", "usb_devices"):
        print(json.dumps(d.get("usb_devices", []), indent=2, default=str))
        return 0

    if comando in ("os", "sistema"):
        print(json.dumps(d.get("os", {}), indent=2, default=str))
        return 0

    if comando == "displays" or comando == "monitores":
        print(json.dumps(d.get("displays", []), indent=2, default=str))
        return 0

    if comando == "audio":
        print(json.dumps(d.get("audio", {}), indent=2, default=str))
        return 0

    if comando == "sensors":
        print(json.dumps(d.get("sensors", {}), indent=2, default=str))
        return 0

    if comando == "network":
        print(json.dumps(d.get("network", {}), indent=2, default=str))
        return 0

    if comando == "pci":
        print(json.dumps(d.get("pci_devices", {}), indent=2, default=str))
        return 0

    if comando == "bios":
        print(json.dumps(d.get("motherboard", {}), indent=2, default=str))
        return 0

    # Cualquier otra clave directa del índice
    if comando in d:
        print(json.dumps(d[comando], indent=2, default=str))
        return 0

    print(f"❌ Campo desconocido: {comando}", file=sys.stderr)
    print(f"   Campos: {', '.join(CAMPOS_AYUDA)}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
HARDWARE-QUERY_PYEOF
chmod +x "$DIR_CONFIG/hardware-query.py"
info "hardware-query.py creado (motor Python)"

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


# ─── timeline-completo: historial completo de sesiones (lee opencode.db) ───
mkdir -p "$LOCAL_BIN"
cat > "$LOCAL_BIN/timeline-completo" << 'TIMELINE_SHEOF'
#!/usr/bin/env bash
# ============================================================
# timeline-completo.sh — Ver el historial COMPLETO de peticiones
# de OpenCode desde la base de datos (opencode.db)
#
# Uso:
#   timeline-completo                → historial de la sesión actual
#   timeline-completo <sesión_id>    → historial de una sesión concreta
#   timeline-completo --sesiones     → listar todas las sesiones
#   timeline-completo --buscar <txt> → buscar peticiones que contengan texto
#
# NOTA: el timeline de la TUI solo muestra las últimas ~6 peticiones
# (límite hardcodeado en OpenCode). Este script lee TODOS los mensajes
# directamente de opencode.db.
# ============================================================

DB="$HOME/.local/share/opencode/opencode.db"

if [ ! -f "$DB" ]; then
    echo "❌ No se encontró la base de datos en $DB"
    exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "❌ sqlite3 no está instalado"
    exit 1
fi

# ─── Listar sesiones ───
if [ "$1" = "--sesiones" ]; then
    echo "=== SESIONES DE OPENCODE ==="
    sqlite3 -separator " | " "$DB" "
    SELECT substr(id, 1, 20) || '...' || '  ' ||
           datetime(time_created/1000, 'unixepoch', 'localtime') || '  ' ||
           title
    FROM session ORDER BY time_created DESC LIMIT 20;" 2>/dev/null
    exit 0
fi

# ─── Buscar texto ───
if [ "$1" = "--buscar" ]; then
    if [ -z "$2" ]; then
        echo "Uso: timeline-completo --buscar <texto>"
        exit 1
    fi
    echo "=== PETICIONES QUE CONTIENEN: $2 ==="
    sqlite3 -separator " | " "$DB" "
    SELECT datetime(m.time_created/1000, 'unixepoch', 'localtime') || '  ' ||
           substr(replace(replace(json_extract(p.data, '\$.text'), char(10), ' '), char(13), ' '), 1, 80)
    FROM message m
    JOIN part p ON p.message_id = m.id
    WHERE json_extract(m.data, '\$.role') = 'user'
      AND json_extract(p.data, '\$.type') = 'text'
      AND json_extract(p.data, '\$.text') LIKE '%$2%'
    ORDER BY m.time_created ASC;" 2>/dev/null
    exit 0
fi

# ─── Sesión actual (por defecto) o la indicada ───
SES="${1:-$(sqlite3 "$DB" "SELECT id FROM session ORDER BY time_created DESC LIMIT 1;" 2>/dev/null)}"

echo "=== HISTORIAL COMPLETO DE LA SESIÓN ==="
echo "Sesión: $SES"
echo ""
sqlite3 -separator " | " "$DB" "
SELECT printf('%02d', ROW_NUMBER() OVER (ORDER BY m.time_created)) || '. ' ||
       datetime(m.time_created/1000, 'unixepoch', 'localtime') || '  ' ||
       substr(replace(replace(json_extract(p.data, '\$.text'), char(10), ' '), char(13), ' '), 1, 70)
FROM message m
JOIN part p ON p.message_id = m.id
WHERE m.session_id = '$SES' AND json_extract(m.data, '\$.role') = 'user'
  AND json_extract(p.data, '\$.type') = 'text' AND json_extract(p.data, '\$.text') IS NOT NULL
ORDER BY m.time_created ASC;" 2>/dev/null
TIMELINE_SHEOF
chmod +x "$LOCAL_BIN/timeline-completo"
info "timeline-completo creado en ~/.local/bin (historial completo de sesiones)"

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
BACKUP_DIR="${CONFIG_BACKUP}/backups/opencode"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="opencode-backup-${DATE}"

BACKUP_ROOT="${BACKUP_DIR}/${BACKUP_NAME}"

echo "=== Backup OpenCode - $(date '+%d/%m/%Y %H:%M') ==="

# ─── 0. VERIFICACIÓN OBLIGATORIA DEL SETUP (AGENTS.md) ───
# El setup-opencode-completo.sh debe estar CORRECTO y COMPLETO antes
# de generar el backup. Si la verificación falla, se ABORTA.
echo "🔍 Verificando setup-opencode-completo.sh (check-setup-completo.sh)..."
if [ -f "$HOME/.config/opencode/check-setup-completo.sh" ]; then
    if bash "$HOME/.config/opencode/check-setup-completo.sh"; then
        echo "✅ Setup verificado correctamente. Continuando backup..."
    else
        echo ""
        echo "❌❌❌ VERIFICACIÓN DEL SETUP FALLIDA ❌❌❌"
        echo "   El setup-opencode-completo.sh no está correcto/completo."
        echo "   Corrige el setup ANTES de hacer el backup (ver AGENTS.md)."
        echo "   El backup se ABORTA para no guardar un setup defectuoso."
        exit 1
    fi
else
    echo "⚠️ check-setup-completo.sh no encontrado. ¿Se instaló correctamente?"
fi

mkdir -p "${BACKUP_DIR}" "${BACKUP_ROOT}"

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

# ─── 1b. Incluir respaldo OnlyOffice-IA en el tarball ───
if [ -d "${CONFIG_BACKUP}/data/onlyoffice-ai" ]; then
    mkdir -p "${BACKUP_ROOT}/data"
    cp -r "${CONFIG_BACKUP}/data/onlyoffice-ai" "${BACKUP_ROOT}/data/onlyoffice-ai"
    echo "   ✅ Respaldo OnlyOffice-IA incluido en el backup"
fi

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

# Restaurar respaldo OnlyOffice-IA en Config/opencode/data/
if [ -d "${SOURCE_DIR}/data/onlyoffice-ai" ]; then
    mkdir -p "/home/antonio/Config/opencode/data"
    cp -r "${SOURCE_DIR}/data/onlyoffice-ai" "/home/antonio/Config/opencode/data/onlyoffice-ai"
    echo "✅ Respaldo OnlyOffice-IA restaurado en Config/opencode/data/"
fi

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
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" .
cd - > /dev/null

BACKUP_SIZE=$(ls -lh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" | awk '{print $5}')
echo "   ✅ Tarball creado (${BACKUP_SIZE}): ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# ─── 5. Limpiar directorio temporal del backup
echo ""
echo "🧹 Limpiando directorio temporal..."
rm -rf "${BACKUP_ROOT}"

# ─── 5. Retención: borrar tarballs con más de 30 días (LOG_RETENTION_DAYS) ───
RETENTION_DAYS="${LOG_RETENTION_DAYS:-30}"
echo ""
echo "🧹 Aplicando retención (${RETENTION_DAYS} días) en ${BACKUP_DIR}..."
OLD_TARBALLS=$(find "${BACKUP_DIR}" -maxdepth 1 -name 'opencode-*.tar.gz' -mtime +"${RETENTION_DAYS}" 2>/dev/null | wc -l)
if [ "${OLD_TARBALLS}" -gt 0 ]; then
    find "${BACKUP_DIR}" -maxdepth 1 -name 'opencode-*.tar.gz' -mtime +"${RETENTION_DAYS}" -delete 2>/dev/null || true
    echo "   🗑️  ${OLD_TARBALLS} tarballs antiguos eliminados (más de ${RETENTION_DAYS} días)"
else
    echo "   ✅ No hay tarballs antiguos que eliminar"
fi

# ─── 6. Poda diaria: conservar solo el ÚLTIMO tarball de cada día ───
echo "🗂️  Podando duplicados del mismo día (se conserva el último)..."
PODADOS=0
for f in "${BACKUP_DIR}"/opencode-*_*.tar.gz "${BACKUP_DIR}"/opencode-*-*.tar.gz; do
    [ -f "$f" ] || continue
    DAY=$(basename "$f" | grep -oE '[0-9]{8}' | head -1 || true)
    [ -n "$DAY" ] || continue
    LAST=$(find "${BACKUP_DIR}" -maxdepth 1 -name "opencode-*-${DAY}-*.tar.gz" 2>/dev/null | sort | tail -1)
    if [ -n "$LAST" ] && [ "$f" != "$LAST" ]; then
        rm -f "$f"
        PODADOS=$((PODADOS+1))
    fi
done
echo "   🗑️  ${PODADOS} duplicados del mismo día eliminados"

echo ""
echo "✅ Backup completado!"
echo ""
echo "Ubicación: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
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

# ---- 0. Setup symlink libggml-cpu.so.0 (whisper-cli lo necesita) ----
setup_ggml_cpu_symlink() {
  local BIN_DIR="${SHARE_DIR}/whisper-cpp/bin"
  local VARIANT=""
  # Elegir la mejor variante de CPU disponible (Ryzen 9 7900 = Zen 4)
  for cand in zen4 alderlake skylakex icelake haswell cascadelake x64 sse42; do
    if [ -f "${BIN_DIR}/libggml-cpu-${cand}.so" ]; then
      VARIANT="${cand}"
      break
    fi
  done
  if [ -n "${VARIANT}" ] && [ -f "${BIN_DIR}/libggml-cpu-${VARIANT}.so" ]; then
    ln -sf "libggml-cpu-${VARIANT}.so" "${BIN_DIR}/libggml-cpu.so.0"
    ln -sf "libggml-cpu-${VARIANT}.so" "${BIN_DIR}/libggml-cpu.so"
    log "Symlink libggml-cpu.so.0 -> libggml-cpu-${VARIANT}.so"
  else
    warn "No se encontró variante libggml-cpu-*.so para crear el symlink"
  fi
}

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
      cp -dP "${WHISPER_TMP}"/whisper-src/build/bin/libggml*.so* "${SHARE_DIR}/whisper-cpp/bin/" 2>/dev/null || true
      setup_ggml_cpu_symlink
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
    setup_ggml_cpu_symlink
    rm -rf "${WHISPER_TMP}"
  fi
  cat > "${LOCAL_BIN}/whisper-cli" << 'WHISPEREOF'
#!/bin/bash
# Wrapper whisper-cli con CUDA: añade el directorio local a LD_LIBRARY_PATH
export LD_LIBRARY_PATH="/home/antonio/.local/share/whisper-cpp/bin:${LD_LIBRARY_PATH}"
exec /home/antonio/.local/share/whisper-cpp/bin/whisper-cli "$@"
WHISPEREOF
  chmod +x "${LOCAL_BIN}/whisper-cli"
  # Verificación: lanzar whisper-cli (debe resolver libggml-cpu.so.0)
  if "${LOCAL_BIN}/whisper-cli" --help >/dev/null 2>&1; then
    log "whisper-cli operativo (GPU/CUDA si hay nvidia)"
  else
    warn "whisper-cli no arranca: comprueba libggml*.so en ${SHARE_DIR}/whisper-cpp/bin"
  fi
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

cat > "\$DIR_CONFIG/hardware-info.md" << 'HWINFOEOF'
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
| Uso CUDA | LM Studio (Qwen 3.5-9B) y whisper-cpp (transcripción ~0,85 s) |

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

# OCV - OpenCode con voz (pasa por el lanzador que verifica LM Studio)
function ocv() {
    script -q -f -c "REAL_OPENCODE=/usr/bin/opencode /home/antonio/.local/bin/opencode $*" /dev/null 2>&1
}

# Alias para perfiles local/cloud
alias opencode-local="bash ~/.config/opencode/switch-mcp-profile.sh local && opencode"
alias opencode-cloud="bash ~/.config/opencode/switch-mcp-profile.sh cloud && opencode"
alias ocv-local="bash ~/.config/opencode/switch-mcp-profile.sh local && ocv"
alias ocv-cloud="bash ~/.config/opencode/switch-mcp-profile.sh cloud && ocv"
export OPENCODE_ENABLE_EXA=1
export LMSTUDIO_API_KEY="lm-studio"
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

# ═══════════════════════════════════════════════════════════
# PASO 19: OnlyOffice Desktop Editors + integración IA con OpenCode
# ═══════════════════════════════════════════════════════════
echo "--- 19/19: Instalando OnlyOffice e integrando IA ---"

# 19.1 Instalar OnlyOffice Desktop Editors desde pacman (repos extra)
if ! command -v onlyoffice-desktopeditors &>/dev/null; then
    info "Instalando onlyoffice-desktopeditors desde pacman..."
    if ! pkexec pacman -S --needed --noconfirm onlyoffice-desktopeditors; then
        error "No se pudo instalar OnlyOffice. Ejecuta manualmente: pkexec pacman -S onlyoffice-desktopeditors"
    else
        info "OnlyOffice instalado correctamente"
    fi
else
    info "OnlyOffice ya está instalado"
fi

# 19.2 Preparar el script de inyección del proveedor IA
mkdir -p "$DIR_CONFIG/data/onlyoffice-ai"
cat > "$DIR_CONFIG/data/onlyoffice-ai/inject-provider.py" << 'INJECTEOF'
#!/usr/bin/env python3
"""
inject-provider.py — Restaura el proveedor "OpenCode Local" (opencode → OnlyOffice AI)

Inyecta en el LevelDB del localStorage del plugin IA de OnlyOffice Desktop Editors
el proveedor compatible con la API de OpenAI que apunta a opencode local (puerto 4001).

Uso:
    python3 inject-provider.py            # inyecta (requiere OnlyOffice cerrado)
    python3 inject-provider.py --check    # solo verifica el estado actual

La configuración original extraída está en: onlyoffice-ai-config.json
"""
import struct, os, json, sys

LVL = os.path.expanduser('~/.local/share/onlyoffice/desktopeditors/data/cache/Local Storage/leveldb')
LOG = os.path.join(LVL, '000003.log')
KEY = b'_onlyoffice://plugin\x00\x01onlyoffice_ai_plugin_storage_key'
PROVIDER_NAME = "OpenCode Local"
MODEL_ID = "models-qwen3.5-9b"
BASE_URL = "http://localhost:4001/v1"
API_KEY = "lm-studio"

# ── CRC32C (polinomio 0x82F63B78) ─────────────────────────────
def _crc32c_table():
    poly = 0x82F63B78
    return [((lambda c: c if c <= 0xFFFFFFFF else c & 0xFFFFFFFF)(
                (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                    (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                        (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                            (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                                (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                                    (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(
                                        (lambda c: (c >> 1) ^ poly if c & 1 else c >> 1)(i)
                                    )))))) )) for i in range(256)]

_TABLE = _crc32c_table()

def crc32c(data, crc=0):
    crc ^= 0xffffffff
    for b in data:
        crc = _TABLE[(crc ^ b) & 0xff] ^ (crc >> 8)
    return (crc ^ 0xffffffff) & 0xffffffff

def mask(crc):
    return (((crc >> 15) | (crc << 17)) + 0xa282ead8) & 0xffffffff

# ── Lectura de records del log ─────────────────────────────────
def _read_varint(buf, off):
    result, shift = 0, 0
    while True:
        b = buf[off]; off += 1
        result |= (b & 0x7f) << shift
        if not (b & 0x80): break
        shift += 7
    return result, off

def parse_log(path):
    data = open(path, 'rb').read()
    off, entries = 0, []
    while off + 7 <= len(data):
        checksum, length, rtype = struct.unpack_from('<IHB', data, off)
        off += 7
        if off + length > len(data): break
        payload = data[off:off+length]; off += length
        if rtype != 1 or len(payload) < 12: continue
        real = mask(crc32c(b'\x01' + payload))
        seq, count = struct.unpack_from('<QI', payload, 0)
        p = 12
        for _ in range(count):
            if p >= len(payload): break
            et = payload[p]; p += 1
            klen, p = _read_varint(payload, p)
            key = payload[p:p+klen]; p += klen
            if et == 1:
                vlen, p = _read_varint(payload, p)
                val = payload[p:p+vlen]; p += vlen
            else:
                val = b'<DEL>'
            entries.append({'seq': seq, 'type': 'put' if et == 1 else 'del',
                            'key': key, 'val': val, 'cksum_ok': (real == checksum)})
    return entries

# ── Escritura ───────────────────────────────────────────────────
def _enc_varint(n):
    out = b''
    while True:
        b = n & 0x7f; n >>= 7
        out += bytes([b | 0x80]) if n else bytes([b])
        if not n: break
    return out

def make_record(seq, key, value):
    payload = struct.pack('<QI', seq, 1) + b'\x01'
    payload += _enc_varint(len(key)) + key
    payload += _enc_varint(len(value)) + value
    return struct.pack('<IHB', mask(crc32c(b'\x01' + payload)), len(payload), 1) + payload

def get_current():
    best = None
    if os.path.exists(LOG):
        for e in parse_log(LOG):
            if e['key'] == KEY and e['type'] == 'put':
                if best is None or e['seq'] > best['seq']:
                    best = e
    return best

def ensure_dirs():
    """Crea los directorios del perfil de OnlyOffice si no existen (instalación limpia)."""
    os.makedirs(LVL, exist_ok=True)

def main():
    check_only = '--check' in sys.argv
    ensure_dirs()
    cur = get_current()

    if cur:
        cfg = json.loads(cur['val'][1:])
        prov = cfg['providers'].get(PROVIDER_NAME)
        print(f"ℹ️  Configuración actual: version={cfg.get('version')}, providers={len(cfg['providers'])}")
        if prov:
            print(f"✅ Proveedor '{PROVIDER_NAME}' YA presente -> {prov['url']}")
            models = [m['id'] for m in cfg.get('models', [])]
            print(f"   Modelos registrados: {models}")
            return 0
        if check_only:
            print(f"❌ Proveedor '{PROVIDER_NAME}' NO presente")
            return 1
        print(f"➕ Añadiendo proveedor '{PROVIDER_NAME}' a la configuración existente...")
    else:
        if check_only:
            print("❌ No hay configuración del plugin AI")
            return 1
        print("➕ No había configuración previa; creándola desde cero...")
        cfg = {"version": 4, "providers": {}, "models": [], "customProviders": {}}

    cfg['providers'][PROVIDER_NAME] = {
        "name": PROVIDER_NAME, "url": BASE_URL, "key": API_KEY,
        "models": [{"id": MODEL_ID, "object": "model", "created": 1780000000,
                    "owned_by": "lmstudio", "name": MODEL_ID,
                    "endpoints": [1], "options": {}}]
    }
    exists = any(m.get('id') == MODEL_ID and m.get('provider') == PROVIDER_NAME for m in cfg.get('models', []))
    if not exists:
        cfg.setdefault('models', []).append({
            "capabilities": 511, "provider": PROVIDER_NAME,
            "name": f"{PROVIDER_NAME} [{MODEL_ID}]", "id": MODEL_ID
        })

    new_value = b'\x01' + json.dumps(cfg, ensure_ascii=False).encode('utf-8')
    max_seq = max((e['seq'] for e in parse_log(LOG)), default=0) if os.path.exists(LOG) else 0
    seq = max_seq + 10

    with open(LOG, 'ab') as f:
        f.write(make_record(seq, KEY, new_value))
    print(f"✅ Record añadido al LevelDB (seq={seq})")

    # Verificar
    for e in parse_log(LOG):
        if e['key'] == KEY and e['seq'] == seq and e['type'] == 'put':
            ok = e['cksum_ok'] and e['val'] == new_value
            cfg2 = json.loads(e['val'][1:])
            print(f"✅ Verificado: cksum={'OK' if e['cksum_ok'] else 'FAIL'}, "
                  f"'{PROVIDER_NAME}' -> {cfg2['providers'][PROVIDER_NAME]['url']}")
            print(f"   Modelos: {[m['id'] for m in cfg2['models']]}")
            return 0 if ok else 1
    print("❌ Verificación fallida")
    return 1

if __name__ == '__main__':
    sys.exit(main())
INJECTEOF
chmod +x "$DIR_CONFIG/data/onlyoffice-ai/inject-provider.py"

# 19.3 Documentación de la integración
cat > "$DIR_CONFIG/data/onlyoffice-ai/ONLYOFFICE-AI-OPENCODE.md" << 'MDEOF'
# 🤖 OnlyOffice IA + OpenCode Local (proveedor OpenAI-compatible)

> **Fecha:** 09/08/2026
> **Autor:** Antonio (configurado por OpenCode)
> **Ubicación del backup:** `~/Config/opencode/data/onlyoffice-ai/`

---

## 📌 Resumen

Integración del **plugin IA de ONLYOFFICE Desktop Editors** con **opencode local**
(modelo Qwen 3.5 Q6_K) usando el endpoint OpenAI-compatible que opencode expone
a través de su proxy en el puerto **4001**.

De esta forma, el asistente de IA de OnlyOffice (chat, resumen, traducción,
análisis de texto, ayuda con código...) usa el modelo local, **sin depender de
servicios en la nube ni enviar datos fuera del equipo**.

---

## 🔧 Datos técnicos

| Parámetro | Valor |
|---|---|
| **Proveedor (nombre)** | `OpenCode Local` |
| **URL base** | `http://localhost:4001/v1` |
| **Modelo** | `models-qwen3.5-9b` |
| **API key** | `lm-studio` (cualquiera; el proxy no la valida) |
| **Capacidades** | 511 (todas: chat, resumen, traducción, análisis, código, etc.) |
| **Aplicación** | ONLYOFFICE Desktop Editors |
| **Plugin IA** | `asc.{9DC93CDB-B576-4F0C-B55E-FCC9C48DD007}` (versión 3.2.2) |

### Arquitectura

```
OnlyOffice (plugin IA)
        │  peticiones OpenAI-compatible
        ▼
http://localhost:4001/v1  ← lmstudio-proxy.py (proxy opencode)
        │  reenvía
        ▼
http://localhost:1234     ← LM Studio server (modelo Qwen 3.5 Q6_K)
```

---

## 📋 Pasos seguidos (configuración realizada)

### 1. Verificación del backend de opencode

Comprobado que el proxy responde y el modelo está cargado:

```bash
curl -s http://localhost:4001/v1/models          # → lista modelos (OK)
curl -s http://localhost:4001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"models-qwen3.5-9b","messages":[{"role":"user","content":"di hola"}]}'
# → {"choices":[{"message":{"content":"¡Hola!"}}]}  (OK)
```

### 2. Localización del almacenamiento del plugin IA

El plugin IA guarda su configuración en el `localStorage` interno de OnlyOffice,
que en Linux se encuentra en un **LevelDB**:

```
~/.local/share/onlyoffice/desktopeditors/data/cache/Local Storage/leveldb/000003.log
```

- **Clave:** `_onlyoffice://plugin\x00\x01onlyoffice_ai_plugin_storage_key`
- **Valor:** `\x01` + JSON (el `\x01` es el marcador de codificación UTF-8 de Chromium)

### 3. Backup de seguridad previo

Antes de tocar nada se copió el almacenamiento completo:

```bash
cp -r ~/.local/share/onlyoffice/desktopeditors/data/cache/Local\ Storage/ \
      ~/LocalStorage-backup-<fecha>/
```

### 4. Análisis del formato LevelDB

Se escribió un parser en Python (sin dependencias externas) para leer los
records del log de LevelDB:
- Checksum **CRC32C** enmascarado (`masked crc32c + 0xa282ead8`)
- Cabecera: checksum(4) + longitud(2) + tipo(1)
- Payload: WriteBatch con `sequence(8) + count(4) + entradas(key/value con varint32)`

### 5. Inyección del proveedor

Se añadió un **nuevo record** (`Put`) al final del log con una `sequence` mayor
que las existentes (el último `Put` de una clave es el que gana al abrir):

```json
"OpenCode Local": {
  "name": "OpenCode Local",
  "url": "http://localhost:4001/v1",
  "key": "lm-studio",
  "models": [{ "id": "models-qwen3.5-9b", "endpoints": [1], ... }]
}
```

Y el modelo registrado para todas las tareas:

```json
{
  "capabilities": 511,
  "provider": "OpenCode Local",
  "name": "OpenCode Local [models-qwen3.5-9b]",
  "id": "models-qwen3.5-9b"
}
```

### 6. Verificación final

- Checksum del record nuevo: **OK**
- Relectura del log tras abrir OnlyOffice: la configuración persiste ✅
- Resultado: el proveedor aparece en **IA → Ajustes → Editar modelos de IA**

---

## 🖱️ Método alternativo (manual, sin tocar LevelDB)

Si en el futuro se quiere añadir otro proveedor por la interfaz:

1. Abrir un documento en OnlyOffice
2. Pestaña **IA** → **Ajustes** → **Editar modelos de IA**
3. **+** → rellenar URL `http://localhost:4001/v1`, modelo `models-qwen3.5-9b`,
   API key `lm-studio`
4. Marcar las tareas deseadas → **OK**

### Archivo de proveedor personalizado (JS)

También se puede subir un archivo JS (método oficial de ONLYOFFICE para
proveedores personalizados) — ver `opencode-provider.js` en esta carpeta:

```js
"use strict";

class Provider extends AI.Provider {
    constructor() {
        super("OpenCode Local", "http://localhost:4001", "lm-studio", "v1");
    }
}
```

Ruta de subida: **IA → Ajustes → Editar modelos de IA → + → Custom providers → +**

---

## ♻️ Restauración de esta configuración

Hay **tres niveles** de restauración, de más a menos fino:

### Opción A — Script de inyección (recomendada)

```bash
# Requisito: cerrar OnlyOffice primero
python3 ~/Config/opencode/data/onlyoffice-ai/inject-provider.py
# Comprobar sin modificar:
python3 ~/Config/opencode/data/onlyoffice-ai/inject-provider.py --check
```

Reconstruye el proveedor y el modelo sobre la configuración existente o la crea
desde cero si no hay ninguna.

### Opción B — Copia del LevelDB completo (snapshot)

Restaurar el directorio completo del snapshot:

```bash
# SoloOffice cerrado:
cp -r ~/Config/opencode/data/onlyoffice-ai/localstorage-snapshot/leveldb/* \
      ~/.local/share/onlyoffice/desktopeditors/data/cache/Local\ Storage/leveldb/
```

⚠️ Restaura también el resto de claves del localStorage de esa fecha.

### Opción C — Configuración JSON legible

El archivo `onlyoffice-ai-config.json` contiene la configuración completa
(15 proveedores + modelo OpenCode Local) por si se necesita inspeccionar,
editar o migrar.

---

## 🚀 Instalación automática (setup-opencode-completo.sh)

El instalador completo `setup-opencode-completo.sh` incluye el **PASO 19**
que automatiza todo este proceso:

1. **Instala** OnlyOffice Desktop Editors desde **pacman** (repos extra):
   `pkexec pacman -S --needed --noconfirm onlyoffice-desktopeditors`
2. **Embe** el script `inject-provider.py` y este documento en
   `~/.config/opencode/data/onlyoffice-ai/`
3. **Inicializa el perfil** de OnlyOffice (primera ejecución breve) si no
   existe el almacenamiento del plugin IA
4. **Inyecta el proveedor** "OpenCode Local" automáticamente y lo verifica
   con `--check`

Al reinstalar el sistema desde cero, basta con ejecutar el setup y la
integración IA de OnlyOffice queda lista sin intervención manual.

---

## 📁 Archivos incluidos en este backup

| Archivo | Descripción |
|---|---|
| `ONLYOFFICE-AI-OPENCODE.md` | Este documento |
| `onlyoffice-ai-config.json` | Configuración completa del plugin IA (legible) |
| `inject-provider.py` | Script de restauración del proveedor (autocontenido) |
| `opencode-provider.js` | Archivo JS del proveedor (método manual oficial) |
| `localstorage-snapshot/` | Snapshot del LevelDB del localStorage (estado exacto) |

---

## ⚠️ Consideraciones

- **Modelo en VRAM:** para que OnlyOffice responda, el modelo debe estar cargado
  (arrancar con `opencode` u `ocv`, o `bash ~/.config/opencode/start-lmstudio.sh`).
  Si no, LM Studio devuelve error de modelo no cargado.
- **Solo local:** el proxy escucha en `127.0.0.1:4001`, por lo que esta
  configuración funciona únicamente en este equipo.
- **Document Server (Docker):** si se usara OnlyOffice en Docker, habría que:
  1. Hacer que el proxy escuche en `0.0.0.0`
  2. Usar `http://host.docker.internal:4001/v1` (o IP del host) como URL
  3. Añadir cabeceras CORS al proxy (`Access-Control-Allow-Origin`)
- **Privacidad:** al ser 100% local, los documentos no salen del equipo. 🔒
- **Seguridad:** el backup de esta carpeta debe incluirse en cualquier copia
  general de `~/Config/opencode/`.
MDEOF

# 19.4 Inicializar el perfil de OnlyOffice (primera ejecución) si hace falta
OA_LVL="$HOME/.local/share/onlyoffice/desktopeditors/data/cache/Local Storage/leveldb"
mkdir -p "$OA_LVL"
if ! grep -q "onlyoffice_ai_plugin_storage_key" "$OA_LVL/000003.log" 2>/dev/null; then
    info "Primera ejecución de OnlyOffice para inicializar el perfil IA..."
    setsid onlyoffice-desktopeditors &>/dev/null &
    sleep 25
    pkill -f onlyoffice-desktopeditors 2>/dev/null || true
    sleep 2
fi

# 19.5 Inyectar el proveedor OpenCode Local (Qwen local en :4001)
info "Configurando proveedor IA 'OpenCode Local' (http://localhost:4001/v1)..."
python3 "$DIR_CONFIG/data/onlyoffice-ai/inject-provider.py" || true
if python3 "$DIR_CONFIG/data/onlyoffice-ai/inject-provider.py" --check; then
    info "✅ Integración IA OnlyOffice + OpenCode lista"
else
    aviso "La integración IA no se pudo verificar; revísala manualmente tras abrir OnlyOffice"
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

