# Para el Hermes de Windows — montar el esquema de backup de Hermes (equivalente al de Linux)

Nota escrita desde **Linux (cachyos)** el 29/09/2026. Va dirigida a ti, Hermes de Windows
(`%LOCALAPPDATA%\hermes`). El objetivo es que Windows tenga **su propio** esquema de backup
con la misma filosofía que el de Linux, pero con el destino en el disco SEAGATE compartido.

Antonio lo pidió así: la copia de seguridad vive en el disco, no en el disco del sistema.

---

## 1. Dónde va todo (estructura exacta)

El disco SEAGATE se ve en Windows con una letra variable (D:…Z:): localízala buscando una
carpeta `Linux\Config\` en la raíz (`hermes-sync.cmd` ya tiene esa búsqueda; reutilízala).
Aquí abajo llamo `X:` a esa letra.

```
X:\Linux\
├── Config\
│   └── Hermes-Win\                  ← CREAR. Respaldo canónico de este equipo
│       ├── AGENTS-WIN.md            documenta este esquema (reglas)
│       ├── backup-hermes.ps1        genera el zip + copia saneada + retención
│       ├── sync-hermes.ps1          backup sin salida (para la tarea programada)
│       ├── check-setup-win.ps1      verificación previa (aborta el backup si falla)
│       ├── restaurar-hermes.ps1     instalación desde limpio / restauración
│       ├── backups\                 zips: hermes-win-backup-AAAAMMDD-HHMMSS.zip (+ restore dentro)
│       └── sesion-hermes\           copia lista para instalar desde cero
│           ├── config.yaml .env auth.json SOUL.md
│           └── (mismo contenido que se restaura en %LOCALAPPDATA%\hermes)
└── Documentos\
    └── dotfiles\
        └── hermes-win\              ← CREAR. Copia saneada SIN NINGUNA CLAVE
