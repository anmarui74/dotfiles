# Nota: modelos de OpenCode Go alojados en China

## Síntoma
Si un modelo de OpenCode Go deja de funcionar de repente con el error:

```
The latest version of this model is only available hosted in China and
requires explicit opt in: https://opencode.ai/workspace/wrk_01KWNJZHA9QS258DM0M2KY8PNZ/go
```

## Causa
El modelo ha pasado a servirse desde la API oficial del proveedor en China
(DeepSeek, Alibaba, etc.) en vez de desde los servidores de OpenCode en
UE/EEUU/Singapur. OpenCode exige aceptarlo explícitamente por cumplimiento legal.

## Solución
1. Ir a https://opencode.ai/auth e iniciar sesión
2. Entrar en el workspace: https://opencode.ai/workspace/wrk_01KWNJZHA9QS258DM0M2KY8PNZ/go
3. Activar el toggle **"Enable models hosted in China"**

## Alternativa sin opt-in
Si no se quiere aceptar el alojamiento en China (privacidad/GDPR), usar modelos
alojados en infraestructura de OpenCode (UE/EEUU/Singapur):
- Qwen3.7 Plus
- MiMo-V2.5
- MiniMax M2.7
- Kimi K2.6

## Historial
- 31/07/2026: DeepSeek V4 Flash falló. Antonio activó el toggle y volvió a funcionar.

## Workspace
- ID: wrk_01KWNJZHA9QS258DM0M2KY8PNZ
- Suscripción Go: ~5€ primer mes, luego ~10€/mes
