---
doc: ADR-082
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-29
origen: DECISIONS.md (indice) - entrega del silo f14 + 4 cambios aditivos de kernel + registro en admin.html
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md, ../BLUEPRINT.md, ../NEXT.md, ../TASKS.md, ../ERRORES_HISTORICOS.md, ADR-041-entrega-del-silo-f9-mistico-rastro-mc-atomo.md, ADR-042-silo-f10-rico-cyberpunk-fosforescente.md, ADR-043-fix-mobile-del-hero-del-silo-f11-cyberpunk.md, ADR-048-silo-f12-kande-tropical-noir-brutalista.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md). ADR nuevo (2026-10-29); el indice de `DECISIONS.md` lo lista bajo **ADR-082** (el brief preveia `ADR-072`, ya asignado a la atribucion del link de invitador; se usa el siguiente libre tras ADR-081).

#### ADR-082: Silo F14 "Vinilos Inversos" (Cartel Urbano / Fanzine Grunge) - Silo Nuevo, 4 Cambios Aditivos de Kernel con Gate `__esF14Silo()` y Contrato Opt-In `content.boletos.link|url`

* **ID:** ADR-082 | **Fecha:** 2026-10-29 | **Estado:** Aprobado y entregado. Working tree con 5 archivos de codigo tocados (`css/templates/fiesta/f14.css` NUEVO real + `css/templates/fiesta/f14-volcado-tailwind.bak.css` respaldo + `evento-app.html` + `admin.html` + `scripts/smoke_f14_vinilos.js` NUEVO) y el respaldo del volcado. Este ADR es el cierre documental: **0 cambios de codigo por este cierre**.
* **Autor:** Documentation Specialist (`@docs-keeper`); el silo, el kernel y el registro en admin fueron implementados por los equipos de dominio. Este ADR registra la entrega verificada archivo por archivo (patron ADR-006).

## 1. Contexto (problema)

1. **El nombre `f14.css` estaba ocupado por un volcado inservible.** `css/templates/fiesta/f14.css` contenia **38.082 bytes de HTML + Tailwind** (markup volcado, no CSS). El kernel lo inyecta como hoja de estilos cuando el evento tiene `template_id='f14'`, asi que el silo existia "de nombre" pero no renderizaba nada: cualquier evento apuntado a `f14` habria caido al estilo base sin error visible. **Ningun evento lo usaba**, por eso el defecto no se habia manifestado. El volcado se conserva en `css/templates/fiesta/f14-volcado-tailwind.bak.css` (38.082 bytes, Cero Borrado) y se registra como incidente en `ERRORES_HISTORICOS.md` seccion 32 (E32).
2. **Faltaba una estetica de cartel urbano / fanzine** en el catalogo de Fiesta: los 13 silos existentes cubren tropical noir, cyberpunk, mistico, brutalismo claro, etc., pero ninguno el registro "papel kraft + tinta + oxido" de fanzine impreso.
3. **Tres carencias funcionales del kernel bloqueaban cualquier silo de ese estilo** (no son exclusivas de f14): (a) el acordeon de FAQ no era accesible por teclado; (b) el hero y la ubicacion no tenian un ancla de mapa, asi que "VER EN MAPA" no existia como elemento; (c) las redes sociales solo se pintaban en el footer, sin forma de reutilizarlas en otro contenedor.
4. **La boleteria tenia un unico destino cableado** (`wa.me`): un evento con link de ticketera externa no podia usar el modulo de boletos.

## 2. Decision

Se entrega el silo f14 y **4 cambios ESTRICTAMENTE ADITIVOS** en el kernel `evento-app.html`. La regla que gobierna los 4 es la misma: **el comportamiento previo de los otros 13 silos no puede cambiar**. Cada cambio se valida por su modo "apagado".

### 2.1 Silo NUEVO `css/templates/fiesta/f14.css` (theme `vinilos`)

