# 🛟 Playbook de Recuperación de OpenCode (Windows)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| 🛟 Recuperación | 10/09/2026 · rev. 10/09/2026 | Antonio |

> Procedimiento paso a paso para restaurar OpenCode desde un backup o una
> reinstalación desde limpio, recuperar el grafo de memoria y re-sincronizar
> todo el sistema **en Windows (PowerShell 5.1)**.

> ⚠️ **Nota Windows:** todos los comandos de este playbook son de
> **Windows PowerShell 5.1**. No existen `bash`, `zsh`, `systemd`, `sudo` ni
> `pkexec`. La elevación se hace con **UAC** y la automatización periódica con el
> **Programador de tareas** de Windows.

---

## 📑 Índice

1. [Antes de empezar](#antes-de-empezar)
2. [Escenario A: restaurar el grafo de memoria (pérdida/corrupción)](#escenario-a-restaurar-el-grafo-de-memoria)
3. [Escenario B: reinstalación desde limpio](#escenario-b-reinstalación-desde-limpio)
4. [Escenario C: recuperar solo un archivo de configuración](#escenario-c-recuperar-solo-un-archivo)
5. [Re-sincronización y verificación](#re-sincronización-y-verificación)
6. [Checklist de verificación final](#checklist-de-verificación-final)
7. [Soluciones a problemas comunes](#soluciones-a-problemas-comunes)

---

## Antes de empezar

### 🔑 Rutas clave

| Elemento | Ruta |
|----------|------|
| Config activa | `C:\Users\evo01\.config\opencode\` |
| Copia de seguridad | `D:\Linux\Config\opencode-win\` |
| Backups de OpenCode | `D:\Linux\Config\opencode-win\backups\opencode\` |
| Grafo de memoria (activo) | `C:\Users\evo01\.config\opencode\data\memory\memory.jsonl` |
| Grafo de memoria (backup) | `D:\Linux\Config\opencode-win\data\memory\mcp-memory-backup-*.jsonl` |
| Variables de entorno | `C:\Users\evo01\.config\opencode\.env` |
| Credenciales de proveedores LLM (NVIDIA, OpenCode GO) | `C:\Users\evo01\.local\share\opencode\auth.json` (backup en `credenciales\auth.json`) |
| Base de datos de sesiones | `C:\Users\evo01\.local\share\opencode\opencode.db` |
| Cache de plugins npm | `C:\Users\evo01\.cache\opencode\node_modules\` |
| Instalador completo | `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1` |

### ⏸️ Detener servicios antes de restaurar

> ⚠️ **No aplica en Windows:** `systemctl --user` no existe. La tarea
> programada de sincronización se detiene con el **Programador de tareas**:

```powershell
# Detener la tarea de sincronización (si existe)
Stop-ScheduledTask -TaskName "opencode-sync" -ErrorAction SilentlyContinue

# Detener el proxy local de LM Studio
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -like "*lmstudio-proxy*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# Detener OpenCode
Get-Process opencode -ErrorAction SilentlyContinue | Stop-Process -Force
```

> ⚠️ Detener la tarea evita que la sincronización automática interfiera
> mientras restauras archivos. Al terminar, vuelve a arrancarla.

---

## Escenario A: restaurar el grafo de memoria

Para cuando el grafo se pierde o corrompe (el servidor MCP memory no carga,
errores de entidades vacías, archivo dañado, etc.).

### Paso 1 — Localizar el backup más reciente

```powershell
Get-ChildItem "D:\Linux\Config\opencode-win\data\memory\mcp-memory-backup-*.jsonl" |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
```

Guarda la ruta resultante, por ejemplo:
`D:\Linux\Config\opencode-win\data\memory\mcp-memory-backup-20260905_0042.jsonl`

### Paso 2 — Hacer copia del grafo actual (por seguridad)

```powershell
Copy-Item "C:\Users\evo01\.config\opencode\data\memory\memory.jsonl" `
  "C:\Users\evo01\.config\opencode\data\memory\memory.jsonl.corrupto" -Force -ErrorAction SilentlyContinue
```

### Paso 3 — Copiar el backup a la ruta activa

```powershell
Copy-Item "D:\Linux\Config\opencode-win\data\memory\mcp-memory-backup-XXXX.jsonl" `
  "C:\Users\evo01\.config\opencode\data\memory\memory.jsonl" -Force
```

### Paso 4 — Verificar que el archivo es JSONL válido

```powershell
python -c "import json; [json.loads(l) for l in open(r'C:\Users\evo01\.config\opencode\data\memory\memory.jsonl', encoding='utf-8') if l.strip()]; print('grafo OK')"
```

> ⚠️ **Nota Windows:** no hay `python3`; el intérprete es
> `C:\Python314\python.exe` (invocable como `python`).

### Paso 5 — Reiniciar OpenCode

El servidor MCP memory lee `MEMORY_FILE_PATH` (vía `environment` en el bloque
`mcp.memory` de los perfiles JSON). Al abrir `ocv` se recarga el grafo
automáticamente.

---

## Escenario B: reinstalación desde limpio

Para cuando reinstalas OpenCode desde cero en Windows.

### Paso 1 — Localizar el backup más reciente

```powershell
Get-ChildItem "D:\Linux\Config\opencode-win\backups\opencode\*" |
  Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

### Paso 2 — Instalar OpenCode y dependencias base

> ⚠️ **No aplica en Windows:** no hay `pacman` ni `pkexec`. OpenCode se instala
> **globalmente por npm** (paquete `opencode-ai`). Node está en
> `C:\Program Files\nodejs\node.exe` y npm es la versión 11.19.0.

```powershell
# OpenCode (global por npm)
npm install -g opencode-ai

# Comprobar versiones
node --version
npm --version
```

### Paso 3 — Ejecutar el instalador completo

Ejecuta el instalador PowerShell que contiene toda la configuración del setup:

```powershell
powershell -ExecutionPolicy Bypass -File "D:\Linux\Config\opencode-win\instalar-opencode-win.ps1"
```

> ⚠️ Si el instalador necesita privilegios, aparecerá una ventana de **UAC**:
> acepta para continuar (equivale al `pkexec`/`sudo` de Linux).

> ⚠️ **No aplica en Windows:** el `setup-opencode-completo.sh` y el `restore.sh`
> (Bash + tarball `.tar.gz`) son de Linux. En Windows el instalador equivalente es
> `instalar-opencode-win.ps1`.

> 🔑 El instalador debe restaurar también `auth.json` (credenciales de NVIDIA
> `nvapi-*` y OpenCode GO `sk-*`) a `C:\Users\evo01\.local\share\opencode\auth.json`
> desde `credenciales\auth.json`. Sin este paso, los agentes en la nube no
> funcionan tras reinstalar.

### Paso 4 — Restaurar el grafo de memoria

Siguiendo el [Escenario A](#escenario-a-restaurar-el-grafo-de-memoria), copia
el backup del grafo a la ruta activa.

### Paso 5 — Restaurar la base de datos de sesiones (opcional)

```powershell
Copy-Item "D:\Linux\Config\opencode-win\backups\opencode\opencode-backup-XXXX.tar.gz" "$env:TEMP\" -Force
tar -xzf "$env:TEMP\opencode-backup-XXXX.tar.gz" -C "$env:TEMP" opencode.db
Copy-Item "$env:TEMP\opencode.db" "C:\Users\evo01\.local\share\opencode\opencode.db" -Force
```

> Este paso recupera el historial de sesiones y peticiones (TUI timeline).

> ⚠️ **Nota Windows:** `tar.exe` está incluido en Windows 10/11, por lo que se
> pueden extraer los tarballs `.tar.gz` sin instalar nada extra.

### Paso 6 — Re-sincronizar y verificar

Sigue la sección [Re-sincronización](#re-sincronización-y-verificación).

---

## Escenario C: recuperar solo un archivo

Para cuando solo necesitas un fichero concreto (un JSON, script o doc).

### Paso 1 — Extraer el archivo del backup

```powershell
tar -xzf "D:\Linux\Config\opencode-win\backups\opencode\opencode-backup-XXXX.tar.gz" `
  -C "$env:TEMP\opencode-restore" ".config/opencode/opencode.json"
```

### Paso 2 — Copiar a la ruta activa

```powershell
Copy-Item "$env:TEMP\opencode-restore\.config\opencode\opencode.json" `
  "C:\Users\evo01\.config\opencode\opencode.json" -Force
```

### Paso 3 — Re-sincronizar a la copia de seguridad

> ⚠️ **No aplica en Windows:** el script `sync-opencode.sh` es de Linux. Copia el
> archivo a la carpeta de respaldo con PowerShell:

```powershell
Copy-Item "C:\Users\evo01\.config\opencode\opencode.json" `
  "D:\Linux\Config\opencode-win\opencode.json" -Force
```

---

## Re-sincronización y verificación

Tras cualquier restauración, ejecuta en orden:

```powershell
# 1. Cargar variables de entorno en la sesión actual
Get-Content "C:\Users\evo01\.config\opencode\.env" | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
    Set-Item -Path "Env:$($matches[1].Trim())" -Value $matches[2].Trim()
  }
}

# 2. Inicializar/comprobar componentes (LM Studio, modelo, proxy, memoria)
ocv-status

# 3. Arrancar de nuevo la tarea programada de sincronización
Start-ScheduledTask -TaskName "opencode-sync" -ErrorAction SilentlyContinue

# 4. Regenerar la copia de seguridad
Copy-Item "C:\Users\evo01\.config\opencode\AGENTS.md" "D:\Linux\Config\opencode-win\AGENTS.md" -Force
```

> ⚠️ **No aplica en Windows:** los pasos originales usaban
> `set -a; source .env; set +a`, `init-opencode.sh`, `systemctl --user start` y
> `backup-opencode.sh`. En Windows se sustituyen por el fragmento PowerShell de
> arriba (variables de entorno, `ocv-status`, Programador de tareas y `Copy-Item`).

---

## Checklist de verificación final

| # | Comprobación | Comando (PowerShell) |
|---|--------------|----------------------|
| 1 | Servidor LM Studio en puerto 1234 | `Invoke-RestMethod http://localhost:1234/v1/models` |
| 2 | Proxy en puerto 4001 | `Invoke-RestMethod http://localhost:4001/v1/models` |
| 3 | Dashboard de métricas en 4200 | `Invoke-RestMethod http://localhost:4200/api/metrics` |
| 4 | Grafo de memoria cargado | `(Get-Content "C:\Users\evo01\.config\opencode\data\memory\memory.jsonl" \| Measure-Object -Line).Lines` |
| 5 | PWAs en el Escritorio | ⚠️ No aplica (en Linux: `ls /home/antonio/Escritorio/chrome-*.desktop`) |
| 6 | Tarea de sync activa | `Get-ScheduledTask -TaskName "opencode-sync"` |
| 7 | Variables de entorno | `$env:MEMORY_FILE_PATH` |
| 8 | Historial de sesiones | ⚠️ No aplica `timeline-completo`; usar el módulo `sqlite3` de Python |
| 9 | Plugin TUI de voz + throughput | abrir `ocv` y verificar barra lateral |

> ⚠️ **Nota Windows:** el punto 5 (PWAs `.desktop`) y el punto 8
> (`timeline-completo`, script Bash) no aplican tal cual en Windows.

---

## Soluciones a problemas comunes

| Problema | Causa probable | Solución |
|----------|----------------|----------|
| MCP memory no carga sus herramientas | Issue #39908 (draft-07 vs 2020-12) | Ver seguimiento-issue-memory.md; usar el grafo desde backups |
| Error `-32602` al añadir observaciones | Falta `entityName` en el array | Revisar AGENTS.md → Recordatorio MCP memory |
| El proxy no responde en 4001 | Proceso no arrancado | Arrancar con `ocv` (o el servidor LM Studio con `lms.exe`) |
| El dashboard no muestra datos | `ENABLE_METRICS=false` o proxy viejo | Verificar `.env` y que `lmstudio-proxy.py` sea la versión con métricas |
| TUI no muestra historial completo | Límite hardcodeado (~6 peticiones, PR #26861) | Consultar `opencode.db` con el módulo `sqlite3` de Python |
| Modelo de OpenCode Go requiere opt-in | Migración a hosting en China | Activar toggle en https://opencode.ai/workspace/wrk_01KWNJZHA9QS258DM0M2KY8PNZ/go |

> ⚠️ **No aplica en Windows:** la solución original del proxy
> (`bash ~/.config/opencode/start-lmstudio-server.sh`) y la de `timeline-completo`
> son de Linux.

---

> 📁 Este playbook vive en `C:\Users\evo01\.config\opencode\documentacion\07-playbook-recuperacion.md`
> (activo) y `D:\Linux\Config\opencode-win\documentacion\07-playbook-recuperacion.md`
> (backup). El instalador es `D:\Linux\Config\opencode-win\instalar-opencode-win.ps1`.