```

**No toques `X:\Linux\Documentos\dotfiles\hermes\`** (sin el `-win`): esa es la copia saneada
de Linux. La tuya es `hermes-win\` para que no os piséis al versionar.

Desde Linux, `X:\Linux\Config` se ve **solo lectura** (root:root). Si al escribir te da
«Acceso denegado», no lo fuerces: déjalo anotado en la nota del punto 7 y sigue con el resto.

---

## 2. Punto de partida: el esquema de Linux como referencia

En la carpeta compartida tienes el original, léelo antes de escribir nada:

- `HermesSync\windows\esquema-linux\AGENTS.md` — documento maestro del esquema de Linux
  (qué se respalda, credenciales, retención, automatización, reglas).
- `HermesSync\windows\esquema-linux\backup-hermes.sh` — el generador.
- `HermesSync\windows\esquema-linux\sync-hermes.sh` — envoltorio para el timer.
- `HermesSync\windows\esquema-linux\check-setup-completo.sh` — verificación previa.
- `HermesSync\windows\esquema-linux\setup-hermes-completo.sh` — instalación desde limpio.
- `HermesSync\windows\LEEME-WINDOWS.md` — tus propias notas del esquema dual boot.

Los `.sh` son de Linux: **no los ejecutes en Windows**, son la especificación a traducir a
PowerShell (`tar.exe`, `robocopy`, `Compress-Archive`, `schtasks`).

---

## 3. Qué se respalda y qué no (igual que en Linux)

| ✅ Dentro del zip | ❌ Fuera del zip |
|---|---|
| `config.yaml`, `SOUL.md`, `install_id`, `channel_directory.json`, `shell-hooks-allowlist.json` | `state.db` y `sessions/` (histórico de conversaciones) |
| `skills\`, `plugins\`, `hooks\`, `agent-hooks\` | `cache\`, `logs\`, `runtime\`, `sandboxes\`, `terminal-sessions\` |
| `memories\` (`MEMORY.md`, `USER.md`), `cron\` (sin `executions.db`) | `tools\`, `installs\`, clones git de Hermes (~GB) |
| `kanban.db` (copia consistente, no el fichero abierto) | `*.lock`, `*.pid`, `*.sock`, temporales |
| Credenciales: tu `.env` y `auth.json` **dentro de `Hermes-Win`** (con permisos restringidos) | `pairing\`, `pending_messages\`, `state\` |

El zip de Windows debe ser el equivalente del tarball de Linux: **sin estado, con
credenciales**, y con permisos restringidos (NTFS: solo el usuario `evo01`; equivalente al
0600/0700 de Linux).

Nombre y formato: `Hermes-Win\backups\hermes-win-backup-AAAAMMDD-HHMMSS.zip`, con el script
de restauración dentro (`restore-win.cmd`), igual que el `restore.sh` de Linux.
Retención: **30 días** + poda de duplicados del mismo día (se conserva el último).

---

## 4. La copia saneada (sin claves) — lo más importante

`X:\Linux\Documentos\dotfiles\hermes-win\` es la copia que puede acabar en un repositorio
**público**, así que:

1. Cópiala con robocopy excluyendo: `.env`, `*.env`, `auth.json`, `credenciales\`, `shared\`,
   `backups\`, `*.zip`, `*.tar.gz`, `*-restore.*`, `*.lock`, `__pycache__`.
2. **Pásale el escaneo de claves** antes de darla por buena. Patrones que usa Linux
   (sobre todos los ficheros, no solo los `.md`):

   ```
   (nvapi-|oc_sk_)[A-Za-z0-9_-]{15,}      → claves NVIDIA / OpenCode
   (^|[^A-Za-z0-9])sk-[A-Za-z0-9]{25,}    → claves tipo OpenAI
   AEMET_API_KEY=[A-Za-z0-9]{15,}
   NVIDIA_API_KEY=[A-Za-z0-9_-]{15,}
   OPENCODE_GO_API_KEY=[A-Za-z0-9_-]{15,}
   ssh-(rsa|ed25519|dss) [A-Za-z0-9+/=]{20,}      → claves públicas/privadas SSH
   BEGIN [A-Z ]*PRIVATE KEY
   [0-9]{8,12}:[A-Za-z0-9_-]{30,}                → token de bot de Telegram
   ```

3. **La comprobación buena no es (solo) por patrones**: saca los valores reales de tu `.env`
   y de `auth.json` y búscalos literalmente dentro de `hermes-win\`. Si alguno aparece, la
   copia NO se publica. En Linux, el 29/09/2026, este segundo paso fue el que encontró una
   clave escondida en un snapshot de caché que el escaneo por patrones no veía.
4. El `.gitignore` va **en el origen** (`Hermes-Win\.gitignore` → se copia a `hermes-win\`):
   si lo creas solo en el destino, el siguiente volcado lo borra. Contenido mínimo:
   `.env`, `*.env`, `auth.json`, `credenciales/`, `shared/`, `backups/`, `*.zip`, `*.tar.gz`,
   `*-restore.*`, `__pycache__/`.

---

## 5. Automatización

| Momento | Linux | Windows (a montar) |
|---|---|---|
| Cada 30 min | `hermes-sync.timer` (systemd de usuario) → `sync-hermes.sh` | tarea programada `HermesBackup-Win` cada 30 min → `sync-hermes.ps1` (sin admin: `schtasks /create /sc minute /mo 30`, igual que `HermesSync-Publicar`) |
| Al cerrar sesión de Hermes | hook `on_session_end` → publica y respalda | lo mismo: encadénalo al `HermesSync-Publicar` o al cierre de Hermes |

Antes de cada backup, `check-setup-win.ps1` verifica que el esquema está completo (carpetas,
scripts y que el zip contiene lo esperado) y **aborta** si falta algo, para no guardar un
setup defectuoso.

---

## 6. Instalación desde limpio

`restaurar-hermes.ps1` debe: instalar Hermes si falta, restaurar el último zip de
`Hermes-Win\backups\` (o `Hermes-Win\sesion-hermes\`), reponer `.env` y `auth.json` con
permisos restringidos y verificar al final (`hermes doctor`, y que existan `config.yaml`,
`SOUL.md`, `memories\`, `skills\`).

Prueba de verdad, como en Linux: restaura **en una carpeta temporal** (`-Destino`), no encima
de tu instalación, y comprueba que el resultado tiene los ficheros clave y `hermes doctor`
sale limpio.

---

## 7. Al terminar, deja constancia

Escribe `X:\HermesSync\NOTA-PARA-LINUX.md` con: qué creaste, dónde, qué automatización
quedó activa, el resultado del test de restauración y cualquier cosa que no pudieras hacer
(permisos de `Linux\Config`, tareas programadas que exijan admin, etc.). El motor de Linux
lee esa carpeta al arrancar, así que así me entero sin que Antonio tenga que contarlo.

---

## 8. Reglas que no se deben romper

1. Credenciales **sí** en `Hermes-Win\backups\` y en `Hermes-Win\sesion-hermes\`, **nunca**
   en `X:\Linux\Documentos\dotfiles\hermes-win\` (ni en `dotfiles\hermes\`, que es de Linux).
2. `state.db` y `sessions\` no entran en el backup de configuración (el histórico viaja por
   el esquema dual boot, no por aquí).
3. Nada de copiar el directorio completo de Hermes: la whitelist de arriba y punto.
4. No sustituir `state.db` con Hermes en marcha (ya lo sabes: `Test-HermesVivo`).
5. El zip de respaldo va con permisos restringidos; la copia saneada sin claves, siempre.
