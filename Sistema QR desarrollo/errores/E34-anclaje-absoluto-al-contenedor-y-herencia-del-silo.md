---
doc: E34 (ERRORES_HISTORICOS.md 34)
version: v1.8.0-STABLE (heredada)
fecha: 2026-11-04
origen: ERRORES_HISTORICOS.md seccion 34 (nueva, 2026-11-04). Ciclo del hero movil de vinilos-inversos-c8yu (silo f14), commits 8bd6eec..27bcc04; NEXT.md hito -57.
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md, ../NEXT.md, ../TASKS.md, ../css/templates/fiesta/f14.css, ../scripts/smoke_f14_vinilos.js]
estado: resuelto en CSS (2026-11-04)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) seccion 34 - [INDEX](../INDEX.md).

## 34. Meta movil desalineado por anclaje absoluto al contenedor y herencia del silo (2026-11-04 - silo f14)

### A. Sintoma

* En el hero movil (390 px) el meta en dos columnas se veia "desalineado y de distintos tamanos": la fecha, la hora y el lugar no compartian linea base, el icono de calendario quedaba pegado al borde de la pantalla y el bloque no estaba centrado (18 px a la izquierda frente a 48 px a la derecha).

### B. Causa raiz

1. El calendario se posicionaba con `position:absolute; left:0` y su unico ancestro posicionado era `#mod-hero-meta` (el contenedor), no el `.meta-item`. `left:0` se resolvia contra la caja de padding del contenedor, es decir x=0: el icono se anclaba al borde del viewport y arrastraba el bloque a la izquierda.
2. Las filas del grid las dimensionaba el item del lugar, que heredaba `line-height:1.24` (17.86 px) del bloque base (`f14.css:566`) mientras la fecha y la hora tenian 16 px. Cada fila crecia a 18 px y la hora caia 2 px mas abajo (372 frente a 370).
3. Cada fila traia su propio `letter-spacing` del bloque base (0.01em la fecha, 0.07em la hora) y la hora llevaba `font-weight:800` frente a 900 del resto: misma `font-size`, distinto ritmo optico.

### C. Como se resolvio

* `position:relative` en `.meta-item:nth-child(1)` para que el icono se ancle a su celda (x=33) y no al contenedor (x=0).
* `grid-template-rows:16px 16px`, `row-gap:0` y una sola tipografia en los tres items (`0.9rem / 900 / line-height:16px / letter-spacing:0`), declarada con los mismos selectores `:nth-child` para vencer la especificidad del bloque base.
* `grid-template-columns:auto minmax(0,auto)` + `justify-content:center` para centrar el conjunto (33 px por lado) sin perder la capacidad de encoger.
* Medido a 390 px: fecha 358-374 y 67..199; hora 374-390; lugar 358-374 / 374-390 y 253..357; calendario 33..69. `scrollWidth` 390.

### D. Lecciones

* (1) Un `position:absolute` se ancla al ancestro POSICIONADO mas cercano: si el item no lo declara, el ancla es el contenedor aunque el item envuelva visualmente al icono.
* (2) En un silo con herencia (f14 define `line-height` y `letter-spacing` por `:nth-child`), el override movil debe repetir el selector con `:nth-child`; declarar solo `.meta-item` no gana la especificidad.
* (3) Medir `left/right` de cada item con CDP, no solo `top/bottom`: el descentrado y el desalineado horizontal no aparecen en una medicion vertical.
* (4) Guard: `scripts/smoke_f14_vinilos.js` (79 asserts) + CDP a 390 px.
