# 🚀 NEXT.md — Estado de Relevo y Próximos Pasos (v1.13-FIX)

Este documento define el punto de control estratégico y las directrices para la continuación inmediata del desarrollo. Es la hoja de ruta obligatoria para cualquier IA o agente que retome el proyecto para asegurar la fidelidad de 1px y la integridad del núcleo.

---

#### -2. Hito Más Reciente — Fix "Null Pointer Regression" (ADR-024)
*   **Qué se corrigió:** el panel se bloqueaba por completo para organizaciones con registros de `inscritos` incompletos (caso "Barrio R10": `nombre`/`evento_nombre` en `NULL`), porque `_renderTablaPagina()` usaba `.replace()` sin blindar sobre esos campos. **Confirmado que no es regresión de ADR-023** — bug preexistente que esa organización disparó primero. Se corrigió con el patrón Silent Fallback (`(campo||'')`) y, preventivamente, se blindó también `evStats` en `renderPanel()` (mismo riesgo, aún no disparado). Log TRACE agregado. Ver `DECISIONS.md` ADR-024.
*   **Entregado además:** `migrations/adr024_audit_nulls_inscritos.sql` (solo lectura) para ubicar qué otros registros/organizaciones tienen campos incompletos — incluye nota de que algunos `NULL` en `inscritos` son legítimos por diseño (campos de Fase 2 de `b5`), no corregir a ciegas con `UPDATE` masivo.
*   **⚠️ Alcance no cubierto, pendiente de priorización (TSK-023):** el mismo patrón de riesgo podría existir en `renderEventos()`/`renderInvitadoresPerfil()` (Admin) y en el resto del archivo no auditado — el mandato de esta sesión se limitó explícitamente a `_renderTablaPagina` y subfunciones de `renderPanel`.

#### -1. Hito Anterior — Reorganización de Navegación de Panel (ADR-023)
*   **Qué se entregó:** Igual que ADR-022 pero para "Panel" — 4 pestañas internas (**Resumen** por defecto, Tendencias, Rankings, Asistentes) agrupando las 14 secciones de analítica que antes eran un único scroll. Controles globales (vista/período/exportar) siguen siempre visibles fuera de las pestañas. Ver `DECISIONS.md` ADR-023.
*   **Bug real detectado y corregido en la misma sesión:** la regla CSS que oculta pestañas por defecto solo cubría `[data-adm-tab]`; al reutilizar el patrón con el nuevo atributo `data-pnl-tab` (namespace separado a propósito para no interferir con Admin), las 4 pestañas de Panel se habrían mostrado todas a la vez. Corregido antes de entregar. Ver `ERRORES_HISTORICOS.md` §10 — lección: al reutilizar un patrón de "atributo + clase de estado compartida" para un segundo módulo, verificar que el selector CSS cubra el nuevo namespace de atributo, no solo el nombre de la clase.
*   **Nota para la siguiente sesión:** igual que con Admin, el orden visual de las 4 pestañas de Panel no corresponde al orden físico de los bloques en el archivo — ubicar por `id` o `data-pnl-tab`, no por posición aproximada.

#### 0. Hito Anterior — Reorganización de Navegación de Admin (ADR-022)
*   **Qué se entregó:** El módulo "Admin" (antes un único scroll continuo) ahora tiene 3 pestañas internas — **Historial** (vista por defecto), **+ Nuevo evento** (el Wizard de ADR-021), **Invitadores** — con contadores en cada pestaña. El Historial ganó título de sección (antes no tenía), buscador por nombre, filtro por categoría (Cine/Fiesta/Campaña) y separación Próximos/Pasados/Todos. "Nuevo asistente" (rol `admin_evento`) se reubicó dentro de Historial. Ver `DECISIONS.md` ADR-022.
*   **Regresión real detectada y corregida en la misma sesión:** `aplicarRestriccionesAdminEvento()` ocultaba la card de creación con un selector posicional (`#pg-admin > .wrap > .card`) que la reestructuración en pestañas rompió silenciosamente — corregido antes de entregar. Ver `ERRORES_HISTORICOS.md` §9. Lección para próximas sesiones: antes de envolver/reordenar HTML existente, grepear el archivo por selectores posicionales (`>`, `:nth-child`, `:first-child`) que apunten a esa región.
*   **Confirmación de Dirección:** el desarrollo activo del motor público se está haciendo desde `evento3.html` — dato relevante para TSK-017 (ver abajo), aunque no cierra formalmente la reconciliación con el link `evento.html` que sigue generando `admin.html`.

#### 0b. Hito Anterior — Wizard Inteligente de Creación (ADR-021)
*   **Qué se entregó:** `admin.html` reestructurado en un Wizard de 4 pasos (Cimiento, ADN Visual, Contenido, Blindaje) con Orquestador de Intención Cine/Fiesta/Campaña, modo "Captura Pura" (sin QR), armonías cromáticas vía TinyColor2 y fix de persistencia de `template_id`/`categoria_slug`. Ver `DECISIONS.md` ADR-021 y `ERRORES_HISTORICOS.md` §8 para el detalle completo (incluye dos hallazgos reales: columnas documentadas-pero-no-escritas y un bug de anidación `<div>` en el campo Aforo, ambos corregidos).
*   **⚠️ Nota para la siguiente sesión sobre `admin.html`:** el Wizard se implementó envolviendo el HTML existente **in situ** con `data-wiz-step="N"` en vez de reordenar físicamente el archivo — el orden visual de los 4 pasos en pantalla **no** corresponde al orden físico de los bloques en el archivo. Antes de editar cualquier campo del formulario de creación de eventos, ubicarlo por su `id` o por su `data-wiz-step`, no por su posición aproximada en el archivo.
*   **⚠️ No cerrado todavía:** TSK-016 (`evento.html` debe consumir `captura_pura`), TSK-017 (reconciliar `evento.html` vs. `evento3.html` como "El Cerebro" — ver Riesgos §4 abajo) y TSK-018 (ejecutar la migración SQL) siguen pendientes y son prioridad inmediata.

