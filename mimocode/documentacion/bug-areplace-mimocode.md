# 🐛 Bug A.replace is not a function MiMoCode

Error fatal en TUI MiMoCode 0.1.14 relacionado con `A.replace(/\n$/,"")` en el bundle.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ⚠️ abierto | 09/09/2026 · rev. 09/09/2026 | Antonio |

> Reporte inicial a partir de stack trace de OpenCode 0.1.14. MiMoCode es fork y comparte la TUI.

---

## 📑 Índice
1. [Resumen](#resumen)
2. [Entorno](#entorno)
3. [Error](#error)
4. [Logs revisados](#logs-revisados)
5. [Pasos de reproducción](#pasos-de-reproducción)
6. [Mitigación](#mitigación)

---

## Resumen
Se detecta un `TypeError: A.replace is not a function` en la TUI. El código minificado intenta `A.replace(/\n$/,"")` y `A` no es string.

## Entorno
- MiMoCode 0.1.14
- Binario: `/home/antonio/.mimocode/bin/mimo`
- Config: `~/.config/mimocode/mimocode.jsonc`
- Logs: `~/.local/share/mimocode/log/`
- Agente activo: cloud
- Sesión: `ses_-ffe5f7a968a17ffebBcg8NYWU`

## Error
```
TypeError: A.replace is not a function. (In 'A.replace(/\n$/,"")', 'A.replace' is undefined)
at cG (/ $bunfs/root/src/index.js:974:8249)
...
opencode-version=0.1.14
```

## Logs revisados
Revisión 09/09/2026 09:03-09:07. No se encontró `A.replace` en logs activos. Se observa `GoUsageLimitError` en title generator.

## Pasos de reproducción
1. Abrir MiMoCode con agente cloud
2. Generar respuesta con contenido vacío / streaming
3. Render de mensaje dispara `A.replace`

## Mitigación
Reiniciar sesión, forzar agente build, monitorear logs activos.

---

> 📁 /home/antonio/Config/mimocode/documentacion/bug-areplace-mimocode.md
