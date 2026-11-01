# ADR-086 - Tipografia de cartel condensada con contorno cafe, hero guiado por contenido y rotulo LINE UP (silo f14)

- **Estado:** IMPLEMENTADO Y VERIFICADO
- **Fecha:** 2026-11-01
- **Dominio:** CSS de silo (`css/templates/fiesta/f14.css`) - tier FREE, alcance solo f14
- **Tarea:** TSK-121 (tercera iteracion del hero de `vinilos-inversos-c8yu`, tras TSK-116/ADR-083 y TSK-120/ADR-085)
- **Relacionadas:** ADR-083 (alto del hero por ancho y celda compartida del grid), ADR-085 (meta en 2 columnas), ADR-001 (vanilla, sin dependencias ni build), ADR-080 (paleta del evento)

## Contexto

Tres defectos visuales frente a la maqueta `referentes/hero.jpg`:

1. **Titulo:** la maqueta usa una condensada muy pesada con **contorno cafe**. El silo pintaba
   `#event-title` con `--f14-display` (`system-ui` primero) y `text-shadow` plano: ancho normal y
   relieve sucio.
2. **Meta:** el bloque estaba alineado al fondo de la celda del grid, pero el hero tenia un alto
   fijo de `clamp(600px, 43vw, 880px)` (ADR-083) mucho mayor que su contenido, asi que quedaba un
   hueco muerto de **123 px** entre el subtitulo y el meta (y 158 px en movil).
3. **Line up:** el rotulo decia `VINILOS INVERSOS` y no tenia subtitulo; debia decir `LINE UP` con
   la tagline `una noche para vibrar con los mejores sonidos` justo debajo.

## Decision

### 1. Stack condensado elegido por medicion, no por intuicion

Nuevo token `--f14-poster`. Se midio el ancho real de `VINILOS` a 120 px en Chrome:

| Familia | Ancho | Resultado |
|---|---|---|
| `system-ui` (stack anterior) | 491 px | ancho, no es cartel |
| `'Arial Narrow'` | 551 px | **no resuelve**: cae al sans generico |
| `'Liberation Sans Narrow'` | 551 px | no resuelve |
| `Franklin Gothic Medium` | 410 px | resuelve |
| `Impact` | 368 px | resuelve, condensada pesada |
| `Haettenschweiler` | 274 px | resuelve, ultra condensada |

Decision: `Impact, Haettenschweiler, 'Franklin Gothic Medium', 'Arial Narrow', sans-serif`.
`font-stretch: condensed` se descarto porque **no cambia nada** (551 -> 551): es un no-op sin
eje variable y podia interferir en el emparejamiento de familias.

### 2. Contorno cafe con `text-stroke`

Token nuevo `--f14-cafe: #4A2E1B` (tinta de la maqueta) y, sobre `#event-title` y el rotulo
`LINE UP`, `-webkit-text-stroke: clamp(1.2px, 0.32vw, 4.4px)` + `paint-order: stroke fill`.
Se elimina el `text-shadow` plano anterior (hacia de relieve sucio) y se conserva una sombra
corta para despegar el cartel del fondo.

### 3. Hero guiado por contenido (la causa real del hueco)

`#mod-hero`, `#unified-frame` y `#mod-hero-meta` comparten la celda `hero` del grid y se alinean al
fondo (`align-self: end`). Mientras el hero tuvo alto fijo, el meta se pegaba al fondo de una banda
mucho mas alta que su contenido. Ahora:

- `min-height: clamp(360px, 26vw, 560px)` (solo suelo de seguridad, deja de dominar),
- `padding-bottom: calc(var(--f14-cd-h) + 6rem)` (reserva meta + contador).

Resultado: el alto lo fija el contenido y el meta queda **26 px** bajo el subtitulo en desktop y
**25 px** en movil, sin margenes magicos ni cambios de DOM. Se ajustaron los tres breakpoints con
la misma aritmetica (1199: `clamp(340px,40vw,520px)`; 767: `min-height: 280px` y
`padding-bottom: cd-h + 4.7rem`).

### 4. Rotulo del line up y su tagline

- `#mod-lineup::before` = `LINE UP` con la tipografia de cartel.
- Tagline en **`.lineup-grid::before`**, no en `#mod-lineup::after`: el `::after` de la seccion
  renderiza **despues** de la grilla de artistas. El wrapper se fuerza a `display:block !important`
  para que la tagline sea hermana de `#db-lineup` y quede justo bajo el rotulo. Se muestra en
  MAYUSCULAS con `letter-spacing: 0.24em` via `text-transform`: el `content` conserva el texto tal
  como se escribio, la transformacion es solo de presentacion.

## Alternativas descartadas

| Alternativa | Por que no |
|---|---|
| Subir el meta con `margin-bottom` negativo tuneado | Depende del alto del contenido: se rompe al cambiar el titulo o el numero de lineas del lugar |
| `@font-face` o CDN con una condensada real (Anton, Druk) | ADR-001: sin dependencias externas ni build en runtime |
| Imagen/SVG con el titulo | Duplica el dato y mata la indexabilidad del `<h1>` |
| Hardcodear el subtitulo (`DRUM N BASS - REGGAE - HIP HOP`) en CSS | Oculta el dato real (Cero Borrado) y miente si cambia el evento |
| `text-shadow` multi-offset como contorno | 8 sombras por glifo: caro y sucio a tamaños grandes |

## Consecuencias

- **Positivas:** titulo de cartel y meta pegado al subtitulo con **0 cambios de HTML/JS**; el hero
  deja de tener banda vacia y gana densidad como la maqueta; todo sigue aislado por `.tpl-f14`.
- **Limite aceptado:** el contorno depende de `-webkit-text-stroke` (soportado por Chrome, Safari
  y Firefox modernos; sin soporte el titulo simplemente pierde el borde, no se rompe).
- **Deuda declarada (datos, no codigo):** los textos pedidos para el meta
  (`NOVIEMBRE 20`, `8:00 P.M`, `KLANDESTUNO BAR`, `KRA 4 # 19-54 (PISO 4)`) y el subtitulo con
  guiones son **datos** (`content.subtitulo` + `content.meta`). El `PATCH` directo a
  `eventos.config_landing` con la clave anon devuelve **200 + `[]`**: RLS lo rechaza (mismo muro de
  TSK-118). Se aplican como overrides en el admin; el CSS del silo ya los pinta (`meta-line`).

## Verificacion (archivo real, ADR-006)

| Comprobacion | Resultado |
|---|---|
| `git diff --numstat` | `css/templates/fiesta/f14.css` **+64 / -28** (unico archivo de codigo) |
| Cambios en motor / admin / API / SQL / otros silos | **0** |
| Balance de llaves del CSS | **0** (minimo 0) |
| Lineas agregadas con bytes > 127 | **0** |
| `node scripts/smoke_f14_vinilos.js` | **PASS 38 / FAIL 0** |
| `node scripts/smoke_hero_contract.js` | **PASS 64 / FAIL 0** |
| Harness visual 1440 px | hueco subtitulo->meta **26 px**; meta->contador **24 px**; `scrollWidth == clientWidth` |
| Harness visual 500 px | hueco **25 px**; meta->contador **16 px**; sin desborde horizontal |
| Sonda de fuentes | Impact 368 / Haettenschweiler 274 / Franklin 410 / Arial Narrow 551 / system-ui 491 |
