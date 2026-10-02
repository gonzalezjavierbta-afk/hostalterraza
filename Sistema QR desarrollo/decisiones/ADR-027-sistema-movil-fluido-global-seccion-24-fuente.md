---
doc: ADR-027
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L300-324 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L300-324 del original).

#### ADR-027: Sistema Móvil Fluido Global (Sección 24, Fuente Única) y Matriz QA para todo el rango mobile (b5)
* **ID:** ADR-027 | **Fecha:** Agosto 2026 | **Estado:** Aprobado — Sección 24 entregada en `b5.css` (al final del silo, 1679 → 1722 líneas). Pendiente de Prueba de Carga Dual visual por Dirección contra la Matriz QA (abajo) antes de certificarse.
* **Problema:** ADR-026 (Solución B) resolvió el solapamiento pero dejó el hero con una franja de "normalización tardía" para viewports cortos+angostos (Sección 23, `≤640px + ≤740px alto`). Dirección amplió el mandato: **garantizar render correcto y proporcionado en TODO el rango móvil (320→430px de ancho × 568→932px de alto) + tablets portrait hasta 991px, sin parches por dispositivo**. Causa raíz del "hero apretado": el hero es `100svh` y el meta se ancla con `margin:-40vh` mientras el bloque superior (eyebrow, título, descripción) ocupa altura casi fija en `rem`; el hueco descripción→meta ≈ `60vh − alturaFija` crece con la altura (~50px en 375x667 → ~170px en 414x896) y en pantallas angostas la descripción envuelve más líneas y agrava la compresión.
* **Decisión:** Estrategia **Fuente Única (ADR-017)** aplicada al rango completo `@media (max-width:991px)` en una capa final (Sección 24, gana en cascada y supersede las Secciones 19/23 para el hero): valores fluidos con `clamp()`/`max()` que interpolan continuamente, sin depender de franjas cortas+angostas. No se tocan los sistemas de títulos (Secciones 20/21), el `z-index` del form (Sección 22) ni las grillas por ancho ya correctas.
   1. **HERO fluido** (knobs documentados en el comentario de la Sección 24):
      * `#mod-hero` → `min-height:100svh/100vh` (uniforma también el rango 900-991px que usaba `90vh`).
      * `.hero-content` → `margin-top: clamp(2.5vh, 2rem, 6vh)`.
      * `.hero-eyebrow` → `margin-bottom: clamp(0.8rem, 1.6vh, 1.2rem)`.
      * `#event-title` → `font-size: clamp(1.45rem, 6.5vw, 2.4rem)`; `margin-bottom: clamp(0.8rem, 1.5vh, 1.5rem)`.
      * `.hero-description` → `font-size: clamp(0.8rem, 1.1vw + 0.6rem, 1rem)`; `margin-top: clamp(1.2rem, 2.6vh, 2.5rem)`.
      * `#mod-hero-meta` → `margin: max(-36vh, -20rem) 0 0 0` (reemplaza el `-40vh`): proporcional en pantallas bajas (hueco mínimo garantizado ~80px en el peor caso 320x568) y ancla fija `-20rem` en las muy altas (la composición no "vuela").
   2. **Auditoría de otros `min-height`:** el banner `impactohist-banner` efectivo ya es `min-height:200px` (la regla de la línea 1122 supersede la de `480px` de la línea 734 en cascada), por lo que no requiere cambio. El único módulo realmente sensible a la altura es el hero.
   3. **Resultado numérico esperado (hueco descripción→meta):** 320x568 ≈ 80px; 375x667 ≈ 150px; 414x896 ≈ 310px; 430x932 ancla en `-20rem`.
* **Matriz QA (verificación pendiente de Dirección en DevTools emulación — dispositivo / criterio):**
  * 320x568 (iPhone SE 1ª gen): sin scroll horizontal; descripción 100% legible sin solaparse con el meta; hueco descripción→meta ≥ 60px; meta íntegro sobre el área oscura; FAQ sin deformar el "+"; galería 2col.
  * 360x640 (Android medio): idem + form sobre gradiente sin cubrir cifras de impacto.
  * 375x667 (iPhone SE 2ª gen): descripción→meta ≈ 150px; primera fila de impacto completa tras el form.
  * 375x812 (iPhone X): composición equilibrada sin "vuelo" del meta.
  * 414x896 (iPhone XR): ≈ 310px de aire; sin regresión vs. el estado "se ve bien" previo.
  * 430x932 (iPhone 14 Pro Max): meta anclado en `-20rem`; sin hueco excesivo.
  * 768x1024 (tablet portrait): mismo sistema fluido (≤991px); grillas por ancho sin romperse.
  * Si algún dispositivo falla, ajustar el clamp/knob correspondiente de la Sección 24 (no añadir parches por dispositivo).
* **Impacto:** `b5.css` actualizado (Sección 24 al final; balance de llaves 391/391 OK). `eventovenezuela.html` sin cambios (cero diffs, Invariabilidad del Cerebro intacta). La Sección 23 queda superseded en cascada para los valores de hero (historia, Cero Borrado).
 * **Enmienda v2 (ago-2026, "últimos cambios de diseño" — mandato de Dirección dirigido a la versión mobile):** se rediseña el bloque superior del hero en la Sección 24 para el rango ≤991px: (1) eyebrow + título BAJAN (`hero-content { margin-top: clamp(3rem, 11vh, 5rem) }`); (2) el título crece `clamp(1.9rem, 9.5vw, 3.4rem)` para llenar mucho más el espacio; (3) la descripción queda cerca de media pantalla(`margin-top: clamp(1.1rem, 2.4vh, 2.2rem)`). El `nav` está oculto en mobile (≤899px) y el `padding-top` del hero es `0.5rem`, por lo que `hero-content margin-top` es el único control de altura del bloque. Nueva expectativa de hueco descripción→meta con la descripción real (≈260 caracteres, 6-7 líneas): 375x667 ≈ 60-70px; 414x896 ≈ 190px; 320x568 ≈ 15-25px (caso peor real, la descripción larga consume el espacio disponible antes del meta). Pendiente: Prueba de Carga Dual contra la Matriz QA con los nuevos valores.

