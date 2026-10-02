---
doc: ADR-043
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L652-670 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L652-670 del original).

#### ADR-043: Fix Mobile del Hero del Silo F11 "CYBERPUNK FOSFORESCENTE" (v3.2.0) — Orden Explicito de los 4 Hermanos del Hero y Hero en Una Sola Pantalla (60/40)
* **ID:** ADR-043 | **Fecha:** 16 de septiembre de 2026 | **Estado:** Aprobado y entregado. Working tree con UN SOLO archivo modificado (`css/templates/fiesta/f11.css` v3.2.0, 1554 lineas). Escudo GOLD PASS (balance de llaves 213/213 diff 0, ASCII-safety, desktop `min-height: 85vh !important` intacto, breakpoint 992-1279px intacto, sin media queries nuevas, Cero Borrado). Cierre documental ASCII-safe.
* **Autor:** Documentation Specialist / `@docs-keeper-free` (el fix fue implementado por el equipo frontend `*-free` con plan T1+T2 aprobado por el usuario; este ADR es cierre documental: 0 cambios de codigo).
* **Problema:** Bug visual reportado por el usuario en el hero mobile del silo f11 "CYBERPUNK FOSFORESCENTE" (`css/templates/fiesta/f11.css`): en pantallas <=767px, dentro del hero, arriba se veian los elementos (countdown, meta, boton) y abajo el titulo — el orden visual opuesto al aprobado (titulo → countdown → meta → boton).
* **Diagnostico verificado (contra el archivo real del repositorio, ADR-006 - no contra documentacion previa):**
   1. **`css/templates/fiesta/f11.css` real (1554 lineas, cabecera v3.2.0 "CORRECCION MOBILE: HERO COMPACTO BAJO EL TITULO Y CUBRIMIENTO DE FONDO", sep-2026):** en la media query `@media (max-width: 767px)` (linea 1243) solo `#mod-hero` recibia `order: 1`; los 3 hermanos `#unified-frame` (countdown), `#mod-hero-meta` y `#mod-hero-ctas` quedaban con `order: 0` (default flexbox) → el navegador los colocaba antes que el titulo. La media query ya fijaba `#main-content-flow` como flex-columna, por lo que el orden de apilado dependia exclusivamente de `order` — un reordenamiento parcial de hermanos sin renumerar el resto deja el layout dependiendo del default del motor.
   2. **La correccion aplicada (verificada en el archivo real):** orden explicito de los 4 hermanos del hero con doble notacion `.tpl-f11` + `.Tpl-F11` (lineas 1260-1266: `#mod-hero`=1, `#unified-frame`=2, `#mod-hero-meta`=3, `#mod-hero-ctas`=4) y re-numeracion explicita del resto de bloques 5-15 (lineas 1267-1277). Hero 60/40 (lineas 1279-1297): `min-height: 60vh !important` + `min-height: 60svh !important` (fallback), `background-position: center center !important` + `background-size: cover !important`, paddings/gaps compactados. Titulo `clamp(2.6rem, 11vw, 4.2rem)` (linea 1313) y version 480px `clamp(2.2rem, 10vw, 3.4rem)` (linea 1451). NO fueron tocados: desktop `min-height: 85vh !important` (linea 260), breakpoint 992-1279px (linea 1510) y `css/templates/fiesta/f11gemini.css` (decision explicita del usuario).
* **Decision (entregable real, verificado archivo por archivo):**
   1. **Unico archivo tocado:** `css/templates/fiesta/f11.css` → v3.2.0 (1544 → 1554 lineas). Ningun otro archivo del repositorio fue modificado por este fix.
   2. **T1 — Orden explicito de los 4 hermanos del hero (767px):** `#mod-hero`=1, `#unified-frame`=2, `#mod-hero-meta`=3, `#mod-hero-ctas`=4, con re-numeracion 5-15 del resto de bloques — resultado visual aprobado por el usuario: titulo → countdown → meta → boton. Ningun hijo depende del `order` default.
   3. **T2 — Hero en una sola pantalla:** proporcion 60/40 aprobada por el usuario; `#mod-hero` con `min-height: 60svh` (fallback `60vh`), titulo `clamp(2.6rem, 11vw, 4.2rem)` en 767px y escalado `clamp(2.2rem, 10vw, 3.4rem)` en 480px, `background-position: center center` en mobile (conservando `background-size: cover`), paddings/gaps compactados para comprimir countdown+meta+boton en el ~40% restante del viewport, eliminando el scroll vertical en el hero.
* **QA ejecutado (Escudo GOLD):** PASS - balance de llaves 213/213 (diff 0), ASCII-safety (bytes >127 solo en comentarios historicos, no en reglas activas), desktop `min-height: 85vh !important` intacto, breakpoint 992-1279px intacto, sin media queries nuevas, Cero Borrado (ningun ID del Contrato v112 eliminado), Aislamiento Atomico (doble notacion `.tpl-f11` + `.Tpl-F11`). Los archivos de codigo NO fueron modificados por este cierre.
* **Impacto:** **1 archivo de codigo tocado** en el working tree (`css/templates/fiesta/f11.css` v3.2.0), **0 migraciones SQL**, **0 cambios de esquema**, **0 endpoints**, **0 cambios a `evento.html`/`admin.html`**. Silo f11 agregado al catalogo de Silos Operativos Validados en `PROJECT.md` Seccion 6. El silo se carga y aplica por `template_id='f11'` (kernel de `evento.html`); el theme de f11 NO esta registrado en `admin.html` — `_THEME_TYPE` (linea 2785) llega hasta `mistico` y `_THEME_TPL` (linea 2797) hasta `f9` (verificado contra el archivo real de `admin.html`, ADR-006).
* **Pendientes (no ejecutados):**
   1. Commit de la entrega por Direccion (working tree modificado, sin commit).
   2. Verificacion visual (Prueba de Carga Dual) en dispositivos reales del hero 60/40 en mobile y desktop — la proporcion es nueva y no hay referencia fotografica en este ciclo.
   3. Registro opcional del theme de f11 en `admin.html` (`_THEME_TYPE`/`_THEME_TPL`, card + label en el Wizard) si Direccion quiere crearlo/editarlo por el Wizard — paralelo a los registros pendientes de `rico` (ADR-042) y completados de `mistico` (ADR-041).
* **Referencias:** `ERRORES_HISTORICOS.md` Seccion 12 (registro del bug con causa raiz, solucion y verificacion), ADR-042 (patron de cierre de silo y registro de themes; misma familia visual "Cyberpunk Fosforescente" y mismo estado de theme sin registrar), ADR-006 (baseline de verdad contra el archivo real y nomenclatura atomica por silos), ADR-018/019 (patron de fix de layout mobile por breakpoint con causa raiz verificada), `AGENTS.md` (roster de agentes).

