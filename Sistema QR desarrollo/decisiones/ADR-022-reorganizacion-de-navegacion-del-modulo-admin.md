---
doc: ADR-022
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L204-220 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L204-220 del original).

#### ADR-022: Reorganización de Navegación del Módulo Admin (Historial / Crear / Invitadores)
* **ID:** ADR-022 | **Fecha:** Agosto 2026 | **Estado:** Aprobado — código entregado en `admin.html`.
* **Problema:** La página "Admin" (`pg-admin`, la vista de aterrizaje por defecto del sistema) era un único scroll continuo de ~640 líneas sin navegación interna: Wizard "Nuevo evento" → "Invitadores" → "Nuevo asistente" (solo `admin_evento`) → lista de eventos. Tres hallazgos concretos de la auditoría previa al diseño:
  1. La lista de eventos (`ev-list`) no tenía título de sección (`<div class="ch">`) — aparecía sin encabezado al final del scroll.
  2. `ev-list` no tenía buscador, filtro ni orden — cronológico por `created_at`, sin distinguir próximos/pasados ni por categoría (categoría disponible recién desde ADR-021).
  3. "Panel" (pestaña separada del nav principal) ya cubre analítica/exportación de inscritos — el historial dentro de "Admin" debía mantenerse como vista de gestión (editar/link/eliminar), no duplicar analítica.
* **Decisión (mandato de Dirección: proceder con el criterio más coherente sin bloquear en preguntas ya heurísticamente resueltas):**
  1. **Navegación por pestañas internas** (`Historial` / `+ Nuevo evento` / `Invitadores`) dentro de la misma página `pg-admin`, con el mismo patrón in-situ de ADR-021 (`data-adm-tab="N"` + controlador `admGoTab()`) — sin relocalizar HTML físicamente, mismo argumento de riesgo que ADR-021.
  2. **Historial como vista de aterrizaje por defecto** (no "Crear evento" como antes): es la consulta más frecuente en el uso diario de un admin ya operando el sistema; crear un evento nuevo es una acción deliberada, no el estado de reposo natural del panel.
  3. **Historial ahora con título de sección, buscador por nombre, filtro por categoría (Cine/Fiesta/Campaña) y separación Próximos/Pasados/Todos**, aplicados en memoria sobre lo ya cargado por `loadEventos()` (sin nuevas consultas a Supabase). Eventos sin `fecha` (ej. campañas con centinela) se tratan siempre como "próximos".
  4. **Contadores en las pestañas** (`adm-tab-badge`): historial muestra el total de eventos de la org; invitadores muestra invitadores únicos por código (no filas de links).
  5. **"Nuevo asistente"** (solo rol `admin_evento`) se reubicó dentro de la pestaña Historial — es una acción de gestión sobre el evento ya asignado a ese rol, no de creación de eventos nuevos ni de invitadores.
* **Hallazgo de regresión detectado y corregido en la misma sesión (antes de entregar):** `aplicarRestriccionesAdminEvento()` ocultaba la card de creación con el selector posicional `#pg-admin > .wrap > .card` (hijo directo de `.wrap`). Al envolver esa card en `<div data-adm-tab="crear">`, pasó a ser **nieta** de `.wrap`, no hija directa — el selector dejó de coincidir y habría dejado el Wizard de creación visible/accesible para el rol `admin_evento`, que no debería poder crear eventos. Se corrigió ocultando el tab "Crear" completo (botón + contenido) por atributo (`[data-adm-pill="crear"]` / `[data-adm-tab="crear"]`) en vez de por posición en el árbol, y forzando el aterrizaje a "historial" si ese tab estaba activo. Ver `ERRORES_HISTORICOS.md` §9 — mismo principio general que ADR-007/ADR-010 de este proyecto: los selectores acoplados a la posición en el DOM son frágiles ante refactors estructurales; preferir selectores por atributo/ID.
* **Justificación:** Consistente con ADR-021 en método (envoltura in-situ, cero relocalización, cero IDs eliminados) y en objetivo (reducir fricción de navegación sin aumentar superficie de riesgo). Historial-por-defecto y filtros de búsqueda se justifican por el patrón de uso esperado de un panel de gestión ya en producción con eventos acumulándose con el tiempo.
* **Impacto:** `admin.html` actualizado (CSS `.adm-nav`/`.adm-tab`/`.hist-filters`, HTML envuelto en `data-adm-tab`, JS `admGoTab()`/`setHistTime()`/`_aplicarFiltrosHistorial()`, `renderEventos()` y `renderInvitadoresPerfil()` extendidos, `aplicarRestriccionesAdminEvento()` corregida). Verificado con parser HTML5 (0 errores de anidación) y `node --check` sobre el JS combinado (sintaxis válida) antes de entregar.
* **Pendientes:** Verificación visual real por Dirección (Prueba de Carga Dual) en desktop y mobile; los mismos pendientes de ADR-021 (TSK-016/017/018) siguen abiertos y no fueron tocados en esta sesión.

