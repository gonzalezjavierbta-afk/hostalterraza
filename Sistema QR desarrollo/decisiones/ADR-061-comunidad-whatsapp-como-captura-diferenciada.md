---
doc: ADR-061
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L1285-1331 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L1285-1331 del original).

#### ADR-061: Comunidad WhatsApp como captura diferenciada (separada de los asistentes con QR) y tipado de invitadores

* **ID:** ADR-061 | **Fecha:** 2026-09-30 | **Estado:** IMPLEMENTADO y verificado (Escudo GOLD APROBADO; `node scripts/express_check.js` -> **PASS 16 / FAIL 0**). Decision de producto y de contrato de captura/atribucion; **no requirio migracion** (ver Justificacion 1 y 2). El codigo vive en `admin.html` y `evento-app.html` (working tree, SIN commit); la implementacion es de los dominios admin/renderer y el cierre documental es de `@docs-keeper`.
* **Autor:** Chief Architect (decision de producto) + `@admin-dev-free` / `@renderer-dev-free` (implementacion). Cierre documental a `@docs-keeper`.
* **Problema / Contexto:**
    1. **La comunidad se mezclaba con los asistentes.** La landing de evento (`evento-app.html`, servida como `/evento.html`) captura personas que solo quieren **unirse al grupo de WhatsApp** de la comunidad: inserta en `inscritos` con `tipo='interesado'`, `tipo_ayuda='interesado'`, `respuestas_custom={origen:'landing-interesado'}` y `cuenta_aforo=false` (no generan QR). Hasta hoy esas filas se contaban y listaban en el tab "Asistentes" junto a los registros con QR, sin una vista propia; distorsionaba aforo, la lista de invitados y las metricas de conversion.
    2. **`inscritos.tipo` ya admite `interesado`.** El CHECK `inscritos_tipo_check` fue ampliado a 10 valores por `migrations/adr031_inscritos_tipo_interesado.sql` (9 vigentes + `interesado`). Por lo tanto, capturar comunidad **NO requiere migracion**.
    3. **`invitadores.tipo_invitado` es una columna `text` SIN CHECK en la base de datos.** Solo se usaba para etiquetar el link (`invitado` / `frecuente` / `artista` / `produccion` / `pago`). Se necesitaba un tipo **`comunidad`** que genere un link a la **landing** (no a los formularios de registro). Al ser texto libre, agregar el valor `comunidad` **NO requiere migracion**.
    4. **Brecha de atribucion (silenciosa).** La landing **no leia `?ref`** ni persistia `ref_codigo`/`ref_nombre` en el INSERT de `inscritos`, mientras `serie.html` **si** lo hacia (`serie.html:457` lectura; `:667-668` y `:755-756` persistencia). Las capturas de comunidad originadas en la landing quedaban **sin invitador atribuido** (el panel de invitadores no podia contabilizarlas). No habia error de consola ni de red: solo perdida de atribucion.
* **Opciones evaluadas:**
    1. **Dejar la comunidad dentro del tab Asistentes (statu quo):** las capturas de WhatsApp se siguen contando como asistentes con QR -> distorsiona aforo, lista de invitados y conversion; **RECHAZADA**.
    2. **Sub-tab propio "Comunidad WhatsApp" + predicado unico de exclusion + tipo de invitador `comunidad` + atribucion `?ref` en la landing (ELEGIDA):** separa la metrica de interes de la de acceso, evita la doble visualizacion y cierra la brecha de atribucion, sin tocar el esquema.
    3. **Nueva columna en `inscritos` para marcar comunidad:** **RECHAZADA** por innecesaria; `tipo='interesado'` + `respuestas_custom.origen='landing-interesado'` ya distinguen las filas. Una columna nueva exigiria migracion y no aporta.
    4. **Reutilizar `tipo_invitado='pago'`/`'invitado'` para el link de comunidad:** **RECHAZADA**: obligaria a registrar un asistente con QR en vez de llevar a la landing/grupo, rompiendo la intencion de la captura.