#### 1. Resumen del Punto de Control (Evolución v110 y Silo b5)
*   **Hito Sellado:** Integración exitosa del silo **b5 ("Emergencia Crítica")** y evolución formal al **Contrato de Datos v110**, expandiendo la capacidad a 20 átomos soberanos interactivos.
*   **Estado del Sistema:** **v1.6.1-GOLD / Contrato v112**. Certificación de la lógica **Dual-Phase** en `eventovenezuela.html` (Registro de Fase 1 + Perfilamiento in-place de Fase 2) como estándar de alta conversión.
*   **Arquitectura:** Validación operativa del modelo de silos atómicos y blindaje de datos mediante el control estricto de esquemas en Supabase.

#### 2. Instrucciones para la Siguiente IA / Sesión
Para mantener el control del proyecto y la trazabilidad, se debe seguir esta secuencia inquebrantable:
1.  **Carga de Contexto:** Leer obligatoriamente en este orden: `PROJECT.md` -> `BLUEPRINT.md` -> `TASKS.md` -> `DECISIONS.md` -> `NEXT.md`.
2.  **Soberanía de Silos:** Al operar sobre plantillas de campaña o emergencia, asegurar la correcta separación de estilos bajo el selector atómico correspondiente.
3.  **Invariabilidad del Cerebro:** Queda prohibido modificar el HTML base de orquestación. Toda reordenación visual debe gestionarse vía `grid-template-areas` en el CSS del silo.
4.  **Asunción de Roles:** Asumir estrictamente el rol asignado según la **Matriz de Capacidades de AI-DOS v1.2**.

#### 3. Próximos Objetivos Operativos (Sincronía con TASKS.md)
*   **Prioridad 0 (TSK-017, ⚠️ bloqueante para dar por cerrado ADR-021):** Reconciliar si `evento.html` (al que apunta el link público de `admin.html`) es el mismo motor que `evento3.html` ("El Cerebro" según `BLUEPRINT.md` §1) — de esto depende si `template_id`/`categoria_slug` tienen efecto visual real.
*   **Prioridad 0b (TSK-016, TSK-018):** Consumir `captura_pura` en `evento.html` y ejecutar `migrations/adr021_eventos_columns.sql` en Supabase.
*   **Prioridad 1 (TSK-010):** Verificación y despliegue del esquema de base de datos en Supabase para la tabla inscritos (incorporando las columnas críticas: `whatsapp`, `tipo_ayuda`, `autorizacion` y el contenedor `respuestas_custom` en JSONB).
*   **Prioridad 2 (TSK-011):** Despliegue físico del archivo `b5.css` en la ruta estandarizada `css/templates/campana/`.
*   **Prioridad 3:** Retomar las tareas estratégicas de monetización e infraestructura (`TSK-001` Integración Wompi y `TSK-002` Edge Function de webhook).

#### 4. Riesgos Activos y Restricciones a Preservar (STRICT)
*   **Slug Hardcodeado:** El identificador `'hostal-terraza'` es el único que asigna permisos de System Admin global. No modificar esta cadena en filtros RLS ni guardas de navegación.
*   **Cumplimiento CSP de Vercel:** Prohibido introducir librerías que ejecuten `eval()` o `new Function()`. El estándar de referencia para QRs es `qr-creator`.
*   **Estabilidad de Supabase:** Mantener los websockets de **Realtime deshabilitados** para prevenir bloqueos en la interfaz; usar polling o reconsultas manuales.
*   **Asunciones de Base de Datos:** El núcleo de `eventovenezuela.html` asume la existencia de las nuevas columnas de la v110 en la tabla `inscritos`; cualquier desajuste interrumpirá la Fase 2 del flujo de conversión.
*   **Regla de Bloque (ADR-007):** Los módulos multimedia (#mod-video, #mod-lineup) deben conservar `display: block !important` para evitar el colapso visual tras la inyección JS[cite: 2].
*   **Tratamiento Geist 900:** Obligatoriedad de tipografía **Geist 900 de 3.2rem** con efectos Afterglow en todas las tarjetas de datos técnicos para el estándar de $10,000[cite: 6].
*   **Motor Público Ambiguo (ADR-021 / TSK-017):** `BLUEPRINT.md` declara `evento3.html` como "El Cerebro", pero `admin.html` enlaza a `evento.html` tras crear un evento. No modificar la lógica de generación de `pubLink` en `admin.html` hasta confirmar cuál de los dos es el motor vigente — un cambio a ciegas podría romper enlaces ya distribuidos.

---
*Este documento se actualiza bajo la Regla v127, garantizando la preservación total de la información histórica.*