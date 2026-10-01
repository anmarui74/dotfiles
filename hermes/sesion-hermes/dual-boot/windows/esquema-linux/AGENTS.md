# 🔄 Esquema de backup de Hermes Agent (equivalente al de OpenCode)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ activo | 28/09/2026 · rev. 28/09/2026 | Antonio |

> Réplica del esquema de backup de OpenCode (`~/Config/opencode/AGENTS.md`) para Hermes:
> respaldo canónico, tarball con `restore.sh` dentro, credenciales en 0600, retención de 30
> días y copia saneada en dotfiles.

---

## 📑 Índice
1. [Estructura](#estructura)
2. [Qué se respalda y qué no](#qué-se-respalda-y-qué-no)
3. [Credenciales y claves de API](#credenciales-y-claves-de-api)
4. [Procedimientos](#procedimientos)
5. [Restauración](#restauración)
6. [Automatización (systemd)](#automatización-systemd)
7. [Dual boot Linux ↔ Windows](#dual-boot-linux--windows)
8. [Reglas que NO se deben romper](#reglas-que-no-se-deben-romper)

---

## Estructura

- `~/.hermes/` → configuración **ACTIVA** (la que usa Hermes)
- `~/Config/hermes/` → copia de **SEGURIDAD** para instalaciones desde limpio

```
~/Config/hermes/
├── AGENTS.md                     # este documento (reglas del esquema)
├── backup-hermes.sh              # genera el tarball + restore.sh + copia dotfiles
├── sync-hermes.sh                # sincroniza y regenera backup (systemd cada 30 min)
├── check-setup-completo.sh       # verificación automática (aborta el backup si falla)
├── bootstrap-hermes.sh           # atajo al instalador desde limpio
├── setup-hermes-completo.sh      # enlace simbólico → sesion-hermes/
├── backups/hermes/               # tarballs hermes-backup-*.tar.gz (0600, dir 0700)
├── dual-boot/                    # estado compartido Linux ↔ Windows (ver sección propia)
│   ├── hermes-dual-sync.sh       # motor de sincronización (Linux); enlace en ~/.local/bin
│   └── instalar-montaje.sh       # montaje permanente del disco compartido (pkexec)
├── sesion-hermes/                # respaldo canónico + instalador (única copia del setup)
└── sync.log                      # histórico de sincronizaciones
```

En `~/Documentos/dotfiles/hermes/` va la copia **SANEADA** (sin claves) que se versiona en el
repo `anmarui74/dotfiles`. El commit/push lo hace Antonio a mano (el script solo deja la copia).

---

## Qué se respalda y qué no

| ✅ Se respalda | ❌ NO se respalda (regenerable o voluminoso) |
|---|---|
| `config.yaml`, `SOUL.md`, `install_id`, `channel_directory.json` | `hermes-agent/` (clon git de ~810 MB, se reclona solo) |
| `skills/`, `plugins/`, `hooks/`, `pets/`, `skins/`, `tui-widgets/`, `desktop-plugins/` | `tools/` e `installs/` (~3 GB de descargas gestionadas por Hermes) |
| `memories/` (`MEMORY.md`, `USER.md`) | `cache/`, `audio_cache/`, `image_cache/`, `models_dev_cache.json` |
| `cron/` (trabajos, sin la BD de ejecuciones) | `state.db*` y `sessions/` (histórico de conversaciones) |
| `kanban.db` (copia con `sqlite3 .backup`) | `logs/`, `runtime/`, `sandboxes/`, `terminal-sessions/` |
| `credenciales/` → `.env` + `auth.json` (0600) y `shared/` (auth del Portal Nous) | clones temporales `.hermes-clone-*`, `pairing/`, `pending_messages/`, `state/` |
| `extras/bin/` → stack de voz (`kokoro-tts`, `whisper-stt`, `whisper-cli`, `hermes-voz`…) | ficheros `.lock`, `.pid`, `.sock` |

El tarball resultante pesa unos pocos MB (frente a los ~3 GB del directorio completo).

---

## Credenciales y claves de API

- Las claves viven en `~/.hermes/.env` y los tokens OAuth de proveedores en `~/.hermes/auth.json`.
  `~/.hermes/shared/nous_auth.json` guarda el token del Portal Nous (access + refresh).
- **SÍ deben estar** dentro del tarball de `~/Config/hermes/backups/hermes/`: es la copia de
  restauración y las necesita. Por eso el tarball se crea con `umask 077` + `chmod 600` y su
  directorio con `chmod 700`.
- **NUNCA** deben estar en `~/Documentos/dotfiles/`. Esa es la frontera real.
- Antes de commitear la copia de dotfiles, verificar:

```bash
cd ~/Documentos/dotfiles
git grep -nIP '(nvapi-|oc_sk_)[A-Za-z0-9_-]{15,}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{25,}|AEMET_API_KEY=[A-Za-z0-9]{15,}|NVIDIA_API_KEY=[A-Za-z0-9_-]{15,}|OPENCODE_GO_API_KEY=[A-Za-z0-9_-]{15,}' -- ':(exclude)*.md'
```

Si devuelve algo, NO hacer commit/push y borrar el fichero.

---

## Procedimientos

### Backup manual
```bash
bash ~/Config/hermes/backup-hermes.sh
```
Antes de copiar nada ejecuta `check-setup-completo.sh`; si el esquema no está correcto,
el backup se **aborta** para no guardar un setup defectuoso.

### Sincronización + backup
```bash
bash ~/Config/hermes/sync-hermes.sh          # con salida
bash ~/Config/hermes/sync-hermes.sh --quiet  # vía systemd
```

### Instalación desde limpio
```bash
bash ~/Config/hermes/setup-hermes-completo.sh   # o bootstrap-hermes.sh
```
Instala Hermes si falta, restaura el último tarball (o `sesion-hermes/`), recoloca los scripts
de voz y verifica `config.yaml`, `.env`, `auth.json`, `SOUL.md`, `memories/` y `skills/`.

### Al modificar la configuración de Hermes
1. Los cambios se hacen en `~/.hermes/` (activo) con `hermes config set` (nunca a mano en `config.yaml`).
2. Ejecutar `bash ~/Config/hermes/sync-hermes.sh` → refresca `sesion-hermes/` y regenera el tarball.
3. Si el cambio afecta a la restauración, actualizar `sesion-hermes/setup-hermes-completo.sh`.

---

## Restauración

Desde un tarball:
```bash
mkdir -p /tmp/restore-hermes
tar -xzf ~/Config/hermes/backups/hermes/hermes-backup-AAAAmmdd-HHMMSS.tar.gz -C /tmp/restore-hermes
bash /tmp/restore-hermes/hermes-backup-*-restore.sh
hermes doctor
```

El `restore.sh` restaura la configuración y los datos en `~/.hermes/`, devuelve `.env` y
`auth.json` a su sitio con permisos 600 y repone los scripts de voz en `~/.local/bin/`.

---

## Automatización (systemd)

- `~/.config/systemd/user/hermes-sync.service` → ejecuta `sync-hermes.sh --quiet`
- `~/.config/systemd/user/hermes-sync.timer` → cada 30 minutos (`OnBootSec=5min`, `OnUnitActiveSec=30min`)

```bash
systemctl --user status hermes-sync.timer
systemctl --user list-timers hermes-sync.timer
tail -20 ~/Config/hermes/sync.log
```

Retención: `LOG_RETENTION_DAYS` (por defecto 30 días) y poda diaria (se conserva el último
tarball de cada día).

---

## Dual boot Linux ↔ Windows

Los dos sistemas comparten **un mismo estado de Hermes** (conversaciones, memoria, skills,
cron, kanban) a través de la carpeta `HermesSync/` del disco SEAGATE
(`/mnt/seagate/HermesSync` en Linux, `E:\HermesSync` en Windows). Nunca están encendidos a
la vez, así que la regla es **el último que publica manda**, con historial y copia previa.

| Pieza | Linux | Windows |
|---|---|---|
| Directorio activo | `~/.hermes` | `%LOCALAPPDATA%\hermes` |
| Motor | `~/Config/hermes/dual-boot/hermes-dual-sync.sh` (atajo `hermes-dual-sync`) | `E:\HermesSync\windows\hermes-dual-sync.ps1` |
| Publica | hook `on_session_end` + timer cada 10 min + al apagar | tarea `HermesSync-Publicar` cada 5 min |
| Importa | unidad de usuario al arrancar (antes del gateway) | tarea `HermesSync-Importar` al iniciar sesión |
| Config | `~/.config/hermes-dual-sync.conf` | parámetro `-Comun` / autodetección |

- Montaje del disco compartido: `/etc/fstab` → `UUID=A472BB2A72BB005A /mnt/seagate ntfs3 …nofail,x-systemd.automount`
  (instalado con `pkexec bash ~/Config/hermes/dual-boot/instalar-montaje.sh`).
- Unidades: `~/.config/systemd/user/hermes-dual-sync-{import,export,apagado}.service` y `hermes-dual-sync.timer`.
  El timer lleva `Unit=hermes-dual-sync-export.service` porque el servicio no comparte nombre base con él.
- El hook vive en `~/.hermes/agent-hooks/dual-sync-publicar.sh` y está anotado en
  `~/.hermes/shell-hooks-allowlist.json` (si se edita el script hay que volver a aprobarlo).
- Documento de usuario para Windows: `HermesSync/LEEME.md`.
- **Nota de traspaso al Hermes de Windows**: `HermesSync/PARA-WINDOWS-backup.md` (copia en
  `windows/`, con el esquema de Linux en `windows/esquema-linux/`) le encarga montar su propio
  esquema de backup con destino en el disco compartido: respaldo canónico en
  `X:\Linux\Config\Hermes-Win\` y copia saneada sin claves en
  `X:\Linux\Documentos\dotfiles\hermes-win\`. Al terminar debe dejar constancia en
  `HermesSync/NOTA-PARA-LINUX.md`.

Comandos: `hermes-dual-sync estado|import|export|listar-historico|restaurar <equipo> <epoch>`
(`--quiet`, `--forzar`, `--reiniciar-gateway`, `--solo-si-cambia`, `--comun <ruta>`).

Pitfalls que ya han mordido:

- **Nunca `exec … 2>/dev/null` en el motor**: redirige el stderr del shell para el resto de la
  ejecución y los mensajes de error desaparecen (parecía que el script "moría sin decir nada").
- **Windows con "inicio rápido"** deja las particiones NTFS marcadas: Linux las monta en solo
  lectura y la publicación se omite con aviso. Desactivar el inicio rápido.
- **El disco compartido tarda en montarse y el import de arranque lo pillaba sin montar**: está en
  fstab con `x-systemd.automount`, así que el NTFS sólo se monta cuando alguien toca
  `/mnt/seagate`. Caso real del 29/09/2026: arranque 10:44:13 → import 10:44:26 → montaje real
  10:47:43; el import no hizo nada y, con `--quiet`, salió con éxito en silencio (indistinguible de
  un import correcto: `estado` decía "Última importación: nunca"). Arreglado por dos vías: el
  motor fuerza el acceso al punto de montaje y espera hasta 12 s (`ls` dispara el automount), y la
  unidad de import lleva `RequiresMountsFor=/mnt/seagate`. Además el aviso de "disco no montado"
  ahora se escribe siempre en stderr, aunque vaya con `--quiet`, para que quede en el journal.
- **Comprobar que el import de arranque hizo su trabajo**: `journalctl --user -u hermes-dual-sync-import.service`
  sólo dice "Starting/Finished" (el script calla con `--quiet`); la prueba de verdad es
  `hermes-dual-sync estado` → "Última importación" y `~/.hermes/.dual-sync/estado.json`. Si dicen
  "nunca" tras cambiar de sistema, el estado del otro equipo está sólo en `historial/<equipo>/`.
- **No sustituir `state.db` con Hermes en marcha** — ni el gateway ni una sesión abierta
  (CLI, escritorio). El caso real del 28/09/2026: la importación de arranque coincidió con el
  arranque de Hermes, la base se sustituyó con la aplicación viva y quedó ilegible
  (`database disk image is malformed`); hubo que restaurar la publicación del historial y
  copiar aparte las sesiones del otro sistema. Los motores ya lo detectan (Linux: `lsof`;
  Windows: `Test-HermesVivo`, que pregunta por CIM a cualquier proceso de Hermes, con una
  segunda comprobación justo antes de copiar y verificación de integridad después). Si aun así
  pasa: parar Hermes, restaurar la publicación buena del historial
  (`hermes-dual-sync restaurar <equipo> <epoch>`) y fusionar las sesiones del otro sistema
  desde su copia, nunca al revés.
- **La semilla lleva claves en claro** (`.env`, `auth.json`): se genera **solo a petición**
  (`hermes-dual-sync semilla` en Linux, `-Accion semilla` en Windows) y se aplica una única vez
  en el otro sistema (`%LOCALAPPDATA%\hermes\.dual-sync\semilla-aplicada.json`). Antes se
  recreaba sola cuando faltaba, así que borrarla no servía de nada: reaparecía con las claves
  en pocos minutos. Borrarla cuando ya esté aplicada.
- **Los scripts de Windows no se ejecutan desde la carpeta común**: Windows usa su copia en
  `%LOCALAPPDATA%\hermes\dual-boot\`. La carpeta común es distribución/referencia, así que una
  publicación desde Linux no revierte los arreglos hechos en Windows — pero conviene mantener
  la copia de `~/Config/hermes/dual-boot/windows/` igual que la común (el `rsync -au` del
  export solo actualiza lo que es más nuevo en origen).

---

## Reglas que NO se deben romper

1. El instalador desde limpio vive **solo** en `sesion-hermes/` (más el enlace simbólico en la raíz).
2. Nunca copiar `.env`, `auth.json`, `credenciales/` ni `*.tar.gz` a `~/Documentos/dotfiles/`.
3. Usar `rsync --delete --delete-excluded` en la copia de dotfiles: con solo `--delete`, lo
   excluido se acumula en el destino.
4. El tarball se crea siempre con `umask 077` y se deja en 600.
5. No meter en el backup `state.db`, `sessions/`, `tools/`, `installs/` ni `hermes-agent/`.

> 📁 `~/.hermes/` · `~/Config/hermes/` · `~/Documentos/dotfiles/hermes/`
