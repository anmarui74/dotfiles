# 🖥️ Configuración LM Studio MiMoCode
Servidor LM Studio, proxy propio en el puerto 4001 y modelos locales de MiMoCode.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 23/09/2026 | Antonio |

> Infraestructura LM Studio **propia** de MiMoCode (ya no se reutiliza la de OpenCode)

---

## 📑 Índice
1. [Arquitectura](#arquitectura)
2. [Puertos](#puertos)
3. [Infraestructura propia](#infraestructura-propia)
4. [Proxy](#proxy)
5. [Modelos](#modelos)
6. [Configuración en el proveedor](#configuración-en-el-proveedor)

---

## Arquitectura

```
LM Studio (puerto 1234) → lmstudio-proxy.py (puerto 4001) → MiMoCode
```

MiMoCode apunta al **proxy**, no directamente a LM Studio. El proxy inyecta
`stats.tokens_per_second` en las respuestas no-streaming y expone el prefijo `lmstudio/`.

---

## Puertos

| Componente | Puerto |
|------------|--------|
| LM Studio Server | 1234 |
| Proxy | 4001 |
| Dashboard métricas (OpenCode) | 4200 |

---

## Infraestructura propia

Desde el **22/09/2026 MiMoCode es autónomo**: tiene su **propia copia** de la
infraestructura en `~/.config/mimocode/` y **NO depende de que OpenCode esté instalado**.

| Fichero | Función |
|---------|---------|
| `~/.config/mimocode/start-lmstudio.sh` | Arranca el servidor, carga el modelo y lanza el proxy. Incluye **health-check** de los puertos 1234 y 4001 |
| `~/.config/mimocode/start-lmstudio-server.sh` | Solo servidor + proxy, **sin cargar** el modelo en VRAM |
| `~/.config/mimocode/lmstudio-proxy.py` | Proxy del puerto 4001 (ver abajo) |

Los lanzadores `mimo` y `mimo-local` invocan la copia **propia** (`~/.config/mimocode/start-lmstudio.sh`).
Los equivalentes de OpenCode siguen en `~/.config/opencode/` y son **independientes**.

---

## Proxy

`~/.config/mimocode/lmstudio-proxy.py` — es **autocontenido**:

- Usa `CONFIG_DIR` (el directorio donde vive el propio fichero) para todo.
- **No necesita `.env` ni claves de API**: aplica sus valores por defecto
  (`ENABLE_METRICS=true` y `METRICS_EXPORT_PATH=<CONFIG_DIR>/data/metrics.json`).
- Escribe las métricas en `~/.config/mimocode/data/metrics.json` (**separadas** de las de OpenCode).
- Se puede sobreescribir con un `.env` en `~/.config/mimocode/` si se quisiera.

---

## Modelos

Ambos son **GGUF en cuantización Q6_K** (~7,5 GB) y se descargan de **Hugging Face**:

| En LM Studio | Repo de Hugging Face |
|--------------|----------------------|
| `qwen3.8-9b` (principal) | `empero-ai/Qwen3.8-9B-Distill-GGUF` |
| `qwen3.5-9b` | `unsloth/Qwen3.5-9B-GGUF` |

```bash
# Descarga manual (si el instalador no lo ha hecho)
lms get empero-ai/Qwen3.8-9B-Distill-GGUF@Q6_K --yes
lms get unsloth/Qwen3.5-9B-GGUF@Q6_K --yes
```

> ⚠️ El repo `empero-ai/Qwen3.8-9B-Distill` (sin `-GGUF`) solo contiene **safetensors**, que LM Studio no usa. Hay que usar la variante `-GGUF`.

El modelo principal se carga con **80k de contexto** (`81920` tokens).

---

## Configuración en el proveedor

`models-qwen3.8-9b` con 80k contexto, declarado en
`provider.lmstudio` de `mimocode.jsonc` con `baseURL = http://localhost:4001/v1`
y `only_configured_models: true`.

```jsonc
"lmstudio": {
  "npm": "@ai-sdk/openai-compatible",
  "name": "Qwen 3.8 Q6_K",
  "only_configured_models": true,
  "options": { "baseURL": "http://localhost:4001/v1" },
  "models": {
    "models-qwen3.8-9b": {
      "name": "Qwen 3.8 - Tool Calling Excellence",
      "tool_call": true,
      "limit": { "context": 81920, "output": 8192 }
    }
  }
}
```

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
