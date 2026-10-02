# ADR-070: Titulo del hero en 2 lineas, con el subtitulo como 2a linea (y captura unica en Cimientos)

- **Estado:** DECIDIDO (implementado y verificado el 2026-10-02)
- **Dominio:** kernel de render (`evento-app.html`) + editor (`admin.html`) + silos CSS
- **Ruta de la sesion:** FREE (`opencode/big-pickle`). Los dominios de riesgo (`renderer`, `admin`) no son invocables desde FREE: los cambios se aplicaron de forma directa por el primario y se certificaron con subagentes FREE (`explore`, `frontend-tpl`, `qa-auditor`, `docs-keeper`).

## Problema

El admin escribia el nombre del evento, el subtitulo y la descripcion en lugares distintos, y el kernel partia el titulo en 2 lineas partiendo la lista de palabras por la mitad. Eso producia tres defectos:

1. **Dato huerfano.** El subtitulo se capturaba en el paso 3 del wizard pero se pintaba debajo del titulo, no como parte de el: el autor tenia que decidir el ritmo del titulo en un sitio y el texto en otro.
2. **Partido arbitrario.** Partir `NOMBRE DEL EVENTO` en `NOMBRE DEL` / `EVENTO` produce lineas desiguales sin ningun criterio editorial y rompe palabras.
3. **Ruido de captura.** El autor veia en Contenido un campo de subtitulo que no era un subtitulo del titulo sino un parrafo suelto debajo.

## Decision

1. **Captura unica en Cimientos.** El subtitulo (`ev-hero-subtitulo`) y la descripcion (`ev-d`) se capturan en el paso 1 del wizard, junto al nombre. Se movio el bloque de markup: cada ID existe **exactamente una vez** (Cero Borrado).
2. **La 2a linea del titulo ES el subtitulo.** Se retira el split automatico por palabras. En los silos con capacidad, `#event-title` recibe dos spans que **ya existian** en el CSS: `.hero-title-line1` = nombre y `.hero-title-line2` = subtitulo. Si no hay texto de subtitulo, la 2a linea no se crea (regla de vacio, fail-open: no se crea una linea vacia que empuje el layout).
3. **Sin duplicar.** Cuando el titulo ya pinto el subtitulo como 2a linea, `#event-subtitle` permanece oculto. Si se encendiera tambien, el mismo texto apareceria dos veces en el hero.
4. **Capacidad por allowlist explicita, no por prefijo.** Se agregan dos funciones al kernel, con el mismo criterio de token completo que ya usaba `__esFamiliaF9()`:
   - `__esTitulo2Lineas()` = `['tpl-f6', 'tpl-f9', 'tpl-f10', 'tpl-f13']`
   - `__esMeta2Lineas()` = `['tpl-f9', 'tpl-f9b']`

## Exclusiones deliberadas

- **`tpl-f8` FUERA del titulo de 2 lineas.** Su CSS oculta `#event-title` con `display:none !important`. Si el subtitulo viviera dentro del titulo, **seria invisible**: se perderia en silencio. Por eso el admin tampoco lo ofrece.
- **`tpl-f9b` FUERA del titulo de 2 lineas.** Ya tiene su propio bloque `#event-subtitle` con estilo propio; meterlo tambien en el titulo lo duplicaria.
- **La meta de 2 lineas NO crece.** `.meta-line` **solo** tiene CSS en `f9` y `f9b` (lo advierte `f12.css:735`). Encenderla en otro silo imprimiria los dos spans sin estilo (una linea cruda) y **degradaria** el hero. La allowlist se mantiene conservadora a proposito: la omision es la proteccion.

## Invariante que NO se debe romper

**La tabla del admin y la del kernel deben coincidir.** Si el admin ofrece un campo que el kernel no pinta, el dato se captura y se pierde en silencio; no hay error, no hay aviso. Por eso:

- `_THEME_TITULO_2_LINEAS` en `admin.html` = `{ afromango-editor, mistico }` = `{ f6, f9 }`.
- `_THEME_TPL` solo mapea `f5, f6, f7, f8, f9, f11, f12, f9b`; por lo tanto los silos **alcanzables** con 2 lineas de titulo son `f6` y `f9`, que son exactamente los dos de la tabla del admin.
- `f10` y `f13` estan listados en el kernel por si se mapean despues. **Anadir un silo exige las dos cosas: su CSS y su entrada en la allowlist del kernel.**

## Wizard de 5 pasos

El admin pasa de 4 a 5 pasos: `1 Cimientos`, `2 ADN Visual`, `3 Contenido`, `4 Registro + QR`, `5 Blindaje`. El paso 4 concentra formulario, preguntas abiertas, la casilla "¿el formulario entrega codigo QR?" y el segundo escaneo de ticket. La casilla de QR esta **espejada en ambos sentidos** con el selector de salida del paso 1 sobre el mismo dato `_evCapturaPura`: dos controles, una sola fuente de verdad.

## Verificacion

- `node --check` sobre los `<script>` inline de `admin.html` y `evento-app.html`: OK.
- Balance de `<div>` sin cambios respecto a HEAD: `admin.html` diff 3, `evento-app.html` diff 1.
- `scripts/smoke_ticket_diseno.js`: 265/265 PASS.
- `scripts/smoke_hero_contract.js` (nuevo): 64/64 PASS, con 4 asserts **guard** que mutan una copia en memoria para demostrar que detectan la regresion (regreso del split, desalineacion de allowlist, id duplicado, panel borrado del DOM).

## Alternativas descartadas

- **Mantener el split y anadir el subtitulo como 3er elemento:** mantiene el partido arbitrario y el autor sigue sin control sobre donde cae la quebra.
- **Dejar que el CSS decida la quebra de linea:** `text-wrap: balance` es estandar pero no garantiza dos lineas ni es controlable desde el admin; el autor necesita una decision explicita.
- **Habilitar la meta de 2 lineas en f6/f10/f13:** requiere escribir `.meta-line` en esos silos. Es trabajo legitimo, pero es una decision estetica por silo, no parte de este ADR.

## Consecuencias

- El kernel ya no parte texto: el autor decide donde cae la linea 2 escribiendola.
- El subtitulo tiene una unica fuente de verdad (el admin) y un unico destino visual.
- Cualquier silo nuevo que quiera 2 lineas necesita CSS **y** allowlist en el kernel **y** entrada en la tabla del admin, en ese orden.