* **Decision:**
    1. **Separar la comunidad como metrica propia.** En `admin.html` se agrega el sub-tab **"Comunidad WhatsApp"** (`data-pnl-pill="comunidad"` + badge `#pnl-badge-comunidad`, L1536; panel `data-pnl-tab="comunidad"` L1759-1786) con tabla `#pn-com-table`, busqueda `#pn-com-search`, filtro de estado `#pn-com-estado-filter` y exportacion Excel/PDF (`exportarComunidad`).
    2. **Predicado unico `_esComunidad(i)`.** Una sola funcion decide que es comunidad: `tipo === 'interesado'` **o** `respuestas_custom.origen === 'landing-interesado'` (`admin.html:9010-9012`). Ese MISMO predicado se usa en (a) el sub-tab (`_filtrarComunidad()` -> `renderComunidadPanel()`, `admin.html:9014-9077`) y (b) la **exclusion** de Asistentes (`_filtrarInscritosPanel()` `admin.html:8902` y el badge de Asistentes `admin.html:8926`), de modo que **ninguna fila aparece en los dos lados** (incluido el dato legacy con `origen` pero `tipo` distinto).
    3. **Etiquetas.** `interesado`/comunidad se rotula como **"Comunidad"** en `tipoBadge` (`admin.html:7627`), `catBadge` (`admin.html:8870`), `tipoLabels`/`tipoColors` (`admin.html:7462-7463`, `:8197`, `:8645`) y como opcion en `#ei-tipo` (`admin.html:2543`).
    4. **Invitadores tipados.** Se agrega `comunidad` a `#pi-tipo-sel` (`admin.html:1274`) y a `tipoLabels` de invitadores (`admin.html:6750`). `generarLinkInvitador()` (`admin.html:6833-6858`) ramifica: para `tipo='comunidad'` el link apunta a la **landing** `"/evento.html?slug=<slug>&tipo=comunidad&ref=<codigo>"` (para una serie usa el primer evento de la serie como landing); el resto de tipos conserva los formularios de registro y `serie.html`. La columna `tipo_invitado` guarda `'comunidad'` como texto (sin migracion).
    5. **Atribucion en la landing.** `evento-app.html` lee `?ref` (`:959`), resuelve el invitador en `invitadores` por `codigo` (`:985-988`, con `maybeSingle()`), **fail-open** (si la consulta falla o no hay match, la landing continua sin atribucion; en `__HT_PREVIEW` hay **cero red**, ADR-008) y persiste `ref_codigo`/`ref_nombre` en el INSERT de `inscritos` (`:2442-2443`). No se toca la landing de serie (ya lo hacia).
* **Justificacion:**
    1. **Cero migracion (inscritos.tipo):** el CHECK de `migrations/adr031_inscritos_tipo_interesado.sql` ya incluye `interesado`; la escritura de comunidad no viola `inscritos_tipo_check`. Confirmado contra el archivo real (ADR-006).
    2. **Cero migracion (invitadores.tipo_invitado):** es columna `text` **sin CHECK**; agregar el valor `comunidad` es solo un nuevo literal, no un cambio de esquema.
    3. **Fuente unica anti-duplicados:** un solo predicado `_esComunidad()` evita que la misma fila se muestre como asistente y como comunidad (patron de la Regla de No-Duplicidad / BUG-006/018/019). Separar mejora aforo, lista de invitados y conversion.
    4. **Cierre de brecha de atribucion:** sin leer `?ref`, un link de invitador "comunidad" no podia atribuir las capturas; ahora el panel de invitadores puede contabilizarlas, alineado con lo que `serie.html` ya hacia.
    5. **Fail-open:** la atribucion nunca puede romper la landing; en vista previa no hay red (ADR-008).
* **Consecuencias:**
    1. **Datos legacy:** las filas ya existentes con `respuestas_custom.origen='landing-interesado'` (aunque su `tipo` no sea `interesado`) se reclasifican en el sub-tab Comunidad **sin reescribir la base** (predicado por `origen`) y dejan de contarse en Asistentes.
    2. **El aforo y las exportaciones de Asistentes** ya no incluyen comunidad; la comunidad tiene su propia exportacion (Excel/PDF).
    3. **Invariantes:** el valor `'comunidad'` de `tipo_invitado` es solo etiqueta/ramificacion de link; no altera RLS, ni `org_id`, ni el Contrato de Datos v112 (**0 IDs afectados**, Cero Borrado intacto).
    4. **Reversibilidad total:** retirar el sub-tab + el predicado + la rama `comunidad` y el bloque `?ref` restaura el estado previo; no hay migracion que deshacer.
