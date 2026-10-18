# Plan y resumen — convivencia de los dos Hermes (dual boot Linux ↔ Windows)

| ⚙️ Estado | 📅 Fecha | 👤 Usuario | 🖥️ Equipo |
|---|---|---|---|
| Fases 1 a 5 aplicadas y verificadas en Linux · encargo 20 para Windows | 14/10/2026 01:15 | Antonio | Linux (CachyOS) |

> Tres objetivos: que cada sesión sepa en qué SO está, que no se pierda ninguna conversación al
> cambiar de sistema, y que ningún Hermes pise el estado del otro.

---

## 1. Lo que fallaba (diagnóstico cerrado)

| # | Objetivo | Fallo encontrado |
|---|---|---|
| 1 | Saber el SO al arrancar | Ninguno nuevo: la regla de `SOUL.md` entró en vigor a las 00:11 (las 4 confusiones del día fueron en sesiones anteriores) |
| 2 | Todas las conversaciones | El import **sustituía** `state.db` en bloque (lo local no publicado se perdía) **y la publicación salía corta**: 2 mensajes del último turno de Windows quedaron fuera de su copia |
| 3 | Cada uno en su sistema | El import copiaba el `SOUL.md` del otro sobre el local sin mirar |
| 4 | Poda del historial | Tres incumplimientos de la regla acordada (detalle abajo) |
| 5 | Aviso automático | No había veredicto: los fallos se descubrían cuando Antonio preguntaba |

**Causa raíz del fallo 2, medida:** la publicación de Windows de las 00:09:04 contiene mensajes
**hasta las 00:07:59**; los 2 que faltaban son de las **00:08:16** y **00:08:30** (el último turno). El
`MANIFEST` se calcula sobre la propia copia, así que cuadraba consigo mismo y el agujero no se veía.
Su log del motor termina a las 00:09:05 sin registrar ningún cierre: después ya no publicó.

## 2. Decisiones de Antonio (14/10/2026, 00:45)

1. **`SOUL.md`: opción A** — sigue viajando (es lo que hace que la regla del SO se cargue en cada
   sesión), pero el import **no lo pisa** si difiere: archiva el del otro y avisa.
2. **Import: sí** — export previo si hay cambios locales + integrar en vez de sustituir.
3. **Poda, diagnóstico y veredicto: adelante.**

## 3. Aplicado y verificado (Linux)

**Import y `SOUL.md`** — `hermes-dual-sync.sh` (copia `.bak-20261014-004917` al lado) y
`windows/hermes-dual-sync.ps1`, los dos publicados en la carpeta común:

- El import llama a `scripts/fusionar-mensajes.py --origen … --local … --aplicar`; si falla, cae al
  copiado clásico avisando en el log. Avisa también si tras fusionar baja el recuento.
- El `SOUL.md` del otro no se pisa: si difiere (comparando sin contar CRLF/LF), se archiva como
  `SOUL.md.de-<equipo>` en el backup previo del import y queda constancia en el log.
- En Windows, función `Import-Soul` y la misma fusión en las dos ramas (también en la del arranque,
  que era donde estaba el agujero); sintaxis validada aquí con el parser de PowerShell.

**Publicación corta (la causa real de los 2 mensajes perdidos):**

- Linux: ya reintentaba 3 veces, pero **si la copia seguía corta publicaba igual** y solo avisaba.
  Ahora **aborta**: mejor no publicar que publicar incompleto.
- Windows: la copia publicada **solo se contaba**, nunca se comparaba con la base viva. Ahora copia a
  un temporal, cuenta las dos, reintenta hasta 3 veces y aborta si sigue corta.

**Poda del historial** — los tres fallos reales, corregidos:

1. `~/.config/hermes-dual-sync.conf` (del 28/09) traía **`RETENCION=5`** y **sobrescribía** el 15 del
   script: la poda conservaba 5 publicaciones, no las 15 de la regla del 13/10. Corregido, con
   `DIAS_MIN_PODA=7` explícito.
2. La poda del motor de **Windows** no era la regla: borraba por patrón suelto (`*-state.db`,
   `*-resto.zip`, con `-Skip 5`) y sin mínimo de días → dejaba medias publicaciones (hay cinco en
   `historial/PC-ANTONIO/` sin su `state.db`) y no respetaba ni retención ni días. Sustituida por la
   misma regla que Linux.
3. `rm -f` **no borra directorios** (y `Get-ChildItem -File` ni los veía): un `resto` descomprimido
   sobrevivía siempre y dejaba la publicación a medias para siempre. Ahora `rm -rf` y
   `Remove-Item -Recurse -Force`.

Sobre el historial real: **0 publicaciones podables hoy** (todas son de los últimos 7 días), que es lo
correcto. El disco compartido tiene **3,0 TB libres**, así que el tamaño no es un problema.

**Veredicto automático (Fase 5):** `orientar.py --veredicto` responde en una línea y con código 0/1
sobre disco compartido, estado del otro sin integrar, motor propio sin publicar desde hace >30 min y
salud del perfil. Enganchado al aviso de arranque, que **solo escribe en Telegram si hay algo mal** (y
siempre lo deja en `~/Config/hermes/logs/arranque-linux.log`). El script es común: Windows puede usar
el mismo modo.

**Corrección de un diagnóstico mío:** dije que la poda no reconocía los formatos del otro motor. Era
falso: borra por prefijo de epoch, mire la extensión que mire. Lo que la frenaba era la regla de los
7 días; lo que estaba mal era la retención del `.conf` y la poda de Windows.

**Pruebas (todas en verde, `dual-boot/pruebas/`):**

| Prueba | Qué verifica |
|---|---|
| `prueba-import.sh` | El import no pierde nada local, entra la sesión del otro y el `SOUL.md` no se pisa |
| `prueba-poda.sh` | 21 → 15 publicaciones, nada de <7 días tocado, la última intacta y el directorio borrado |
| `prueba-copia-corta.sh` | Con una copia 2 mensajes corta el motor **aborta** y no toca lo publicado |

Todo propagado a las copias canónicas (hashes idénticos) y backup regenerado. El motor de producción
publica con normalidad.

## 4. Lo que queda

| Qué | Estado |
|---|---|
| Windows: encargo 20 — ejecutado el 14/10 a las 01:16:59: motor local actualizado, validado y los 4 arreglos comprobados | ✅ |
| Que la regla del SO y el veredicto se prueben en varias sesiones y arranques seguidos | En curso (esta sesión la lleva) |
| Auditoría del manual de Linux: 4 avisos preexistentes → **119 comprobaciones, 0 desfases** (unidades del renumerador también al esquema, con `RequiresMountsFor`) | ✅ |
| Informe de `orientar.py`: ya no dice «ábrelo/impórtalo» cuando el estado del otro está integrado | ✅ |

Regla de trabajo: una causa raíz a la vez, y nada por bueno sin leer el artefacto real en los dos
sistemas.
