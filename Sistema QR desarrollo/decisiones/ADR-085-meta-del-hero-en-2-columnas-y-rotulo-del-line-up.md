# ADR-085 - Meta del hero en 2 columnas por CSS Grid y rotulo del line up (silo f14)

- **Estado:** IMPLEMENTADO Y VERIFICADO
- **Fecha:** 2026-11-01
- **Dominio:** CSS de silo (`css/templates/fiesta/f14.css`) - tier FREE, alcance solo f14
- **Tarea:** TSK-120 (nace del rediseno del hero de `vinilos-inversos-c8yu`, TSK-116)
- **Relacionadas:** ADR-083 (composicion por celda compartida del grid), ADR-080 (paleta del evento), ADR-001 (vanilla JS, sin dependencias)

## Contexto

El hero del evento `vinilos-inversos-c8yu` (`template_id='f14'`, theme `vinilos`) ya estaba
reencuadrado a sangre sobre la imagen real (TSK-116, ADR-083), pero el bloque de metadatos
seguia con la forma heredada del kernel: **una fila de tres chips** (`fecha`, `hora`, `lugar`)
con tipografia de `0.72rem` y `flex-wrap`.

La maqueta aprobada (`referentes/hero.jpg`) pide otra cosa:

```
[calendario]  20 NOVIEMBRE        |  [pin] KLANDESTINO
              8:00 PM            |        KRA 4 # 19-56
                                 |        BOGOTA D.C.
```

Es decir: **dos columnas** separadas por un divisor vertical, la fecha como linea **grande**
(es el dato que el visitante busca primero) y la hora subordinada debajo, el lugar con su
direccion a la derecha. Ademas el nombre del evento debe presidir la seccion de artistas
(`#mod-lineup`, la seccion que va inmediatamente debajo del hero).

Restriccion dura: el motor compartido `evento-app.html` emite el meta como **tres
`.meta-item` planos y hermanos** dentro de `#mod-hero-meta`, sin wrappers por columna:

```html
<div id="mod-hero-meta" class="hero-meta">
  <div class="meta-item"><svg .../><span id="meta-fecha">...</span></div>
  <div class="meta-item"><svg .../><span id="meta-hora">...</span></div>
  <div class="meta-item"><svg .../><span id="meta-lugar">...</span></div>
</div>
```

Y `#mod-lineup` **no tiene ningun encabezado** en el DOM: es `<section>` + `.lineup-grid` +
`#db-lineup`.

## Decision

1. **Las dos columnas se resuelven solo con CSS Grid**, sin tocar el DOM (Cero Borrado y
   contrato de atomos intactos):
   * `#mod-hero-meta` pasa a `display: grid !important` con
     `grid-template-columns: auto minmax(0, 1fr)` y `grid-template-rows: auto auto`.
   * Colocacion por `:nth-child` (los tres items son fijos y siempre existen en el DOM; el
     kernel solo los oculta con `display:none` inline):
     * `:nth-child(1)` **fecha** -> columna 1, fila 1, `clamp(1.05rem, 1.7vw, 1.55rem)` y peso 900.
     * `:nth-child(2)` **hora** -> columna 1, fila 2.
     * `:nth-child(3)` **lugar** -> columna 2, `grid-row: 1 / span 2`.
2. **El divisor vertical de la maqueta es un `border-left` sobre el lugar** con
   `align-self: stretch`: el item se estira a las dos filas y el borde cubre exactamente la
   altura del bloque (si el lugar viene vacio, el kernel oculta el item y el divisor
   desaparece con el).
3. **Un unico icono por columna, como la maqueta**: se oculta el icono de reloj del item de la
   hora y su texto se alinea bajo la fecha con
   `padding-left: calc(clamp(20px, 2.2vw, 26px) + 0.5rem)` (ancho del icono + gap del flex).
4. **El rotulo del line up va en `#mod-lineup::before`** con el nombre del evento. El silo f14
   es **exclusivo** de este evento (verificado por REST: **1 de 13** eventos con
   `template_id='f14'`), asi que un `content` fijo no contamina otros silos ni otros eventos.
