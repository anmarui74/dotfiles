# NOTA-PARA-WINDOWS — Linux → Windows

Generada: 24/10/2026 · Desde: CachyOS (Linux)

## Qué se actualizó en el disco compartido (Linux → Windows)

`~/Config/hermes/dual-boot/windows/alias-modelos.json` se sincronizó con los alias y el whitelist NVIDIA vivos de Linux. Windows debe aplicar estos cambios en su propio Hermes:

### 1. Alias de modelo en opencode.json de Windows

Aplicar cada alias con `hermes config set model.aliases.<nombre> <modelo> --force`:

| Alias | Modelo |
|---|---|
| `local` | `lmstudio/qwen3.8-9b` |
| `nvidia` | `nvidia/nvidia/nemotron-3-ultra-550b-a55b` |
| `glimmer` | `nvidia/meta/muse-glimmer-30b` |
| `lightning` | `nvidia/nvidia/nemotron-3.5-lightning-30b-a3b` |
| `vision` | `nvidia/meta/llama-3.2-11b-vision-instruct` |
| `local-qwen35` | `lmstudio/qwen3.5-9b` |
| `local-gemma` | `lmstudio/google/gemma-4-e4b` |
| `multimodal` | `opencode-go/mimo-v2.5` |

Alias **retirados** del export (ya no existen en Linux): `nemotron-super`, `gpt-oss`, `nano-omni`. Si en Windows todavía existen, bórralos.

### 2. Whitelist NVIDIA en opencode.json de Windows

Reemplazar `providers.nvidia.whitelist` por esta lista (orden indiferente):

- `nvidia/nemotron-3.5-super-vl-120b-a12b`
- `nvidia/nemotron-3.5-lightning-30b-a3b`
- `nvidia/nemotron-3.5-bolt-e4b`
- `meta/llama-3.2-11b-vision-instruct`
- `nvidia/nemotron-3-ultra-550b-a55b`
- `meta/muse-glimmer-30b`

Eliminar de la whitelist de Windows (ya no están en Linux): `openai/gpt-oss-20b`, `nvidia/nemotron-3-super-120b-a12b`, `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning`.

### 3. Alias complejos no replicados en Windows

`nemotron-super-vl` (`nemotron-3.5-super-vl-120b-a12b`), `bolt` (`nemotron-3.5-bolt-e4b`) y `flashnext` (objeto `qwen3.8-flash-next` en `:1919`) no entran en el export simple de Windows. Se gestionan desde Linux con `hermes-nvidia-aliases`.

### 4. Qué no cambia

- Agente por defecto: sigue siendo `deepseek-v4.1-flash` (opencode-go).
- El export es "una foto del config de Linux": si en Linux cambian los alias o el whitelist, regenerar este archivo y volver a sincronizar.

## Qué hace Hermes en Windows tras aplicar esto

El auditor `hermes-auditoria-manual` (cuando se ejecute desde Windows contra su propia copia) debe dar **SIN DESFASES** en los bloques de alias y whitelist NVIDIA.

---
*Esta nota se deja por escrito en el canal Linux→Windows; la ejecuta el Hermes de Windows, no desde Linux.*