* **Evidencia (ADR-006, verificado contra el archivo real):**
    * `admin.html` (`git diff --numstat`: +190/-8; 11051 lineas): pill L1536; panel `data-pnl-tab="comunidad"` L1759-1786; `#pi-tipo-sel` opcion `comunidad` L1274; `#ei-tipo` opcion `interesado` L2543; `tipoLabels` invitadores L6750; `generarLinkInvitador()` L6833-6858 (rama comunidad L6844-6857); `tipoLabels`/`tipoColors` L7462-7463; `tipoBadge` L7620-7630 (map `interesado` L7627); `tipoLabels` L8197; `tipoColors` L8645; `catBadge` L8863-8870; `_filtrarInscritosPanel` exclusion L8902; badge Asistentes L8926; bloque Comunidad L9000-9077 (`_esComunidad` L9010-9012, `_filtrarComunidad` L9014-9030, `renderComunidadPanel` L9032-9077, `filtrarComunidadTabla` L9079, `exportarComunidad` L9083+); escrituras del invitador L6864-6877.
    * `evento-app.html` (`git diff --numstat`: +17/-1; 2572 lineas): `refParam` L959; `refCodigo`/`refNombre` L962; resolucion del invitador L985-988; INSERT `inscritos` con `respuestas_custom.origen='landing-interesado'` L2441 y `ref_codigo`/`ref_nombre` L2442-2443.
    * `serie.html` (referencia de la brecha): lectura de `?ref` L457; persistencia `ref_codigo`/`ref_nombre` L667-668 y L755-756.
    * `migrations/adr031_inscritos_tipo_interesado.sql`: `CHECK (tipo IN (...))` con 10 valores, incluido `interesado`.
    * `scripts/express_check.js`: baseline `evento-app.html:1` (preexistente) agregado; `node scripts/express_check.js` -> **PASS 16 / FAIL 0**.
* **Ajustes finales post-cierre (2026-09-30, misma sesion):**
    1. **Las metricas del Resumen EXCLUYEN la comunidad.** En `renderPanel()` se distingue `const listAll = _pnAllList = inscritos || []` (base completa para las tablas Asistentes/Comunidad) de `const list = listAll.filter(i => !_esComunidad(i))` (metricas del Panel). Consecuencia: KPIs (Inscritos / Asistencia / No-show / Frecuentes / Hora pico), grafica por evento, **distribucion por tipo (donut)**, embudo, retencion, heatmaps, ranking de inscriptores, crecimiento, perfil, geo, canales e insights ya **no cuentan comunidad**; `renderTabla(listAll)` conserva `_pnAllList` completo. La comunidad se mide en su propio sub-tab.
    2. **Estado en el sub-tab Comunidad = "Interesado".** La columna Estado muestra un badge fijo `💬 Interesado` (ya no `Ingresó/Pendiente`, que no aplica a filas sin QR). Se elimino el filtro `#pn-com-estado-filter` y su logica en `_filtrarComunidad()`; el export (`exportarComunidad`, Excel y PDF) escribe `Interesado`.
    3. **Fix del `duplicate key "invitadores_codigo_key"` al generar links.** `invitadores.codigo` es **UNICO** en la base; el INSERT de `generarLinkInvitador()` (una fila nueva por link, con el mismo `codigo`) violaba el constraint. Ahora `generarLinkInvitador()` **resuelve la fila contra la base, no contra la cache**: consulta `invitadores` por `codigo` (sin filtro de `org_id`), la **actualiza** por `id` si existe (`tipo_invitado`, `link_generado`, `evento_id`/`serie_id`) y solo inserta si el `codigo` es nuevo (con fallback a UPDATE por `codigo` ante un `23505`). Implica **una fila por invitador** (un link vigente), consistente con el constraint; los links previos siguen funcionando por `?ref` (la atribucion es por `codigo`).
    4. Verificacion: Escudo GOLD PASS (sintaxis inline OK + balance de divs delta 0); `node scripts/express_check.js` -> **PASS 16 / FAIL 0**.
* **Rollback:** revertir los bloques de comunidad y la rama `comunidad` de `admin.html` y el bloque `?ref` de `evento-app.html`. No hay migracion ni endpoint que deshacer; el esquema nunca cambio.
* **Referencias:** ADR-031 (categoria `interesado` en `inscritos.tipo`, `migrations/adr031_inscritos_tipo_interesado.sql`), ADR-006 (baseline contra el archivo real), ADR-008 (Silent Fallback / sin red en vista previa), ADR-024 / ADR-029 (blindaje de nulos en el panel), ADR-030 (exportacion de lista de invitados; base de `exportarComunidad`), ADR-033 (modos de pagina publica `landing`/`formulario`), ADR-047 (contrato `form_redirect`/comunidad del landing), `admin.html`, `evento-app.html`, `serie.html`, `ERRORES_HISTORICOS.md` §19, `TASKS.md` TSK-078, `NEXT.md` hito -27.

---

