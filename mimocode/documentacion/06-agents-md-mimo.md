# 🤖 AGENTS.md MiMoCode
Instrucciones del agente, reglas de estilo y reglas de backup de MiMoCode.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 23/09/2026 | Antonio |

> Reglas obligatorias que sigue el agente en MiMoCode

---

## 📑 Índice
1. [Ubicación](#ubicación)
2. [Reglas de usuario y formato](#reglas-de-usuario-y-formato)
3. [Reglas de backup y claves](#reglas-de-backup-y-claves)
4. [Recordatorios técnicos](#recordatorios-técnicos)

---

## Ubicación

`~/.config/mimocode/AGENTS.md` — **referenciado en `instructions`** de `mimocode.jsonc`,
así que se carga automáticamente en cada sesión.

⚠️ Existe en **3 sitios** y deben estar sincronizados:

| Copia | Ruta |
|-------|------|
| Activa | `~/.config/mimocode/AGENTS.md` |
| Raíz del respaldo | `~/Config/mimocode/AGENTS.md` |
| Copia canónica (la del instalador) | `~/Config/mimocode/sesion-mimocode/config/AGENTS.md` |

> El `sync-mimocode.sh` propaga la activa a la canónica. La de la raíz se copia a mano.

---

## Reglas de usuario y formato

- Responder **siempre en español de España**.
- Fecha `dd/mm/aaaa`, hora en formato **24h**, decimales con **coma**, moneda en **€**, sistema métrico.
- **Emojis** permitidos (el locucionero los filtra antes del TTS).
- Tablas **siempre** en Markdown nativo (nunca cajas ASCII).
- Formato de manuales según la plantilla obligatoria (cabecera de estado, índice, separadores).
- Al preguntar por el **tiempo**: usar **AEMET** (respaldo `wttr.in`).
- Al preguntar por **hardware**: leer `~/.config/opencode/data/hardware/index.json`.
- Elevación de privilegios: el agente usa **`pkexec`**, nunca `sudo`.
- Ante problemas: consultar la **documentación oficial** antes de probar a ciegas.
- **Verificar los hechos** con herramientas antes de afirmar que algo falta o está roto.

---

## Reglas de backup y claves

### 🔑 La frontera de las claves de API

| Ubicación | ¿Lleva claves? |
|-----------|----------------|
| `~/Config/mimocode/backups/mimocode/` (tarballs) | ✅ **SÍ** — es el backup de restauración |
| `~/Config/mimocode/sesion-mimocode/setup-mimocode-completo.sh` | ✅ **SÍ** — embebidas a propósito |
| `~/Documentos/dotfiles/` | ❌ **NUNCA** |

- El volcado a dotfiles usa **`rsync --delete --delete-excluded`** (el segundo flag es
  imprescindible: con solo `--delete` lo excluido NO se purga).
- El instalador embebe `auth.json` con las claves reales; la copia de dotfiles se **sanea**
  a `TU_CLAVE_AQUI`. **Nunca** sanear el instalador canónico.
- Verificar antes de commitear:

  ```bash
  cd ~/Documentos/dotfiles
  git grep -nIP --exclude='*.md' '(nvapi-|oc_sk_)[A-Za-z0-9_-]{15,}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{25,}|AEMET_API_KEY=[A-Za-z0-9]{15,}'
  ```

  > El patrón exige **límite de palabra** antes de `sk-` y claves **largas**, para no dar falsos
  > positivos con `task-<hash>`, `disk-encryption-keyvault` o el ejemplo `sk-1234567890abcdef`.

### 🔄 Cómo se hace un backup

```bash
bash ~/Config/mimocode/backup-mimocode.sh
```

Una sola orden: el script **sincroniza la copia canónica, verifica el setup y empaqueta**.
No hace falta ejecutar el `sync` antes. Si la verificación falla, el backup se **ABORTA**.

---

## Recordatorios técnicos

- **MCP memory**: cada observación de `memory_add_observations` DEBE incluir `entityName`
  junto a `contents`, o devuelve error `-32602`. Igual en `memory_create_relations` (`from`, `to`, `relationType`).
- **LSP/MCP**: hay que replicarlos a mano en los **3** perfiles (`mimocode.jsonc`,
  `profiles/local/`, `profiles/cloud/`) — la duplicación es intencional.
- **Heredocs del instalador**: si editas un lanzador, el timer, los scripts de backup, `auth.json`
  o la infraestructura LM Studio, hay que **replicarlo en el instalador** o el backup se aborta
  (`check-setup-completo.sh` compara 11 heredocs).
- **Nunca** debe haber configs (`mimocode*.json(c)`, `tui.json`, `cli.json`) en la **raíz** de
  `~/Config/mimocode/`: el `sync` los borra.

---

> 📁 `~/.config/mimocode/` - Configuración activa · `~/Config/mimocode/` - Copia de seguridad e instalador
