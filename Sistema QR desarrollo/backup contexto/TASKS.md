📂 TASKS.md — Tablero Operativo (v1.15-FIX)
### TASKS.md — Tablero Operativo de Tareas
#### Estado General
*   **Proyecto:** Sistema QR Hostal Terraza
*   **Checkpoint Actual:** v1.6.5-FIX / Contrato v112 (ADR-021 Wizard + ADR-022 Nav. Admin + ADR-023 Nav. Panel + ADR-024 Null Fix + ADR-025 Separación Master Admin — ✅ verificado en producción)
*   **Sprint Activo:** Sprint 1 — Monetización SaaS, Automatización y Conversión de Emergencia
*   **Última Actualización:** 10 de agosto de 2026

--------------------------------------------------------------------------------

#### 🔴 ALTA PRIORIDAD / EN COLA INMEDIATA

**Separación Master Admin / Barrio R10 (ADR-025) — ✅ Cerrado y verificado en producción**
- [x] **TSK-024 | Chief Architect (Claude):** Código en `admin.html` — reemplazadas las 3 referencias a `slug === 'hostal-terraza'` por `is_master_org === true` (`_IS_SYSTEM_ADMIN()`, `applyRoleNav()`, comentario de `_orgOriginal`). Corte directo sin fallback (mandato de Dirección). Estado: **Completado ✅** en código, 7973→7973 líneas (sin adiciones/eliminaciones fuera de las 3 líneas tocadas). Ver `DECISIONS.md` ADR-025.
- [x] **TSK-025 | Dirección:** Ejecutar `migrations/adr025_master_admin_separation.sql` contra la instancia real de Supabase. Estado: **Completado ✅** — columna `is_master_org`, org "SaaS Master Admin" creada, login de Dirección reasignado a la org maestra, login operativo nuevo de Barrio R10 (`barrior10@gmail.com`) creado, políticas `insert_organizaciones`/`delete_organizaciones` reescritas. Verificado: las 4 cuentas resuelven su organización correctamente al loguear.
- [x] **TSK-027 | Chief Architect (Claude):** Fix de consistencia en el selector de período del Panel — el HTML marcaba "7d" como botón activo por defecto mientras la variable real `_pnPeriod` inicializa en `'30d'`. Sin impacto visual (no existe regla CSS `.pn-period.on`), pero el markup no reflejaba el comportamiento real. Corregido para que "30d" sea el botón marcado por defecto. Detectado mientras se diagnosticaba el reporte "panel no muestra los inscritos de Barrio R10" (causa real: filtro de 30 días ocultando registros más antiguos, no relacionado con ADR-025). Ver `DECISIONS.md` ADR-025 Addendum 2 y `ERRORES_HISTORICOS.md` §12.
- [ ] **TSK-026 | Chief Architect (⚠️ hallazgo de auditoría, prioridad alta, único pendiente abierto de esta sesión):** Revisar y retirar las políticas RLS legacy permisivas detectadas en `eventos` (`"Admins escriben eventos"`, ALL sin chequeo de `org_id`), `clientes` (`"Clientes acceso total autenticado"`, ALL sin ningún chequeo) y `perfiles` (`is_superadmin()` sin acotar por organización + `org_perfiles_update` sin `WITH CHECK` que impida auto-escalación de `rol`/`org_id`) — hoy permiten a cualquier cliente autenticado, no solo a Barrio R10, leer/escribir datos de otras organizaciones. Requiere su propio Context Package. Ver diagnóstico completo en `DECISIONS.md` ADR-025.

