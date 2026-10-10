# Para el Hermes de Windows — reproducir los ajustes locales del Hermes de Linux

Nota escrita desde **Linux (cachyos)** el 29/09/2026, dirigida a ti, Hermes de Windows
(`%LOCALAPPDATA%\hermes`). Antonio quiere que el Hermes de Windows se comporte **igual** que el
de Linux en dos cosas que allí se resolvieron a mano:

1. **Ctrl+Q corta la locución en curso y nada más** (no interrumpe el turno; interrumpir sigue
   siendo Ctrl+C, que además corta el audio). Sin el parche, Ctrl+Q en Windows interrumpe el
   turno y la voz sigue sonando.
2. **Los agentes/modelos**: los alias de modelo (`nvidia`, `local`, `gpt-oss`, `glimmer`,
   `multimodal`…), el **modelo por defecto** (`deepseek-v4.1-flash` vía `opencode-go`, el mismo que
   en Linux) y el plugin `nvidia` que limita el catálogo al whitelist de OpenCode, para que el
   selector `/model` muestre lo mismo que en Linux.

---

## 1. Material (todo en esta carpeta, `D:\HermesSync\windows\`)

| Fichero | Qué es |
|---|---|
| `aplicar-ajustes-linux.ps1` | **El que se ejecuta.** Aplica el parche del CLI, copia el plugin y fija los alias. |
| `parches\ctrl-q-corta-audio.patch` | Parche local del CLI (toca `hermes_cli/cli_tui_mixin.py` y `tools/voice_mode.py`). |
| `alias-modelos.json` | Export de Linux: alias de modelo, modelo por defecto (el «agente general») y whitelist NVIDIA. **Solo nombres, ninguna clave.** |
| `plugins\model-providers\nvidia\` | Plugin que sustituye al perfil NVIDIA de serie y filtra por el whitelist. |

---

## 2. Cómo se ejecuta (sin administrador)

```powershell
cd D:\HermesSync\windows
powershell -ExecutionPolicy Bypass -File .\aplicar-ajustes-linux.ps1
```

Solo mirar qué haría, sin tocar nada:

```powershell
powershell -ExecutionPolicy Bypass -File .\aplicar-ajustes-linux.ps1 -SoloEstado
```

Si tu repo no está en `%LOCALAPPDATA%\hermes\hermes-agent`, indícalo:

```powershell
powershell -ExecutionPolicy Bypass -File .\aplicar-ajustes-linux.ps1 -Repo "C:\ruta\hermes-agent"
```

Es **idempotente**: si ya está aplicado, no cambia nada.

---

## 3. Qué hace, paso a paso

1. **Parche del CLI**: comprueba si ya está aplicado (`git apply --reverse --check`); si no, lo
   aplica (`git apply`). Requiere `git` en el PATH y el repo de Hermes con `.git`.
2. **Plugin de agentes**: copia `plugins\model-providers\nvidia\` a
   `%LOCALAPPDATA%\hermes\plugins\model-providers\nvidia\`.
3. **Alias de modelo**: `hermes config set model.aliases.<nombre> <modelo> --force` para cada uno
   de los 11 del export.
4. **Modelo por defecto**: `hermes config set model.default <modelo>` y
   `hermes config set model.provider <proveedor>` con lo que traiga `agente_por_defecto` del export
   (hoy `deepseek-v4.1-flash` / `opencode-go`). Después limpia `model.base_url` y `model.api_mode`
   **solo si están puestos**: una ruta heredada de otro proveedor dejaría el modelo nuevo apuntando
   al relay viejo.
5. **Whitelist NVIDIA**: si existe `%USERPROFILE%\.config\opencode\opencode.json`, actualiza solo
   `providers.nvidia.whitelist` con los 7 ids del export (no toca nada más). Si no existe, avisa y
   sigue: los alias funcionan igual, solo no se filtra el catálogo.
6. **Avisos del esquema**: si la copia local del motor del dual boot
   (`%LOCALAPPDATA%\hermes\dual-boot\hermes-dual-sync.ps1`, que es la que Windows ejecuta de verdad)
   difiere de la distribuida, o si el lanzador de la carpeta Inicio ha dejado de importar antes del
   gateway, lo avisa — sin cambiar nada — con el comando exacto para arreglarlo
   (`windows\actualizar-motor-local.ps1` / `registrar-tareas.cmd`). Detalles:
   `windows\PARA-WINDOWS-motor-fusion.md`.

---

## 4. Verificación (no dar nada por bueno sin esto)

```powershell
# 1. Parche aplicado -> exit 0 y sin salida
git -C "$env:LOCALAPPDATA\hermes\hermes-agent" apply --reverse --check "$PWD\parches\ctrl-q-corta-audio.patch"
echo $LASTEXITCODE

# 2. Modelo por defecto y alias que ve Hermes (deben coincidir con los de Linux)
hermes config get model
hermes config get model.aliases

# 3. Plugin en su sitio
dir "$env:LOCALAPPDATA\hermes\plugins\model-providers\nvidia"
```

Prueba funcional del reparto de teclas (la de verdad): abre Hermes, `/voice on`, pide algo que se
locute y pulsa **Ctrl+Q** mientras habla. Debe callarse la voz **y no** aparecer
`⚡ Interrupting agent...` (eso sería Ctrl+C). El parche **no entra en una sesión ya abierta**:
reinicia Hermes después de aplicarlo.

---

## 5. Cuándo hay que repetirlo

- Después de cada `hermes update` en Windows: el actualizador autostashea los cambios locales y
  los restaura, pero un conflicto puede dejarlos aparcados. Si `Ctrl+Q` vuelve a interrumpir el
  turno, vuelve a ejecutar el `.ps1`.
- Si en Linux cambian los alias o el modelo por defecto, vuelve a ejecutarlo para que Windows se
  iguale (el `agente_por_defecto` del export lo fija el paso 4).
- Si el parche no aplica limpio (el código aguas arriba cambió), **no lo fuerces a ciegas**: deja
  constancia en `NOTA-PARA-LINUX.md` con el error de `git apply` y se reconcilia desde Linux.

---

## 6. Al terminar, deja constancia

Escribe o amplía `D:\HermesSync\NOTA-PARA-LINUX.md` diciendo: qué ejecutaste, el resultado de la
verificación (exit de `git apply --reverse --check`, alias aplicados, si el whitelist se actualizó)
y cualquier cosa que no pudieras hacer. El motor de Linux lee esa carpeta al arrancar.
