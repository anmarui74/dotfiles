# 🔄 Esquema de backup de Hermes Agent en Windows (equivalente al de Linux)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario | 🖥️ Equipo |
|-----------|----------|------------|-----------|
| ✅ activo | 29/09/2026 | Antonio | PC-ANTONIO (Windows 11) |

> Réplica en Windows del esquema de `~/Config/hermes/` de Linux: respaldo canónico, ZIP con
> `restore-win.cmd` dentro, credenciales con permisos restringidos, retención de 30 días y copia
> saneada (sin claves) en dotfiles. Origen: `D:\HermesSync\PARA-WINDOWS-backup.md`.

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
  `commit-parche.txt` (hoy `94f3f170d`) y vuelve a aplicar. Si ni así aplica, hay que portar el parche.
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

Probado el 30/09/2026 (v0.21.5+4202 → v0.21.5+4708, 506 commits):

```powershell
# 1. Guardar el parche aplicado, por si acaso
git -C $env:LOCALAPPDATA\hermes\hermes-agent diff > $env:TEMP\ctrl-q-antes.patch
# 2. Actualizar (deja el parche en un stash y NO lo reaplica: lo portamos a mano después)
hermes update --yes --keep-stash
```

Con el árbol limpio, el updater hace git pull, reinstala dependencias, reconstruye TUI/web y
**vuelve a empaquetar el escritorio** (`apps/desktop/release/win-unpacked`). Reinicia el gateway solo.

Después del update **el parche Ctrl+Q hay que portarlo** (el código cambió en esas zonas). Flujo:
editar `hermes_cli/cli_tui_mixin.py` (`_tui_cut_tts` + llamada en Ctrl+C + Ctrl+Q solo corta TTS) y
`tools/voice_mode.py` (`_playback_interrupted`), verificar y guardar el parche nuevo:

```powershell
python -m py_compile hermes_cli/cli_tui_mixin.py tools/voice_mode.py
git -C <repo> diff > X:\HermesSync\windows\parches\ctrl-q-corta-audio.patch
git -C <repo> apply --reverse --check X:\HermesSync\windows\parches\ctrl-q-corta-audio.patch   # debe pasar
```

Y actualizar `commit-parche.txt` con el commit nuevo (`git rev-parse --short HEAD`), copiar el parche
a `Hermes-Win\parches\` y pasar el check + `sync-hermes.ps1`.

Comprobaciones tras un update:
- `hermes --version`, `hermes doctor`, `hermes hooks doctor` (el hook de cierre sigue allowlisted).
- **Avisos de config**: revisar si algún toolset de `platform_toolsets` ya no existe. Pasó con `stt`
  (desapareció en este update): la lista de la plataforma `cli` se corrigió con
  `hermes config set platform_toolsets.cli "[...]"`. La validación se puede ejecutar sin arrancar
  Hermes con `hermes_cli.toolset_validation.validate_platform_toolsets`.
- Si se usa computer-use: `hermes computer-use install --upgrade` (pide UAC; el updater lo omite).

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

Registro (sin administrador; `schtasks /sc minute` basta, a diferencia de los disparadores
"al iniciar sesión"):

```cmd
schtasks /create /tn HermesBackup-Win /sc minute /mo 30 /tr "powershell -NoProfile -ExecutionPolicy Bypass -File \"X:\Linux\Config\Hermes-Win\sync-hermes.ps1\" -Quiet" /f
schtasks /query /tn HermesBackup-Win
schtasks /run   /tn HermesBackup-Win
```

Retención: 30 días + poda de duplicados del mismo día (se conserva el último ZIP del día).

---

## Reglas que NO se deben romper

1. Credenciales **sí** en `Hermes-Win\backups\` y `Hermes-Win\sesion-hermes\` (ACL restringida),
   **nunca** en `dotfiles\hermes-win\` ni en `dotfiles\hermes\`.
2. `state.db` y `sessions\` no entran en el backup de configuración: el histórico viaja por el
   esquema dual boot, no por aquí.
3. Nada de copiar el directorio completo de Hermes: la whitelist y punto.
4. No sustituir `state.db` con Hermes en marcha.
5. La copia saneada sin claves, siempre; el commit/push de dotfiles lo hace Antonio a mano.

> 📁 `%LOCALAPPDATA%\hermes` · `X:\Linux\Config\Hermes-Win` · `X:\Linux\Documentos\dotfiles\hermes-win`
