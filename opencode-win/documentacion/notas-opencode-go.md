# ☁️ Modelos de OpenCode Go alojados en China (Windows)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ activo | 10/09/2026 · rev. 10/09/2026 | Antonio |

> 📝 **Nota:** si un modelo de OpenCode Go deja de funcionar de repente, esto es lo que ocurre y cómo arreglarlo.

---

## 🔍 Síntoma

Error al usar un modelo de OpenCode Go:

```
The latest version of this model is only available hosted in China and
requires explicit opt in: https://opencode.ai/workspace/wrk_01KWNJZHA9QS258DM0M2KY8PNZ/go
```

## ⚠️ Causa

El modelo ha pasado a servirse desde la API oficial del proveedor en **China**
(DeepSeek, Alibaba, etc.) en vez de desde los servidores de OpenCode en
UE/EEUU/Singapur. OpenCode exige aceptarlo explícitamente por cumplimiento legal.

## ✅ Solución

1. Ir a <https://opencode.ai/auth> e iniciar sesión
2. Entrar en el workspace: <https://opencode.ai/workspace/wrk_01KWNJZHA9QS258DM0M2KY8PNZ/go>
3. Activar el toggle **"Enable models hosted in China"**

> 🔑 **Credenciales en Windows:** la sesión de OpenCode Go se guarda en
> `C:\Users\evo01\.local\share\opencode\auth.json`. El agente `cloud` usa el modelo
> `opencode-go/deepseek-flash` (configurado en `opencode.jsonc`).

## 🛡️ Alternativa sin opt-in

Si no se quiere aceptar el alojamiento en China (privacidad/GDPR), usar modelos
alojados en infraestructura de OpenCode (UE/EEUU/Singapur):

| Modelo | Notas |
|--------|-------|
| Qwen3.7 Plus | Alternativa general |
| MiMo-V2.5 | Alternativa general |
| MiniMax M2.7 | Alternativa general |
| Kimi K2.6 | Alternativa general |

## 📜 Historial

| Fecha | Evento |
|-------|--------|
| 31/07/2026 | DeepSeek V4 Flash falló. Antonio activó el toggle y volvió a funcionar |

## 🗂️ Workspace

| Campo | Valor |
|-------|-------|
| ID | `wrk_01KWNJZHA9QS258DM0M2KY8PNZ` |
| Suscripción Go | ~5 € el primer mes, luego ~10 €/mes |

> 📁 Config activa en Windows: `C:\Users\evo01\.config\opencode\`
> (`opencode.jsonc` global/cloud y `opencode-local.json` para LM Studio).
