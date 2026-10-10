# 🔄 Esquema de backup de Hermes Agent en Windows (equivalente al de Linux)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario | 🖥️ Equipo |
|-----------|----------|------------|-----------|
| ✅ activo · rev. 10/10/2026 | 29/09/2026 | Antonio | PC-ANTONIO (Windows 11) |

> Réplica en Windows del esquema de `~/Config/hermes/` de Linux: respaldo canónico, ZIP con
> `restore-win.cmd` dentro, credenciales con permisos restringidos, retención de 30 días y copia
> saneada (sin claves) en dotfiles. Origen: `D:\HermesSync\PARA-WINDOWS-backup.md`.
>
> ⚠️ En Windows hay **dos paquetes de respaldo activos**; ver «Respaldo rápido» al final del
> apartado Procedimientos para no confundirlos.

---

## 📑 Índice
1. [Estructura](#estructura)
2. [Qué se respalda y qué no](#qué-se-respalda-y-qué-no)
3. [Credenciales y claves de API](#credenciales-y-claves-de-api)
4. [Procedimientos](#procedimientos)
5. [Restauración](#restauración)
6. [Requisitos externos (lo que no viaja en el ZIP)](#requisitos-externos-lo-que-no-viaja-en-el-zip)
7. [Automatización (tareas programadas)](#automatización-tareas-programadas)
8. [Motor del dual boot en este equipo](#motor-del-dual-boot-en-este-equipo)
9. [Traspaso de información con Linux (canal de encargos)](#traspaso-de-información-con-linux-canal-de-encargos)
10. [Voz local (Kokoro TTS + whisper.cpp)](#voz-local-kokoro-tts--whispercpp)
11. [Modelos y alias](#modelos-y-alias)
12. [Parches locales del CLI (Ctrl+Q)](#parches-locales-del-cli-ctrlq)
13. [Herramientas propias y atajos](#herramientas-propias-y-atajos)
14. [Skills propias](#skills-propias)
15. [Inventario del equipo](#inventario-del-equipo-sistema-windowsmd)
16. [Documentación de configuración (documentos/)](#documentación-de-configuración-documentos)
17. [Reglas que NO se deben romper](#reglas-que-no-se-deben-romper)

---

## Estructura

- `%LOCALAPPDATA%\hermes` → configuración **ACTIVA** (la que usa Hermes; `HERMES_HOME`).
- `D:\Linux\Config\Hermes-Win\` → copia de **SEGURIDAD** para instalaciones desde limpio.
  La letra del disco SEAGATE la asigna Windows y **hoy es `D:`**; si algún día cambiara, se
  localiza por su marca: `<letra>:\HermesSync\.hermes-sync`.

```
D:\Linux\Config\Hermes-Win\
├── AGENTS-WIN.md            # este documento (reglas del esquema)
├── SISTEMA-WINDOWS.md       # inventario del equipo visto desde Windows (ver §15)
├── .gitignore               # se copia a dotfiles (si falta allí, el volcado lo borraría)
├── backup-hermes.ps1        # genera el ZIP + respaldo canónico + copia saneada
├── sync-hermes.ps1          # envoltorio de la tarea programada (cada 30 min)
├── check-setup-win.ps1      # verificación previa (aborta el backup si falla)
├── restaurar-hermes.ps1     # restauración desde el ZIP
├── bootstrap-hermes.ps1     # atajo al instalador desde limpio
├── instalar-desde-cero.ps1  # instalación completa en un equipo recién instalado (8 pasos)
├── registrar-tareas.ps1     # registra las tareas programadas y los lanzadores del Inicio
├── hermes-auditoria-manual.ps1  # auditoría del manual contra la configuración viva
├── commit-parche.txt        # commit de referencia del parche Ctrl+Q
├── hook-backup-hermes.sh    # copia del hook on_session_end (agent-hooks\backup-hermes.sh)
├── lanzar-oculto.vbs        # lanzador sin ventana de las tareas programadas
├── backup-tarea.cmd         # envoltorio del .vbs para el Programador de tareas
├── documentos\              # copia de respaldo de los markdown de configuración (ver §16)
├── extras\bin\              # scripts propios de voz (hermes-kokoro-tts.py, hvoz, …)
├── parches\                 # parches históricos por commit (el vivo está en HermesSync\windows\parches)
├── backups\                 # zips hermes-win-backup-AAAAMMDD-HHMMSS.zip (ACL restringida)
├── sesion-hermes\           # respaldo canónico + instalador (config, .env, auth.json, SOUL)
├── informe-instalacion-*.txt # informe que deja instalar-desde-cero.ps1 en cada ejecución
└── sync.log                 # histórico de sincronizaciones

D:\Linux\Documentos\dotfiles\hermes-win\   # copia SANEADA (sin claves), se versiona en git
```

Réplica en la home de Linux (partición btrfs de CachyOS vista con WinBtrfs; la letra cambia):

```
<F:>\@home\antonio\Config\Hermes-Win\                    # espejo del respaldo canónico (con credenciales)
<F:>\@home\antonio\Documentos\dotfiles\hermes-win\       # espejo de la copia saneada (repo git de dotfiles)
```

Nunca tocar `D:\Linux\Documentos\dotfiles\hermes\` (sin `hermes-win`): esa es la de Linux.

---

## Qué se respalda y qué no

| ✅ Dentro del ZIP | ❌ Fuera del ZIP |
|---|---|
| `config.yaml`, `SOUL.md`, `install_id`, `channel_directory.json`, `shell-hooks-allowlist.json` | `state.db*` y `sessions\` (histórico de conversaciones; viaja por el esquema dual boot) |
| `skills\`, `plugins\`, `memories\`, `hooks\`, `agent-hooks\` | `cache\`, `logs\`, `runtime\`, `sandboxes\`, `terminal-sessions\` |
| `cron\` (sin `executions.db`) | `tools\`, `installs\`, `hermes-agent\` (clon git) |
| `kanban.db` (copia consistente con la API `.backup` de SQLite) | clones temporales, `pairing\`, `pending_messages\`, `state\` |
| `skins\`, `tui-widgets\`, `desktop-plugins\`, `pets\` (si existen) | ficheros `*.lock`, `*.pid`, `*.sock`, `__pycache__` |
| Credenciales: `.env` y `auth.json` en `credenciales\` (ACL restringida) y en `sesion-hermes\` | `shared\` en dotfiles (sí va al ZIP: es el token del Portal Nous) |

El ZIP pesa unos pocos MB (frente a los ~3 GB del directorio completo).

---

## Credenciales y claves de API

- Las claves viven en `%LOCALAPPDATA%\hermes\.env` y los tokens OAuth en `auth.json`.
- **SÍ van** en el ZIP y en `sesion-hermes\`: son la copia de restauración. Por eso esas dos
  rutas llevan la herencia NTFS quitada y solo el usuario `evo01` con control total
  (`icacls <ruta> /inheritance:r /grant:r "USUARIO:(OI)(CI)F"`), equivalente al 0600/0700 de Linux.
- **NUNCA** deben estar en `D:\Linux\Documentos\dotfiles\`. Esa es la frontera real.
- Antes de dar por buena la copia saneada, `backup-hermes.ps1` ejecuta un escaneo en **dos fases**:
  1. Patrones (`nvapi-`, `oc_sk_`, `sk-…`, `AEMET_API_KEY=…`, `NVIDIA_API_KEY=…`,
     `OPENCODE_GO_API_KEY=…`, claves SSH, `BEGIN … PRIVATE KEY`, token de bot de Telegram).
  2. **Valores reales** extraídos de `.env` y `auth.json`, buscados literalmente en toda la copia
     (esta fase es la que encontró una clave escondida en Linux el 29/09/2026).
  Si algo aparece, el fichero se borra de la copia saneada y queda anotado en
  `AVISO-CLAVES-*.txt`.

---

## Procedimientos

### Backup manual
```powershell
powershell -ExecutionPolicy Bypass -File D:\Linux\Config\Hermes-Win\backup-hermes.ps1
```
Antes de copiar nada ejecuta `check-setup-win.ps1`; si el esquema no está correcto, el backup se
**aborta** para no guardar un setup defectuoso.

### Sincronización + backup (lo que corre la tarea programada)
```powershell
powershell -ExecutionPolicy Bypass -File D:\Linux\Config\Hermes-Win\sync-hermes.ps1 -Quiet
```

### Réplica en la home de Linux (F:)

Cada ejecución del backup publica además el esquema en la home **real** de Linux (la partición btrfs
de CachyOS, que desde Windows se ve como `F:` gracias a WinBtrfs), con el mismo patrón que el esquema
de OpenCode (`backup-opencode.ps1`, §4):

| Destino | Contenido |
|---|---|
| `<F:>\@home\antonio\Config\Hermes-Win\` | espejo del respaldo canónico, **con credenciales** (es la copia de restauración, no un repo público) |
| `<F:>\@home\antonio\Documentos\dotfiles\hermes-win\` | espejo de la copia saneada, dentro del repo git de dotfiles (el commit lo hace Antonio a mano) |

La letra de la partición puede cambiar entre arranques: si `F:` no responde, se localiza por la marca
`<letra>:\@home\antonio\.hermes`. Si no aparece, el backup **continúa** y lo deja anotado en
`sync.log`; `-SinF` omite la réplica y `-UnidadF G:` fuerza la letra. En la copia replicada de
dotfiles se repite el escaneo de claves (solo lectura) y se preserva su `.git`.

### Copia publicada del esquema (`HermesSync\windows\esquema-windows`)

El backup refresca además (paso 12) la copia de **referencia** que Linux lee en el disco
compartido: solo la lista blanca de scripts y documentos (`AGENTS-WIN.md`, `backup-hermes.ps1`,
`sync-hermes.ps1`, `check-setup-win.ps1`, `restaurar-hermes.ps1`, `bootstrap-hermes.ps1`,
`registrar-tareas.ps1`, `instalar-desde-cero.ps1`, `hook-backup-hermes.sh`, `commit-parche.txt`,
`.gitignore` y `agent-hooks\backup-hermes.sh`), copiando solo lo que cambia. **No** es un espejo
del directorio: `sesion-hermes\` y `backups\` nunca van ahí (llevan credenciales). Antes se
refrescaba a mano y se quedaba desfasada.

### Instalación desde limpio

**Equipo recién instalado (Windows sin Hermes)** — un solo comando:

```powershell
powershell -ExecutionPolicy Bypass -File D:\Linux\Config\Hermes-Win\instalar-desde-cero.ps1
```

Hace los 8 pasos: comprueba el sistema → instala Hermes con el instalador oficial (`uv` + Python +
Node si faltan, `-SkipSetup`) → restaura el último ZIP (config, credenciales, skills, plugins,
memories, cron, kanban) → aplica los ajustes de entorno (`aplicar-ajustes-linux.ps1`: parche
Ctrl+Q, alias de modelo, plugin nvidia, `LM_API_KEY`, whitelist NVIDIA de OpenCode) → monta el hook
de cierre (`config.yaml` + `shell-hooks-allowlist.json`) → LM Studio (servidor 1234, modelos de los
alias `local-*`, `LM_API_KEY`) → registra la tarea de backup → verifica todo y deja un informe en
`informe-instalacion-*.txt`.

Detalles que importan:

- **El parche Ctrl+Q solo aplica en el commit con el que se hizo.** El repo se clona en HEAD; si el
  upstream ha movido esos ficheros, el script lo detecta, reintenta fijando el commit que hay en
  `commit-parche.txt` (hoy `f86276d2eb`) y vuelve a aplicar. Si ni así aplica, hay que portar el parche.
  Verificado el 03/10/2026: el parche describe exactamente el árbol tanto en `94f3f170d` como en
  `bd0affe5e` (esas zonas no cambiaron en los 1516 commits), así que el mismo parche sirve para ambos.
- `-Commit <sha>` fuerza el commit de instalación; `-Zip`, `-Disco`, `-HermesHome`, `-InstallDir`
  permiten apuntar a otro sitio (pruebas aisladas). `-Sin*Ajustes|LMStudio|Tareas|Hermes`,
  `-DescargarModelo` (hace `lms get` de lo que falte) y `-SoloVerificar` para auditar sin tocar nada.
- El instalador oficial **añade `<HERMES_HOME>\bin` al PATH del usuario**: hay que abrir una
  terminal nueva para tener el comando `hermes`.
- Si un alias `local-*` apunta a un modelo que no está descargado en LM Studio, el script lo dice con
  el comando exacto (`lms get <modelo>`); no lo descarga solo salvo que se pase `-DescargarModelo`.

**Restaurar sin más (Hermes ya instalado, recuperar la configuración):**

```powershell
powershell -ExecutionPolicy Bypass -File D:\Linux\Config\Hermes-Win\bootstrap-hermes.ps1
```

Restaura el último ZIP (o `sesion-hermes\`), repone `.env` y `auth.json` con ACL restringida y
verifica al final (`hermes doctor`, `config.yaml`, `SOUL.md`, `memories\`, `skills\`).

> Probado de verdad el 29/09/2026: instalación completa en un `HERMES_HOME` aislado
> (`D:\prueba-cero`) siguiendo los 8 pasos, con el reintento del parche incluido (repo clonado en
> HEAD → checkout a `8423c477` → parche aplicado) y verificación final sin fallos.

### Al modificar la configuración de Hermes
1. Los cambios se hacen en `%LOCALAPPDATA%\hermes` con `hermes config set` (nunca a mano en `config.yaml`).
2. Ejecutar `sync-hermes.ps1` → refresca `sesion-hermes\` y regenera el ZIP.

### Actualizar Hermes (y volver a aplicar el parche Ctrl+Q)

Historial de updates en este equipo:

| Fecha | Versión | Commits | Commit final |
|---|---|---|---|
| 30/09/2026 | v0.21.5+4202 → v0.21.5+4708 | 506 | 94f3f170d |
| 03/10/2026 | v0.21.5+4708 → v0.21.5+6224 | 1516 | bd0affe5e |
| 10/10/2026 | v0.21.5+7252 → v0.21.6+521 | 2449 | f86276d2eb |

> **Estado del 10/10/2026 (tras el update de esa noche)**: versión instalada
> `v0.21.6+521.gf86276d.dirty` (`main` @ `f86276d2eb`), commit de referencia del parche
> **`f86276d2eb`**, y `hermes --version` dice **«Up to date»**. El parche Ctrl+Q sobrevivió al
> update (sigue aplicando limpio en reversa, sin tocar nada) y se regeneró el fichero del parche.

Flujo probado (03/10/2026, con el parche Ctrl+Q vivo):

```powershell
# 1. Guardar el parche aplicado, por si acaso
git -C $env:LOCALAPPDATA\hermes\hermes-agent diff > $env:TEMP\ctrl-q-antes.patch
# 2. Actualizar. SIN --keep-stash: el autostash guarda los cambios locales y los restaura
#    sobre el código nuevo (avisa con «Local changes were restored on top of the updated codebase»).
hermes update
```

El updater hace git pull, reinstala dependencias, reconstruye TUI/web y **vuelve a empaquetar el
escritorio** (`apps/desktop/release/win-unpacked`). Reinicia el gateway solo.

Al terminar, comprobar que el parche Ctrl+Q sobrevivió (debe seguir describiendo el árbol):

```powershell
git -C <repo> apply --reverse --check D:\HermesSync\windows\parches\ctrl-q-corta-audio.patch   # exit 0
python -m py_compile hermes_cli/cli_tui_mixin.py tools/voice_mode.py                          # sin salida
git -C <repo> diff > D:\HermesSync\windows\parches\ctrl-q-corta-audio.patch                   # regenerar (blobs nuevos)
git -C <repo> rev-parse --short HEAD > D:\Linux\Config\Hermes-Win\commit-parche.txt           # commit de referencia
```

El diff regenerado conserva el mismo contenido (solo cambian los hashes de blob del encabezado); el
parche histórico por commit se conserva como `parches\ctrl-q-<commit>.patch`. Si el parche NO aplica
limpio (el código aguas arriba cambió), **no forzarlo**: anotarlo en `NOTA-PARA-LINUX.md` y
reconciliar desde Linux.

Comprobaciones tras un update:
- `hermes --version` (debe decir «Up to date» y el commit nuevo), `hermes doctor`,
  `hermes hooks doctor` (el hook de cierre sigue allowlisted).
- **Avisos de config / toolsets**: `validate_platform_toolsets` debe salir a 0 diagnósticos. Pasó con
  `stt` (desapareció en el update del 30/09) y la lista `cli` se corrigió con
  `hermes config set platform_toolsets.cli "[...]"`. Validación sin arrancar Hermes:
  `config_check_diagnostics(load_config(), get_env_value)` con el python del venv del runtime
  (`installs\<id>\environments\<id>\venv\Scripts\python.exe`); el `python` del PATH no tiene `ruamel`.
- Desktop: el sello `apps\desktop\build\install-stamp.json` debe traer el commit nuevo y
  `apps\desktop\release\win-unpacked\Hermes.exe` recién empaquetado.
- Si se usa computer-use: `hermes computer-use install --upgrade` (pide UAC; el updater lo omite:
  «Windows cua-driver refresh deferred»).

### Respaldo rápido (segundo paquete, `%LOCALAPPDATA%\hermes\backup`)

Además del esquema de esta carpeta existe un paquete ligero, pensado para «acabo de tocar algo,
quiero un respaldo ya»:

- Script: `%LOCALAPPDATA%\hermes\backup\backup-hermes.ps1` (+ atajos `hermes-backup` en
  `~\.local\bin`); documentado en `%LOCALAPPDATA%\hermes\backup\LEEME.md`.
- Tarea programada `HermesBackup-Diario` (diaria a las 21:00, con `-ConConversaciones`).
  Desde el 10/10/2026 lleva además un **disparador al iniciar sesión (retraso de 5 min)** y
  `StartWhenAvailable = true`: la de las 21:00 no se ejecutaba nunca (a esa hora el equipo
  suele estar arrancado en Linux), así que el respaldo rápido —el único paquete que lleva
  `state.db` + `sessions\`, o sea la vía de emergencia para recuperar conversaciones— estuvo
  sin generarse del 05/10 al 10/10. Detalle en `%LOCALAPPDATA%\hermes\backup\LEEME.md`.
- Destino: `D:\HermesSync\backups\hermes\` (ZIP `hermes-backup-<equipo>-AAAAMMDD-HHMMSS.zip` +
  carpeta `saneado\` sin claves).
- Se lanza tras un `hermes update` para que el estado recién actualizado quede respaldado sin
  esperar a la tarea de los 30 minutos.

No sustituye al esquema de `Hermes-Win\` (respaldo canónico + `sesion-hermes\` + copia saneada
versionada en dotfiles): el paquete rápido no refresca `sesion-hermes\` ni la copia de dotfiles.

---

## Restauración

Desde un ZIP (el propio ZIP lleva `restore-win.cmd` + `restaurar-hermes.ps1`):

```powershell
# Prueba de verdad: SIEMPRE en una carpeta temporal, nunca encima de la instalación activa
powershell -ExecutionPolicy Bypass -File D:\Linux\Config\Hermes-Win\restaurar-hermes.ps1 `
    -Destino "$env:TEMP\restore-hermes"
```

Sin argumentos restaura sobre `%LOCALAPPDATA%\hermes` (la instalación activa). `-SoloSesion`
restaura únicamente el respaldo canónico. El script repone `.env` y `auth.json` con ACL
restringida y verifica los ficheros críticos al terminar.

---

## Requisitos externos (lo que no viaja en el ZIP)

El ZIP pesa unos pocos MB: lleva configuración, datos y scripts, pero **no** las dependencias
pesadas ni lo instalado fuera de `%LOCALAPPDATA%\hermes`. Para que una instalación desde limpio
quede igual que este equipo hay que reponerlas aparte (el instalador `instalar-desde-cero.ps1` lo
hace con lo marcado ✅).

| Pieza | Dónde vive | Cómo se repone |
|---|---|---|
| **Python 3.14** ✅ | `C:\Python314\python.exe` | Lo usan los scripts de voz. `winget install Python.Python.3.14` |
| Node (26.7.0) y Python del runtime | `%LOCALAPPDATA%\hermes\tools\` | Los baja el instalador de Hermes solo |
| **git** ✅ | `C:\Program Files\Git` (2.53.0.windows.3) | `winget install Git.Git` — la terminal del agente es **git-bash (MSYS)**: sintaxis POSIX |
| **LM Studio** | modelos en `%USERPROFILE%\.lmstudio\models\` | `lms get qwen3.8-9b@q6_k` (hoy solo está ese; `local-qwen35` y `local-gemma` piden `lms get` aparte) |
| **Stack de voz** | scripts en `%USERPROFILE%\.local\bin\`; binarios en `whisper.cpp*` y `ffmpeg\` | ✅ Los **scripts** (`hermes-kokoro-tts.py`, `hermes-whisper-stt.py`, `hermes-voz.py`, `hvoz`, `hvoz.cmd`) viajan en **`extras\bin\`** del esquema, al respaldo canónico (`sesion-hermes\extras\bin`), a dotfiles y a la copia publicada (`esquema-windows\extras\bin`). Los **binarios** y el **modelo** no (cientos de MB): reponerlos aparte — `whisper.cpp-cuda\Release\whisper-cli.exe` (con sus DLL de CUDA), `ffmpeg\bin\ffmpeg.exe` (9.0.1, gyan.dev) y el modelo en `%USERPROFILE%\.local\models\whisper\ggml-large-v3-turbo-q5_0.bin` (574 MB) |
| **computer-use** | `cua-driver-0.21.0-win32-x64` | `hermes computer-use install --upgrade` (pide UAC) |
| VS Code, Obsidian, Perplexity, MEGAsync | `%LOCALAPPDATA%\Programs\` / accesos | `winget` o a mano |

✅ **Resuelto el 10/10/2026**: los scripts de voz se copiaron a `Hermes-Win\extras\bin\`, y de ahí
viajan al respaldo canónico (`sesion-hermes\extras\bin`), a la copia saneada de dotfiles y a la copia
publicada para Linux (`HermesSync\windows\esquema-windows\extras\bin`) (no al
ZIP, que es la configuración de Hermes). Los **binarios** (`whisper.cpp`, `ffmpeg`) y el **modelo**
siguen fuera a propósito: pesan cientos de MB y se reponen aparte (rutas y versiones en la tabla de
arriba).

---

## Automatización (tareas programadas)

Las tres tareas y el hook, tal como están registrados en este equipo *(verificado 10/10/2026)*:

| Tarea | Cada cuánto | Qué ejecuta | Último resultado |
|---|---|---|---|
| `HermesBackup-Win` | **cada 30 min** (`TimeTrigger`, repetición `PT30M`) | `lanzar-oculto.vbs` → `backup-tarea.cmd` → `sync-hermes.ps1 -Quiet` | 0 |
| `HermesBackup-Diario` | **diaria a las 21:00** (`DailyTrigger`) **+ al iniciar sesión** (retraso 5 min) | `%LOCALAPPDATA%\hermes\backup\backup-hermes.ps1 -ConConversaciones` (respaldo rápido, ver «Respaldo rápido») | 0 |
| `HermesSync-Publicar` | **cada 5 min** (`TimeTrigger`, repetición `PT5M`) | `dual-boot\lanzar-oculto.vbs` → `publicar.cmd` (estado al disco compartido) | 0 |
| Hook `on_session_end` | al cerrar sesión de Hermes | `agent-hooks\backup-hermes.sh` (allowlist de shell; declarado en `config.yaml` → `hooks.on_session_end`, `timeout: 120`) | — |

Cada una de esas ejecuciones refresca también la réplica en la home de Linux (F:) descrita arriba,
así que lo que viaja al disco de Linux va dentro del mismo backup verificado.

Registro (sin administrador; `schtasks /sc minute` basta, a diferencia de los disparadores
"al iniciar sesión"):

```cmd
schtasks /create /tn HermesBackup-Win /sc minute /mo 30 /tr "powershell -NoProfile -ExecutionPolicy Bypass -File \"D:\Linux\Config\Hermes-Win\sync-hermes.ps1\" -Quiet" /f
schtasks /query /tn HermesBackup-Win
schtasks /run   /tn HermesBackup-Win
```

Retención: 30 días + poda de duplicados del mismo día (se conserva el último ZIP del día).

### Trabajos de cron de Hermes

Además de las tareas de Windows, el propio Hermes lleva sus trabajos en
`%LOCALAPPDATA%\hermes\cron\jobs.json` *(instantánea 10/10/2026)*:

| Trabajo | Cuándo | Estado | Qué hace |
|---|---|---|---|
| «Espejo Obsidian al dia (Hermes/OpenCode/MiMoCode)» (`6e92f0fa9876`) | lunes 09:00 (`0 9 * * 1`) | activo · entrega por Telegram | audita los manuales de los tres programas contra el sistema vivo y refresca el espejo del vault |
| «Pendientes del lado Windows (10/10)» (`0252363db327`) | una sola vez (10/10 18:52) | **deshabilitado** (ya ejecutado) | aviso puntual que se programó el Hermes de Windows |

Los trabajos de una sola vez (`once`) quedan deshabilitados al ejecutarse: siguen en `jobs.json` pero
no vuelven a correr. El del espejo es el **mismo en los dos sistemas** (viaja por el estado compartido
del dual boot) y `cron.catch_up_missed: true` recupera una pasada perdida si el equipo estaba apagado.


---

## Motor del dual boot en este equipo

El motor que **ejecuta** Windows es la copia local `%LOCALAPPDATA%\hermes\dual-boot\`
(`hermes-dual-sync.ps1` + `copiar-state.py`), no la distribuida en `D:\HermesSync\windows\`. Es a
propósito: así una republicación desde Linux no revierte los arreglos hechos aquí.

Cuando Linux publique cambios del motor, pasarlos a la copia local (sin administrador):

```powershell
powershell -ExecutionPolicy Bypass -File D:\HermesSync\windows\actualizar-motor-local.ps1 -SoloEstado
powershell -ExecutionPolicy Bypass -File D:\HermesSync\windows\actualizar-motor-local.ps1
```

Deja copia `.bak-<fecha>` de lo anterior, compara hashes al terminar y comprueba (solo lectura)
que el lanzador de la carpeta Inicio sigue importando el estado antes del gateway (si `hermes
gateway install` o un `hermes update` lo reescribe, se recupera con `registrar-tareas.cmd`).

**Import con Hermes en marcha (desde 05/10/2026).** Sustituir `state.db` con Hermes vivo la
corrompe, así que el motor **fusiona** (`copiar-state.py --fusionar`): añade las sesiones que
falten con sus mensajes, prompts y datos de uso, sin borrar nada local, y copia `sessions\`,
`memories\`, `skills\`, `cron\` y `SOUL.md`. `kanban.db` se deja para el primer import con Hermes
cerrado y queda anotado en `.dual-sync\estado.json` (`"parcial": true`, `"pendientes":
["kanban.db"]`). Con Hermes cerrado el import hace la sustitución completa de siempre.

**Atajo `-SoloSiCambia` (corregido el 05/10/2026).** La lista de ficheros vigilados se montaba
como `@(Join-Ruta $HermesHome 'state.db', (Join-Ruta …), …)`: por precedencia del operador coma
en PowerShell las seis rutas se pegaban en una sola cadena, `Test-Path` fallaba siempre y el
motor concluía «sin cambios» **sin publicar nunca** (así estuvo del 29/09 al 05/10). Cada ruta va
ahora entre paréntesis; si se toca esa lista, confirmarlo con una publicación real en
`HermesSync\logs\<equipo>.log` (`Publicando estado de …`).

**Comprobación del número de sesiones (relajada el 10/10/2026).** El import abortaba si la copia
publicada no tenía *exactamente* las sesiones que declara `MANIFEST.json` («state.db remota tiene 71
sesiones y el manifiesto declara 72. Import abortado.»). El manifiesto lo escribe el motor de Linux
contando su base **viva**, y esa cuenta puede llevar alguna sesión más que la copia publicada (caso
real del 09/10: una sesión oculta `Bot Chat` de 0 mensajes). Como el `sha256` de la copia ya se
comprueba contra el del manifiesto, la diferencia ahora se **avisa** (`AVISO: la copia tiene N
sesiones y el manifiesto declara M; el sha256 coincide, sigo con el import.`) y no bloquea; sigue
abortando si el `sha256` no coincide o si la copia no tiene tabla de sesiones. Copia previa:
`hermes-dual-sync.ps1.bak-20261010`. Con esta comprobación bloqueando cada 5 minutos, Windows no
publicó nada del 07/10 17:46 al 10/10 08:20 (`LastTaskResult = 1` en `HermesSync-Publicar`).

---

## Traspaso de información con Linux (canal de encargos)

El estado de Hermes (memorias, skills, conversaciones, kanban) viaja solo por
`HermesSync\estado\`. Para lo que hay que **hacer** o **leer** hay dos canales
automáticos, simétricos:

| Dirección | Tareas de una sola vez | Notas |
|---|---|---|
| Windows → Linux | `HermesSync\linux\encargos\*.sh` (las ejecuta el hook `encargos-linux` en Linux) | `HermesSync\NOTA-PARA-LINUX.md` |
| Linux → Windows | `HermesSync\windows\encargos\*.ps1` (las ejecuta el hook `encargos-windows`) | `HermesSync\NOTA-PARA-WINDOWS.md` |

### Encargos para este equipo (Linux → Windows)

Los `.ps1` (o `.cmd`) que Linux deja en `HermesSync\windows\encargos\` los ejecuta el
hook **`encargos-windows`** al arrancar el gateway. Vive en
`%LOCALAPPDATA%\hermes\hooks\encargos-windows\` (HOOK.yaml + handler.py, cargado por
*trusted-by-placement*) y **viaja en el backup**, porque `hooks` está en la lista de
respaldados.

- Se ejecutan **una sola vez**: el nombre queda en
  `%LOCALAPPDATA%\hermes\state\encargos-hechos.json`.
- Si fallan (salida ≠ 0) se reintentan en el siguiente arranque; conviene que sean
  **idempotentes**, **sin argumentos**, **sin interacción** y **sin secretos**.
- Tiempo máximo: 300 s.
- Los `.ps1` se leen explícitamente en UTF-8 (PowerShell 5.1 asumiría ANSI al no llevar
  BOM y rompería los acentos de un encargo escrito desde Linux).
- Salida en **dos** sitios, para poder leerla desde los dos sistemas:
  `HermesSync\logs\encargos-windows.log` y
  `%LOCALAPPDATA%\hermes\logs\encargos-windows.log`.
- En cada arranque el hook deja además constancia del estado de las dos notas.

Convención completa, ejemplo y comprobaciones: `HermesSync\windows\encargos\LEEME.md`.

Lanzar la pasada a mano, sin reiniciar el gateway:

```powershell
python -c "import sys;sys.path.insert(0,r'%LOCALAPPDATA%\hermes\hooks\encargos-windows');import handler;handler.handle('gateway:startup',{})"
```

## Voz local (Kokoro TTS + whisper.cpp)

Todo por **comandos externos**, igual que en Linux (los proveedores de tipo `command` de Hermes), y
en el `config.yaml` activo:

| Pieza | Configuración | Comando |
|---|---|---|
| **TTS** | `tts.provider: kokoro` · `tts.providers.kokoro` | `"C:\Python314\python.exe" "%USERPROFILE%\.local\bin\hermes-kokoro-tts.py" --text-file {input_path} --out {output_path} --voice {voice} --speed {speed}` |
| **STT** | `stt.provider: whispercpp` · `stt.language: es` | `"C:\Python314\python.exe" "%USERPROFILE%\.local\bin\hermes-whisper-stt.py" --in {input_path} --out {output_path} --language {language}` |

- `stt.enabled: true` y formato de salida `txt`.
- Atajo `hvoz` (en `%USERPROFILE%\.local\bin`) arranca el CLI con la voz ya puesta; `hermes-voz.py`
  es el ayudante.
- El **modelo** de whisper.cpp y su binario viven en `%USERPROFILE%\.local\bin\whisper.cpp*` y **no**
  van en el ZIP (ver «Requisitos externos»).
- En Linux el equivalente es Kokoro (`~/.local/bin/kokoro-tts`, voz `ef_dora`) + `whisper-stt`.

---

## Modelos y alias

`model.default: deepseek-v4.1-flash` con proveedor **`opencode-go`**. Alias definidos en
`model.aliases` (`/model <alias>` los alterna; `hermes model` los lista):

| Alias | Modelo |
|---|---|
| `local` | `lmstudio/qwen3.8-9b` |
| `local-qwen35` | `lmstudio/qwen3.5-9b` |
| `local-gemma` | `lmstudio/google/gemma-4-e4b` |
| `nvidia` | `nvidia/nvidia/nemotron-3-ultra-550b-a55b` |
| `nemotron-super` | `nvidia/nvidia/nemotron-3-super-120b-a12b` |
| `gpt-oss` | `nvidia/openai/gpt-oss-20b` |
| `glimmer` | `nvidia/meta/muse-glimmer-30b` |
| `lightning` | `nvidia/nvidia/nemotron-3.5-lightning-30b-a3b` |
| `nano-omni` | `nvidia/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` |
| `vision` | `nvidia/meta/llama-3.2-11b-vision-instruct` |
| `multimodal` | `opencode-go/mimo-v2.5` |

- Son **los mismos 11 alias que en Linux** (el repertorio de OpenCode se replica aquí).
- El catálogo de NVIDIA lo filtra el plugin `model-providers` con el whitelist de
  `~/.config/opencode/opencode.json`; los alias NVIDIA se recomponen con `hermes-nvidia-aliases` en
  Linux, no aquí.
- Los alias `local-*` apuntan a LM Studio (`http://127.0.0.1:1234`): si el modelo no está
  descargado, la llamada falla. *(Instantánea 10/10/2026: en Windows solo está `Qwen/Qwen3.8-9B`.)*

### Plugins instalados

En `%LOCALAPPDATA%\hermes\plugins\` *(instantánea 10/10/2026)*:

| Plugin | Estado | Qué aporta |
|---|---|---|
| `model-providers\nvidia` | activo | sustituye el perfil del proveedor NVIDIA y filtra su catálogo con el whitelist de OpenCode (ver arriba) |
| `homeassistant` | **deshabilitado** (10/10/2026) | del catálogo oficial (v2.0.1, pin `ba30cb0cf8`): adaptador de plataforma del gateway (eventos de HA por WebSocket; `cron deliver=homeassistant`) y el toolset `homeassistant` (`ha_list_entities`, `ha_get_state`, `ha_list_services`, `ha_call_service`) |

- Los dos viajan en el ZIP (`plugins\` está en la lista de respaldados).
- `homeassistant` quedó **deshabilitado el 10/10/2026** (`hermes plugins disable homeassistant`;
  `plugins.enabled` vacío y `plugins.disabled: [homeassistant]`). Estaba instalado y habilitado pero
  **sin credenciales** (`HASS_TOKEN` no estaba en el `.env`) y sin ninguna instancia de HA en la red.
  **No se ha desinstalado**: sigue en `plugins\` para cuando se monte Home Assistant. Para
  reactivarlo: crear un token de larga duración en HA, ponerlo en `%LOCALAPPDATA%\hermes\.env`
  (`HASS_TOKEN`, y `HASS_URL` si no es `http://homeassistant.local:8123`) y
  `hermes plugins enable homeassistant`. El cambio entra **al reiniciar la sesión**.


---

## Parches locales del CLI (Ctrl+Q)

El CLI se parchea en local para que **Ctrl+Q corte la locución sin interrumpir el turno** (Ctrl+C
sigue interrumpiendo).

| Pieza | Dónde |
|---|---|
| Parche vivo | `D:\HermesSync\windows\parches\ctrl-q-corta-audio.patch` |
| Parches históricos por commit | `D:\HermesSync\windows\parches\ctrl-q-<commit>.patch` |
| Commit de referencia | `D:\Linux\Config\Hermes-Win\commit-parche.txt` → **`f86276d2eb`** (10/10/2026) |

- El parche **solo aplica en el commit con el que se hizo**; `instalar-desde-cero.ps1` lo detecta y
  fija el commit si el upstream movió esos ficheros.
- Tras un `hermes update`, comprobar que sigue describiendo el árbol y regenerarlo (procedimiento en
  «Actualizar Hermes» de este documento).
- Si no aplica limpio, **no forzarlo**: anotarlo en `NOTA-PARA-LINUX.md` y reconciliar desde Linux.

---

## Herramientas propias y atajos

| Pieza | Qué hace |
|---|---|
| `backup-hermes.ps1` (+ atajos `backup-hermes.cmd` en cmd/PowerShell y `hermes-backup` en git-bash/zsh) | Respaldo del esquema: ZIP + `sesion-hermes\` + copia saneada + réplica en `F:` + copia publicada |
| `sync-hermes.ps1` | El mismo backup en modo silencioso; es lo que corre la tarea de 30 min |
| `check-setup-win.ps1` | Verificación previa; si falla, el backup **aborta** |
| `restaurar-hermes.ps1` / `bootstrap-hermes.ps1` | Restauración desde ZIP / atajo de restauración |
| `instalar-desde-cero.ps1` | Instalación completa en un equipo recién instalado (8 pasos) |
| `registrar-tareas.ps1` | Registra las tareas programadas y los lanzadores de la carpeta Inicio |
| `lanzar-oculto.vbs` + `backup-tarea.cmd` | Lanzadores sin ventana de las tareas |
| `hook-backup-hermes.sh` → `agent-hooks\backup-hermes.sh` | Hook de shell aprobado para `on_session_end`: regenera el backup al cerrar sesión |
| `gateway-service\hermes-ready-notify.ps1` (+ `arranque-ready-notify.vbs`) | Aviso por Telegram cuando el gateway queda listo; log en `logs\ready-notify.log` |
| `dual-boot\` | Motor local del dual boot (`hermes-dual-sync.ps1`, `copiar-state.py`, `publicar.cmd`, `lanzar-oculto.vbs`) |
| `hooks\encargos-windows\` | Hook de gateway que ejecuta los encargos de Linux |
| `extras\bin\` | Scripts propios de voz (`hermes-kokoro-tts.py`, `hermes-whisper-stt.py`, `hermes-voz.py`, `hvoz`, `hvoz.cmd`): se copian al respaldo canónico, a la copia saneada de dotfiles y a la copia publicada (`esquema-windows\extras\bin`) |
| `hermes-auditoria-manual.ps1` | **Auditoría del manual**: lo contrasta con la configuración viva (inventario, tareas, alias, voz, plugins, skills, hooks, cron, parche, copias, espejo y credenciales) |
| Atajos en `%USERPROFILE%\.local\bin` | `hermes-backup`, `hermes-auditoria-win`, `hvoz`, `ocv` / `ocv-local` / `ocv-cloud` / `ocv-status`, `timeline-completo`, `hw_query` |

### Auditoría del manual: `hermes-auditoria-manual`

Es el gemelo de `hermes-auditoria-manual.py` de Linux: contrasta este documento y
`SISTEMA-WINDOWS.md` con la configuración **viva**. Se pasa antes de dar por bueno un cambio del
esquema.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\Linux\Config\Hermes-Win\hermes-auditoria-manual.ps1
hermes-auditoria-win          # el mismo atajo, desde cualquier carpeta
```

- Salida `SIN DESFASES (N comprobaciones)` y código 0; si hay desfases, los lista y sale con 1.
  `-Json` para máquinas.
- Qué comprueba: inventario del esquema (que todo lo que hay esté citado), tareas programadas (y su
  último resultado), alias de modelo, voz, plugins, skills propias, hooks, cron, parche del CLI,
  rutas citadas que deben existir, `documentos\`, las copias (canónica, réplica en `F:` y publicada),
  el espejo de Obsidian y la frontera de credenciales.
- ⚠️ Este `.ps1` va en **UTF-8 con BOM**: PowerShell 5.1 lo leería en ANSI sin BOM y los emojis de
  las rutas del vault romperían el parser (la misma trampa que en los encargos).

---

## Skills propias

- **15 propias** en `skills\autonomous-ai-agents\`: 14 `hermes-*` (`hermes-agent`,
  `hermes-backup-restore`, `hermes-cambio-de-modelo`, `hermes-dual-boot-sync`, `hermes-event-hooks`,
  `hermes-gateway-startup-alert`, `hermes-voz-local-gpu`, `hermes-actualizaciones`,
  `hermes-auditoria-sesiones`, `hermes-diagnostico-arranque`, `hermes-local-surfaces`,
  `hermes-modelos-proveedores`, `hermes-modelos-viables`, `hermes-upstream-pr`) +
  `modelos-locales-dimensionado`; y las 4 de orquestación (`claude-code`, `codex`, `computer-use`,
  `opencode`).
- Es el **mismo repertorio que en Linux**: viajan en el ZIP y, además, por el estado compartido del
  dual boot (`estado\skills\`), así que las dos partes trabajan con las mismas.
- **No se espejan al vault de Obsidian** (a diferencia de los manuales): viven en `skills\` y son
  parte del respaldo.

---

## Inventario del equipo

`SISTEMA-WINDOWS.md` (esta misma carpeta) es el **inventario del equipo visto desde Windows**: CPU,
RAM, GPU, sistema, discos y letras, el espejo LDM, el estado compartido, la configuración viva de
Hermes, las herramientas instaladas, las incidencias y las recomendaciones.

- **Captura vigente: 10/10/2026.** Se regenera con los comandos de su anexo 8.
- Es el gemelo de `SISTEMA-CACHYOS.md` (el que mira desde Linux); entre los dos se cubre el equipo
  completo sin depender del sistema en el que estés.
- **No viaja en el ZIP** (es documentación de referencia, no una pieza de la restauración), pero
  **sí** en la copia saneada de dotfiles y en el vault de Obsidian (carpeta `Hermes-win`).

---

## Documentación de configuración (documentos/)

`Hermes-Win\documentos\` guarda una **copia de respaldo** de los markdown de configuración del
esquema: `AGENTS-WIN.md`, `SISTEMA-WINDOWS.md` y `SOUL.md`.

- **Es copia, no original**: el original de cada documento sigue en su ruta de siempre (`AGENTS-WIN.md`
  y `SISTEMA-WINDOWS.md` en la raíz del esquema; `SOUL.md` en `%LOCALAPPDATA%\hermes\`).
- La regenera `backup-hermes.ps1` en cada pasada (y por tanto `sync-hermes.ps1`, cada 30 min): no
  hay que copiar nada a mano. **Nunca se edita ahí.**
- **Sí viaja a la copia saneada de dotfiles** (como el resto del árbol); **no** va en el ZIP.
- Lectura cómoda: el espejo del vault de Obsidian, carpeta **`Hermes-win`** (skill
  `obsidian-espejo-config` para el procedimiento).

---

## Reglas que NO se deben romper

1. Credenciales **sí** en `Hermes-Win\backups\` y `Hermes-Win\sesion-hermes\` (ACL restringida),
   **nunca** en `dotfiles\hermes-win\` ni en `dotfiles\hermes\`.
2. `state.db` y `sessions\` no entran en el backup de configuración: el histórico viaja por el
   esquema dual boot, no por aquí.
3. Nada de copiar el directorio completo de Hermes: la whitelist y punto.
4. No sustituir `state.db` con Hermes en marcha.
5. La copia saneada sin claves, siempre; el commit/push de dotfiles lo hace Antonio a mano.
6. La réplica en la home de Linux respeta la misma frontera: `Config\Hermes-Win` **sí** lleva
   credenciales (igual que `~/Config/hermes` en Linux) y `dotfiles\hermes-win` **no**, nunca.

> 📁 `%LOCALAPPDATA%\hermes` · `D:\Linux\Config\Hermes-Win` · `D:\Linux\Documentos\dotfiles\hermes-win`
> · `<F:>\@home\antonio\Config\Hermes-Win` · `<F:>\@home\antonio\Documentos\dotfiles\hermes-win`