5. **Soporte `.meta-line`** (`display: block`) agregado en el silo: hoy es **inerte** porque el
   motor solo habilita la fecha en 2 lineas para `tpl-f9`/`tpl-f9b`; queda listo para el fix
   descrito en las deudas.

## Por que `display: grid !important`

La **activacion atomica** del mismo `f14.css` (seccion 3) fija `display: flex !important` para
`#mod-hero`, `#unified-frame`, `#mod-hero-meta` y `#mod-hero-ctas`, porque el kernel apaga todo
por defecto (IoC v212). Un `display: grid` sin `!important` **pierde**. El `!important` aqui no
rompe el ocultamiento del kernel: ese se aplica **inline** (`style.setProperty('display','none','important')`)
y las declaraciones inline `!important` ganan siempre al CSS de autor.

## Alternativas descartadas

| Alternativa | Por que no |
|---|---|
| Reordenar o envolver los items en el DOM (2 wrappers de columna) | Rompe el contrato de atomos (v210) y exige cambio del motor compartido: riesgo alto para un cambio visual y gate §2 innecesario |
| `:has(#meta-fecha)` para seleccionar por id | Compatibilidad (Firefox < 121) para una ganancia nula: los items son fijos y `:nth-child` es determinista |
| Hardcodear la fecha formateada en CSS (`content: "20 NOVIEMBRE"`) | Duplica el dato: si el evento se reprograma, el CSS miente mientras el contador y la fecha real cambian |
| Mantener `flex` y simular columnas con `width`/`order` | No hay forma de apilar fecha+hora en una columna y el lugar en otra sin wrappers; el `order` no crea filas |

## Consecuencias

* **Positivas:** el meta queda alineado con la maqueta (jerarquia, tamano, divisor, iconos) con
  **0 cambios de HTML/JS** y aislamiento total por `.tpl-f14`. Se corrigieron de paso dos
  reglas responsive incoherentes con el nuevo layout (el `@media (max-width:767px)` ponia
  `flex-direction: column`, inerte en grid, y el `@media (min-width:1279px)` un `gap` ajeno).
* **Limite aceptado:** el lugar es **un unico string** (`eventos.ubicacion`), asi que no se
  puede pintar en 3 lineas (`nombre` / `direccion` / `ciudad`) sin override `content.meta.lugar`
  (gateado) o un campo nuevo. Se ve correcto en una linea.
* **Deuda declarada (media):** la fecha se sigue pintando **ISO** (`2026-11-20`) y ahora es la
  linea grande, asi que el defecto es visible. La causa es `__esMeta2Lineas()`
  (`evento-app.html:919-926`), cuya allowlist es literal `['tpl-f9','tpl-f9b']`; en f14 la rama
  de `__formatoFechaLarga()` no se ejecuta. Fix propuesto: agregar `'tpl-f14'` a la allowlist
  (2 lineas aditivas) y el silo pintaria `VIERNES 20` / `NOVIEMBRE DE 2026` con el CSS ya
  presente. **No ejecutado: requiere gate `AGENTS.md` §2** (motor compartido).

## Verificacion (archivo real, ADR-006)

| Comprobacion | Resultado |
|---|---|
| `git diff --numstat` | `css/templates/fiesta/f14.css` **+147 / -18** (unico archivo de codigo) |
| Cambios en otros silos / motor / admin / API / SQL | **0** |
| Balance de llaves del CSS | **0** (minimo 0) |
| Lineas agregadas con bytes > 127 | **0** |
| `node scripts/smoke_f14_vinilos.js` | **PASS 38 / FAIL 0** |
| `node scripts/smoke_all.js` | **11 PASS / 1 FAIL** (`smoke_f9b_mistico_nocturno`, deuda preexistente confirmada con `git stash`) |
| Harness visual local (Chrome headless, 1440 / 767 / 500 px) | 2 columnas con divisor, jerarquia fecha>hora>lugar, sin solapes ni scroll horizontal |
