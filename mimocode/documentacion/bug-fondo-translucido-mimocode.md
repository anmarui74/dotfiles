# 🐛 Fondo translúcido en la TUI de MiMoCode (bug oficial #1146)
Diagnóstico completo del fondo translúcido en kitty y comentario listo para publicar en el issue #1146.

| ⚙️ Estado | 📅 Fecha | 👤 Usuario |
|-----------|----------|------------|
| ✅ Diagnóstico cerrado · ✅ comentario **publicado** en el issue #1146 | 16/09/2026 · rev. 16/09/2026 | Antonio |

> Es un **bug de MiMoCode**, no de la configuración ni del terminal: `renderer.setBackgroundColor(theme.background)` hace que el terminal aplique su `background_opacity` a **toda** la TUI, con cualquier tema. El arreglo está propuesto en el PR **#1382**, sin fusionar.

---

## 📑 Índice
1. [Resumen](#resumen)
2. [Causa raíz](#causa-raíz)
3. [Evidencia](#evidencia)
4. [Vías descartadas](#vías-descartadas)
5. [Comentario para el issue #1146](#comentario-para-el-issue-1146)

---

## Resumen

| Dato | Valor |
|---|---|
| Issue oficial | [#1146](https://github.com/XiaomiMiMo/MiMo-Code/issues/1146) *"Theme background stays transparent after changing theme"* — **ABIERTO** (19/06/2026) |
| PR de arreglo | [#1382](https://github.com/XiaomiMiMo/MiMo-Code/pull/1382) *"fix(tui): use solid system theme background"* — **sin fusionar** |
| Versión afectada | **0.1.14**, que es la **última** publicada (02/09/2026) → no hay actualización que lo arregle |
| Síntoma | Los colores del tema se aplican, pero el fondo se queda translúcido (se ve el escritorio) con **cualquier** tema y persiste tras reiniciar |
| Alcance | Cualquier terminal que aplique opacidad al fondo por defecto (kitty, etc.) |

---

## Causa raíz

1. `packages/opencode/src/cli/cmd/tui/context/theme.tsx:484-486`

```js
createEffect(() => {
  renderer.setBackgroundColor(values().background)
})
```

2. `packages/core/src/renderer.ts:4062` (opentui)

```js
public setBackgroundColor(color: ColorInput): void {
  const parsedColor = parseColor(color)
  this.lib.setBackgroundColor(this.rendererPtr, parsedColor as RGBA)
  this.backgroundColor = parsedColor as RGBA
  this.nextRenderBuffer.clear(parsedColor as RGBA)
  this.requestRender()
}
```

La aplicación declara al terminal que **su fondo por defecto es el mismo color que pinta**. Y la documentación de kitty dice que `background_opacity` *«only sets the background color's opacity in cells that have the same background color as the default terminal background»*. Al coincidir siempre, **todas** las celdas de la TUI caen en ese caso y kitty las compone a `background_opacity` (0,8) → el escritorio se ve a través.

---

## Evidencia

- **Control:** OpenCode, en la **misma** ventana de kitty, sale **sólido** → el terminal no transparenta las celdas que un programa pinta con un color explícito. Esto descarta que sea un problema global del terminal.
- **Independiente del tema:** se probaron varios temas (tokyonight, mimocode, system) y el fondo siguió translúcido.
- **No es una clave de configuración:** el esquema oficial `theme.json` (53 claves) no tiene ninguna para el fondo del renderizador; `thinkingOpacity` sólo afecta al **texto** del bloque de pensamiento (*"Opacity applied to thinking/reasoning text"*, default 0,6).
- **Descartado el modo `plain`:** `util/terminal.ts:21-26` → `isPlainTerminal()` sólo es verdadero con `MIMOCODE_TUI_PLAIN` o terminal nativo de macOS; en Linux sin la variable es `false`.
- **Entorno medido:** Arch Linux + Wayland (GNOME) · kitty **0.48.2** con `background_opacity 0.8` · `COLORTERM=truecolor` · `TERM=xterm-kitty` · MiMoCode **0.1.14** · modo `dark` · `theme: tokyonight` · `MIMOCODE_TUI_PLAIN` sin definir.

---

## Vías descartadas

| Vía | Resultado |
|---|---|
| Cambiar de tema / subir `thinkingOpacity` a 1 | ❌ No afecta al fondo (sólo al texto del pensamiento) |
| Tema propio en `~/.config/mimocode/themes/*.json` | ❌ Mecanismo oficial y verificado (`theme.tsx:540-572`), pero no puede tocar el fondo del renderizador |
| Plugin TUI que reajuste `api.renderer` (`plugin/tui.ts:508`) | ❌ **Empeoró**: reaplicar `setBackgroundColor` con intervalo fuerza repintados parciales y deja sin pintar los paneles |
| Editar `kitty.conf` | ⛔ Vetado por el usuario (decisión suya, no una limitación técnica) |
| Ventana sin transparencia (`kitty -o background_opacity=1.0`) | ✅ **Funciona**, pero abre ventana nueva (rechazado) |

---

## Comentario para el issue #1146

> ✅ **PUBLICADO** el 16/09/2026 por `anmarui74` → https://github.com/XiaomiMiMo/MiMo-Code/issues/1146#issuecomment-5690774840

```markdown
Still reproducing on **v0.1.14** (latest release, 2026-09-02) — Arch Linux, Wayland (GNOME), **kitty 0.48.2**.

The symptom matches this report exactly:

- theme colors apply correctly (via `/themes`), but the **background stays translucent** (desktop wallpaper visible through it);
- it happens with **every** theme (tokyonight, mimocode, system, …), so it is not theme-specific;
- it persists across restarts;
- **control test:** OpenCode running in the **same** kitty window renders a **solid** background, so the terminal is not forcing transparency on cells that an app paints with an explicit color.

### Root cause (source, v0.1.14)

1. `packages/opencode/src/cli/cmd/tui/context/theme.tsx:484-486`

   ```js
   createEffect(() => {
     renderer.setBackgroundColor(values().background)
   })
   ```

2. opentui `packages/core/src/renderer.ts:4062`

   ```js
   public setBackgroundColor(color: ColorInput): void {
     const parsedColor = parseColor(color)
     this.lib.setBackgroundColor(this.rendererPtr, parsedColor as RGBA)
     this.backgroundColor = parsedColor as RGBA
     this.nextRenderBuffer.clear(parsedColor as RGBA)
     this.requestRender()
   }
   ```

So the app publishes **the very color it paints** as the terminal's *default background*. kitty documents `background_opacity` as applying *"only … in cells that have the same background color as the default terminal background"* — and since they always match, every cell of the TUI falls into that case and gets composited at `background_opacity` (0.8).

Note that #1382 targets the `system` theme, but the `system` theme is not needed to reproduce: any theme with an **opaque** background still goes through `renderer.setBackgroundColor`.

### Environment

- OS: Arch Linux, Wayland, GNOME
- Terminal: kitty 0.48.2 (`background_opacity 0.8`, `COLORTERM=truecolor`, `TERM=xterm-kitty`)
- MiMoCode 0.1.14 (latest), dark mode, `theme: tokyonight`, `MIMOCODE_TUI_PLAIN` unset

### Suggested direction

Avoid publishing the theme background as the terminal default (or publish a value that differs from the painted one), so painted cells stop being treated as "default background" cells by the terminal. A config-side workaround does not exist today — the theme schema has no key for the renderer background.
```

> 📁 `~/.config/mimocode/` - Configuración activa de MiMoCode · `~/Config/mimocode/documentacion/` - Documentación de incidencias
