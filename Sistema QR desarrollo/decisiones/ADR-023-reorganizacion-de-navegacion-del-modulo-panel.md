---
doc: ADR-023
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L221-235 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L221-235 del original).

#### ADR-023: Reorganización de Navegación del Módulo Panel (Resumen / Tendencias / Rankings / Asistentes)
* **ID:** ADR-023 | **Fecha:** Agosto 2026 | **Estado:** Aprobado — código entregado en `admin.html`.
* **Problema:** Se pidió aplicar la misma reestructuración de ADR-022 a "Panel" (`pg-panel`, la vista de analítica/exportación de inscritos). A diferencia de "Admin", Panel no tenía 3 concerns preexistentes claramente separables en cards — era **14 secciones** (KPIs, 6 gráficos, 4 rankings/perfiles, insights, tabla de asistentes con buscador/filtros/acciones masivas ya maduros, y log de accesos) en un único scroll continuo bajo una cabecera de controles globales (selector de vista, filtro de período 7d/30d/90d/todo, menú de exportación).
* **Decisión:**
  1. **Agrupación en 4 pestañas** por afinidad de uso, no por orden físico en el archivo (mismo método in-situ de ADR-021/022): **📊 Resumen** (KPIs, Inscritos vs asistencia, Distribución por tipo, Insights automáticos) — vista por defecto; **📈 Tendencias** (Heatmap por hora, día de semana, Embudo, Retención, Crecimiento de la base, Inscripciones por día/hora); **🏆 Rankings** (Ranking de inscriptores, Ranking de eventos, Perfil del asistente promedio, Origen de asistentes, Canales de llegada); **👥 Asistentes** (Lista de asistentes + Log de accesos — se agrupó el Log aquí en vez de darle pestaña propia por ser una única card de bajo uso relativo, y por afinidad temática con la tabla de asistentes: ambas son vistas a nivel de registro individual, no analíticas agregadas).
  2. **Controles globales (vista/período/exportar) fuera de las pestañas**, siempre visibles arriba — aplican a los datos subyacentes de las 4 pestañas por igual, no son contenido de una sola sección.
  3. **Resumen como vista por defecto** (no una de las 4 elegida arbitrariamente): es la lectura "de un vistazo" análoga al rol que cumple un dashboard overview; a diferencia de ADR-022 (donde Historial ganó por ser la consulta más frecuente), aquí no hay una sub-vista claramente más frecuente que las demás, así que se usó el criterio de "qué es lo primero que se querría ver".
  4. **Reutilización de las clases CSS `.adm-nav`/`.adm-tab` de ADR-022** (sin duplicar CSS) para mantener consistencia visual entre los dos paneles reorganizados. Namespace de atributos separado (`data-pnl-tab`/`data-pnl-pill` vs. `data-adm-tab`/`data-adm-pill`) y controlador JS propio (`pnlGoTab()` vs. `admGoTab()`) para que ambas páginas, que coexisten en el mismo DOM, no interfieran entre sí.
  5. **Badge de conteo en la pestaña Asistentes** (`_pnAllList.length`, la lista completa sin filtrar) — igual que en ADR-022. Las demás pestañas no llevan badge: no hay un conteo único y significativo que resumir en un ranking o una tendencia de la misma forma que "cuántos asistentes hay".
  6. **La tabla de Asistentes no se tocó funcionalmente** — ya tenía buscador, filtro por tipo, filtro por estado, selección masiva y paginación (más madura que el Historial de eventos antes de ADR-022). El trabajo aquí fue puramente de agrupación/navegación, no de agregar funcionalidad nueva.
* **Bug detectado y corregido antes de entregar:** la regla CSS que oculta pestañas por defecto (`[data-adm-tab]{display:none}`) solo cubría el atributo `data-adm-tab` — al reutilizar el mismo patrón con el atributo `data-pnl-tab` (namespace separado, ver punto 4), las 4 pestañas de Panel se habrían mostrado todas a la vez, sin ocultarse, porque ninguna regla CSS las alcanzaba. Corregido ampliando el selector a `[data-adm-tab],[data-pnl-tab]{display:none}` (y su contraparte `.adm-visible`) antes de la verificación final.
* **Justificación:** Mismo argumento de riesgo que ADR-021/022 (envoltura in-situ, cero relocalización, cero IDs eliminados) aplicado a una página con casi el triple de secciones que Admin — el beneficio de navegar por pestañas en vez de scroll es proporcionalmente mayor aquí.
* **Impacto:** `admin.html` actualizado (HTML envuelto en `data-pnl-tab` dentro de `pg-panel`, JS `pnlGoTab()` + badge en `_renderTablaPagina()`, CSS ampliado para cubrir ambos namespaces de pestañas). Verificado con parser HTML5 (0 errores de anidación) y `node --check` sobre el JS combinado antes de entregar.
* **Pendientes:** Verificación visual real por Dirección (Prueba de Carga Dual) en desktop y mobile. Los pendientes de ADR-021/022 (TSK-016/017/018) siguen abiertos y no fueron tocados en esta sesión.

