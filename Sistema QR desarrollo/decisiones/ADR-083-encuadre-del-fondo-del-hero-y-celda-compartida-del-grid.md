---
doc: ADR-083
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-11-01
origen: DECISIONS.md (indice) - rediseno del HERO del silo f14 sobre la maqueta referentes/hero.jpg
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md, ../BLUEPRINT.md, ../NEXT.md, ../TASKS.md, ../ERRORES_HISTORICOS.md, ADR-082-silo-f14-vinilos-inversos-kernel-y-contrato-boletos-link.md, ADR-006-nomenclatura-atomica.md, ADR-043-fix-mobile-del-hero-del-silo-f11-cyberpunk.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md). ADR nuevo (2026-11-01); el indice de `DECISIONS.md` lo lista bajo **ADR-083** (siguiente libre tras ADR-082).

#### ADR-083: Encuadre del Fondo del HERO y Composicion por Celda Compartida del Grid (Silo F14)

* **ID:** ADR-083 | **Fecha:** 2026-11-01 | **Estado:** Aprobado e implementado. Working tree con **1 archivo de codigo tocado** (`css/templates/fiesta/f14.css`, `git diff --numstat` = **+290 / -59**, 47.483 bytes) y **0 cambios en HTML/JS/SQL**. Los docs de cierre (`TASKS.md`, `NEXT.md`, `DECISIONS.md`) son aditivos (+63 / -0).
* **Autor:** Orquestador de implementacion (tier FREE) con `@frontend-tpl` (implementacion) y `@docs-keeper` (cierre). Verificacion con `@explore` (mapa previo) y `node scripts/smoke_f14_vinilos.js`.

## 1. Contexto (problema)