**Wizard Inteligente (ADR-021) — Pendientes de cierre**
- [ ] **TSK-016 | Lead Developer:** Modificar `evento.html` para leer la nueva columna `captura_pura`: si es `true`, omitir la generación/render del QR tras el registro y mostrar un mensaje de agradecimiento personalizado en su lugar. No se pudo implementar en la sesión de ADR-021 porque `evento.html` no formaba parte de los archivos subidos.
- [ ] **TSK-017 | Chief Architect (⚠️ prioridad alta, verificar primero):** Reconciliar la contradicción entre `BLUEPRINT.md` §1 (declara `evento3.html` como "El Cerebro") y el link público que genera `admin.html` tras crear un evento (`/evento.html?slug=...`, ver `_crearEventoUnico()` y TSK-008). **Actualización de Dirección:** confirmado que el desarrollo activo se está haciendo desde `evento3.html`. Sigue pendiente confirmar formalmente si `evento.html` (al que `admin.html` sigue enlazando) es un alias/redirect de `evento3.html`, un remanente pre-migración a actualizar, o un motor distinto — de esto depende si `template_id`/`categoria_slug` (persistidos desde ADR-021) tienen efecto visual real en el link que el admin comparte.
- [ ] **TSK-018 | Lead Developer:** Ejecutar `migrations/adr021_eventos_columns.sql` (idempotente) contra la instancia real de Supabase para confirmar/crear `template_id`, `categoria_slug`, `captura_pura` en `eventos`.

- [ ] **TSK-003 | Lead Developer (Gemini):** Configurar pg_cron para envío automático de recordatorios 24h antes del evento vía send-ticket-email.

**Blindaje Campaña b5 (Emergencia)**
- [ ] **TSK-010 | Lead Developer:** Verificar y crear columnas en tabla `inscritos` (whatsapp, tipo_ayuda, autorizacion) [cite: 810, 735].

- [ ] **TSK-012 | Chief Architect:** Implementar ADR-012 en `DECISIONS.md` para documentar la extensión del Contrato v110 [cite: 811].

--------------------------------------------------------------------------------

#### 🟡 PRIORIDAD MEDIA

**Refinamiento y UX**
- [ ] **TSK-005 | Lead Developer:** Implementar el dashboard contextual para porteros en scanner.html (contador vs aforo y últimos 5 ingresos).
- [ ] **TSK-006 | Creative Director:** Configurar manifest.json y Service Worker para hacer el scanner instalable (PWA) [cite: 700, 713].
- [ ] **TSK-013 | Creative AI:** Desarrollar el módulo aditivo "08 Actualizaciones" y el desglose de tarjetas para la sección Historia de b5 [cite: 809].
- [ ] **TSK-014 | Documentation:** Sincronizar permanentemente PROJECT.md y BLUEPRINT.md bajo el estándar v127-MASTER.
- [x] **TSK-015 | Chief Architect (Claude):** Expansión Nuclear f1 — fix de desborde 400px, edge-to-edge en video/playlist y recuperación proporcional del póster con centrado en escritorio. Estado: **Completado ✅ (v2.5.0-GOLD)**, verificado visualmente por el Director en mobile y desktop. Auditoría reveló que los parches iniciales (v2.1.0–v2.3.0) apuntaban a selectores fantasma (`#modulo-lineup`, `#modulo-gallery`, `.media-grid`, `.poster-main-img`, `.spotify-container`) inexistentes en el DOM real de `evento3.html`; corregido con los IDs reales (`#mod-video`, `#mod-lineup`, `#mod-playlist`, `#db-poster-img`, `#db-spotify-embed`), stack móvil de `.lineup-grid` y liberación de wrappers `max-width:1100px` en video/playlist. Ver `ERRORES_HISTORICOS.md` Sección 5 y `DECISIONS.md` ADR-013.
- [x] **TSK-019 | Chief Architect (Claude):** Wizard Inteligente de Creación de Eventos (4 pasos) en `admin.html` — Orquestador de Intención Cine/Fiesta/Campaña, Captura Pura (toggle + persistencia), armonías cromáticas vía TinyColor2, fix de persistencia `template_id`/`categoria_slug` y fix del bug de anidación `<div>` en Aforo. Estado: **Completado ✅** en código (HTML/CSS/JS de `admin.html`, verificado con parser HTML5 — 0 errores de anidación en ~7800 líneas), pendiente de verificación visual real por Dirección (Prueba de Carga Dual) y de cerrar TSK-016/017/018. Ver `DECISIONS.md` ADR-021 y `ERRORES_HISTORICOS.md` §8.
- [x] **TSK-020 | Chief Architect (Claude):** Reorganización de navegación del módulo Admin — pestañas internas Historial/Crear/Invitadores (Historial por defecto), título + buscador + filtro de categoría + Próximos/Pasados en el Historial, contadores en pestañas, y reubicación de "Nuevo asistente" (admin_evento). Estado: **Completado ✅** en código, verificado con parser HTML5 (0 errores) y `node --check` sobre el JS. Detectó y corrigió en la misma sesión una regresión real: `aplicarRestriccionesAdminEvento()` ocultaba la card de creación con un selector posicional que la reestructuración en pestañas habría roto — corregido a selector por atributo. Ver `DECISIONS.md` ADR-022 y `ERRORES_HISTORICOS.md` §9.
- [x] **TSK-021 | Chief Architect (Claude):** Misma reorganización aplicada a Panel — 4 pestañas internas Resumen/Tendencias/Rankings/Asistentes (Resumen por defecto) agrupando las 14 secciones de analítica que antes eran un único scroll, controles globales (vista/período/exportar) siempre visibles fuera de las pestañas, badge de conteo en Asistentes. No se agregó funcionalidad nueva a la tabla de asistentes (ya tenía buscador/filtros/acciones masivas/paginación). Estado: **Completado ✅** en código, verificado con parser HTML5 (0 errores) y `node --check`. Detectó y corrigió en la misma sesión un bug real antes de entregar: la regla CSS de ocultamiento por defecto solo cubría el atributo `data-adm-tab`, no el nuevo `data-pnl-tab` — las 4 pestañas de Panel habrían quedado todas visibles a la vez. Ver `DECISIONS.md` ADR-023 y `ERRORES_HISTORICOS.md` §10.
- [x] **TSK-022 | Chief Architect (Claude):** Fix "Null Pointer Regression" — Silent Fallback en `_renderTablaPagina()` (bloqueaba TODO el panel para orgs con `inscritos.nombre`/`evento_nombre` nulos, caso "Barrio R10") y en `evStats` de `renderPanel()` (mismo riesgo, no disparado aún). Confirmado que NO es regresión de ADR-023. Log TRACE del Escudo GOLD agregado. Verificado con parser HTML5, `node --check` y una prueba funcional aislada con casos `null`. Entregada además `migrations/adr024_audit_nulls_inscritos.sql` (solo lectura) para ubicar otros registros/orgs con campos incompletos — corregida tras reporte de fallo real en Postgres (alias combinados en `ORDER BY`, resuelto con CTE). Ver `DECISIONS.md` ADR-024 y `ERRORES_HISTORICOS.md` §11.
- [ ] **TSK-023 | Chief Architect (⚠️ alcance no cubierto en ADR-024, pendiente de priorización):** El mismo patrón de riesgo (métodos de string sin blindar sobre campos de Supabase) podría existir en `renderEventos()`/`renderInvitadoresPerfil()` (Admin, ADR-022) y en el resto del archivo no auditado en la sesión de ADR-024 — el mandato de esa sesión se limitó explícitamente a `_renderTablaPagina` y subfunciones de `renderPanel`.

