# 🔄 Esquema de backup de Hermes Agent (equivalente al de OpenCode)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ activo | 30/09/2026 · rev. 30/09/2026 | Antonio |

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
6. [Requisitos externos (no viajan en el tarball)](#requisitos-externos-no-viajan-en-el-tarball)
7. [Automatización (systemd)](#automatización-systemd)
8. [Aviso de arranque del gateway](#aviso-de-arranque-del-gateway)
9. [Voz local (Kokoro TTS + whisper STT)](#voz-local-kokoro-tts--whisper-stt)
10. [Comprobar qué modelos son viables como agente](#comprobar-qué-modelos-son-viables-como-agente)
11. [Parches locales del CLI](#parches-locales-del-cli-ctrlq-corta-el-audio-ctrlc-lo-corta-e-interrumpe)
12. [Dual boot Linux ↔ Windows](#dual-boot-linux--windows)
13. [Herramientas propias: parche, unidades y atajos](#herramientas-propias-parche-del-cli-unidades-systemd-y-atajos)
14. [Skills propias](#skills-propias)
15. [Reglas que NO se deben romper](#reglas-que-no-se-deben-romper)

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
│   ├── windows/                  # material para el Hermes de Windows (lo publica el export)
│   └── instalar-montaje.sh       # montaje permanente del disco compartido (pkexec)
├── units/                        # unidades systemd de usuario propias (backup, LM Studio, alias NVIDIA, aviso de arranque)
├── parches/                      # parches locales del CLI (Ctrl+Q corta la locución sin interrumpir el turno)
├── hermes-parche-ctrlq.sh        # estado / aplicar / revertir el parche del CLI
├── lm-studio-watchdog.sh         # vigilante del "servidor mudo" de LM Studio
├── hermes-nvidia-aliases.{sh,py} # recompone los alias NVIDIA desde el whitelist de OpenCode
├── logs/                         # logs de las utilidades propias (alias, modelos viables, watchdog, parches)
├── state/                        # estado efímero de esas utilidades (p. ej. alias NVIDIA aplicados)
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
bash ~/Config/hermes/setup-hermes-completo.sh                 # completo (voz + LM Studio + dock)
bash ~/Config/hermes/setup-hermes-completo.sh --con-modelos    # además baja los ~21 GB de modelos
bash ~/Config/hermes/setup-hermes-completo.sh --sin-externos   # solo config, datos y esquema
```
Instala Hermes si falta, restaura el último tarball (o `sesion-hermes/`), recoloca los scripts
de voz y verifica `config.yaml`, `.env`, `auth.json`, `SOUL.md`, `memories/` y `skills/`.
Repone además lo que no cabe en el tarball: el stack de voz (PASO 5c), LM Studio con su ajuste de
contexto y la entrada ancla del dock (PASO 5d) — ver [Requisitos externos](#requisitos-externos-no-viajan-en-el-tarball).
Los modelos de LM Studio solo se descargan con `--con-modelos` o confirmándolo por teclado;
`--sin-externos` omite los PASOS 5c y 5d (útil sin NVIDIA, sin red o para pruebas).

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
El tarball incluye bajo `esquema/` el propio instalador, el parche del CLI, las unidades
systemd (incluidas las del dual boot) y el esquema de dual boot.

---

## Requisitos externos (no viajan en el tarball)

El tarball pesa ~1 MB: lleva configuración, datos y scripts, pero **no** las dependencias
pesadas ni los paquetes del sistema. Para que una instalación desde limpio quede igual que
este equipo hay que reponerlas aparte. El instalador ya lo hace (PASOS 1, 5c y 5d).

| Pieza | Dónde vive | Cómo se repone |
|---|---|---|
| Paquetes del sistema | pacman | `sudo pacman -S --needed python313 cmake cuda ffmpeg sox nodejs` |
| Stack de voz: venv de Kokoro + modelos y whisper.cpp con CUDA + modelo | `~/.local/share/tts-local/`, `~/.local/share/kokoro/`, `~/.local/share/whisper-cpp/` | `bash ~/Config/hermes/instalar-stack-voz.sh` (~1,5 GB; whisper lo delega en `~/Config/opencode/bootstrap-ocv.sh`) |
| LM Studio (app) | `/usr/bin/lm-studio` (paquete AUR `lmstudio-bin`) | El setup lo instala solo con `yay`/`paru` (`-S --noconfirm --needed lmstudio-bin`; pedirá sudo). A mano: `yay -S lmstudio-bin` |
| Modelos de LM Studio (alias `local`, `local-qwen35`, `local-gemma`) | `~/.lmstudio/models/` (~21 GB) | `lms get qwen3.8-9b@q6_k`, `lms get qwen3.5-9b@q6_k`, `lms get google/gemma-4-e4b@q4_k_m` — o `setup-hermes-completo.sh --con-modelos` (sin preguntar) |
| `defaultContextLength` de LM Studio ≥ 65536 | `~/.lmstudio/settings.json` | El setup lo ajusta a 81920 (con copia `.bak`); sin él Hermes rechaza el modelo local como principal |
| Entrada ancla del dock de GNOME en XWayland | `~/.local/share/applications/hermes.desktop` | La crea el PASO 5d (temporal, hasta que entre el PR upstream #129373) |
| Gateway de mensajería | unidad `hermes-gateway.service` | `hermes gateway start` (el CLI crea y habilita la unidad) |

Comprobar sin instalar nada:
```bash
bash ~/Config/hermes/instalar-stack-voz.sh --comprobar
bash ~/Config/hermes/check-setup-completo.sh   # su sección 8 avisa de lo que falte
```

⚠️ Al probar el instalador con un HOME aislado (`HOME=/tmp/x bash setup-hermes-completo.sh`),
si se invoca el CLI real con ese HOME, **se reescriben los shims del runtime real**
(`~/.hermes/hermes-agent/.hermes/bin/hermes` y `hermes-acp`) apuntando al python del HOME de
prueba, y `hermes` deja de arrancar. En pruebas: pon un `hermes` simulado en el `PATH` o revisa
`head -2` de esos shims después y restaura la ruta real (`~/.hermes/tools/python-*/bin/python3`).

---

## Automatización (systemd)

Unidades de usuario del esquema (copia en `~/Config/hermes/units/`; las del dual boot, en
`dual-boot/systemd-user/`):

| Unidad | Qué hace |
|---|---|
| `hermes-sync.service` + `.timer` | sincroniza `sesion-hermes/`, la copia saneada de dotfiles y regenera el tarball cada 30 minutos (`OnBootSec=5min`, `OnUnitActiveSec=30min`) |
| `lm-studio-app.service` | LM Studio en **modo servicio (sin ventana)**, sirviendo el API local en el 1234 |
| `lm-studio-gui.service` | LM Studio **con ventana**, a demanda con el atajo `lm-studio-gui` (no se habilita) |
| `lm-studio-watchdog.service` + `.timer` | vigila el «servidor mudo» de LM Studio cada 5 min |
| `hermes-nvidia-aliases.path` + `.service` | recompone los alias NVIDIA cuando cambia el whitelist de OpenCode |
| `hermes-ready-notify.service` | aviso por Telegram cuando el gateway está listo (sección propia más abajo) |
| `hermes-dual-sync-{import,export,apagado}.service` + `.timer` | estado compartido con Windows (ver «Dual boot») |
| `hermes-gateway.service` | **del propio Hermes**, no del esquema: la recrea `hermes gateway install` |

```bash
systemctl --user status hermes-sync.timer
systemctl --user list-timers hermes-sync.timer
tail -20 ~/Config/hermes/sync.log
```

Retención: `LOG_RETENTION_DAYS` (por defecto 30 días) y poda diaria (se conserva el último
tarball de cada día).

---

## Aviso de arranque del gateway

Antonio quiere saber cuándo queda disponible Hermes al encender o reiniciar el PC.

- Script: `~/.local/bin/hermes-ready-notify.sh` (viaja en `extras/bin/` del tarball y de
  `sesion-hermes/`).
- Unidad: `hermes-ready-notify.service` (`oneshot`, `After=hermes-gateway.service`,
  `WantedBy=default.target`; copia en `units/`).
- Flujo: espera hasta `HERMES_READY_TIMEOUT` (180 s por defecto) a que el servicio del gateway esté
  `active` **y** el log muestre la conexión de Telegram posterior al arranque; entonces envía el
  mensaje por la API de Telegram al `TELEGRAM_HOME_CHANNEL` del `.env`. El token nunca va en `argv`
  (se pasa a `curl` por stdin) para que no aparezca en `ps` ni en los logs.
- **No duplica el aviso nativo**: en reinicios planificados (`/restart`, `hermes update`) el propio
  gateway ya avisa vía `~/.hermes/.restart_notify.json` / `.restart_pending.json`; con esos
  marcadores el script calla.
- Prueba real: `systemctl --user start hermes-ready-notify.service` (envía el mensaje) o
  `DRY_RUN=1 ~/.local/bin/hermes-ready-notify.sh` (lo imprime sin enviarlo). **Nunca reiniciar
  `hermes-gateway` desde una sesión propia del gateway**: el drain espera al turno en curso y acaba
  en SIGTERM a los 70 s.
- Detalle completo: skill `hermes-gateway-startup-alert`.

---

## Voz local (Kokoro TTS + whisper STT)

Todo local y en CUDA, sin nube (skill `hermes-voz-local-gpu`):

- **TTS**: proveedor de tipo comando en `tts.providers.kokoro` de `~/.hermes/config.yaml` →
  `~/.local/bin/kokoro-tts --text-file {input_path} --out {output_path} --voice {voice}`, voz
  `ef_dora` (española), salida WAV y `tts.provider: kokoro`.
- **STT**: `~/.local/bin/whisper-stt` (envuelve el build CUDA de whisper.cpp, modelo
  `ggml-large-v3-turbo-q5_0.bin`, idioma `es` por defecto) declarado como proveedor STT de tipo
  comando. `hermes-voz` arranca el CLI e inyecta `/voice on`.
- Los scripts (`kokoro-tts`, `whisper-stt`, `whisper-cli`, `hermes-voz` y, si están,
  `speak-kokoro*`) viajan en `extras/bin/` del tarball y de `sesion-hermes/`. **El modelo y el
  binario de whisper.cpp no** (viven en `~/.local/share/whisper-cpp/`): una instalación desde limpio
  repone los scripts, pero hay que volver a descargar el modelo.
- La locución se corta con `ctrl+q` (solo calla la voz) o `ctrl+c` (corta e interrumpe el turno):
  ver «Parches locales del CLI».

---

## Comprobar qué modelos son viables como agente

`hermes-modelos-viables` (`hermes-modelos-viables.sh` + `hermes-modelos-viables.py`, atajo en
`~/.local/bin`) aplica la misma metodología que el `check-nvidia-whitelist.sh` de OpenCode: un
modelo sólo sirve como agente si responde con HTTP 200 real, genera a ≥ 10 tok/s (configurable) y
emite **tool calling** de verdad.

```bash
hermes-modelos-viables              # locales de LM Studio + whitelist de NVIDIA
hermes-modelos-viables --local      # solo LM Studio
hermes-modelos-viables --nvidia     # solo NVIDIA
hermes-modelos-viables --modelo qwen3.8-9b --json
```

- Los locales se descubren por **sondeo en vivo** (`http://127.0.0.1:1234/v1/models`), igual que el
  selector de Hermes: si el servidor de LM Studio no está arrancado (`lms server start`), el
  proveedor `lmstudio` se queda sin modelos y no aparece utilizable.
- El whitelist de NVIDIA se lee de `~/.config/opencode/opencode.json` (una sola fuente de verdad);
  las claves salen de `~/.hermes/.env` (`NVIDIA_API_KEY`; `LM_API_KEY` es opcional en LM Studio).
- Log en `~/Config/hermes/logs/modelos-viables.log` (la carpeta `logs/` queda excluida de la copia
  de dotfiles).

### Modelos en uso (réplica del esquema de OpenCode)

Los modelos se alternan con `/model <alias>`. Los alias viven en `model.aliases` de
`~/.hermes/config.yaml` y replican el repertorio de OpenCode (`~/.config/opencode/opencode.json`:
whitelist NVIDIA + proveedor `local` + `opencode-go`). En Hermes los alias se consultan **antes**
que el catálogo de models.dev, que es justo lo que hace el plugin `nvidia-filter` en OpenCode
(ocultar modelos NVIDIA retirados):

| Alias | Modelo en Hermes | Equivalente en OpenCode |
|---|---|---|
| `local` | `lmstudio/qwen3.8-9b` | proveedor `local` (agentes `local`, `title`) |
| `local-qwen35` | `lmstudio/qwen3.5-9b` | descargado en LM Studio |
| `local-gemma` | `lmstudio/google/gemma-4-e4b` | descargado en LM Studio (único con visión) |
| `nvidia` | `nvidia/nvidia/nemotron-3-ultra-550b-a55b` | agente `nvidia` |
| `nemotron-super` | `nvidia/nvidia/nemotron-3-super-120b-a12b` | whitelist |
| `gpt-oss` | `nvidia/openai/gpt-oss-20b` | whitelist |
| `glimmer` | `nvidia/meta/muse-glimmer-30b` | whitelist |
| `lightning` | `nvidia/nvidia/nemotron-3.5-lightning-30b-a3b` | whitelist |
| `nano-omni` | `nvidia/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` | whitelist |
| `vision` | `nvidia/meta/llama-3.2-11b-vision-instruct` | whitelist |
| `multimodal` | `opencode-go/mimo-v2.5` | agente `multimodal` |

Requisito que vive **fuera** del backup de Hermes (es config de LM Studio, no de Hermes):
`defaultContextLength` en `~/.lmstudio/settings.json` debe ser ≥ 65536; aquí está en 81920 (es lo
que declara OpenCode para `qwen3.8-9b` y cabe con los tres locales en 16 GB: gemma-4-e4b 6,7 GB,
qwen3.8-9b 11,5 GB). Hermes exige 64 000 tokens de ventana; con el valor de fábrica (8192) rechaza
el local como modelo principal y deja inservible el escalón `lmstudio` de la cadena de respaldo
(cae al escalón anterior).

**Regla al cargar un modelo en LM Studio**: primero VRAM limpia (`lms unload --all`, y comprobar
que no queda un `llama-server` huérfano con `nvidia-smi --query-compute-apps=pid,used_memory
--format=csv`). Con otro modelo residente, una carga que cabe de sobra falla con `cudaMalloc
failed: out of memory` — y ese error es engañoso: no significa que la ventana pedida no quepa.
Procedimiento y trampas: skill `hermes-cambio-de-modelo`.

### El selector sigue el whitelist de NVIDIA (plugin) y los alias se recompensan solos

`hermes model` y `/model` mostraban los 82 modelos NVIDIA del catálogo. Ahora la lista sale del
whitelist de OpenCode, por dos piezas que se mantienen solas:

| Pieza | Qué hace |
|---|---|
| `~/.hermes/plugins/model-providers/nvidia/` | Perfil de proveedor que sustituye al de serie y filtra el catálogo con `providers.nvidia.whitelist` de `~/.config/opencode/opencode.json`. Equivalente al plugin `nvidia-filter` de OpenCode. El whitelist se **relee en cada consulta**: si el timer quincenal retira un modelo, la lista de Hermes cambia sola. También alinea la lista curada del repo (`_PROVIDER_MODELS`) para que no se cuelen modelos retirados. |
| `hermes-nvidia-aliases` (`~/Config/hermes/hermes-nvidia-aliases.{py,sh}`, atajo en `~/.local/bin`) | Recompone los alias cortos (`nvidia`, `gpt-oss`, `glimmer`…) desde el whitelist: añade los nuevos (nombre derivado, avisado en el log), retira los que salen y nunca toca alias ajenos (`local`, `multimodal`…). Estado en `state/nvidia-aliases.json`, log en `logs/nvidia-aliases.log`. |

- Disparador: la unidad de usuario **`hermes-nvidia-aliases.path`** vigila
  `~/.config/opencode/opencode.json`: cuando `check-nvidia-whitelist.sh` (días 1 y 16, vía
  `check-nvidia-whitelist.timer`) reescribe el whitelist, el servicio `hermes-nvidia-aliases.service`
  recompone los alias al momento. No se ha tocado ninguna unidad de OpenCode.
- A mano: `hermes-nvidia-aliases` (o `--dry-run` para ver qué haría, `--json` para máquinas).
- Las dos unidades tienen copia en `~/Config/hermes/units/` para una reinstalación desde limpio:
  `cp ~/Config/hermes/units/hermes-nvidia-aliases.* ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable --now hermes-nvidia-aliases.path`.
- Si algún día la caché de catálogos está vacía, la primera apertura de `/model` puede mostrar la
  lista curada del repo hasta que el refresco en segundo plano llega; `/model --refresh` lo fuerza.

### LM Studio: la app y el servicio headless no caben a la vez

`lms server start` levanta un LM Studio **headless** que se queda con el perfil de la app
(`~/.config/LM Studio/SingletonLock -> cachyos-<pid>`). Con ese candado vivo, al abrir la ventana
de LM Studio su lista de modelos aparece **vacía**, aunque los ficheros, el índice (`model-index-cache.json`),
`lms ls` y la API sigan viendo los 4 modelos. Diagnóstico rápido: `ls -la ~/.config/"LM Studio"/SingletonLock`
y comparar con `pgrep -af "lm-studio"`.

Receta — ya automatizada, no hay que hacerla a mano: el arranque de sesión usa el **modo servicio**
(subsección siguiente) y, para ver la interfaz, el atajo `lm-studio-gui` para ese modo y abre la
ventana; al cerrarla vuelve el modo servicio. Tampoco hace falta `lms server start` ni
`lms daemon up`: la unidad de arranque ya deja el API sirviendo, y el candado lo gestiona el atajo.

#### La app, bajo systemd de usuario: `lm-studio-app.service` (modo servicio, SIN ventana)

- **Antonio pidió (30/09/2026) que al iniciar sesión no se abra la ventana.** El arranque es ahora
  `ExecStart=/usr/bin/lm-studio --run-as-service`: el modo servicio oficial («Desktop app in
  headless mode», doc `developer/core/headless`), el mismo que usa `lms server start` por dentro.
  El journal lo confirma: `Running in headless mode.`
- Unidad: `~/.config/systemd/user/lm-studio-app.service` (copia en `~/Config/hermes/units/`), con
  `TMPDIR=/tmp`, `Restart=on-failure` y `WantedBy=default.target` (ya no depende de
  `graphical-session.target`). **Por qué no se lanza a mano**: desde una sesión de agente hereda el
  `TMPDIR` de la caché de Hermes, monta la AppImage dentro de `~/.hermes/cache/scratch` y deja el
  proceso atado a esa sesión (así se llegó al zombi del 29/09/2026).
- **LM Studio ignora SIGTERM, también en modo servicio**: sin `KillSignal=SIGKILL` +
  `SuccessExitStatus=SIGKILL 137` systemd agotaba el `TimeoutStopSec` (20 s) y la unidad quedaba en
  «failed (timeout)» cada vez que se paraba o al abrir la ventana.
- Estado y reinicio: `systemctl --user status|restart lm-studio-app.service` · log:
  `journalctl --user -u lm-studio-app`.
- Comprobado el 30/09/2026 que sin ventana no se pierde nada: `curl
  http://127.0.0.1:1234/v1/models` → HTTP 200 con los 4 modelos y el selector `/model` de Hermes
  mostrando *LM Studio (3 models)*.
- Alternativa oficial para máquinas sin GUI: el daemon `llmster` (`lms daemon up`, doc
  `developer/core/headless_llmster`). Aquí no hace falta: la app ya tiene unidad y vigilante.

#### Abrir la ventana cuando haga falta: atajo `lm-studio-gui`

La interfaz sigue haciendo falta para gestionar modelos, así que hay un segundo modo **a demanda**:

| Pieza | Qué hace |
|---|---|
| `lm-studio-gui` (atajo; script `lm-studio-gui.sh` en `~/Config/hermes/`, symlink en `~/.local/bin`) | `lm-studio-gui [abrir\|parar\|estado]`: abre la ventana, la cierra o dice qué modo está activo |
| `lm-studio-gui.service` (copia en `units/`) | la app **con** ventana: `Conflicts=lm-studio-app.service` para antes el modo servicio y `ExecStopPost` lo vuelve a arrancar al cerrarla. **No se habilita**: se arranca solo con el atajo |
| `lm-studio-gui-run.sh` | `ExecStart` de esa unidad: limpia los `Singleton*` huérfanos (los que apuntan a un PID muerto) antes de lanzar la app |

- **Por qué `Conflicts`**: con el modo servicio vivo, abrir la ventana desde el menú choca con su
  `SingletonLock` («Another instance of the app is already running») o, con un candado huérfano, la
  app muestra la **lista de modelos vacía**. El atajo resuelve las dos cosas.
- Ciclo verificado el 30/09/2026: `abrir` deja `lm-studio-gui` activa y `lm-studio-app` inactive
  (result `success`), la API responde 200 durante todo el ciclo y `parar` devuelve el modo servicio
  solo, sin dejar ninguna unidad en «failed».
- Mientras la ventana está abierta, el API lo sirve la propia app (`enableLocalService: true`), así
  que Hermes no se queda sin el modelo local en ningún momento.
- **Validado por Antonio el 30/09/2026 tras reiniciar la sesión**: al entrar no aparece ninguna
  ventana, LM Studio arranca solo y **deja su icono en la bandeja del sistema** (señal de que está
  vivo), y `/model` ofrece sus *3 models*. El icono, además, es la vía cómoda de abrir la ventana:
  si se abre desde ahí, comprobar que la lista de modelos **no** salga vacía; si sale vacía es el
  choque de candado, y entonces `lm-studio-gui parar` y `lm-studio-gui`. Cerrar la ventana la minimiza a la
  bandeja y el servidor sigue; para volver del todo al modo servicio, `lm-studio-gui parar`.
- **Pitfall (sigue vigente)**: el servidor puede quedarse **mudo** (acepta conexiones en el 1234
  pero no contesta: `curl` se cuelga, `lms ls` no lista) y la interfaz muestra la lista de modelos
  vacía, porque la saca de ese mismo servidor. En `~/.lmstudio/server-logs/AAAA-MM/` se ve la última
  petición sin responder. Arreglo: `systemctl --user restart lm-studio-app.service` (o esperar al
  vigilante, que lo hace solo).

#### Vigilante del «servidor mudo»: `lm-studio-watchdog`

`Restart=on-failure` no cubre el caso que más duele (proceso vivo, servidor sin contestar), así que
hay un vigilante propio:

- `~/Config/hermes/lm-studio-watchdog.sh` (atajo en `~/.local/bin/lm-studio-watchdog`), disparado
  por `lm-studio-watchdog.timer` **cada 5 min** (unidades copiadas en `~/Config/hermes/units/`).
- Qué hace: `curl -m 5` a `http://127.0.0.1:1234/v1/models`. Si no responde 200 durante **2 pasadas
  seguidas**, reinicia `lm-studio-app.service`. Si la unidad no está activa, **no toca nada** (así no
  pelea si Antonio la ha parado para usar `llmster`).
- Log: `~/Config/hermes/logs/lm-studio-watchdog.log` (solo escribe fallos, reinicios y recuperaciones).
  Estado de fallos: `~/.hermes/state/lm-studio-watchdog.fallos` (efímero, fuera del backup).
- Probado el 29/09/2026 con un agujero negro local (socket que acepta y nunca contesta): detecta,
  reinicia la unidad y la API vuelve sola. Coste medido por pasada: **~5 ms de CPU y 15 MB de RSS
  durante milisegundos**, sin VRAM ni carga de modelos (el sondeo solo lista `/v1/models`).
- Comprobar a mano sin esperar al temporizador: `systemctl --user start lm-studio-watchdog.service`
  (silencioso = todo bien).



### LM Studio en el selector: `LM_API_KEY`

Hermes **no autodetecta** LM Studio (su disponibilidad no se deduce de una clave), así que el
proveedor no aparecía en `/model` aunque el servidor estuviera levantado. Con `LM_API_KEY=lm-studio`
en `~/.hermes/.env` (el servidor sin auth lo ignora) ya sale la fila *LM Studio (3 models)* con sus
modelos en vivo. Es la misma clave que exporta el `.zshrc` para OpenCode.

### Al probar cambios de configuración de Hermes

**Nunca lanzar `hermes` con un `HERMES_HOME` temporal y vacío**: el lanzador trata ese home como
instalación nueva, se pone a reconstruir (TUI, web, escritorio, `agent-browser`, `cua-driver`) y
**reescribe `~/.hermes/hermes-agent/.hermes/bin/{hermes,hermes-acp}` con las rutas del home
temporal**, dejando el lanzador real roto. Ocurrió el 29/09/2026 y se reparó sustituyendo el prefijo
`/tmp/wl-hermes` → `/home/antonio/.hermes` en esos dos ficheros. Para probar cambios de config sin
tocar nada, usar un doble del binario (`HERMES_BIN=<script que simula `config get/set/unset`>`) o
una copia completa del home.

### Parches locales del CLI (Ctrl+Q corta el audio; Ctrl+C lo corta e interrumpe)

El CLI de serie no cortaba la locución al pulsar `ctrl+q` ni `ctrl+c` (solo la grabación o el
barge-in llamaban a `stop_playback()`), así que el audio seguía sonando. Se arregla con un parche
**local**, no con configuración:

- `hermes_cli/cli_tui_mixin.py` → nuevo helper `CLITuiMixin._tui_cut_tts(motivo)`, invocado desde
  los manejadores de `ctrl+q` y `ctrl+c`. Solo actúa si hay audio sonando (`is_audio_output_active()`
  o la tubería de TTS sin terminar).
- `tools/voice_mode.py` → flag `_playback_interrupted`: tras un corte deliberado, la cadena de
  reproductores **ya no prueba el siguiente candidato**. Sin esto, matar `ffplay` hacía arrancar
  `aplay` con la MISMA frase desde el principio (chasquido + reinicio): parecía que la tecla no
  callaba nada y había que pulsar **dos veces** (la segunda mataba `aplay`; después quedaba el aviso
  `No audio player available for …ogg` en `errors.log` como firma del corte completo). El flag se
  activa en `stop_playback()` y cuando un reproductor muere por señal (`rc < 0`), y se limpia al
  empezar cada reproducción.
- **Reparto de teclas pedido por Antonio (29/09/2026)**: `ctrl+q` **solo** calla la locución y no
  hace nada más — no interrumpe el turno ni cierra selectores. Interrumpir el turno (con su salida
  forzada por doble pulsación y su cadena de prioridades) sigue siendo `ctrl+c`, que además corta el
  audio. Antes de esto, `ctrl+q` conservaba la interrupción de serie y Antonio se encontraba con el
  turno cancelado cuando solo quería silenciar la voz.
- El diff vive en `~/Config/hermes/parches/ctrl-q-corta-audio.patch` y se aplica/revierte con
  `hermes-parche-ctrlq [estado|aplicar|revertir]` (atajo en `~/.local/bin`; log en
  `~/Config/hermes/logs/parches.log`). Es idempotente y sale con 0/1/2 según esté aplicado, sin
  aplicar o en conflicto.
- **El cambio no entra en una sesión ya abierta**: el módulo está importado en el proceso en marcha.
  Hay que reiniciar Hermes para que la tecla se comporte así.
- Prueba funcional del reparto de teclas: `scripts/test-ctrlq-solo-tts.py` de la skill
  `hermes-voz-local-gpu` (interpreta el módulo real y comprueba que Ctrl+Q no interrumpe el turno).
- Corte reproducible sin tocar la tecla: `scripts/test-corte-reproductor.py` de la misma skill
  (pipeline real + `stop_event`/`stop_playback()`; exit 0 = corte limpio, 1 = algún reproductor
  reintentó, 2 = no llegó a sonar).
- **Después de cada `hermes update`**: el actualizador autostashea los cambios locales y los
  restaura, pero un conflicto puede dejarlos aparcados. Comprobar con `hermes-parche-ctrlq estado`.
- Si algún día el arreglo entra aguas arriba, se revierte el parche y este apartado se borra.
- **Arreglo propuesto aguas arriba**: PR abierto en `NousResearch/hermes-agent` (#128385, rama
  `fix/cli-interrupt-cuts-tts`, worktree en `~/pr-hermes-ctrlq`), que corta la locución en Ctrl+C y
  Ctrl+Q y hace que un corte deliberado no reintente la cadena de reproductores. Mantiene la
  semántica de serie de las teclas. Si lo aceptan: revertir el parche local (queda solo la
  preferencia de que Ctrl+Q no interrumpa el turno, que seguiría siendo local) y borrar el worktree
  con `git -C ~/.hermes/hermes-agent worktree remove ~/pr-hermes-ctrlq`.

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
- **Ajustes locales de Linux → Windows**: `windows/PARA-WINDOWS-ajustes-linux.md` +
  `windows/aplicar-ajustes-linux.ps1` (con `parches/ctrl-q-corta-audio.patch`,
  `alias-modelos.json` y `plugins/model-providers/nvidia/`). Reproducen en el Hermes de Windows
  el parche Ctrl+Q (corta la locución **sin** interrumpir el turno) y los agentes/modelos: los 11
  alias de modelo, el plugin `nvidia` y el whitelist NVIDIA dentro del `opencode.json` de Windows.
  El script es idempotente y admite `-SoloEstado`; **tras cada `hermes update` en Windows hay que
  repetirlo** (el actualizador puede dejar el parche aparcado).

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

## Herramientas propias: parche del CLI, unidades systemd y atajos

Todo lo que se montó a mano vive en la raíz de `~/Config/hermes/` y entra en los dos destinos
(`sesion-hermes/` y el tarball, este último bajo `esquema/`):

| Pieza | En `~/Config/hermes/` | Atajo en `~/.local/bin` |
|---|---|---|
| Parche del CLI (Ctrl+Q corta la locución) | `parches/ctrl-q-corta-audio.patch` + `hermes-parche-ctrlq.sh` | `hermes-parche-ctrlq` |
| Unidades systemd de usuario | `units/*.{service,timer,path}` | — |
| Vigilante de LM Studio | `lm-studio-watchdog.sh` | `lm-studio-watchdog` |
| Ventana de LM Studio (modo a demanda) | `lm-studio-gui.sh` + `lm-studio-gui-run.sh` | `lm-studio-gui`, `lm-studio-gui-run` |
| Alias NVIDIA | `hermes-nvidia-aliases.{sh,py}` | `hermes-nvidia-aliases` |
| Modelos viables | `hermes-modelos-viables.{sh,py}` | `hermes-modelos-viables` |
| Dual boot | `dual-boot/*.sh` | `hermes-dual-sync` |
| Stack de voz (Kokoro/whisper) | `sesion-hermes/extras/bin/` (y `extras/bin/` del tarball) | `kokoro-tts`, `whisper-stt`, `whisper-cli`, `hermes-voz` |
| Aviso de arranque | `units/hermes-ready-notify.service` | `hermes-ready-notify.sh` |

- El instalador desde limpio (`setup-hermes-completo.sh`, PASO 5b) repone los atajos, copia las
  unidades, habilita los servicios (`hermes-sync.timer`, `hermes-ready-notify.service`,
  `lm-studio-app.service`, `lm-studio-watchdog.timer`, `hermes-nvidia-aliases.path`) y aplica el
  parche del CLI. El `restore.sh` del tarball hace lo mismo a partir de `esquema/`.
- `check-setup-completo.sh` comprueba que existan los ficheros, las unidades y los atajos, y
  **avisa** (sin abortar el backup) si el parche del CLI está pendiente de aplicar.
- Tras cada `hermes update`: `hermes-parche-ctrlq estado` (0 = aplicado, 1 = sin aplicar,
  2 = conflicto); si no está, `hermes-parche-ctrlq aplicar` y reiniciar Hermes.

## Skills propias

Las skills viven en `~/.hermes/skills/` (entran en el backup). Las de autoría local, todas en
`autonomous-ai-agents/`: `hermes-agent`, `hermes-backup-restore`, `hermes-cambio-de-modelo`,
`hermes-modelos-proveedores`, `hermes-modelos-viables`, `hermes-dual-boot-sync`,
`hermes-voz-local-gpu`, `hermes-local-surfaces`, `hermes-gateway-startup-alert`,
`hermes-upstream-pr` y `hermes-auditoria-sesiones`. Son la memoria operativa del esquema: ante una
tarea de Hermes se carga la skill correspondiente antes de improvisar.

---

## Reglas que NO se deben romper

1. El instalador desde limpio vive **solo** en `sesion-hermes/` (más el enlace simbólico en la raíz).
2. Nunca copiar `.env`, `auth.json`, `credenciales/` ni `*.tar.gz` a `~/Documentos/dotfiles/`.
3. Usar `rsync --delete --delete-excluded` en la copia de dotfiles: con solo `--delete`, lo
   excluido se acumula en el destino.
4. El tarball se crea siempre con `umask 077` y se deja en 600.
5. No meter en el backup `state.db`, `sessions/`, `tools/`, `installs/` ni `hermes-agent/`.
6. El parche del CLI, las unidades de `units/` y los atajos viajan SIEMPRE en el tarball (bajo
   `esquema/`), en `sesion-hermes/` y en la copia saneada: sin ellos, una instalación desde limpio
   no llega al estado actual.
7. El material para Windows (`dual-boot/windows/`) se publica con `hermes-dual-sync export`; no se
   edita directamente en la carpeta común (el export lo sobrescribe).
8. Los scripts que viven fuera de `~/.hermes` (stack de voz y `hermes-ready-notify.sh`) viajan
   SIEMPRE en `extras/bin/` del tarball y de `sesion-hermes/`: sin ellos la instalación desde limpio
   se queda muda y sin aviso de arranque.
9. Al cambiar una pieza del esquema, actualizar a la vez este documento y la skill que la
   documenta (`hermes-*`), que es lo que se carga en las sesiones.

> 📁 `~/.hermes/` · `~/Config/hermes/` · `~/Documentos/dotfiles/hermes/`
