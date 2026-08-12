📂 TASKS.md — Tablero Operativo (v1.14-FIX)
### TASKS.md — Tablero Operativo de Tareas
#### Estado General
*   **Proyecto:** Sistema QR Hostal Terraza
*   **Checkpoint Actual:** v1.6.5-FIX / Contrato v112 (ADR-021 Wizard + ADR-022 Nav. Admin + ADR-023 Nav. Panel + ADR-024 Null Fix + ADR-025 Separación Master Admin + ADR-029 Auditoría Null Completa)
*   **Sprint Activo:** Sprint 1 — Monetización SaaS, Automatización y Conversión de Emergencia
*   **Última Actualización:** 12 de agosto de 2026

--------------------------------------------------------------------------------

#### 🔴 ALTA PRIORIDAD / EN COLA INMEDIATA

**Separación Master Admin / Barrio R10 (ADR-025) — Pendientes de cierre**
- [x] **TSK-024 | Chief Architect (Claude):** Código en `admin.html` — reemplazadas las 3 referencias a `slug === 'hostal-terraza'` por `is_master_org === true` (`_IS_SYSTEM_ADMIN()`, `applyRoleNav()`, comentario de `_orgOriginal`). Corte directo sin fallback (mandato de Dirección). Estado: **Completado ✅** en código, 7973→7973 líneas (sin adiciones/eliminaciones fuera de las 3 líneas tocadas). Ver `DECISIONS.md` ADR-025.
- [ ] **TSK-025 | Dirección / Lead Developer:** Ejecutar `migrations/adr025_master_admin_separation.sql` contra la instancia real de Supabase — columna `is_master_org`, creación de la org "SaaS Master Admin", reasignación del login actual a la org maestra, alta del nuevo login operativo de Barrio R10, y reescritura de las políticas `insert_organizaciones`/`delete_organizaciones`. Incluye pasos manuales de Supabase Dashboard (creación de usuario) que no pueden ejecutarse por SQL puro.
- [ ] **TSK-026 | Chief Architect (⚠️ hallazgo de auditoría, prioridad alta, fuera del mandato de ADR-025):** Revisar y retirar las políticas RLS legacy permisivas detectadas en `eventos` (`"Admins escriben eventos"`, ALL sin chequeo de `org_id`), `clientes` (`"Clientes acceso total autenticado"`, ALL sin ningún chequeo) y `perfiles` (`is_superadmin()` sin acotar por organización + `org_perfiles_update` sin `WITH CHECK` que impida auto-escalación de `rol`/`org_id`) — hoy permiten a cualquier cliente autenticado, no solo a Barrio R10, leer/escribir datos de otras organizaciones. Requiere su propio Context Package. Ver diagnóstico completo en `DECISIONS.md` ADR-025.

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
- [x] **TSK-005 | Lead Developer:** Dashboard contextual para porteros en scanner.html. Estado: **Completado ✅** — el contador vs aforo (número de ingresos, "de X inscritos · aforo Y", barra de ocupación con estados verde/ámbar/rojo y badges frecuente/invitado) ya existía en `updateCounter()`; se cerró el gap de "últimos 5 ingresos": `seedUltimosIngresos()` consulta `inscritos` (`used=true`, `order hora_ingreso desc`, `limit 5`) y `renderUltimosIngresos()` puebla la sección "Últimas entradas" al iniciar, con fallback offline desde `qrCache` y blindaje null (patrón ADR-024, `(nombre||'—')`). Verificado con `node --check` (sintaxis OK), prueba funcional con casos null/vacío/top-5/orden offline y balance de `<div>` 0. Ver hito en `NEXT.md`.
- [ ] **TSK-006 | Creative Director:** Configurar manifest.json y Service Worker para hacer el scanner instalable (PWA) [cite: 700, 713].
- [ ] **TSK-013 | Creative AI:** Desarrollar el módulo aditivo "08 Actualizaciones" y el desglose de tarjetas para la sección Historia de b5 [cite: 809].
- [ ] **TSK-014 | Documentation:** Sincronizar permanentemente PROJECT.md y BLUEPRINT.md bajo el estándar v127-MASTER.
- [x] **TSK-015 | Chief Architect (Claude):** Expansión Nuclear f1 — fix de desborde 400px, edge-to-edge en video/playlist y recuperación proporcional del póster con centrado en escritorio. Estado: **Completado ✅ (v2.5.0-GOLD)**, verificado visualmente por el Director en mobile y desktop. Auditoría reveló que los parches iniciales (v2.1.0–v2.3.0) apuntaban a selectores fantasma (`#modulo-lineup`, `#modulo-gallery`, `.media-grid`, `.poster-main-img`, `.spotify-container`) inexistentes en el DOM real de `evento3.html`; corregido con los IDs reales (`#mod-video`, `#mod-lineup`, `#mod-playlist`, `#db-poster-img`, `#db-spotify-embed`), stack móvil de `.lineup-grid` y liberación de wrappers `max-width:1100px` en video/playlist. Ver `ERRORES_HISTORICOS.md` Sección 5 y `DECISIONS.md` ADR-013.
- [x] **TSK-019 | Chief Architect (Claude):** Wizard Inteligente de Creación de Eventos (4 pasos) en `admin.html` — Orquestador de Intención Cine/Fiesta/Campaña, Captura Pura (toggle + persistencia), armonías cromáticas vía TinyColor2, fix de persistencia `template_id`/`categoria_slug` y fix del bug de anidación `<div>` en Aforo. Estado: **Completado ✅** en código (HTML/CSS/JS de `admin.html`, verificado con parser HTML5 — 0 errores de anidación en ~7800 líneas), pendiente de verificación visual real por Dirección (Prueba de Carga Dual) y de cerrar TSK-016/017/018. Ver `DECISIONS.md` ADR-021 y `ERRORES_HISTORICOS.md` §8.
- [x] **TSK-020 | Chief Architect (Claude):** Reorganización de navegación del módulo Admin — pestañas internas Historial/Crear/Invitadores (Historial por defecto), título + buscador + filtro de categoría + Próximos/Pasados en el Historial, contadores en pestañas, y reubicación de "Nuevo asistente" (admin_evento). Estado: **Completado ✅** en código, verificado con parser HTML5 (0 errores) y `node --check` sobre el JS. Detectó y corrigió en la misma sesión una regresión real: `aplicarRestriccionesAdminEvento()` ocultaba la card de creación con un selector posicional que la reestructuración en pestañas habría roto — corregido a selector por atributo. Ver `DECISIONS.md` ADR-022 y `ERRORES_HISTORICOS.md` §9.
- [x] **TSK-021 | Chief Architect (Claude):** Misma reorganización aplicada a Panel — 4 pestañas internas Resumen/Tendencias/Rankings/Asistentes (Resumen por defecto) agrupando las 14 secciones de analítica que antes eran un único scroll, controles globales (vista/período/exportar) siempre visibles fuera de las pestañas, badge de conteo en Asistentes. No se agregó funcionalidad nueva a la tabla de asistentes (ya tenía buscador/filtros/acciones masivas/paginación). Estado: **Completado ✅** en código, verificado con parser HTML5 (0 errores) y `node --check`. Detectó y corrigió en la misma sesión un bug real antes de entregar: la regla CSS de ocultamiento por defecto solo cubría el atributo `data-adm-tab`, no el nuevo `data-pnl-tab` — las 4 pestañas de Panel habrían quedado todas visibles a la vez. Ver `DECISIONS.md` ADR-023 y `ERRORES_HISTORICOS.md` §10.
- [x] **TSK-022 | Chief Architect (Claude):** Fix "Null Pointer Regression" — Silent Fallback en `_renderTablaPagina()` (bloqueaba TODO el panel para orgs con `inscritos.nombre`/`evento_nombre` nulos, caso "Barrio R10") y en `evStats` de `renderPanel()` (mismo riesgo, no disparado aún). Confirmado que NO es regresión de ADR-023. Log TRACE del Escudo GOLD agregado. Verificado con parser HTML5, `node --check` y una prueba funcional aislada con casos `null`. Entregada además `migrations/adr024_audit_nulls_inscritos.sql` (solo lectura) para ubicar otros registros/orgs con campos incompletos — corregida tras reporte de fallo real en Postgres (alias combinados en `ORDER BY`, resuelto con CTE). Ver `DECISIONS.md` ADR-024 y `ERRORES_HISTORICOS.md` §11.
- [x] **TSK-023 | Chief Architect (Claude):** Auditoría completa del patrón "métodos de string sin blindar" (ADR-024) sobre `admin.html` — el mandato de ADR-024 se limitó a `_renderTablaPagina`/`renderPanel`; esta sesión extendió el barrido a TODO el archivo. Resultado: 11 puntos de crash reales corregidos con Silent Fallback `(campo||'')` — `renderEventos()` (L3516 y L3539: `s.nombre`/`e.nombre`.replace en los `onclick` de `openMod`), `renderInvitadoresPerfil()` (L4281 `g.nombre.split`) y `abrirPerfilInvitador()` (L4309 `grupo.nombre.split`, L4349 `l.link_generado.split('slug=')`), más `renderDirectorio()` (L5012 `p.nombre.split`), duplicados (L4931/32 `p.a/b.nombre.split`), `showVerify()` de Admin (L5497 `ins.nombre.split`), `descargarInvitacion()` (L5359 `ev.nombre.replace`), export de eventos (L6467 `ev.nombre.replace` en nombre de hoja), `filtrarGlobalOrgs()`/gráficas globales (L2912 `o.nombre.length`) y búsqueda global (L3205 `inv.codigo.includes`). Se blindaron además interpolaciones que mostraban el texto literal `"null"` al usuario en las dos funciones del mandato (eventos y perfiles de invitador). Verificado con `node --check`, prueba funcional aislada con casos `null` (13/13 OK) y balance de `<div>` 0 (760/760). Ver `DECISIONS.md` ADR-029.

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
*TRACE: Sincronía técnica [v1.16-FIX] sellada. TSK-023 (auditoría null-pointer ADR-024 extendida a todo admin.html — 11 crashes corregidos) y TSK-005 (dashboard contextual portero) completados; Wizard Inteligente (ADR-021), navegación de Admin (ADR-022), navegación de Panel (ADR-023), fix "Null Pointer Regression" (ADR-024) y Separación Master Admin/Barrio R10 (ADR-025, código completado, SQL pendiente de ejecución) integrados; TSK-016/017/018/023→✅/025/026 en cola. Documentación integrada y análisis de ingeniería entregado.*