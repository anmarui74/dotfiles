# 🚀 Qwen3.8-Flash-Next local con llama.cpp
Modelo MoE de 125B (6B activos) servido en `127.0.0.1:1919` con llama.cpp compilado a mano, con visión activa.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 24/10/2026 · rev. 24/10/2026 | Antonio |

> Servidor propio (no LM Studio) para el modelo abierto más grande que cabe en este equipo:
> 3 shards `UD-IQ3_XXS` (82 GB) + `mmproj` de visión, repartidos entre VRAM, RAM y NVMe.

---

## 📑 Índice
1. [Qué es este modelo](#qué-es-este-modelo)
2. [Hardware y reparto de memoria](#hardware-y-reparto-de-memoria)
3. [Por qué llama.cpp y no LM Studio](#por-qué-llamacpp-y-no-lm-studio)
4. [Instalación y descarga](#instalación-y-descarga)
5. [Arranque: servicio y script](#arranque-servicio-y-script)
6. [Ajustes de rendimiento](#ajustes-de-rendimiento)
7. [Visión](#visión)
8. [Uso diario](#uso-diario)
9. [Integración con OpenCode](#integración-con-opencode)
10. [Integración con Hermes](#integración-con-hermes)
11. [Problemas conocidos](#problemas-conocidos)
12. [Referencias](#referencias)

---

## Qué es este modelo

**Qwen3.8-Flash-Next** es el primer modelo abierto de la arquitectura que Qwen usará en su
familia 4. No es un 125B denso: es un **MoE con 6B activos por token** más una **tabla de
n-gramas (PLE) de 51B** que se lee por `mmap` desde el SSD.

| Dato | Valor |
|------|-------|
| Arquitectura | `qwen4_exp` (Gated DeltaNet + Qwen Sparse Attention) |
| Parámetros | 125B MoE (6B activos) + 51B n-gram + 4B MTP |
| Modalidad | Texto + imagen + vídeo (con `mmproj`) |
| Contexto | 262.144 nativo, extensible a 1M (aquí: 65.536) |
| Licencia | Qwen Community 1.0 (no Apache) |
| Quant usado | `unsloth/Qwen3.8-Flash-Next-GGUF` → `UD-IQ3_XXS` (82 GB, 3 shards) |

> ⚠️ El **«Qwen3.8-Flash»** que se anuncia en la web de Qwen es la versión de **API** (Qwen
> Cloud). Los pesos abiertos se llaman **`-Next`** y son los que corren aquí.

---

## Hardware y reparto de memoria

| Componente | Modelo |
|------------|--------|
| CPU | AMD Ryzen 9 7900 (12 núcleos / 24 hilos) |
| RAM | 64 GB DDR5-6000 (2×32 GB) |
| GPU | NVIDIA RTX 4070 Ti SUPER, 16 GB (sm_89) |
| Disco | NVMe, ~500 GB libres |

El modelo no cabe en ningún nivel por separado, así que el diseño reparte la carga:

| Nivel | Qué aloja | Tamaño |
|-------|-----------|--------|
| **VRAM** (16 GB) | capas densas, Qwen Sparse Attention, KV y expertos calientes | ~14,6 GB (15,9 con visión) |
| **RAM** (64 GB) | expertos MoE fríos, calculados en CPU | ~35-44 GB de RSS |
| **SSD** (NVMe) | tabla PLE de n-gramas (51B), por `mmap` perezoso | ~50 GB, ~2,7 KB/token |

El KV cache es pequeño porque **solo 12 de las 48 capas** guardan caché (atención completa 1 de
cada 4): unos 24 KB por token, ~1,5 GiB a 65K de contexto.

### ¿Está el modelo en RAM? Sí, pero cuenta como «caché»

El GGUF se abre con **`mmap` perezoso**: el kernel trae del NVMe solo las páginas que se leen
(expertos activos y filas de la tabla PLE). `free` clasifica esas páginas como **caché**, no
como memoria «usada», así que la línea `usado 9 de 61 GB` **no** significa que el modelo no esté
cargado.

| Medición (24/10/2026) | Valor |
|---|---|
| RAM anónima (procesos) | ~9 GB |
| Caché de página total | ~54 GB |
| GGUF ya residente en page cache | **37,8 GB de 82,9 GB** |
| RSS del proceso `llama-server` | ~24 GB |
| Librerías CUDA/ggml mapeadas | ~130 MB (`libcublasLt` 80 MB, `libcuda` 11 MB…) |

No se cargan los 82 GB de golpe **a propósito**: con 64 GB de RAM, forzarlo con `--mlock` o
`--no-mmap` mataría el sistema. Las páginas que faltan se leen del NVMe bajo demanda (por eso la
primera petición va a ~7 tok/s).

```bash
qwen-flash estado    # muestra caché, RSS y GB del GGUF ya en RAM
```

---

## Por qué llama.cpp y no LM Studio

| Motivo | Detalle |
|--------|---------|
| **Catálogo** | El modelo no está en el catálogo de LM Studio |
| **Ajuste fino** | `--fit`, `--fit-target`, `--n-cpu-moe`, `--spec-type ngram-mod` y el `mmap` perezoso solo existen en llama.cpp |
| **Control del offload** | El paginado perezoso **es** el mecanismo de offload: `--mlock` o `--no-mmap` matarían el invento |

LM Studio sigue siendo el sitio de los modelos pequeños (`qwen3.8-9b`, `gemma-4-E4B`) en el
puerto 1234; este servidor es independiente, en el 1919.

---

## Instalación y descarga

llama.cpp compilado con CUDA para `sm_89`:

```bash
cd ~/src/llama.cpp
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89
cmake --build build -j"$(nproc)" --target llama-server
```

Modelo (3 shards) y proyector de visión:

```bash
mkdir -p ~/modelos/qwen3.8-flash-next
# shards: Qwen3.8-Flash-Next-UD-IQ3_XXS-0000{1..3}-of-00003.gguf
#   desde https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF
# proyector:
curl -L -o ~/modelos/qwen3.8-flash-next/mmproj-F16.gguf \
  https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/resolve/main/mmproj-F16.gguf
```

---

## Arranque: servicio y script

```
systemd --user (qwen-flash-next.service, disabled)
  └─ ~/Config/qwen-flash-next/arrancar-qwen-flash-next.sh
       └─ ~/src/llama.cpp/build/bin/llama-server
            -m …/UD-IQ3_XXS/…00001-of-00003.gguf
            --mmproj …/mmproj-F16.gguf
            --host 127.0.0.1 --port 1919 --alias qwen3.8-flash-next
```

| Fichero | Qué es |
|---------|--------|
| `~/Config/qwen-flash-next/arrancar-qwen-flash-next.sh` | arranque con los ajustes afinados |
| `~/.config/systemd/user/qwen-flash-next.service` | unidad de usuario (**disabled** a propósito) |
| `~/.local/bin/qwen-flash` | atajo: arrancar / parar / estado / logs / prueba |
| `~/Config/qwen-flash-next/bench.sh` | banco de pruebas de tok/s con distintos flags |
| `~/Config/qwen-flash-next/probar-modelo.py` | viabilidad: tool calling + prefill + decode |
| `~/Config/qwen-flash-next/configurar-opencode.py` | registra el proveedor en OpenCode (idempotente) |

La unidad **no arranca sola** porque ocupa ~40 GB de RAM. Para tenerla residente:

```bash
systemctl --user enable --now qwen-flash-next.service
```

---

## Ajustes de rendimiento

Variables de entorno para experimentar sin editar el script: `QWEN_CTX`, `QWEN_FIT_TARGET`,
`QWEN_THREADS`, `QWEN_PORT`, `QWEN_DIR`, `LLAMA_SERVER`, `QWEN_VISION`, `QWEN_MMPROJ`.

| Flag | Por qué |
|------|---------|
| `--fit on --fit-target 1280` | Deja ~1,3 GB de VRAM libre (el mmproj ocupa ~0,9) y coloca las capas solas. **Llenar la tarjeta hunde la generación** (de ~28 a ~5 tok/s) |
| `-ctk q8_0 -ctv q8_0` | KV cache cuantizado: ahorra ~0,75 GiB a 65K sin pérdida apreciable |
| `-b 4096 -ub 1024` | Amortiza el tráfico de expertos por ubatch; mejora el prefill |
| `--spec-ngram-mod-n-min 3 --n-max 12` | Limita la especulación (por defecto 48-64), que en CPU sale cara |
| `-c 65536` | Mínimo que acepta Hermes; cada 32K extra cuesta ~0,75 GiB |
| `--parallel 1` | Con más slots se multiplica el KV y se pierde VRAM |
| `-t 12` | Núcleos **físicos** del Ryzen 9 7900 |
| `--jinja` | Necesario para el chat template y `reasoning_effort` |
| `--reasoning-effort low` | Por defecto razona en `xhigh` y se va a >1.600 tokens en preguntas simples |
| `--spec-type ngram-mod` | Decodificación especulativa por n-gramas (el GGUF no trae cabeza MTP) |
| `-ncmoe N` | Alternativa a `--fit` para fijar a mano los expertos en CPU. Con 45 baja a 10,7 GB de VRAM pero pierde ~2 tok/s; con 38 **no cabe** |
| `--no-warmup` | Ahorra el calentamiento inicial; la primera petición paga el `page-in` |
| **Nunca** `--mlock` / `--no-mmap` | El paginado perezoso **es** el offload |

### Cifras medidas

| Métrica | Medido |
|---------|--------|
| Decode sostenido | **32,9 tok/s** (200 tokens, caliente, con visión) |
| Prefill | **309 tok/s** (prompt de 3.852 tokens) |
| Tool calling | 2/2 con dos herramientas en juego |
| Carga en frío | 8-19 s hasta `model loaded` |
| VRAM | 14.489 MiB de 16.376 con mmproj (~1,9 GB libres) |
| RAM | 35-44 GB de RSS (el resto es caché de página del PLE) |
| **Turno real de agente** (OpenCode, prompt de 25.974 tok) | **105 s**: prefill 72,4 s (358,8 tok/s) + decode 28 tok/s |
| Turno con herramientas (2ª vuelta, 2.649 tok) | 17,4 s (prefill 9,8 s a 270 tok/s) |

La primera petición tras arrancar baja a ~7-15 tok/s: son fallos de página al leer los tensores
desde el NVMe. A partir de ahí se estabiliza.

### Banco de pruebas (24/10/2026)

Medido con `bench.sh` (200 tokens, temperatura 0,3, sin *thinking*), 7 configuraciones sobre la
misma máquina:

| Config | Decode | VRAM | Conclusión |
|--------|--------|------|------------|
| A) La de partida: `--fit-target 1024 -t 12` | 26,2 tok/s | 14.730 MiB | Referencia |
| B) A + `-ctk/-ctv q8_0 -ub 1024 -b 4096 -t 16` | 26,6 tok/s | 14.682 MiB | KV q8_0 no cuesta precisión y libera VRAM |
| C) `-ncmoe 45` + KV q8_0 + ubatch 1024 | 27,1 tok/s | **10.711 MiB** | 4 GB de VRAM libres |
| D) B + `--spec-ngram-mod-n-min 3 --n-max 12` | **29,6 tok/s** | 15.038 MiB | Mejor decode: +13 % sobre A |
| E) D + `-ncmoe 45` | 27,4 tok/s | 10.763 MiB | Pierde 2 tok/s pero sobra VRAM |
| F) D + `-ncmoe 38` | ❌ no arrancó | — | 38 capas en GPU no caben |
| G) D con `-t 16` | 24,8 tok/s | 13.002 MiB | SMT perjudica: 12 hilos físicos es lo correcto |

**Ganadora: D**, con dos ajustes de seguridad: `--fit-target 1280` (el mmproj se come ~0,9 GB) y
`-t 12`. Verificado con visión activa: **32,9 tok/s**, 14.489 MiB de VRAM y 1,9 GB libres.

> El «prefill» de estas pruebas (31-58 tok/s) **no es representativo**: el banco usa prompts de
> ~30 tokens. Con 3.852 tokens la cifra real es 309 tok/s.

---

## Visión

Activa desde el 24/10/2026 con `mmproj-F16.gguf` (0,90 GB). Funciona aunque el LLM sea
`qwen4_exp` porque el proyector declara **`clip.projector_type = qwen3vl_merger`** y reutiliza el
encoder visual de Qwen3-VL, que llama.cpp sí implementa.

```bash
curl -s http://127.0.0.1:1919/v1/models | python3 -m json.tool | grep -A4 input_modalities
# "input_modalities": ["text", "image", "video"]
```

| Prueba | Resultado |
|--------|-----------|
| Imagen 480×240 con el texto «HOLA 42» | Leído correctamente |
| Tiempo de respuesta | 2,5 s (151 tok de prompt) |
| Decode con visión | 26,2 tok/s |

Para desactivarla: `QWEN_VISION=0` en el servicio (libera ~0,9 GB de VRAM y deja ~2,8 GB libres).

---

## Uso diario

```bash
qwen-flash              # arranca y espera a que responda (~10-60 s)
qwen-flash estado       # unidad, contexto, VRAM y RAM ocupada
qwen-flash prueba       # petición corta con tok/s medidos
qwen-flash parar
qwen-flash logs
```

Antes de arrancarlo, si LM Studio tiene un modelo cargado: `lms unload --all` (se reparte la VRAM).

---

## Integración con OpenCode

En `~/.config/opencode/opencode.json`:

```json
"providers": {
  "flashnext": {
    "name": "Qwen3.8-Flash-Next (llama.cpp local)",
    "package": "@opencode/ai/providers/openai-compatible",
    "settings": {
      "baseURL": "http://127.0.0.1:1919/v1",
      "apiKey": "local",
      "timeout": 900000,
      "chunkTimeout": 180000
    }
  }
}
```

| Clave | Valor |
|-------|-------|
| Proveedor | `flashnext` (openai-compatible) |
| Agente | `agents.flashnext` → `flashnext/qwen3.8-flash-next` |
| Capacidades | `tools: true`, `input: ["text","image"]`, `output: ["text"]` |
| Límites | contexto 65.536 · salida 8.192 |

```bash
/usr/bin/opencode run --model flashnext/qwen3.8-flash-next "…"
```

> ⚠️ Usa el binario **`/usr/bin/opencode`**, no el atajo `opencode`: ese wrapper carga antes
> `qwen3.8-9b` en LM Studio y aborta si no puede.

Los perfiles `opencode-local.json` y `opencode-cloud.json` **heredan** el proveedor por fusión de
configs; `configurar-opencode.py` lo registra de forma idempotente.

---

## Integración con Hermes

En `~/.hermes/config.yaml` (escrito con `hermes config set`; el fichero está protegido contra
edición directa). Estado real el 24/10/2026:

```yaml
providers:
  flashnext:
    api: http://127.0.0.1:1919/v1
    name: Qwen3.8-Flash-Next local
    api_key: local
    model: qwen3.8-flash-next
    context_length: 65536
    discover_models: true
    request_timeout_seconds: 900      # prefill de 26K = ~72 s; el default corta antes
    stale_timeout_seconds: 600
    capabilities: {vision: true, tools: true}
    models:
      qwen3.8-flash-next:
        supports_vision: true         # ← el routing de imágenes lee ESTO
  custom:                             # ← y los timeouts se leen de ESTE id
    request_timeout_seconds: 900
    stale_timeout_seconds: 600

agent:
  reasoning_overrides:
    qwen3.8-flash-next: low           # el servidor corre en low; sin esto el cliente pide medium
```

```bash
/model flashnext           # solo esta sesión
/model flashnext --global  # por defecto
hermes --provider custom:flashnext -m qwen3.8-flash-next -z "…"
```

Tres cosas que no son obvias y cuestan una tarde si se descubren a base de probar:

| Detalle | Por qué |
|---|---|
| **`capabilities.vision` no basta** | El routing de imágenes (`agent/image_routing.py`) lee `model.supports_vision` → `providers.<p>.models.<id>.supports_vision`. Sin esa clave el veredicto es *desconocido* y la imagen se deriva a un modelo auxiliar |
| **Los timeouts van en `providers.custom`** | En runtime el proveedor con nombre se canonicaliza a `provider="custom"`; `get_provider_request_timeout()` consulta `providers.custom`, no `providers.flashnext` |
| **`hermes config set` parte las claves por puntos** | `models.qwen3.8-flash-next` se interpreta como ruta anidada. Solución: pasar el subárbol como JSON entre comillas simples, que el CLI parsea |

```bash
hermes config set providers.flashnext.models '{"qwen3.8-flash-next": {"supports_vision": true}}'
hermes config set agent.reasoning_overrides '{"qwen3.8-flash-next": "low"}'
```

---

## Problemas conocidos

| Síntoma | Causa / solución |
|---------|------------------|
| Primera respuesta lentísima | `page-in` de tensores desde NVMe; es normal (~7-15 tok/s) |
| Generación a ~5 tok/s | VRAM demasiado llena: subir `--fit-target` |
| RAM «libre» a ~0 GB | Es caché de página del PLE, no una fuga |
| OOM con imágenes grandes | Bug upstream #30032 (indexador QSA); arrancar con `QWEN_VISION=0` |
| `--spec-type draft-mtp` falla | El GGUF no trae cabeza MTP; usar `ngram-mod` |
| Prefill flojo con prompts de agente | ~309 tok/s: un prompt de 26K tarda ~80 s la primera vez |

---

## Referencias

- [Qwen3.8-Flash-Next (modelo base)](https://huggingface.co/Qwen/Qwen3.8-Flash-Next)
- [unsloth/Qwen3.8-Flash-Next-GGUF](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF)
- [llama.cpp — servidor y flags](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)
- [Blog de Qwen3.8-Flash-Next](https://qwen.ai/blog?id=qwen3.8-flash-next)
- Issue #30032 (OOM de visión) · Issue #28933 (crecimiento de RSS)

> 📁 `~/.config/opencode/documentacion/11-qwen-flash-next-local.md` ·
> respaldo `~/Config/opencode/documentacion/11-qwen-flash-next-local.md` ·
> operativa completa en `~/Config/qwen-flash-next/LEEME.md`