--------------------------------------------------------------------------------

#### 🟢 BACKLOG / LARGO PLAZO


**Infraestructura SaaS (Bloqueante)**
- [ ] **TSK-001 | Lead Developer (Gemini):** Implementar widget de pago de Wompi en registro.html y en la sección de renovación/suscripción.
- [ ] **TSK-002 | Lead Developer (Gemini):** Crear la Edge Function wompi-webhook en Supabase para validar la firma HMAC y activar organizaciones.activa = true.

- [ ] **TSK-004 | Lead Developer:** Construir la lógica de lista de espera (lista_espera table) para eventos con aforo completo.
- [ ] **TSK-007 | Chief Architect:** Refactorizar admin.html para carga perezosa (lazy load) de módulos pesados (~214KB).
- [ ] **TSK-008 | Lead Developer:** Integración de cobro Wompi directo en evento.html para entradas de pago.
- [ ] **TSK-009 | QA / Chief Architect:** Generación e integración de tickets digitales para Apple Wallet (.pkpass) y Google Wallet.

--------------------------------------------------------------------------------
*TRACE: Sincronía técnica [v1.15-FIX] sellada. Wizard Inteligente (ADR-021), navegación de Admin (ADR-022), navegación de Panel (ADR-023), fix "Null Pointer Regression" (ADR-024) y Separación Master Admin/Barrio R10 (ADR-025, ✅ verificado en producción) integrados; TSK-016/017/018/023/026 en cola. Documentación integrada y análisis de ingeniería entregado.*