* **Archivo real:** 40.075 bytes, ~1.396 lineas, 143 reglas, 5 at-rules, **0 bytes > 127** (ASCII puro). Reemplaza el volcado descrito en sec.1.1.
* **Identidad:** theme slug `vinilos`, nombre "Vinilos Inversos", categoria `fiesta`, `template_id` `f14`.
* **Estetica:** cartel urbano / fanzine grunge, **modo oscuro profundo**, papel kraft y naranja oxido.
* **Paleta (verificada):** `#0E0E0E` base, `#131313` superficie, `#E35925` oxido (acento), `#EA580C` naranja alto, `#DBC8A8` kraft, `#EAE0D0` kraft claro, `#F5F5F5` tinta, `#A3A3A3` tenue, `#262626` linea. Tokens `--f14-*` + puente obligatorio `--tpl-accent: var(--master-accent, #E35925)`.
* **Tipografia:** **stack de sistema con peso 900** (patron f12/f13/f9b). Cero `@import`, cero `@font-face`, **cero requests a Google Fonts**, coherente con los ADR que ya habian eliminado la fuente bloqueante en f6/f8/f10/f13. El efecto "sticker fanzine" se resuelve **con forma** (cinta kraft rotada por pseudoelemento), **no con fuente manuscrita**: una fuente manuscrita habria reintroducido la dependencia externa que esos ADR retiraron.
* **Grid:** 1 columna en mobile; desktop con areas `hero`, `countdown`, `meta`, `ctas`, `lineup`, `cartel`, `video`, `boletos`, `faq`, `ubicacion`, `form`. **Sin area `footer`**: la pagina termina en la fila boleteria + comunidad. Reflujo con `:has([data-hidden])` (el silo no necesita clases nuevas del kernel).
* **Galeria:** **NO existe modulo propio**; se estiliza `#db-gallery-grid`, que vive **dentro de `#mod-video`** (hecho ya documentado del kernel), en fila de 5 con hover `scale(1.05)`.
* **Breakpoints:** 640 / 767 / 992 / 1279 + `prefers-reduced-motion`.
* **Aislamiento (Regla de Oro #9):** 100% scopeado bajo `.tpl-f14` / `.Tpl-F14` (166 ocurrencias de la doble notacion), **0 selectores fuera de scope**, **0 clases/IDs fantasma** (todo selector existe en el DOM real de `evento-app.html`). En particular **NO se usa `.faq-q`**, que `f13.css` estiliza sin que el elemento exista (deuda previa, no de este ADR).
* **Contraste WCAG verificado:** `#F5F5F5`/`#0E0E0E` **17.71**; `#0E0E0E`/`#DBC8A8` **11.80**; `#0E0E0E`/`#EAE0D0` **14.77**; `#0E0E0E`/`#E35925` **5.26**; `#A3A3A3`/`#0E0E0E` **7.65**. El par `#F5F5F5` sobre `#E35925` da **3.37 (no AA)** y se verifico que **el silo NO lo usa en ningun texto**.

### 2.2 Cambio 1 de kernel - FAQ accesible (`evento-app.html:2273`)

* **Que:** el `.faq-item` generado recibe `role="button"`, `tabindex="0"` y `aria-expanded` **sincronizado en el propio `onclick`** (`this.classList.toggle('active')` + `setAttribute` derivado de `classList.contains('active')`) y **`onkeydown` para Enter/Space** (`preventDefault()` + `this.click()`), con `cursor:pointer`.
* **Justificacion anti-regresion:** el **mecanismo de estilo sigue siendo la clase `.active`**. `aria-expanded` es un **espejo de accesibilidad**, no una segunda fuente de verdad: si se hubiera cableado el estado en un `hidden`/estilo inline, los **13 silos** que dependen de `.active` para abrir el acordeon habrian dejado de abrirse. El teclado dispara `click()`, es decir reutiliza **el mismo** camino de codigo.

### 2.3 Cambio 2 de kernel - Anchor "VER EN MAPA" (`#mod-ubicacion`)

* **Que:** `<a class="mapa-link" target="_blank" rel="noopener" hidden>VER EN MAPA</a>` dentro de `#mod-ubicacion` (`evento-app.html:220`); el nodo se resuelve (`mapLink`, `:2314-2321`) y se cablea en `:2336-2350`.
* **Gate:** funcion `__esF14Silo()` (declarada `:1939-1942`), que evalua si la body class contiene `tpl-f14`. **Solo con `tpl-f14`** el ancla se habilita.
* **Justificacion anti-regresion:** el `<a>` **nace `hidden`** y sin `tpl-f14` nadie lo des-oculta: los otros 13 silos ven exactamente el DOM que veian. **Sin query de mapa el ancla se oculta, nunca queda un link roto** (regla de vacio: no se pinta un `href` sin destino).

### 2.4 Cambio 3 de kernel - Redes reutilizables (`renderSocialIcons()`)

* **Que:** el bloque inline que pintaba iconos dentro de `initEvento` se extrae a `renderSocialIcons()` (`:1916-1942`) y pinta **dos** contenedores: `#db-footer-social` (comportamiento **identico** al previo) y el nuevo `div#db-form-social` (`:325`, dentro de `#mod-form`).
* **Gate:** el segundo contenedor se pinta **solo si `__esF14Silo()`**; el footer se pinta **siempre** (tercer parametro `omitirVacios` para el modo estricto).
* **Filtrado estricto:** **sin URL no se pinta icono** (no se generan links muertos).
* **Justificacion anti-regresion:** el cambio es un **extract-method**, no un rewrite: el call site del footer pasa a llamar la funcion con los mismos datos, y el bloque nuevo es un nodo que **no existia antes** y solo se llena bajo gate. Un silo ajeno a f14 ve un `div` vacio que el CSS no estiliza.

### 2.5 Cambio 4 de kernel - `data-ticket-url` en boleteria (`:2429-2436` y `:2444`)

* **Que:** se introduce la constante `__ticketDataUrl`, que se escribe **en el `href` y en el atributo `data-ticket-url`** de la fila de boleto: el atributo y el `href` **leen la misma constante** (no hay forma de que diverjan).
* **Contrato NUEVO de datos (opt-in):** `config_landing.content.boletos.link` | `boletos.url`.
  * Solo se acepta **prefijo `http(s)`**. **Ruta relativa NO soportada** (no hay base URL confiable en el motor publico).
  * Valor invalido o ausente -> **fallback silencioso** al `wa.me` previo.
  * Es **opt-in**: sin el dato, el comportamiento es el de siempre.
* **Justificacion anti-regresion:** **hoy ningun evento tiene ese dato**, por lo que **los 13 silos ven el mismo `href` que antes** (regresion cero). El `wa.me` deja de ser el unico camino pero sigue siendo el **default**, no un caso especial.

### 2.6 Registro del theme `vinilos` en `admin.html` (6 puntos, nace visible por ADR-040)

1. Tarjeta del wizard `data-theme="vinilos"` con `onclick="abrirFichaTheme('vinilos')"` (`admin.html:600-603`), grupo Fiesta.
2. `_THEME_TYPE` `:3352-3353` -> `'vinilos':'fiesta'`.
3. `_THEME_TPL` `:3374-3377` -> `'vinilos':'f14'` (el reverse map `_TPL_THEME` se deriva solo; no se edita).
4. `_THEME_MODULES` `:3430-3445` -> `requeridos: ['ld-mod-boletos','ld-mod-ubicacion','ld-mod-faq-fiesta']`; `recomendados: ['ld-mod-dj-lineup','ld-mod-countdown-fiesta','ld-mod-gallery-fiesta']`.
5. `_THEME_FICHA` `:3675-3681` -> nombre "Vinilos Inversos" + paleta de 5 slots.
6. `names` del badge de `seleccionarTheme()` `:3818` -> `'vinilos':'Vinilos Inversos'`.

**Cero Borrado:** las tarjetas y entradas previas quedan intactas; `vinilos` **nace visible** (ADR-040, fail-open), no requiere curacion en `config_global`.

## 3. Verificacion real (baseline = archivo real, ADR-006)

1. `node scripts/express_check.js` -> **PASS, FAIL 0**; balance de `<div>`: `evento-app.html` **102/101** y `admin.html` **1605/1602**, ambos en el **baseline preexistente** -> **el diff no crecio**.
2. `node --check` de los bloques `<script>` de `evento-app.html` -> **OK**.
3. **`node scripts/smoke_f14_vinilos.js` (NUEVO)** -> **PASS 33, FAIL 0, exit 0**. Cubre: gate `__esF14Silo`, `aria-expanded` en `faq-item`, mapeo `vinilos -> f14`, tarjeta `data-theme="vinilos"`, entre otros.
4. `css/templates/fiesta/f14.css` re-escaneado del disco en este cierre: **40.075 bytes, 0 bytes > 127**; respaldo del volcado **38.082 bytes** presente.
5. Contraste WCAG: los 5 pares de sec.2.1; el par no-AA (`#F5F5F5`/`#E35925` = 3.37) **no se usa como texto**.
6. **0 clases/IDs fantasma:** cada selector del silo existe en el DOM real de `evento-app.html`.

## 4. Consecuencias

* **Positivas:** el catalogo de Fiesta pasa a **14 silos**; la estetica fanzine queda disponible sin dependencias externas de fuente; el kernel gana **3 capacidades reutilizables** (FAQ accesible, redes en cualquier contenedor, destino de boleteria configurable) sin romper el contrato de `.active`, sin tocar el footer de los otros silos y sin alterar ningun `href` existente.
* **Costo:** el kernel crece ~**40 lineas netas** (helper extraido + gate + ancla + constante de boleteria) con **docenas de lineas movidas**, no duplicadas.
* **Riesgo aceptado:** el gate de f14 es **por body class** (una sola fuente: `tpl-f14`), asi que un silo futuro que se llame `f14` heredaria el gate. Se acepta porque el `template_id` es atomico por convencion (ADR-006) y el smoke asserta el mapeo.
* **0 migraciones SQL, 0 cambios de esquema, 0 endpoints, 0 politicas RLS.**

## 5. Deuda tecnica declarada (NO cerrada)

1. **`admin.html:3855` - comentario desactualizado:** la cabecera de `_THEME_TITULO_2_LINEAS` afirma que "`_THEME_TPL` solo mapea f5,f6,f7,f8,f9,f11,f12,f9b"; **hoy tambien mapea f14**. Sin efecto funcional (es un comentario). *(El brief de la tarea citaba `:3846-3849`; la linea real verificada es `:3855` - prevalece el archivo, ADR-006.)*
2. **`_THEME_TITULO_2_LINEAS` (`admin.html:3859`) no incluye `vinilos`:** f14 queda con **`metaDosLineas:false`** y **fuera de `__esTitulo2Lineas()`** del kernel (`tpl-f6/f9/f10/f13`). Si se quisiera titulo en 2 lineas habria que tocar **las dos** tablas a la vez (invariante ADR-070: admin y kernel deben coincidir o el dato se pierde en silencio), y antes definir que pinta la linea 2 en este silo.
3. **f13 sigue sin theme ni card en el catalogo de admin** (deuda **previa**, no de esta tarea): existe `f13.css` pero no se puede seleccionar desde el wizard.
4. **`f13.css` estiliza `.faq-q`, que no existe en el DOM** (deuda previa, no de esta tarea); f14 deliberadamente no la usa.
5. **`boletos.link|url` no lo consume nadie todavia:** el contrato existe en el kernel, pero **el wizard no tiene campo para capturarlo**. Hasta que se agregue, el override es innecesario en la practica (todo cae al `wa.me`).
6. **Commit pendiente:** los 5 archivos de codigo + los docs de este cierre estan en el working tree; el commit lo decide Direccion.

### 5-bis. Addendum (2026-10-29, misma sesion): deudas saldadas y nueva capacidad de medicion

1. **5.1 RESUELTA:** el comentario de `_THEME_TPL` / `_THEME_TITULO_2_LINEAS` (`admin.html:3873-3877`) se actualizo para listar f13 y f14 y para advertir que **mapear el template NO habilita las 2 lineas**: hace falta anadir el theme a la tabla de titulo.
2. **5.3 RESUELTA:** `f13` quedo registrado como theme **`noche-avalon`** en los 6 puntos del catalogo (card `admin.html:604-607`, `_THEME_TYPE :3361`, `_THEME_TPL :3387`, `_THEME_MODULES :3459`, `_THEME_FICHA :3698`, `names :3837`). Nombre y paleta se derivaron de la **cabecera real de `f13.css`** ("Noche Avalon": `#050709`, `#0D3B2A`, `#486B46`, `#F2F2E8`, `#4C236F`, `#8E216C`), no se inventaron; los modulos se dedujeron de los `#mod-*` que el silo enciende.
3. **5.5 RESUELTA (UI):** el wizard captura la URL de ticketera en `#ld-boletos-link` (`admin.html:801`), la escribe como `content.boletos.link` **solo si empieza por `http(s)`** (`:5039-5048`) y la relee en `:6468`; la clave se emite **siempre** (`null` si no aplica) para sobrevivir al overwrite total de `config_landing` (clase BUG-016). El reset del formulario incluye el campo (`:6294`). El contrato del kernel queda **alimentable desde la UI**.
4. **5.2 SIGUE ABIERTA:** `_THEME_TITULO_2_LINEAS` (`admin.html:3865`) no incluye `vinilos` ni `noche-avalon`; f14 y f13 quedan con `metaDosLineas:false`.
5. **5.4 SIGUE ABIERTA:** `f13.css` sigue estilizando `.faq-q`, que no existe en el DOM (deuda previa, no de este ciclo).
6. **Smoke ampliado:** `scripts/smoke_f14_vinilos.js` pasa de 33 a **38 asserts** (valida `noche-avalon` -> f13 y los 3 puntos del circuito `boletos.link`). `express_check` FAIL 0 y balance de divs de `admin.html` en baseline (1605/1602) tras las inserciones.
7. **Nueva capacidad de medicion (fuera del alcance del silo):** `scripts/usage_report.js` y `scripts/session_close.js` se adaptaron al **esquema V2** de la DB de OpenCode (`session_v2` + `session_message`), que es el que escribe hoy; sin ese arreglo el cierre medido del Mandato #20 devolvia **0 sesiones**. Se registra en `TASKS.md` (TSK-115, addendum) y `NEXT.md` (hito -47).
8. **Detectado en este ciclo:** `ld-mod-cartel` no existe como checkbox en el wizard (el `#mod-cartel` lo gobierna el silo, no el admin). El registro de f13 se corrigio para no referenciar un id inexistente; queda como invariante documentado del catalogo.

## 6. Referencias

* ADR-041 / ADR-042 / ADR-043 / ADR-048 - patron de cierre de silo (diagnostico archivo por archivo, ASCII-safety, Cero Borrado, registro de theme en admin).
* ADR-006 - baseline de verdad contra el archivo real (aqui: re-escaneo de `f14.css`, conteo de divs, `grep` de lineas citadas).
* ADR-040 / ADR-045 - catalogo de plantillas: `vinilos` nace visible (fail-open).
* ADR-070 - invariante "tabla del admin == tabla del kernel" (origen de la deuda 5.2).
* ADR-057 - la mitad `.Tpl-*` esta muerta en produccion; f14 mantiene la doble notacion por norma (Cero Borrado) y se sostiene por la mitad minuscula.
* ADR-008 - Silent Fallback (aplica al arte del silo).
* `ERRORES_HISTORICOS.md` seccion 32 (E32) - incidente del volcado HTML+Tailwind que ocupaba `f14.css`.
* `NEXT.md` hito -47 - relevo y deuda; `TASKS.md` TSK-115 - cierre; `BLUEPRINT.md` - referencias certificadas; `AMPLIACION/TEMPLATES.md` v1.8.0 - hub normativo.
