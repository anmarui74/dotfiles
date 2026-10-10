# 🔄 Esquema de backup de Hermes Agent en Windows (equivalente al de Linux)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario | 🖥️ Equipo |
|-----------|----------|------------|-----------|
| ✅ activo · rev. 03/10/2026 | 29/09/2026 | Antonio | PC-ANTONIO (Windows 11) |

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
6. [Automatización (tarea programada)](#automatización-tarea-programada)
7. [Reglas que NO se deben romper](#reglas-que-no-se-deben-romper)

---

## Estructura

- `%LOCALAPPDATA%\hermes` → configuración **ACTIVA** (la que usa Hermes; `HERMES_HOME`).
- `X:\Linux\Config\Hermes-Win\` → copia de **SEGURIDAD** para instalaciones desde limpio.
  La letra `X:` del disco SEAGATE cambia entre arranques; se localiza con la marca
  `<letra>:\HermesSync\.hermes-sync` (en este equipo suele ser `D:`).

```
X:\Linux\Config\Hermes-Win\
├── AGENTS-WIN.md            # este documento (reglas del esquema)
├── .gitignore               # se copia a dotfiles (si falta allí, el volcado lo borraría)
├── backup-hermes.ps1        # genera el ZIP + respaldo canónico + copia saneada
├── sync-hermes.ps1          # envoltorio de la tarea programada (cada 30 min)
├── check-setup-win.ps1      # verificación previa (aborta el backup si falla)
├── restaurar-hermes.ps1     # instalación desde limpio / restauración
├── bootstrap-hermes.ps1     # atajo al instalador desde limpio
├── backups\                 # zips hermes-win-backup-AAAAMMDD-HHMMSS.zip (ACL restringida)
├── sesion-hermes\           # respaldo canónico + instalador (config, .env, auth.json, SOUL)
└── sync.log                 # histórico de sincronizaciones

X:\Linux\Documentos\dotfiles\hermes-win\   # copia SANEADA (sin claves), se versiona en git
```

Réplica en la home de Linux (partición btrfs de CachyOS vista con WinBtrfs; la letra cambia):

```
<F:>\@home\antonio\Config\Hermes-Win\                    # espejo del respaldo canónico (con credenciales)
<F:>\@home\antonio\Documentos\dotfiles\hermes-win\       # espejo de la copia saneada (repo git de dotfiles)
```

Nunca tocar `X:\Linux\Documentos\dotfiles\hermes\` (sin `hermes-win`): esa es la de Linux.

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
- **NUNCA** deben estar en `X:\Linux\Documentos\dotfiles\`. Esa es la frontera real.
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
powershell -ExecutionPolicy Bypass -File X:\Linux\Config\Hermes-Win\backup-hermes.ps1
```
Antes de copiar nada ejecuta `check-setup-win.ps1`; si el esquema no está correcto, el backup se
**aborta** para no guardar un setup defectuoso.

### Sincronización + backup (lo que corre la tarea programada)
```powershell
powershell -ExecutionPolicy Bypass -File X:\Linux\Config\Hermes-Win\sync-hermes.ps1 -Quiet
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
powershell -ExecutionPolicy Bypass -File X:\Linux\Config\Hermes-Win\instalar-desde-cero.ps1
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
  `commit-parche.txt` (hoy `bd0affe5e`) y vuelve a aplicar. Si ni así aplica, hay que portar el parche.
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
powershell -ExecutionPolicy Bypass -File X:\Linux\Config\Hermes-Win\bootstrap-hermes.ps1
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
git -C <repo> apply --reverse --check X:\HermesSync\windows\parches\ctrl-q-corta-audio.patch   # exit 0
python -m py_compile hermes_cli/cli_tui_mixin.py tools/voice_mode.py                          # sin salida
git -C <repo> diff > X:\HermesSync\windows\parches\ctrl-q-corta-audio.patch                   # regenerar (blobs nuevos)
git -C <repo> rev-parse --short HEAD > X:\Linux\Config\Hermes-Win\commit-parche.txt           # commit de referencia
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
powershell -ExecutionPolicy Bypass -File X:\Linux\Config\Hermes-Win\restaurar-hermes.ps1 `
    -Destino "$env:TEMP\restore-hermes"
```

Sin argumentos restaura sobre `%LOCALAPPDATA%\hermes` (la instalación activa). `-SoloSesion`
restaura únicamente el respaldo canónico. El script repone `.env` y `auth.json` con ACL
restringida y verifica los ficheros críticos al terminar.

---

## Automatización (tarea programada)

| Momento | Linux | Windows |
|---|---|---|
| Cada 30 min | `hermes-sync.timer` (systemd de usuario) | tarea `HermesBackup-Win` → `sync-hermes.ps1 -Quiet` |
| Al cerrar sesión de Hermes | hook `on_session_end` | encadenado a la publicación del dual boot (`HermesSync-Publicar`) |

Cada una de esas ejecuciones refresca también la réplica en la home de Linux (F:) descrita arriba,
así que lo que viaja al disco de Linux va dentro del mismo backup verificado.

Registro (sin administrador; `schtasks /sc minute` basta, a diferencia de los disparadores
"al iniciar sesión"):

```cmd
schtasks /create /tn HermesBackup-Win /sc minute /mo 30 /tr "powershell -NoProfile -ExecutionPolicy Bypass -File \"X:\Linux\Config\Hermes-Win\sync-hermes.ps1\" -Quiet" /f
schtasks /query /tn HermesBackup-Win
schtasks /run   /tn HermesBackup-Win
```

Retención: 30 días + poda de duplicados del mismo día (se conserva el último ZIP del día).

---

## Motor del dual boot en este equipo (copia local)

El motor que **ejecuta** Windows es la copia local `%LOCALAPPDATA%\hermes\dual-boot\`
(`hermes-dual-sync.ps1` + `copiar-state.py`), no la distribuida en `X:\HermesSync\windows\`. Es a
propósito: así una republicación desde Linux no revierte los arreglos hechos aquí.

Cuando Linux publique cambios del motor, pasarlos a la copia local (sin administrador):

```powershell
powershell -ExecutionPolicy Bypass -File X:\HermesSync\windows\actualizar-motor-local.ps1 -SoloEstado
powershell -ExecutionPolicy Bypass -File X:\HermesSync\windows\actualizar-motor-local.ps1
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

> 📁 `%LOCALAPPDATA%\hermes` · `X:\Linux\Config\Hermes-Win` · `X:\Linux\Documentos\dotfiles\hermes-win`
> · `<F:>\@home\antonio\Config\Hermes-Win` · `<F:>\@home\antonio\Documentos\dotfiles\hermes-win`