1. **La foto del evento se recortaba de forma distinta en cada resolucion.** `#mod-hero` (`css/templates/fiesta/f14.css`, seccion 6) declaraba `min-height: 82vh` + `overflow: hidden` y **solo `background-image`** (dos gradientes de textura). La foto real la inyecta el kernel como `background-image` inline en `evento-app.html:1564`. En **todo el silo no existia ni `background-size` ni `background-position`**, asi que el navegador aplicaba el default `auto` + `0% 0%`: la imagen se pintaba **a tamano nativo anclada arriba-izquierda**. Con una fuente de **1671x941 px** (ratio 1.776) el resultado medido era: a **1440 px** desbordaba 231 px por la derecha y **cortaba al artista**; a **1920 px** se dibujaba 1920x1081 dentro de una banda de ~886 px (195 px comidos por abajo); a **2560 px** dejaba **889 px de fondo vacio** a la derecha.
2. **La maqueta de referencia (`referentes/hero.jpg`) pide otra jerarquia.** Imagen a sangre al 100% del ancho, **rostro a la derecha** intacto, columna de informacion a la izquierda (organizador, titulo, subtitulo, meta con iconos) y **contador a sangre al pie**. La foto original es compatible con esa lectura: cara del artista en `x 45%-100%`, banda oscura decorativa en `y 76%-100%`, zona naranja libre en `x 0%-45%`.
3. **El contrato v210 impide mover los atomos.** `#mod-hero`, `#unified-frame` (contador) y `#mod-hero-meta` (fecha/hora/lugar) son **hermanos planos** dentro de `#main-content-flow` (grid con areas nombradas). Cualquier intento de anidar el contador o la meta dentro del hero habria roto el contrato y el Cero Borrado (Oro #2).
4. **El orden del grid era el inverso al pedido.** Las areas declaraban `hero -> countdown -> meta -> ctas`; la maqueta exige `hero -> meta -> contador`.
5. **`.hero-subtitle` no tenia CSS en ningun silo** (0 coincidencias en `css/`): el subtitulo musical se renderizaba con el estilo por defecto del navegador.

## 2. Decision

### 2.1 Encuadre: Opcion B/C hibrida, CSS-only

```css
background-size: cover !important;
background-position: 100% 0% !important;   /* ancla al artista (derecha) y al craneo (arriba) */
background-repeat: no-repeat !important;
min-height: clamp(600px, 43vw, 880px);     /* alto guiado por ANCHO, no por vh */
```

* El alto deja de depender de `vh` (impredecible entre pantallas) y pasa a depender del **ancho**: el recorte vertical se vuelve **constante (~24 %) y siempre desde abajo**, sobre la banda oscura decorativa. **Nunca se recorta la cabeza ni los ojos**, que viven en el 30 % superior de la fuente.
* Movil: `clamp(540px, 80svh, 680px)` con `background-position: 82% 0%` (encuadre especifico permitido por el brief, mismo recurso original).
* Se añade `#mod-hero::before` como **scrim** (gradiente lateral 0.40 -> 0 en 50 %, y gradiente inferior 0.62 -> 0 en 40 %) para legibilidad del texto sin apagar el naranja del centro.

### 2.2 Composicion: celda compartida del grid (sin tocar el DOM)

Los tres atomos se asignan a **la misma area** `hero`; `#mod-hero` con `align-self: stretch` y los otros dos con `align-self: end`, apilados con `z-index` y un desplazamiento calculado:

```css
#mod-hero        { grid-area: hero; align-self: stretch; }
#mod-hero-meta   { grid-area: hero; align-self: end; justify-self: stretch;
                   margin-bottom: calc(var(--f14-cd-h) + 1.5rem); z-index: 6; }
#unified-frame   { grid-area: hero; align-self: end; justify-self: stretch;
                   min-height: var(--f14-cd-h); z-index: 7; }
```

* `--f14-cd-h` (106 px escritorio / 74 px movil) es el **contrato de altura** entre el contador y la meta: el alto real del strip medido en DOM es 102 px, por eso el token se fija en 106 y el hueco entre meta y contador queda en 24 px exactos.
* El orden visual pedido se obtiene sin renombrar atomos ni mover nodos. Las areas `countdown` y `meta` se retiran de `grid-template-areas` (base y breakpoint 767) y ambos atomos pasan a `grid-area: hero`.
* En `<=767px` la meta se apila en columna (`flex-direction: column`) y el contador reduce tipografia; siguen compartiendo celda, sin colisiones.

### 2.3 Atomos nuevos y recolocados

* **`.hero-subtitle`** (NUEVO): kraft, `letter-spacing: .34em`, `clamp(0.66rem, 1.05vw, 0.82rem)`.
* **`#org-name-badge`**: de centrado/rotado a **arriba-izquierda** con la sangria del silo (`--f14-pad-x`), pildora kraft, texto oscuro.
* **`#event-title`**: kraft claro, `clamp(2.4rem, 6.4vw, 6.2rem)`, `text-wrap: balance`, sombra de tinta `0.035em`. `.hero-content` limitado a `min(46vw, 640px)` para **no invadir el rostro** (que empieza en el 45 % del ancho).
* **`#unified-frame`**: franja a sangre, fondo `rgba(10,10,10,.86)`, numeros oxido con `font-variant-numeric: tabular-nums`, separadores verticales sutiles.
* **`#mod-hero-meta`**: fila con iconos SVG recoloreados por CSS (`fill` gana al atributo `fill="var(--gold)"`). **`display` se declara SIN `!important`** porque el kernel oculta el padre `.meta-item` con `display:none` inline cuando el dato esta vacio (ADR-056).
* **`#i18n-sw`**: de `fixed` abajo-derecha a `absolute` arriba-derecha del hero, en todos los anchos, para no tapar el contador ni el CTA.

## 3. Alternativas descartadas

1. **Opcion A del brief: `<img>` con `width:100%; height:auto`.** Descartada: el hero no tiene `<img>` y añadirlo exige tocar el markup compartido `evento-app.html:68-74` (afecta a los 14 silos, dominio de riesgo + Escudo GOLD). Fuera del alcance "solo silo". Ademas, a 1920 px la imagen a `height:auto` daria **1081 px de alto**, mas que el viewport.
2. **`background-size: contain`.** Descartada: deja franjas laterales o inferiores vacias (prohibido por el brief).
3. **`background-size: 100% auto`.** Descartada como base: a 2560 px genera una banda de ~620 px sin imagen (la imagen escala a 2560x1442 dentro de una banda menor). Solo es correcta si el alto se ata a `aspect-ratio`, lo que dispararia la altura del hero.
4. **Subir `min-height` para "arreglar" el recorte.** Descartada explicitamente por el brief y por criterio: agrava el problema en pantallas anchas y no estabiliza nada.
5. **Anidar el contador y la meta dentro del hero.** Descartada: rompe el contrato v210 de atomos hermanos planos.

## 4. Consecuencias

* **Crop residual inevitable:** con una fuente 1.78:1 y una banda a 100 % de ancho, el recorte vertical es inherente. La decision lo hace **constante, predecible y anclado al craneo**. La unica solucion "cero recorte" real seria un reencuadre/outpainting de la imagen a 21:9 (trabajo externo, no codigo).
* **Acoplamiento declarado:** `--f14-cd-h` ata el offset de la meta al alto del strip. Si cambia la tipografia del contador hay que revisar el token. El valor esta comentado en el bloque de tokens.
* **Especificidad de la imagen:** si un futuro evento con `template_id='f14'` usa una imagen con el sujeto a la **izquierda**, `background-position: 100% 0%` lo recortaria. El silo asume composicion "sujeto a la derecha" (la del evento vigente).
* **Cero deuda nueva en el kernel:** el cambio no introduce clases, IDs ni data-attributes; todo selector existe en el DOM real.
* **Deuda de datos registrada** (TSK-118/119): `config_landing.colors` conserva la paleta f9 dorada (`#c9a84c`) con `template_id='f14'`; el subtitulo en BD es `"DRUMN AND BASS REGGAE HIP-HOP"`; `#meta-hora` sale como `20:00 HRS` y no `8:00 PM` (formateador del motor, TSK-119).
* **Deuda de codigo registrada** (TSK-117, ALTA, PAGO + gate §2): el contador usa la zona horaria del dispositivo, no `America/Bogota`, y el `setInterval` no se limpia.

## 5. Verificacion

| Comprobacion | Resultado |
|---|---|
| `node scripts/smoke_f14_vinilos.js` | **PASS 38 / FAIL 0** |
| Llaves balanceadas | 168 / 168 |
| Selectores fuera de scope `.tpl-f14` | 0 (119 reglas) |
| ASCII-safety del silo | 0 bytes > 127 |
| Geometria medida (Chrome headless, DOM real) | hero 819 px; meta `669..689`; contador `713..819`; hueco 24 px exactos |
| `document.scrollWidth` vs viewport (390 / 768 / 1440 / 1920) | identicos -> **cero scroll horizontal** |
| Capturas 1920 / 1440 / 768 / 390 | rostro intacto a la derecha; jerarquia de la maqueta respetada |
| Archivos modificados | `css/templates/fiesta/f14.css` unicamente |

## 6. Aprendizaje reutilizable

El fondo del hero de este proyecto **no viene del CSS**: el kernel lo inyecta como `background-image` inline. Por tanto **cualquier silo que declare solo `background-image` (gradientes) hereda `auto` / `0% 0%` y recorta de forma distinta en cada resolucion**. Todo silo nuevo debe declarar explicitamente `background-size` + `background-position` + `background-repeat` en su bloque de hero. Patron correcto de referencia previa: `css/templates/fiesta/f9.css:314-316`.
