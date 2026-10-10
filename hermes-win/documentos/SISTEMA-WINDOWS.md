# 🖥️ Inventario del equipo — vista desde Windows

| ⚙️ Estado | 📅 Captura | 👤 Usuario | 🖥️ Equipo |
|-----------|------------|------------|-----------|
| ✅ al día | 10/10/2026 (captura 17:20–17:45 · revisión 19:45) | Antonio | PC-ANTONIO (Windows 11 Pro) |

> Inventario del equipo **tal como lo ve Windows** (el gemelo de `SISTEMA-CACHYOS.md`, que lo mira
> desde Linux). Es documentación de referencia: describe el sistema, no es una pieza de la
> restauración, así que **no viaja en el ZIP** (aunque sí en la copia saneada de dotfiles).
>
> Escrito por el Hermes de Windows el 10/10/2026. Los valores dinámicos van marcados como
> *(instantánea)*.

---

## 1. Equipo y sistema

| Dato | Valor |
|---|---|
| **Placa** | Micro-Star International **MS-7E51** |
| **CPU** | AMD **Ryzen 9 7900** · 12 núcleos / 24 hilos |
| **RAM** | **63,1 GB** *(instantánea)* |
| **GPU** | NVIDIA **RTX 4070 Ti SUPER** (driver 32.0.16.1742) + iGPU AMD Radeon |
| **SO** | **Windows 11 Pro** build **26300**, 64 bits |
| **Arranque dual** | Con CachyOS Linux: Windows en `C:` (NVMe 1 TB), Linux en `F:` (NVMe 4 TB… ver `SISTEMA-CACHYOS.md`) |

---

## 2. Discos y letras desde Windows *(instantánea)*

| Letra | Etiqueta | Sistema | Salud | Libre / Total |
|---|---|---|---|---|
| `C:` | WINDOWS | NTFS | Healthy | 2209,3 / 3725 GB |
| `D:` | **SEAGATE** | NTFS | Healthy | 3015,3 / 3726 GB |
| `E:` | **TOSHIBA** | NTFS | Healthy | 3502 / 3725,9 GB |
| `F:` | cachyos | **Btrfs** (WinBtrfs) | Healthy | 282,6 / 929,5 GB |
| `H:` | CRUCIAL | **Btrfs** (WinBtrfs) | Healthy | 678,1 / 931,5 GB |

Discos físicos (4 + los dos del espejo):

| # | Modelo | GB | Notas |
|---|---|---|---|
| 0 | KINGSTON SFYRD4000G | 3726 | NVMe grande |
| 1 | KINGSTON SFYRS1000G | 932 | NVMe sistema (`C:`) |
| 2 | CT1000MX500SSD1 | 932 | SATA (Crucial, `H:`) |
| 5 | ST4000NM0035-1V4107 | 3726 | HDD del disco compartido (`D:`, **SEAGATE**) |
| 3, 4 | **TOSHIBA HDWE140** | 3726 c/u | Grupo dinámico LDM → volumen espejo `E:` |

⚠️ **El espejo `E:` no se toca desde Linux suelto**: los dos Toshiba contienen un plexo cada uno del
**mismo** volumen NTFS (misma etiqueta y UUID). En Linux se monta una sola vez con `ldmtool` en
`/mnt/toshiba` y los plexos se ocultan a udisks (ver `SISTEMA-CACHYOS.md`, regla
`90-ocultar-miembros-ldm.rules`). Desde Windows, escribir en `E:` es lo correcto.

**Letras variables**: `D:` (SEAGATE), `F:`/`H:` (los discos de Linux, vía WinBtrfs) y las del espejo
pueden cambiar entre arranques. Se localizan por **etiqueta** o por marca, nunca por letra fija:
`<letra>:\HermesSync\.hermes-sync` (compartido), `<letra>:\@home\antonio\.hermes` (Linux).

---

## 3. Estado compartido y dual boot (visto desde Windows)

