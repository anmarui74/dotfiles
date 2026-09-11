# 🪟 OpenCode en Windows — Backup, instalador y documentación

**Backup completo de la configuración de OpenCode para Windows + instalador desde cero.**

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

> 🖥️ Equipo: AMD Ryzen 9 7900 · NVIDIA RTX 4070 Ti SUPER (16 GB) · 63,1 GB RAM · Windows
> Config activa: `C:\Users\evo01\.config\opencode\`

---

## 📑 Índice

1. [Qué es](#qué-es)
2. [Estructura de carpetas](#estructura-de-carpetas)
3. [Instalación desde cero](#instalación-desde-cero)
4. [Lanzadores](#lanzadores)
5. [Sincronización y backup](#sincronización-y-backup)
6. [Documentación](#documentación)

---

## Qué es

Esta carpeta (`D:\Linux\Config\opencode-win\`) es la **copia de seguridad** de la
configuración de OpenCode en Windows, junto con su **instalador automático** y la
**documentación adaptada**. Es el equivalente Windows de `~/Config/opencode/` de Linux.

Incluye:

- ✅ Configuración real de OpenCode (perfiles, proxy, scripts)
- ✅ Instalador que deja todo operativo **desde cero**
- ✅ Manuales adaptados de Linux a Windows
- ✅ Scripts de utilidad portados (timeline, hardware, NVIDIA, backup)

---

## Estructura de carpetas

```text
D:\Linux\Config\opencode-win\
├── instalar-opencode-win.ps1   ← INSTALADOR AUTOMÁTICO (desde cero)
├── AGENTS.md                   ← Reglas de OpenCode adaptadas a Windows
├── README.md                   ← Este archivo
├── config\                     ← Configuración a desplegar en C:\Users\<usuario>\.config\opencode\
│   ├── opencode.jsonc          ← Perfil global (cloud por defecto)
│   ├── opencode-local.json     ← Perfil local (LM Studio + proxy 4001)
│   ├── tui.json                ← Keybinds + plugin throughput
│   ├── AGENTS.md               ← Reglas (idéntico al de la raíz)
│   ├── lmstudio-proxy.py       ← Proxy 4001 → LM Studio 1234 (métricas)
│   ├── start-lmstudio.ps1      ← Arranque portable (servidor + modelo + proxy)
│   ├── package.json
│   └── prompts\read-agents.txt
├── perfil\
│   └── Microsoft.PowerShell_profile.ps1   ← Funciones ocv / ocv-cloud / ocv-status
├── scripts\                    ← Utilidades portadas a PowerShell
│   ├── timeline-completo.ps1   ← Historial completo de peticiones (SQLite vía Python)
│   ├── hardware-query.ps1      ← Consulta de hardware (CIM)
│   ├── check-nvidia-whitelist.ps1  ← Verificación whitelist NVIDIA
│   ├── sync-opencode.ps1       ← Sincroniza config activa → esta carpeta
│   └── backup-opencode.ps1     ← Backup del grafo de memoria + sync
├── documentacion\              ← Manuales adaptados de Linux a Windows
│   └── README.md               ← Índice de documentación
└── data\
    └── memory\                 ← Backups del grafo de memoria (mcp-memory-backup-*.jsonl)
```

---

## Instalación desde cero

El instalador `instalar-opencode-win.ps1` instala y configura **todo** lo necesario:

| Paso | Qué hace |
|------|----------|
| 1 | Requisitos vía **winget**: Node.js LTS, Python 3.14, LM Studio, Git |
| 2 | **OpenCode** global vía npm (`opencode-ai`) |
| 3 | Despliega la **config** en `%USERPROFILE%\.config\opencode\` |
| 4 | Instala el **perfil de PowerShell** con los lanzadores |
| 5 | Fija la **política de ejecución** `RemoteSigned` (CurrentUser) |
| 6 | Coloca el **modelo Qwen3.8-9B** en LM Studio (copia o enlace) |
| 7 | Arranca LM Studio + modelo + proxy y verifica |
| 8 | (Opcional) Crea tareas programadas (`-WithTasks`) |
| 9 | Verificación final de todos los componentes |

### Uso

```powershell
# Desde una ventana normal (se auto-eleva con UAC cuando hace falta)
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\instalar-opencode-win.ps1"

# Con opciones
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\instalar-opencode-win.ps1" `
  -ModelSource "D:\Linux\modelos_ia\Qwen3.8-9B-Q6_K.gguf" -WithTasks -Unattended

# Si los requisitos ya están instalados (solo despliega config + perfil)
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\instalar-opencode-win.ps1" -SkipPrereqs
```

> ⚠️ El instalador es **idempotente**: si algo ya está instalado, lo detecta y sigue.
> El modelo por defecto se copia desde `D:\Linux\modelos_ia\Qwen3.8-9B-Q6_K.gguf`
> (usa `-ModelSource` para cambiarlo).

---

## Lanzadores

| Comando | Qué hace | Config usada |
|---------|----------|--------------|
| `ocv` | Arranca LM Studio + modelo + proxy y abre OpenCode local (todos los MCPs) | `opencode-local.json` |
| `ocv-local` | Igual, pero con el perfil **local mínimo** (solo `fetch`, `filesystem`, `memory`) | `opencode-local-min.json` |
| `ocv-cloud` | Abre OpenCode en modo cloud (sin LM Studio), todos los MCPs | `opencode.jsonc` (global) |
| `ocv-status` | Muestra estado de LM Studio, modelo en VRAM y proxy | — |

Los comandos están definidos en el **perfil de PowerShell**. Úsalos en una ventana
**nueva** de PowerShell (el perfil se carga al abrirla).

---

## Sincronización y backup

```powershell
# Copia el grafo de memoria (memory.jsonl) con fecha + sincroniza la config activa
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\scripts\backup-opencode.ps1"

# Solo sincroniza la config activa → esta carpeta
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\scripts\sync-opencode.ps1"
```

Los backups del grafo se guardan en `data\memory\mcp-memory-backup-<fecha>.jsonl`
con retención de **30 días**.

---

## Documentación

Todos los manuales están en [documentacion/](documentacion/README.md), adaptados de
Linux a Windows. Incluyen los 12 documentos originales con las secciones que no
aplican en Windows marcadas como `⚠️ No aplica en Windows` y su alternativa.

---

> 📁 Rutas clave: `instalar-opencode-win.ps1` · `config\` · `scripts\` · `documentacion\`