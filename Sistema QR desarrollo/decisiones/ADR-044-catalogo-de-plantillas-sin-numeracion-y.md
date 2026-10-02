---
doc: ADR-044
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L671-693 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L671-693 del original).

#### ADR-044: Catalogo de Plantillas sin Numeracion y Registro del Silo F11 'Fosforescente' (Entrega 1)
* **ID:** ADR-044 | **Fecha:** 16 de septiembre de 2026 | **Estado:** Aprobado y entregado (QA APTO — Escudo GOLD PASS). Working tree con UN SOLO archivo de codigo modificado (`admin.html`); `f11.css`, `evento.html`, `f7.html` y `f11gemini.css` NO fueron tocados por esta entrega — solo se reconcilio documentalmente la version real de `f11.css`.
* **Autor:** Documentation Specialist / `@docs-keeper-free` (implementacion Frontend `*-free`; este ADR es cierre documental: 0 cambios de codigo por este cierre).
* **Problema:** El catalogo de plantillas del Wizard (`admin.html`) mostraba las cards `.ld-theme-card` con una numeracion `P#` cuyo correlativo estaba roto (P9-P13 duplicado entre las categorias Fiesta y Campana), y el silo `f11` "Cyberpunk Fosforescente" — certificado en ADR-043 como template utilizable por `template_id='f11'` — seguia sin registro de theme en `admin.html`, por lo que el Wizard no podia crearlo/editarlo. Ademas, los documentos citaban `f11.css` como v3.2.0 / 1554 lineas cuando el archivo real ya era v3.3.3 / 1595 lineas (desfase de reconciliacion, ADR-006).
* **Diagnostico verificado (contra el archivo real del repositorio, ADR-006 - no contra documentacion previa):**
   1. **`admin.html` real:** la numeracion `P#` estaba hardcodeada en las 18 tarjetas `.ld-theme-card` y en el mapa `names` de `seleccionarTheme()` (etiquetas con numeracion), con `P9`-`P13` duplicados entre Fiesta y Campana — el correlativo no era unico, rompiendo la referenciabilidad de las cards.
   2. **Mapas de themes reales:** `_THEME_TYPE` y `_THEME_TPL` registraban hasta `mistico`->`f9` y `tropilove`->`f8`; `f11` NO tenia entrada (heredado del pendiente opcional de ADR-043); `rico`/`f10` tampoco (pendiente opcional heredado de ADR-042).
   3. **`css/templates/fiesta/f11.css` real (ADR-006):** 1595 lineas, cabecera **v3.3.3** "CIERRE MOBILE: HERO 100svh + TITULO 26vw + COUNTDOWN 1 FILA + AIRE INFERIOR" (sep-2026). Los documentos (ADR-043, TASKS TSK-033, NEXT -9) lo citaban como v3.2.0 / 1554 lineas — el silo avanzo a v3.3.3 despues de ese cierre y el desfase no estaba reconciliado.
   4. **Silo f11 en catalogo de PROJECT.md Seccion 6:** ya figuraba como f11 desde ADR-043 (v3.2.0); la fila requiere actualizacion a la version real.
* **Decision (entregable real, verificado archivo por archivo):**
   1. **Se quito la numeracion `P#`** de las 18 tarjetas `.ld-theme-card` de `admin.html` y del mapa `names` de `seleccionarTheme()`: las cards y los labels quedan SOLO con NOMBRE + DESCRIPCION (sin correlativo P#). Ninguna card fue eliminada, reordenada ni renombrada en su slug — cambio puramente de etiquetado (Cero Borrado).
   2. **Se registro el silo `f11` como theme slug `fosforescente`** (categoria Fiesta): tarjeta nueva `data-theme="fosforescente"` en el grupo Fiesta (descripcion "Neon fucsia · Hero 100svh · Mobile-first"), `_THEME_TYPE['fosforescente']='fiesta'`, `_THEME_TPL['fosforescente']='f11'`, derivado `_TPL_THEME['f11']='fosforescente'` (via reduce sobre `_THEME_TPL`) y label en `names` (`'fosforescente':'Fosforescente'`).
   3. **NO se registro `f10` (`rico`)** en esta entrega: queda pendiente opcional (heredado de ADR-042 y ADR-043 Pendientes 3).
   4. **Reconciliacion documental de `f11.css`:** la fila del silo en `PROJECT.md` Seccion 6 y las menciones en los docs del AI-DOS Core se actualizan a v3.3.3 / 1595 lineas reales (verificado por lectura del archivo, no por referencia cruzada).
   5. **Archivo de codigo tocado:** UNICO `admin.html`. `evento.html`, `f7.html`, `f11.css` y `f11gemini.css` quedaron intactos (Cero cambios, Invariabilidad del Cerebro preservada).
* **QA ejecutado (Escudo GOLD — QA APTO):** sin numeracion P# residual en cards ni en `names` (verificado por grep sobre el archivo real), registro `fosforescente` completo en `_THEME_TYPE`/`_THEME_TPL`/`_TPL_THEME`/`names` + card en el DOM, 0 IDs eliminados (las 18 tarjetas siguen presentes), balance de `<div>` y sintaxis validados. Los archivos de codigo NO fueron modificados por este cierre documental.
* **Impacto:** **1 archivo de codigo tocado** en el working tree (`admin.html`), **0 migraciones SQL**, **0 cambios de esquema**, **0 endpoints**, **0 cambios a `evento.html`/`f7.html`/`f11.css`/`f11gemini.css`**. El theme `fosforescente` nace **visible por defecto** y es forward-compatible con la curacion de ADR-040/045 (la config guarda lo oculto; fail-open). Con este registro, el Wizard puede crear/editar eventos f11.
* **Pendientes (no ejecutados):**
   1. Commit de la entrega por Direccion (working tree modificado, sin commit).
   2. Registro opcional del theme `rico` -> `f10` en `admin.html` (heredado de ADR-042 Pendientes 2 y ADR-043 Pendientes 3).
   3. Verificacion visual (Prueba de Carga Dual) del catálogo sin numeracion y de la tarjeta `fosforescente` en el Wizard.
* **Referencias:** ADR-041/042/043 (patron de registro de themes y estado previo de `f11` y `rico` — los pendientes optativos que esta entrega retoma para `fosforescente`), ADR-006 (baseline de verdad contra el archivo real: reconciliacion v3.3.3/1595 de `f11.css`), ADR-040/045 (curacion de catalogo por la cuenta master: `fosforescente` nace visible, fail-open), `AGENTS.md` (roster de agentes).

