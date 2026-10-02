---
doc: ADR-028
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L325-339 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L325-339 del original).

#### ADR-028: Consolidación de Cascada Aditiva en Canónica (b5.css) — Eliminación de Redundancia Histórica
* **ID:** ADR-028 | **Fecha:** Agosto 2026 | **Estado:** Aprobado — consolidación entregada en `b5.css` (94.9 KB → 64.7 KB, -32%). Validado: verify.js (CASCADE-EQUIVALENT, 0 diffs en 22 celdas) y verify2.js (BOUNDARY-EQUIVALENT, 0 diffs en 120 sondas de borde).
* **Problema:** `b5.css` arrastraba 26 secciones aditivas acumuladas desde ADR-017/018/019/026/027 (cada corrección añadía un bloque `@media` final con `!important` que supersedía el anterior en cascada, Cero Borrado). Resultado: 1831 líneas / 94.9 KB donde múltiples bloques re-declaran los mismos selectores (`.tpl-b5 #mod-hero-meta` aparecía 13 veces, `.tpl-b5 #main-content-flow` 3 veces, etc.), con la prosa histórica de cada ADR incrustada como comentario. El archivo era funcionalmente correcto pero mantenibilidad y legibilidad estaban degradadas — encontrar el valor efectivo de una propiedad requía rastrear toda la cascada.
* **Decisión:** Consolidar la cascada aditiva en forma canónica: **una regla base por selector** (solo reglas incondicionales, el valor que aplica cuando ningún `@media` coincide) + **bloques `@media` por breakpoint** que contengan únicamente los diffs (propiedades cuyo valor efectivo difiere de la base en ese viewport). Breakpoints auto-detectados del fuente (sin hardcodear): `560 / 640 / 780 / 899 / 900 / 991 / 992 / 1024 / 1099 / 1279` + banda corta (`max-height:740`). Selectores en fuente: 230.
* **Método de validación (dif vs pre-ADR28 backup):**
   1. **verify.js** — grid de 22 celdas (11 bandas de ancho × 2 de altura), rep muestreado en píxeles enteros (no puntos medios que caen en zonas ambiguas de banda de 1px). Resultado: 0 diferencias → CASCADE-EQUIVALENT.
   2. **verify2.js** — 120 sondas en bordes exactos (561, 641, 781, 901, 992, 1025, 1100, 1280, etc.) para confirmar que la partición reproduce los breakpoints originales. Resultado: 0 diferencias → BOUNDARY-EQUIVALENT.
* **Reglas de preservación (inviolables):**
   * `.tpl-f1` (cross-template) preservado textualmente al final del archivo.
   * Prosa ADR histórica migrada a este documento (DECISIONS.md) y al backup.
   * Cero Borrado de selectores: los 230 selectores del fuente están presentes en el consolidado.
   * Invariabilidad del Cerebro: `eventovenezuela.html` sin cambios (cero diffs).
* **Impacto:** `b5.css` de 94.9 KB a 64.7 KB (-32%). Balance de llaves 439/439 OK. `eventovenezuela.html` sin cambios. Backup preservado: `css/templates/campana/b5 pre-ADR28 backup.css`.
* **Pendiente:** Prueba de Carga Dual visual por Dirección confirmando paridad pixel-perfecta (la validación de cascada es estructural, no sustitución de QA visual humano).