| Pieza | Ruta |
|---|---|
| Carpeta compartida | `D:\HermesSync\` (marca `.hermes-sync`) |
| Estado publicado/importado | `D:\HermesSync\estado\` (state.db, sessions, memories, skills, cron, kanban) |
| Registros de sincronización | `D:\HermesSync\logs\PC-ANTONIO.log`, `logs\cachyos.log`, `logs\encargos-windows.log` |
| Notes del canal | `D:\HermesSync\NOTA-PARA-LINUX.md` / `NOTA-PARA-WINDOWS.md` |
| Encargos | `HermesSync\windows\encargos\*.ps1` (Linux → Windows) · `HermesSync\linux\encargos\*.sh` (Windows → Linux) |
| Motor local | `%LOCALAPPDATA%\hermes\dual-boot\` (`hermes-dual-sync.ps1` + `copiar-state.py`) |
| Import al arrancar | Lanzador de la carpeta **Inicio** (`Hermes_Gateway.vbs`) |
| Disco de Linux | `F:\@home\antonio\...` (WinBtrfs) |

---

## 4. Hermes en Windows *(instantánea)*

| Dato | Valor |
|---|---|
| **Home** | `%LOCALAPPDATA%\hermes` (`HERMES_HOME`) |
| **Versión** | `v0.21.6+521.gf86276d.dirty` (`main` @ `f86276d2eb`, 10/10/2026) |
| **Instalación** | git, en `%LOCALAPPDATA%\hermes\hermes-agent` · **al día** (update aplicado el 10/10/2026) |
| **Python / Node** | 3.14.7 y 26.7.0 (los del propio Hermes) |
| **Modelo** | `deepseek-v4.1-flash` · proveedor `opencode-go` · **11 alias** (`local`, `local-qwen35`, `local-gemma`, `nvidia`, `nemotron-super`, `gpt-oss`, `glimmer`, `lightning`, `nano-omni`, `vision`, `multimodal`) |
| **Plugins** | `homeassistant` (habilitado) + `model-providers` (filtra el catálogo NVIDIA por el whitelist de OpenCode) |
| **Voz** | TTS **Kokoro** y STT **whisper.cpp**, ambos por comando (`%USERPROFILE%\.local\bin\hermes-kokoro-tts.py` / `hermes-whisper-stt.py`), idioma `es` |
| **Hooks** | gateway: `encargos-windows` · shell aprobado: `on_session_end → agent-hooks\backup-hermes.sh` |
| **Cron** | 2 entradas en `cron\jobs.json`: «Espejo Obsidian al dia (Hermes/OpenCode/MiMoCode)» (`6e92f0fa9876`, lunes 09:00, activo) y «Pendientes del lado Windows (10/10)» (`0252363db327`, de una sola vez, ya ejecutado y deshabilitado) |
| **Aviso de arranque** | `gateway-service\hermes-ready-notify.ps1`, lanzado desde la carpeta Inicio, avisa por Telegram y deja rastro en `logs\ready-notify.log` |
| **Parche local** | Ctrl+Q (corta la locución sin interrumpir el turno) · commit de referencia `f86276d2eb` |
| **computer-use** | `cua-driver-0.21.0-win32-x64` instalado |

### Memoria y skills

- `memories\MEMORY.md` 2.230 B · `memories\USER.md` 1.363 B *(instantánea)*.
- Skills: 12 categorías + **15 propias** en `skills\autonomous-ai-agents\` (14 `hermes-*` +
  `modelos-locales-dimensionado`) y las 4 de orquestación (`claude-code`, `codex`, `computer-use`,
  `opencode`).

---

## 5. Herramientas instaladas (no viajan en el ZIP)

| Pieza | Dónde | Notas |
|---|---|---|
| **Python 3.14** | `C:\Python314\python.exe` | Lo usan los scripts de voz |
| **git** | `C:\Program Files\Git` (2.53.0.windows.3) | La terminal del agente corre en **git-bash (MSYS)** |
| **VS Code**, **Obsidian**, **Perplexity**, **MEGAsync** | `%LOCALAPPDATA%\Programs\` / accesos | — |
| **LM Studio** | modelos en `%USERPROFILE%\.lmstudio\models\` | *(instantánea)* solo descargado `Qwen/Qwen3.8-9B` → el alias `local` funciona; `local-qwen35` y `local-gemma` necesitarían `lms get` |
| **voice stack** | `%USERPROFILE%\.local\bin\` | `hermes-kokoro-tts.py`, `hermes-whisper-stt.py`, `hermes-voz.py`, `hvoz.cmd`, `whisper.cpp` (+ build CUDA), `ffmpeg` |
| **Atajos** | `%USERPROFILE%\.local\bin\` | `hermes-backup`, `hvoz`, `ocv`/`ocv-local`/`ocv-cloud`/`ocv-status`, `timeline-completo`, `hw_query` |

---

## 6. Incidencias detectadas *(10/10/2026 · revisado 19:45)*

1. **Tarea `HermesBackup-Win` intermitente**: falló a las 15:53 y a las 17:27 con
   `0x800710E0` (*ERROR_NO_SUCH_DEVICE*), y funcionó a las 16:11, 17:35 y 17:41 (resultado 0). El
   lanzador vive en el disco SEAGATE (`D:`), así que la causa probable es que la unidad no
   respondiera en ese instante (giro en reposo o disco recién despertado). **Hoy está en 0**; si
   vuelve a fallar, ver `sync.log` y el resultado de la tarea.
2. **Update: aplicado el 10/10/2026 a las 18:50** (`v0.21.5+7252` →
   `v0.21.6+521.gf86276d.dirty`, `main` @ `f86276d2eb`), con el parche Ctrl+Q regenerado y
   aplicando limpio; `hermes --version` dice «Up to date». Esta captura es anterior
   (17:20–17:45) y lo daba por pendiente.
3. **Inicio rápido**: estaba **activado** (`HiberbootEnabled=1`) hasta el 10/10/2026 a las 17:18,
   cuando el encargo 06 lo desactivó (con UAC) tras el NTFS sucio del SEAGATE. Ya en **0**.
4. **`documentos\` no existía** en el esquema de Windows (el de Linux sí lo tiene): añadido el
   10/10/2026, lo regenera el backup.

---

## 7. Recomendaciones

- Pasar `chkdsk` al SEAGATE solo si vuelve a quedar sucio; con el inicio rápido apagado ya no debería
  repetirse (el del 10/10 salió limpio: «Se examinó el sistema de archivos sin encontrar problemas»).
- Añadir **reintentos** a `HermesBackup-Win` (`-RestartCount 3 -RestartInterval 1min`) si el fallo
  intermitente se repite.
- Descargar en LM Studio los modelos de `local-qwen35` y `local-gemma` si se quieren usar en Windows.

---

## 8. Anexo — cómo se regenera esta captura

```powershell
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,BuildNumber,OSArchitecture
Get-CimInstance Win32_ComputerSystem  | Select-Object Manufacturer,Model,TotalPhysicalMemory
Get-CimInstance Win32_Processor       | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors
Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion
Get-Volume | Sort-Object DriveLetter | Format-Table DriveLetter,FileSystemLabel,FileSystem,HealthStatus,Size,SizeRemaining
Get-Disk | Format-Table Number,FriendlyName,Size,PartitionStyle,OperationalStatus,HealthStatus
Get-ScheduledTask | Where-Object TaskName -like '*Hermes*' | Get-ScheduledTaskInfo
hermes --version
```

En Linux, el inventario gemelo es `~/Config/hermes/SISTEMA-CACHYOS.md` (`pkexec` para `smartctl`,
`dmidecode` y `efibootmgr`).
