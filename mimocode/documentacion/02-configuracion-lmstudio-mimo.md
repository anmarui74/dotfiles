# 🖥️ Configuración LM Studio MiMoCode

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

> Servidor LM Studio + proxy 4001 para modelos locales

---

## 📑 Índice
1. [Arquitectura](#arquitectura)
2. [Puertos](#puertos)
3. [Proxy](#proxy)
4. [Modelo](#modelo)

---

## Arquitectura

LM Studio → puerto 1234 → `lmstudio-proxy.py` → puerto 4001 → MiMoCode

---

## Puertos

| Componente | Puerto |
|------------|--------|
| LM Studio Server | 1234 |
| Proxy | 4001 |
| Dashboard métricas | 4200 |

---

## Proxy

`~/.config/opencode/lmstudio-proxy.py` reutilizado. Inyecta `tokens_per_second` y elimina prefijo `lmstudio/`.

---

## Modelo

`models-qwen3.8-9b` con 80k contexto. Configurado en `provider.lmstudio.baseURL = http://localhost:4001/v1`.

> 📁 `~/.config/mimocode/` - Configuración independiente de MiMoCode
