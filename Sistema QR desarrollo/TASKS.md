---
doc: TASKS.md
version: v1.20-FIX (preservada)
fecha: 2026-10-01
origen: TASKS.md L1-261 (AMPLIACION/_backups/TASKS.md.2026-10-01.bak)
version_previa: TASKS.md v1.20-FIX (261 líneas, 178 KB)
relacionados: [INDEX.md, TASKS-DETALLE.md, TASKS-ARCHIVO.md, NEXT.md]
estado: vigente
estructura: indice-v1 (2026-10-01)
---

📂 TASKS.md — Tablero Operativo (v1.20-FIX)
### TASKS.md — Tablero Operativo de Tareas
#### Estado General
*   **Proyecto:** Sistema QR Hostal Terraza
*   **Checkpoint Actual:** v1.6.6-FIX / Contrato v112 (ADR-021 Wizard + ADR-022 Nav. Admin + ADR-023 Nav. Panel + ADR-024 Null Fix + ADR-025 Separación Master Admin + ADR-029 Auditoría Null Completa + ADR-030 Exportación Lista de Invitados + ADR-043 Fix Mobile Hero F11 v3.2.0 + ADR-044 Catálogo Sin Numeración + Registro Silo… [texto completo → TASKS-DETALLE.md](TASKS-DETALLE.md)
*   **Sprint Activo:** Sprint 1 — Monetización SaaS, Automatización y Conversión de Emergencia
*   **Última Actualización:** 30 de septiembre de 2026

--------------------------------------------------------------------------------

> **Este archivo es ahora el tablero.** Muestra solo tareas **abiertas** (una fila por tarea); el texto completo está en [TASKS-DETALLE.md](TASKS-DETALLE.md) (columna Detalle = líneas de ese archivo) y las cerradas en [TASKS-ARCHIVO.md](TASKS-ARCHIVO.md). Totales: **51 abiertas · 50 cerradas · 101 entradas**.

> **Totales al 2026-10-03 (linea agregada, sin reescribir la de arriba):** **57 abiertas · 50 cerradas · 107 entradas**. Los 6 items nuevos son del bloque "CANAL DE CORREOS" (TSK-101..TSK-106), nacidas del cierre documental del canal de correos. Las cifras de la linea anterior se conservan intactas por Cero Borrado documental (Oro #2/#3).
> **Totales tras la Fase 2A del canal de correos (2026-10-03, linea agregada):** **55 abiertas · 52 cerradas · 107 entradas**. Delta = **-2 abiertas / +2 cerradas**, sin entradas nuevas ni borradas: cierran **TSK-104** y **TSK-106**. Las lineas de totales anteriores se conservan intactas por Cero Borrado documental (Oro #2/#3).
> **Delta por ADR-079 (2026-10-07, linea agregada, sin reescribir las de arriba):** +1 entrada / +1 cerrada = **TSK-107** (Check-in multi-punto con override por ticket). No se agregan tareas abiertas: la deuda residual de ADR-079 queda registrada sin ID propio en `NEXT.md` y `DECISIONS.md` (ver cierre al final). Cifras absolutas de este corte NO recontadas en este cierre; se declaran como delta para no afirmar un total no verificado (ADR-006). Las lineas de totales anteriores se conservan intactas por Cero Borrado documental (Oro #2/#3).
> **Correccion aditiva (2026-10-07, misma fecha):** la deuda residual de ADR-079 **YA tiene ID**: **TSK-108..TSK-111** (bloque "DEUDA RESIDUAL ADR-079 — check-in multi-punto", 4 items). La linea anterior se conserva intacta (Cero Borrado); se corrige solo la afirmacion 'sin ID propio'. Deltas efectivos del corte: **+1 cerrada** (TSK-107) y **+4 abiertas** (TSK-108..TSK-111).

#### 🔴 ALTA PRIORIDAD / EN COLA INMEDIATA

| ID | Responsable | Título | Bloque | Detalle |
|---|---|---|---|---|
| [TSK-097](TASKS-DETALLE.md#tsk-097) | Direccion / Documentation Specialist (`@docs-keeper`) | DEUDA PENDIENTE: 6 skills fantasma sin archivo en disco | Consolidacion del roster a 20 agentes, retiro de la ruta… | L87-87 |
| [TSK-098](TASKS-DETALLE.md#tsk-098) | Direccion / Documentation Specialist (`@docs-keeper`) | DEUDA PENDIENTE: decidir si se comprime `AGENTS.md` | Consolidacion del roster a 20 agentes, retiro de la ruta… | L89-90 |
| [TSK-095](TASKS-DETALLE.md#tsk-095) | Direccion / Frontend (DEUDA PENDIENTE, no corregida por decision de… | replicar (o retirar) el fix de `openModInvitador` en `admin bacup.html` | Fix de runtime en `admin.html`: `ReferenceError:… | L93-94 |
| [TSK-083](TASKS-DETALLE.md#tsk-083) | Direccion (con soporte `@sql-security` - PRO: es `jsonb`/datos, no… | EJECUTAR la semilla `migrations/adr064_ticket_disenos.sql` en el Supabase SQL Editor | Diseno de ticket por tipo de asistente (`eventos.config_lan… | L97-97 |
| [TSK-084](TASKS-DETALLE.md#tsk-084) | Direccion | CONFIRMAR si el borrado de `imagenes/cabezote tropilove formulario.jpg.jpeg` es intencional | Diseno de ticket por tipo de asistente (`eventos.config_lan… | L99-99 |
| [TSK-085](TASKS-DETALLE.md#tsk-085) | Frontend (`@admin-dev-free`) | DEUDAS FUNCIONALES de la feature (no bloquean la semilla, etiqueta `[DEUDA-EXPRESS]`) | Diseno de ticket por tipo de asistente (`eventos.config_lan… | L101-101 |
| [TSK-088](TASKS-DETALLE.md#tsk-088) | Direccion (con soporte `@backend-dev` / `@sql-security` - PRO: es… | DEUDA PENDIENTE: adjuntar el ticket al correo | Diseno de ticket por tipo de asistente (`eventos.config_lan… | L103-103 |
*TRACE (2026-10-03, canal de correos, ADR-076 + cierre documental):* la deuda **quedo VERSIONADA en el repo** — `supabase/functions/send-ticket-email/index.ts` (760 lineas, 28.733 bytes, 0 bytes > 127) ahora existe como archivo; antes solo se invocaba por URL. El adjunto del ticket (`ticketUrl`) **ya esta implementado** dentro de la funcion: allowlist anti-SSRF de hosts (`TICKET_ALLOWED_HOSTS`), tope `MAX_TICKET_BYTES` (2 MB), `TICKET_FETCH_TIMEOUT_MS`, y **fail-open** (si el adjunto falla, se envia el correo sin adjunto y se registra el motivo; nunca rompe el envio). **PERO no esta aplicado ni desplegado**: 0 migraciones aplicadas, 0 deploys, working tree **SIN commit**. Y el endpoint **no puede activarse todavia**: desplegarlo sin migrar los 5 call sites los deja en 401 y el correo no se envia en ninguno de los 5 sitios (comportamiento previsto durante la transicion, no un fallo) — ver TSK-101 y TSK-103. Gate de `AGENTS.md` §2 (esquema/migraciones): **AUTORIZADO por el usuario el 2026-10-03** para aplicar las migraciones y desplegar la funcion; **en esta sesion NO se ejecuto nada** (el alcance fue solo cierre documental).
| [TSK-089](TASKS-DETALLE.md#tsk-089) | Direccion (con soporte `@frontend-tpl`/`@docs-keeper`) | COMMIT + PUSH + ADR de la frontera dura | Modulo Guest List (card de beneficio) en el silo F9B… | L106-107 |
| [TSK-081 (c)](TASKS-DETALLE.md#tsk-081-c) | Direccion (con soporte `@sql-security` - PRO, es seguridad/endpoint) | DEUDA ASOCIADA, ya representada por TSK-003: el envio de correo depende de la Edge Function `send-ticket-email`, que NO vive en este… | Formulario de entrega y recuperacion de QR en… | L110-110 |
*TRACE (2026-10-03, canal de correos, ADR-076 + cierre documental):* idem TSK-088 — la deuda **quedo VERSIONADA en el repo**: `supabase/functions/send-ticket-email/index.ts` (760 lineas) **ya no vive solo en produccion**, esta en el working tree **SIN commit**. Dato nuevo y critico: la funcion **ahora aplica su propia autenticacion dual** — header `X-Service-Token` (comparacion en tiempo casi constante contra `SERVICE_SHARED_TOKEN`, canal de BD via `pg_cron -> pg_net`) **o** header `Authorization: Bearer <JWT de sesion>` verificado por firma HMAC-SHA256 contra `SUPABASE_ANON_KEY`, exigiendo `exp` vigente, `sub` no vacio y rol distinto de `anon` y `service_role` (`BLOCKED_ROLES`); **la anon key NO se acepta** (si llega, 401). Sin ninguno de los dos: 401 y no se envia nada. **PERO no esta aplicada ni desplegada**, y el hallazgo critico de este cierre es que **los 5 call sites siguen mandando la anon key**, asi que en el estado actual el correo se perderia en los 5 sitios si se desplegara. Gate de `AGENTS.md` §2: **AUTORIZADO por el usuario el 2026-10-03** para migrar y desplegar; **en esta sesion NO se ejecuto nada** (alcance = solo cierre documental). Ver TSK-101/103/104.
| [TSK-080](TASKS-DETALLE.md#tsk-080) | Direccion (con soporte `@sql-security` — PRO, es esquema) | EJECUTAR `migrations/adr062_invitadores_multi_link.sql` en el Supabase SQL Editor ANTES de desplegar `admin.html` | Multi-link de invitador (N links por invitador) + routing… | L113-114 |
| [TSK-075](TASKS-DETALLE.md#tsk-075) | Frontend / `@js-silo-dev-free` (deuda NO BLOQUEANTE, hallazgo QA §8.1… | el gate de video ya usa token exacto (`evento-app.html:1467`), pero quedan otros gates del mismo silo con… | Silo F9B "Mistico Nocturno" — video banner full-bleed +… | L117-117 |
| [TSK-073](TASKS-DETALLE.md#tsk-073) | Chief Architect (decision de Direccion) + Documentation Specialist (`… | DECIDIR el nombre real del motor publico de eventos y corregir la gobernanza activa que cita `evento.html` | Gobernanza del roster y reconciliacion del nombre del motor… | L120-121 |
| [TSK-073](TASKS-DETALLE.md#tsk-073-2) | Chief Architect (decisiones de alcance y de roster) + `@js-silo-dev-f… | AMPLIACION (2026-09-28 — sigue PENDIENTE y es el UNICO dueno de la deuda): Que se absorbe aqui (por decision de Direccion, no por hallazgo nuevo): (a… | AMPLIACION de TSK-073 — DECISION DE DIRECCION (2026-09-28):… | L124-148 |
| [TSK-060](TASKS-DETALLE.md#tsk-060) | Direccion / Lead Developer (PENDIENTE — no ejecutable por la IA; ADR-… | Ejecutar `migrations/adr051_fase_landing.sql` en Supabase SQL Editor (pendiente de Direccion) — la columna… | Fase PROXIMAMENTE del landing (ADR-051) — Pendientes de… | L151-151 |
| [TSK-061](TASKS-DETALLE.md#tsk-061) | QA / @qa-auditor (verificacion end-to-end; ADR-051) | Verificacion end-to-end de la fase PROXIMAMENTE: activar `fase_landing='proximamente'` en un evento con fecha… | Fase PROXIMAMENTE del landing (ADR-051) — Pendientes de… | L153-154 |
| [TSK-044](TASKS-DETALLE.md#tsk-044) | QA / @qa-auditor (post-commit + D1, T6 smoke) — TEXTO REESCRITO 2026-… | smoke de produccion sobre el evento `kande-musica-tradicional-del-caribe-colombiano-kk4c` con silo f12 | Silo F12 "Kande" (Tropical Noir Brutalista) + Registro del… | L157-157 |
| [TSK-045](TASKS-DETALLE.md#tsk-045) | Direccion / Lead Developer (D1 + D2, Supabase) | (D1) editar el evento `kande-musica-tradicional-del-caribe-colombiano-kk4c` y asignarle la plantilla "Kande"… | Silo F12 "Kande" (Tropical Noir Brutalista) + Registro del… | L159-159 |
| [TSK-046](TASKS-DETALLE.md#tsk-046) | Direccion / Creative Director (assets v1.1.0) | construir y subir a Supabase Storage `assets/templates/f12/` los 4 assets del contrato: `f12-hero-bg.v1.webp`… | Silo F12 "Kande" (Tropical Noir Brutalista) + Registro del… | L161-161 |
| [TSK-047](TASKS-DETALLE.md#tsk-047) | Chief Architect / ADR futuro | barra de navegacion superior del diseno de referencia de Kande — NO implementada porque exigiria un atomo… | Silo F12 "Kande" (Tropical Noir Brutalista) + Registro del… | L163-163 |
| [TSK-048](TASKS-DETALLE.md#tsk-048) | Tooling / @free-build | `@media-reader-free` roto — su frontmatter declara `opencode/mimo-v2.5-free`, que YA NO EXISTE en el catalogo… | Silo F12 "Kande" (Tropical Noir Brutalista) + Registro del… | L165-165 |
| [TSK-049](TASKS-DETALLE.md#tsk-049) | Documentation Specialist (residual del hub v1.4.0) | `TEMPLATES.md` Paso 8 describia 3 puntos de registro y `onclick="seleccionarTheme(...)"`; el real son 6… | Silo F12 "Kande" (Tropical Noir Brutalista) + Registro del… | L167-168 |
| [TSK-051](TASKS-DETALLE.md#tsk-051) | D1 | Meta data-driven (kernel + Supabase): extender el kernel `evento-app.html` (~L817, gate `__esF9Meta`) para habilitar… | Silo F12 "Kande" — Ciclo visual CSS-only v1.3.0 -> v1.9.0 (… | L171-171 |
| [TSK-053](TASKS-DETALLE.md#tsk-053) | D3 | Textos fijos del hero/CTA a datos: "KANDE", subtitulo de la cinta, contenido de la meta y "COMPRAR ENTRADAS" estan… | Silo F12 "Kande" — Ciclo visual CSS-only v1.3.0 -> v1.9.0 (… | L173-173 |
| [TSK-054](TASKS-DETALLE.md#tsk-054) | D4 | Assets del silo f12: `--f12-asset-papel` = `url("")` (vacio) y revision del contrato `assets/templates/f12/` (… | Silo F12 "Kande" — Ciclo visual CSS-only v1.3.0 -> v1.9.0 (… | L175-175 |
| [TSK-055](TASKS-DETALLE.md#tsk-055) | D5 | Deudas heredadas del silo f12: namespacing `ld-mod-historia-fiesta` (el Wizard de Fiesta no puede expresar… | Silo F12 "Kande" — Ciclo visual CSS-only v1.3.0 -> v1.9.0 (… | L177-177 |
| [TSK-056](TASKS-DETALLE.md#tsk-056) | D6 | Verificacion visual pendiente (mobile): el overlay mobile de f12 usa margenes negativos (`-50svh` + `calc` con guard `max(0px,...… | Silo F12 "Kande" — Ciclo visual CSS-only v1.3.0 -> v1.9.0 (… | L179-180 |
| [TSK-063](TASKS-DETALLE.md#tsk-063) | Frontend / @frontend-tpl (PRO — ruta de pago: toca el hero del evento… | Corregir el `min-height:100vh/100svh` del hero de f12 en movil para alinearlo con la norma documentada (72svh… | Silo F12 "Kande" — Ajuste del HERO en MOVIL, ciclo express… | L183-184 |
| [TSK-070](TASKS-DETALLE.md#tsk-070) | Direccion + `@sql-security` (PRO — pendiente, `service_role`) | ejecutar la semilla de prueba `migrations/seed_f9b_mistico_nocturno_prueba.sql` (246 lineas, idempotente, por… | Silo F9B "Mistico Nocturno" — paquete ADR-054 / ADR-055 /… | L187-187 |
| [TSK-071](TASKS-DETALLE.md#tsk-071) | Chief Architect + `@frontend-tpl` (PRO — correccion global, decision… | resolver la convencion capital-T con regresion de 7 silos | Silo F9B "Mistico Nocturno" — paquete ADR-054 / ADR-055 /… | L189-189 |
| [TSK-072](TASKS-DETALLE.md#tsk-072) | Quality (deudas registradas del paquete f9b, NO bloquean) | (P0) `hideForeignModulesByType` en cine — recibe `tipo='cinematografia'` (`_THEME_TYPE[theme]`) pero su `map`… | Silo F9B "Mistico Nocturno" — paquete ADR-054 / ADR-055 /… | L191-192 |
| [TSK-025](TASKS-DETALLE.md#tsk-025) | Dirección / Lead Developer | Ejecutar `migrations/adr025_master_admin_separation.sql` contra la instancia real de Supabase — columna… | Separación Master Admin / Barrio R10 (ADR-025) — Pendientes… | L195-195 |
| [TSK-026](TASKS-DETALLE.md#tsk-026) | Chief Architect (⚠️ hallazgo de auditoría, prioridad alta, fuera del… | Revisar y retirar las políticas RLS legacy permisivas detectadas en `eventos` (`"Admins escriben eventos"`,… | Separación Master Admin / Barrio R10 (ADR-025) — Pendientes… | L197-197 |
| [TSK-028](TASKS-DETALLE.md#tsk-028) | Chief Architect (⚠️ riesgo preexistente detectado en TSK-027, fuera… | `generarInforme()` (~L7900 de `admin.html`, ítem "Informe gráfico (PDF)" del `#export-menu`) consulta… | Separación Master Admin / Barrio R10 (ADR-025) — Pendientes… | L199-200 |
| [TSK-035](TASKS-DETALLE.md#tsk-035) | Dirección / Lead Developer (PENDIENTE — no ejecutable por la IA) | Ejecutar manualmente `migrations/adr040_config_global_templates.sql` en Supabase (SQL Editor) + Prueba de… | Cuenta Master / Catálogo de Plantillas (ADR-040) —… | L203-204 |
| [TSK-016](TASKS-DETALLE.md#tsk-016) | Lead Developer | Modificar `evento.html` para leer la nueva columna `captura_pura`: si es `true`, omitir la generación/render… | Wizard Inteligente (ADR-021) — Pendientes de cierre | L207-207 |
| [TSK-017](TASKS-DETALLE.md#tsk-017) | Chief Architect (⚠️ prioridad alta, verificar primero) | Reconciliar la contradicción entre `BLUEPRINT.md` §1 (declara `evento3.html` como "El Cerebro") y el link… | Wizard Inteligente (ADR-021) — Pendientes de cierre | L209-209 |
| [TSK-018](TASKS-DETALLE.md#tsk-018) | Lead Developer | Ejecutar `migrations/adr021_eventos_columns.sql` (idempotente) contra la instancia real de Supabase para… | Wizard Inteligente (ADR-021) — Pendientes de cierre | L211-212 |
| [TSK-003](TASKS-DETALLE.md#tsk-003) | Lead Developer (Gemini) | Configurar pg_cron para envío automático de recordatorios 24h antes del evento vía send-ticket-email | Wizard Inteligente (ADR-021) — Pendientes de cierre | L214-215 |
*TRACE (2026-10-03, canal de correos, ADR-073 + ADR-074 + cierre documental):* la parte de **`pg_cron` sigue SIN implementarse** — no hay cron, ni trigger de envio, ni llamada automatica; eso es lo que queda abierto (TSK-103/TSK-104). Lo que si cambio: **las 2 piezas que lo bloqueaban estan ESCRITAS y revisadas** (no validadas contra la base de datos real). (1) `eventos.evento_inicio timestamptz` en `migrations/adr073_eventos_evento_inicio.sql` (415 lineas): **instante calculable** derivado de `eventos.fecha`/`eventos.hora` (que son TEXT sin zona horaria, por eso "el recordatorio sale 56 h antes" no era respondible), con backfill fail-closed que acepta 2 formatos por regex y deja `NULL` + reporte DUDOSA en cualquier otro caso. (2) `config_recordatorios` en `migrations/adr074_config_recordatorios.sql` (452 lineas): **la ventana vive en datos** — default global **56 h** (decision de negocio) + override por evento, con el especifico ganando. **Ninguna de las 2 esta aplicada en la base de datos**, y ADR-074 **requiere ADR-073 aplicada antes** (sin instante canonico no hay "ahora + N - ventana"). Gate de `AGENTS.md` §2 (esquema): **AUTORIZADO por el usuario el 2026-10-03** para aplicar las 3 migraciones; **en esta sesion NO se aplico ninguna** (alcance = solo cierre documental). Nota: el valor del titulo ("24h") ya **no coincide** con el default vigente (56 h, ADR-074); la linea original se conserva intacta por Cero Borrado.
*TRACE (2026-10-03, ADR-078 — cierre por cron de recordatorios):* **TSK-003 QUEDA CERRADA.** La parte de `pg_cron` **SI se implemento y se aplico**: `CREATE EXTENSION pg_cron` (version **1.6.4**; `pg_net` ya 0.20.0), funcion `public.fn_enviar_recordatorios_pendientes()` (SECURITY DEFINER, ejecutable solo por `service_role`), y job `recordatorios-horarios` con schedule **`5 * * * *`** ACTIVE y verificado en `cron.job`. Dry-run: `{"eventos":0,"enviados":0,"omitidos":0,"errores":0}`. Correccion ADR-006: el lugar del evento se toma de **`eventos.ubicacion`** (`eventos.lugar` NO existe -> error `42703`). Commit **`f3863fb`** (migracion `migrations/adr078_cron_recordatorios.sql` + ADR-078 + fila en `DECISIONS.md:92`). El TRACE del 2026-10-03 anterior (bajo la misma linea) queda **SUPERADO**: describia `pg_cron` como "SIN implementar" (estado previo a la aplicacion).
| [TSK-010](TASKS-DETALLE.md#tsk-010) | Lead Developer | Verificar y crear columnas en tabla `inscritos` (whatsapp, tipo_ayuda, autorizacion) | Blindaje Campaña b5 (Emergencia) | L218-219 |
| [TSK-012](TASKS-DETALLE.md#tsk-012) | Chief Architect | Implementar ADR-012 en `DECISIONS.md` para documentar la extensión del Contrato v110 | Blindaje Campaña b5 (Emergencia) | L221-222 |

#### 🟡 PRIORIDAD MEDIA

| ID | Responsable | Título | Bloque | Detalle |
|---|---|---|---|---|
| [TSK-031](TASKS-DETALLE.md#tsk-031) | Chief Architect (deuda técnica aceptada — hallazgos H-3/H-4 de la… | (H-3) El FAQ de ejemplo de F9 está hardcodeado para CUALQUIER evento `tpl-f9` sin FAQ configurado, no solo… | Refinamiento y UX | L228-228 |
| [TSK-006](TASKS-DETALLE.md#tsk-006) | Creative Director | Configurar manifest.json y Service Worker para hacer el scanner instalable (PWA) | Refinamiento y UX | L230-230 |
| [TSK-013](TASKS-DETALLE.md#tsk-013) | Creative AI | Desarrollar el módulo aditivo "08 Actualizaciones" y el desglose de tarjetas para la sección Historia de b5 | Refinamiento y UX | L232-232 |
| [TSK-014](TASKS-DETALLE.md#tsk-014) | Documentation | Sincronizar permanentemente PROJECT.md y BLUEPRINT.md bajo el estándar v127-MASTER | Refinamiento y UX | L234-234 |
| [TSK-039](TASKS-DETALLE.md#tsk-039) | Direccion / Lead Developer (deuda MENOR + decision futura derivada de… | (1) `#ld-form-redirect` usa `type="url"` sin normalizacion de esquema — normalizar (prefijar `https://` si… | Contratos de Configuracion Wizard/Landing (ADR-047) —… | L237-238 |
| [TSK-099](TASKS-DETALLE.md#tsk-099) | Lead Developer (ADM) + Chief Architect (ADR) + Documentation Specialist (`@docs-keeper`) | ✅ **COMPLETADA (2026-10-02)** — Permitir invocar los 16 subagentes desde `free-plan`/`free-build` sin cambiar de tier | Gobernanza de tier (ADR-069 + ADR-071) | **Alcance REAL ejecutado (ADR-006):** (1) allow-list de `permission.task` ampliada de **7 a 16** subagentes en `.opencode/agent/free-build.md` y `free-plan.md` (`"*": deny` + 16 `allow`), config commiteada en `5cd53a0` (base `b4b4beb`); (2) los **9 dominios de riesgo** (`sql-security`, `data-migration`, `backend-dev`, `renderer-dev`, `admin-dev`, `architect`, `architect-review`, `seo-dev`, `research-agent`) son invocables en FREE pero **conservan el gate de confirmacion explicita** de `AGENTS.md` §2 — permitir invocar ≠ autorizar ejecutar; (3) ADR-071 creado en `decisiones/ADR-071-allow-list-ampliada-a-los-16-subagentes-en-ruta-free.md` + fila de indice en `DECISIONS.md:86` (working tree, SIN commit); (4) ADR-069 lleva puntero `[enmendado por ADR-071, 2026-10-02]` y su decision original se conserva INTACTA (Cero Borrado); (5) **watchdog recalibrado** por decision de Direccion: subagente = tope blando **18 turnos** con corte al 70% (~turno 12) devolviendo `STATUS: partial`; **25 turnos = tope DURO del ORQUESTADOR** (no del subagente); 50.000 tokens/turno se mantiene — reflejado en `anti-absorcion`, `eficiencia-recursos` y `cascada-tier` L50; (6) `scripts/session_close.js` ahora expone `--budget [N]` y `--umbral N` (reporte por subagente: turnos, % sobre el umbral y veredicto OK/EXCEDIDO, mismo estilo de alertas de su seccion 3) y la seccion "Estimado vs real" ya reporta Tokens/Turnos; (7) `scripts/smoke_qa_asserts.js` NUEVO -> **Resumen: PASS 49, FAIL 0**. **Sesion 14:00-hoy (medicion):** 7 sesiones, 161 turnos, 7.106.060 tokens, 37.675 cache_read/turno; subagentes **5 OK / 1 EXCEDIDO** (`js-silo-dev` 21 turnos = 117%, devolvio `partial` en vez de agotarse). Diagnostico previo que motiva el punto (5): de 22 subagentes del dia, **14 excedieron 18 turnos y 10 pasaron el tope duro de 25**; peor caso `docs-keeper` con 45 turnos (250%). **Ver nota completa y cierre al final del documento.** |

#### 🟠 CANAL DE CORREOS — cierre documental 2026-10-03 (ADR-073 + ADR-074 + ADR-076) — 6 items NUEVOS

> Estos 6 items nacen del cierre documental del 2026-10-03. **Ninguno es ejecutable por este cierre**: ese fue documental. Detalle y TRACEs de estado al final del archivo ("Cierre documental del canal de correos").

| ID | Responsable | Título | Bloque | Detalle |
|---|---|---|---|---|
| [TSK-101](#tsk-101) | `@admin-dev` + `@js-silo-dev` (sesion PAGO; gate §2 aplicado) | **Migrar los 5 call sites** al camino unico (RPC, ADR-077) — **5/5 HECHO (lote completo `serie` + `eventobackup` + `admin` + `registro` + `registroaforo`)** | Canal de correos (ADR-076/077) | ver seccion de cierre al final |
| [TSK-102](#tsk-102) | `@backend-dev` (estrategia **RESUELTA Y APLICADA** por ADR-077) | **`registroaforo.html` publico sin sesion** — resuelto por gateway A (RPC sin credencial del llamador), **IMPLEMENTADO** (early-return email null conservado) | Canal de correos (ADR-076/077) | ver seccion de cierre al final |
| [TSK-103](#tsk-103) | Direccion (operacion) | **Ejecutar el despliegue en 3 pasos** de `send-ticket-email` — **B6 HECHO: v6 ACTIVE (`--no-verify-jwt`); auth HTTP verificada** | Canal de correos (ADR-076/077) | ver seccion de cierre al final |
| [TSK-104](#tsk-104) | Direccion (con soporte `@sql-security` / `@data-migration` — PRO: es esquema) | ✅ **CERRADA 2026-10-03 (Fase 2A COMPLETA)** — **Aplicar las 3 migraciones**: dry-run + orden ADR-073 -> ADR-074 -> ADR-076 | Canal de correos (ADR-073/074/076) | ver seccion de cierre al final |
| [TSK-105](#tsk-105) | Direccion + `@sql-security` (**iteracion D1**) | **Recorte del `SELECT *` anonimo en `inscritos` — NO se puede hacer antes de migrar los call sites** | Canal de correos (ADR-076) | ver seccion de cierre al final |
| [TSK-106](#tsk-106) | Direccion + `@sql-security` (correccion de **comentarios**, no de logica) | ✅ **CERRADA 2026-10-03 (Fase 2A)** — **La auto-afirmacion ASCII de `adr076_enviar_email_seguro.sql` es falsa: 11 bytes > 127 en 3 lineas de comentario** (CORREGIDA) | Canal de correos (ADR-076) | ver seccion de cierre al final |

#### 🟠 DEUDA RESIDUAL ADR-079 — check-in multi-punto (4 items NUEVOS, 2026-10-07)

> Items nacidos del cierre de ADR-079 (R1-R4). Estado: **PENDIENTES**. No bloquean la feature (ya en `main`). Detalle en `DECISIONS.md` ADR-079 y `NEXT.md` hito -44.

| ID | Responsable | Título | Bloque | Detalle |
|---|---|---|---|---|
| [TSK-108](#tsk-108) | Direccion + `@sql-security` (PRO — es seguridad/RLS) | **R1** — Verificar en vivo la RLS anonima de `logs` con las columnas nuevas (`evento_id`/`inscrito_id`) | Check-in multi-punto (ADR-079) | pendiente |
| [TSK-109](#tsk-109) | Direccion + `@data-migration` (PRO — es esquema/backfill) | **R2** — `logs.evento_id` sin backfill en **22/66** filas (sin match exacto por nombre); `inscrito_id` historico **100% NULL** | Check-in multi-punto (ADR-079) | pendiente |
| [TSK-110](#tsk-110) | Direccion / Producto (decision de alcance) | **R3** — Decidir si el override se expone en los registros publicos (`registroaforo.html`, `evento-app.html`); hoy no, por diseno | Check-in multi-punto (ADR-079) | pendiente |
| [TSK-111](#tsk-111) | Frontend (`@admin-dev` / `@frontend-tpl`) | **R4** — `openPuntosInscrito` muestra la union base+override; distinguir herencia vs. propio | Check-in multi-punto (ADR-079) | pendiente |

#### 🟢 BACKLOG / LARGO PLAZO

| ID | Responsable | Título | Bloque | Detalle |
|---|---|---|---|---|
| [TSK-001](TASKS-DETALLE.md#tsk-001) | Lead Developer (Gemini) | Implementar widget de pago de Wompi en registro.html y en la sección de renovación/suscripción | Infraestructura SaaS (Bloqueante) | L244-244 |
| [TSK-002](TASKS-DETALLE.md#tsk-002) | Lead Developer (Gemini) | Crear la Edge Function wompi-webhook en Supabase para validar la firma HMAC y activar organizaciones.activa =… | Infraestructura SaaS (Bloqueante) | L246-247 |
| [TSK-004](TASKS-DETALLE.md#tsk-004) | Lead Developer | Construir la lógica de lista de espera (lista_espera table) para eventos con aforo completo | Infraestructura SaaS (Bloqueante) | L249-249 |
| [TSK-007](TASKS-DETALLE.md#tsk-007) | Chief Architect | Refactorizar admin.html para carga perezosa (lazy load) de módulos pesados (~214KB) | Infraestructura SaaS (Bloqueante) | L251-251 |
| [TSK-008](TASKS-DETALLE.md#tsk-008) | Lead Developer | Integración de cobro Wompi directo en evento.html para entradas de pago | Infraestructura SaaS (Bloqueante) | L253-253 |
| [TSK-009](TASKS-DETALLE.md#tsk-009) | QA / Chief Architect | Generación e integración de tickets digitales para Apple Wallet (.pkpass) y Google Wallet | Infraestructura SaaS (Bloqueante) | L255-256 |

Cerradas (50): TSK-096, TSK-090, TSK-091, TSK-092, TSK-093, TSK-094, TSK-082, TSK-086, TSK-087, TSK-081 (a), TSK-081 (b), TSK-081, TSK-079, TSK-078, TSK-074, TSK-076, TSK-077, TSK-043, TSK-050, TSK-052, TSK-062, TSK-064, TSK-065, TSK-066, TSK-067, TSK-069, TSK-068, TSK-057, TSK-058, TSK-059, TSK-024, TSK-030, TSK-034, TSK-029, TSK-032, TSK-033, TSK-005, TSK-015, TSK-019, TSK-020, TSK-021, TSK-022, TSK-023, TSK-027, TSK-036, TSK-037, TSK-038, TSK-040, TSK-041, TSK-042 → [TASKS-ARCHIVO.md](TASKS-ARCHIVO.md).

---

## TSK-099 — Habilitar los 16 subagentes en ruta FREE (nota de plan, 2026-10-02) — ✅ CERRADA, ver seccion de cierre al final

> **Estado: COMPLETADA (2026-10-02, ADR-071).** El texto de plan de esta seccion se conserva intacto como historial (Cero Borrado, Regla de Oro #3): describe el estado ANTES del cambio. El alcance REAL ejecutado y las cifras estan en la seccion "Cierre de TSK-099" al final del documento.

### Que hay que corregir

En `.opencode/agent/free-build.md` y `.opencode/agent/free-plan.md`, el bloque `permission.task` es IDENTICO y tiene esta forma:

```yaml
task:
  "*": deny
  docs-keeper: allow
  explore: allow
  js-silo-dev: allow
  frontend-tpl: allow
  content-loader: allow
  media-reader: allow
  qa-auditor: allow
```

Los 16 subagentes del roster son: `admin-dev`, `architect`, `architect-review`, `backend-dev`, `content-loader`, `data-migration`, `docs-keeper`, `explore`, `frontend-tpl`, `js-silo-dev`, `media-reader`, `qa-auditor`, `renderer-dev`, `research-agent`, `seo-dev`, `sql-security`. Faltan 9 en `allow`, asi que `"*": deny` los bloquea.

### Correccion propuesta (2 archivos, mismo cambio en ambos)

Agregar las 9 lineas al bloque `task:` de `free-build.md` y `free-plan.md`, de modo que la allow-list quede completa:

```yaml
task:
  "*": deny
  # 7 de bajo riesgo (invocables sin gate)
  docs-keeper: allow
  explore: allow
  js-silo-dev: allow
  frontend-tpl: allow
  content-loader: allow
  media-reader: allow
  qa-auditor: allow
  # 9 de riesgo: ahora invocables, pero el GATE de §2 sigue vigente
  admin-dev: allow
  architect: allow
  architect-review: allow
  backend-dev: allow
  data-migration: allow
  renderer-dev: allow
  research-agent: allow
  seo-dev: allow
  sql-security: allow
```

### Lo que NO hay que tocar (y por que)

1. **NO cambiar `model:` de los 16 subagentes.** ADR-069 (herencia) ya funciona: los subagentes omiten `model:` y heredan `big-pickle` desde FREE. El reporte de `usage_report.js` lo confirma: las 7 sesiones de la sesion del 2026-10-02 corrieron en `opencode/big-pickle` con `cost=0.000000`. Agregar `model:` explicito seria una regresion a la ruta hibrida que ADR-067 elimino.
2. **NO quitar `"*": deny`.** Es la red de seguridad: si mañana se agrega un subagente nuevo y no se autoriza aqui, lo negaria en silencio. El orden `"*": deny` primero + excepciones explicas es lo correcto.
3. **NO eliminar el gate de confirmacion de `AGENTS.md` §2.** Este cambio abre la *posibilidad tecnica* de invocar un dominio de riesgo desde FREE; el gate sigue siendo la regla que exige confirmacion explicita del usuario antes de ejecutar RLS/esquema, migraciones, el motor `evento-app.html` y arquitectura/ADR. Permitir invocar != autorizar ejecutar.
4. **NO cambiar `subagent_depth`.** Sigue en `1` en `opencode.json`; la sesion del 2026-10-02 produjo 7 subagentes de primer nivel sin problema.

### Actualizar en el mismo cambio (si no se hace, la gobernanza queda incoherentente)

- `AGENTS.md` §1 y §2: el texto actual dice "Allow-list FREE (ADR-069)" y lista 7 dominios; y `free-build.md`/`free-plan.md` dicen "los 7 subagentes de tu allow-list FREE" y "Esos 9 dominios NO estan en tu allow-list de `permission.task`". Con el cambio, esas 4 frases quedan falsas. Reemplazar por "los 16 subagentes son invocables; los 9 de riesgo exigen el gate de confirmacion de §2".
- `DECISIONS.md` + nuevo ADR: **superponer** ADR-069 y dejar el cambio trazable (no editar ADR-069 en silencio; un ADR aceptado se supersede, no se reescribe).
- Verificacion: `node scripts/express_check.js` (debe seguir en PASS 27/FAIL 0) + confirmar que `free-build.md` y `free-plan.md` quedaron con las mismas 16 lineas `allow`.

### Advertencia honesta: esto NO arregla los 3 subagentes agotados de la sesion del 2026-10-02

`qa-auditor`, `docs-keeper` y `js-silo-dev` NO fallaron por permiso: se invocaron, corrieron 21-31 turnos y devolvieron informe. Lo que fallo fue que agotaron su presupuesto de pasos antes de escribir su entrega (QA no escribio los asserts; docs-keeper no escribio ningun archivo). Ampliar la allow-list a 16 no cambia eso: el sintoma es el brief, no el permiso. Para los subagentes que deben EDITAR (no solo reportar), el brief tiene que traer `archivo:linea` verificados y un contrato de retorno compacto (Regla 12). Ver `errores/E25-stall-de-implementacion-en-un-subagente-el.md` y `errores/E24-guardian-que-falla-por-el-valor-correcto-el.md`.

### Cierre de TSK-099 (2026-10-02) — COMPLETADA, alcance real ejecutado

**Decision:** ADR-071 (Allow-list FREE ampliada a los 16 subagentes en ruta FREE), que **enmienda** ADR-069 sin reescribirlo (Cero Borrado documental: ADR-069 conserva su decision original y solo lleva el puntero `[enmendado por ADR-071, 2026-10-02]`).

**Alcance REAL ejecutado (verificado contra los archivos reales, ADR-006 — prevalece el archivo):**

1. **Allow-list FREE 7 -> 16:** `.opencode/agent/free-build.md` y `free-plan.md` llevan `permission.task` con `"*": deny` + las **16** lineas `allow` (mismo cambio en ambos archivos). Config commiteada en **`5cd53a0`** (base `b4b4beb`).
2. **Los 9 dominios de riesgo ahora son invocables en FREE pero conservan el gate de confirmacion explicita de `AGENTS.md` §2** (`sql-security`, `data-migration`, `backend-dev`, `renderer-dev`, `admin-dev`, `architect`, `architect-review`, `seo-dev`, `research-agent`). *Permitido por configuracion NO significa autorizado a ejecutar.* El gate, no la denegacion, es la mitigacion.
3. **ADR-071** creado: `Sistema QR desarrollo/decisiones/ADR-071-allow-list-ampliada-a-los-16-subagentes-en-ruta-free.md` (untracked) + fila de indice en `DECISIONS.md:86` (working tree, SIN commit).
4. **Watchdog recalibrado** por decision de Direccion: **subagente = tope blando 18 turnos** con corte al **70% (~turno 12)** devolviendo `STATUS: partial`; **25 turnos = tope DURO del ORQUESTADOR** (ya no del subagente); **50.000 tokens/turno se mantiene**. Reflejado en `anti-absorcion`, `eficiencia-recursos` y `cascada-tier` L50.
5. **Instrumentacion de cierre:** `scripts/session_close.js` ahora expone `--budget [N]` y `--umbral N` -> reporte por subagente con turnos, % sobre el umbral y veredicto **OK/EXCEDIDO** (mismo estilo de alertas de su seccion 3); la seccion "Estimado vs real" ya reporta **Tokens/Turnos**.
6. **`scripts/smoke_qa_asserts.js` NUEVO** -> **Resumen: PASS 49, FAIL 0**. Es el paso unico de certificacion propuesto para `@qa-auditor` en vez de asserts manuales.

**Metrica de la sesion 14:00-hoy (7 sesiones):** 161 turnos, **7.106.060 tokens**, 37.675 cache_read/turno. Desglose de subagentes: **5 OK / 1 EXCEDIDO** (`js-silo-dev` a 21 turnos = 117% del umbral, devolvio `partial` en vez de agotarse -> el corte al 70% funciono). Diagnostico previo que motiva la recalibracion: de **22 subagentes** del dia, **14 excedieron 18 turnos** y **10 pasaron el tope duro de 25**; peor caso **`docs-keeper` con 45 turnos (250%)**.

#### 📌 BASELINE ACTUAL DE `scripts/express_check.js` = **PASS 29 / FAIL 0**

**Regla de lectura para informes futuros (evita leer una regresion donde no la hay):** el baseline vigente es **PASS 29 / FAIL 0**. Antes de este ciclo era PASS 27 / FAIL 0. La diferencia es **esperada y NO es regresion**: el archivo nuevo `scripts/smoke_qa_asserts.js` entra al set por defecto de `express_check.js` y aporta **+2** asserts de sintaxis/ASCII. Si un informe futuro muestra **27**, corresponde a un baseline previo o a un estado del working tree anterior a `smoke_qa_asserts.js` — comparar contra la cifra del commit que se este revisando, nunca contra 27 como si fuera el valor vigente.

**Pendiente de commit (working tree):** ADR-071 + fila de `DECISIONS.md` + recalibracion en `anti-absorcion`/`eficiencia-recursos`/`cascada-tier` + `scripts/session_close.js` + `scripts/smoke_qa_asserts.js` + este cierre documental. Ver `NEXT.md` hito -37.

### Cierre de TSK-100 (2026-10-02) — DECIDIDA, alcance real ejecutado (migracion ESCRITA y NO APLICADA)

**Decision:** ADR-072 (Atribucion del link de invitador en la telemetria del landing). `page_events` solo guardaba `page_ref` (HTTP Referer = ruido de red), nunca el codigo de invitador: no habia forma de saber cuantas personas llegaban por cada link ni cuantas se perdian antes de registrarse.

**Alcance REAL ejecutado (verificado contra los archivos reales con `git diff --numstat`, ADR-006 — prevalece el archivo):**

1. **4 archivos modificados en el working tree, 201 lineas anadidas y 0 borradas** (`git diff --numstat`: `admin.html` +101 / -0, `evento-app.html` +18 / -0, `eventovenezuela.html` +21 / -0, `registroaforo.html` +61 / -0).
2. **1 archivo nuevo:** `migrations/adr072_page_events_ref_invitador.sql`, **257 lineas**, 100% ASCII, idempotente al 100%, con bloque de verificacion comentado para Direccion y bloque de ROLLBACK documentado al final. Tres objetos: columna `ref_codigo text NOT NULL DEFAULT ''` en `page_events` (agregada al FINAL, de 15 a 16 columnas, metadata-only en PostgreSQL 17), indice PARCIAL `idx_page_events_org_ref_created (org_id, ref_codigo, created_at DESC) WHERE ref_codigo <> ''`, y vista `v_landing_invitadores` con `WITH (security_invoker = true)` + `GRANT SELECT TO authenticated` que expone `pageviews`, `visitantes_unicos`, `eventos`, `primera_visita`, `ultima_visita` agrupados por `org_id, evento_slug, ref_codigo`.
3. **`page_ref` NO se toco** (no se renombra ni se borra; Cero Borrado) y **`page_events` sigue con EXACTAMENTE 2 politicas RLS**: este ciclo no creo RPC, ni triggers, ni politicas, ni tablas, y no modifico ninguna de las 4 vistas de ADR-050. `admin.html` lee la vista con `.eq('org_id', ORG_ID)` (`admin.html:9321`), misma mitigacion a nivel de consulta que las 4 vistas previas.
4. **`migrations/adr072_page_events_ref_invitador.sql` esta ESCRITA pero NO APLICADA en produccion.** La aplica Direccion en el Supabase SQL Editor (gate de riesgo de `AGENTS.md` §2). El bloque de rankeo del panel debe seguir mostrando el empty state hasta entonces.
5. **Orden de despliegue obligatorio: (1) aplicar la migracion, (2) desplegar el front.** Al reves, los 3 motores siguen mandando el INSERT sin la columna `ref_codigo` y ese INSERT **falla en silencio** (fire-and-forget): no se registra ninguna llegada y no hay error visible.
6. **Deuda registrada `[DEUDA-EXPRESS]`:** `registroaforo.html` usa claves de sesion/visitante propias (`ht_reg_analytics_*`) mientras los silos usan `ht_analytics_*`, de modo que una misma persona que llega por link de invitador al landing y luego salta al formulario cuenta como **2 visitantes distintos** en `v_landing_invitadores`. No se unifico en este pase; queda para una sesion futura con su propio ADR.

**Deuda que NO se toco (deliberado):** trafico historico por `ref` **irrecuperable** (las filas previas quedan en `ref_codigo = ''` y no se pueden atribuir sin inventar dato; la vista los excluye y el indice es parcial sobre ese mismo predicado), y el riesgo de tenancy ya conocido: `page_events_auth_read` sigue con `USING true` (barrido TSK-026) y la vista nueva, al ser `security_invoker`, **hereda esa exposicion** sin mitigacion propia.

### Cierre documental del canal de correos (2026-10-03) — ADR-073 + ADR-074 + ADR-076

> Las lineas originales de TSK-088, TSK-081 (c) y TSK-003 se conservan INTACTAS (Cero Borrado, Oro #2/#3); su estado de hoy esta en los 3 TRACE con fecha 2026-10-03 insertados bajo cada una. Esta seccion fija el alcance real del cierre: **0 ejecuciones**.

#### TSK-101 a TSK-106 — detalle

1. **TSK-101 — migrar los 5 call sites** a JWT de sesion (`session.access_token`) o `X-Service-Token` desde `pg_net`. Los 5 siguen con la anon key y hay **0 ocurrencias de `access_token`** en esas rutas: `admin.html:8153` (anon key **hardcodeada** dentro del `Bearer` en `enviarQREmail`), `registro.html:678` (key definida en `:451`), `registroaforo.html:1010` (`:329`), `serie.html:994` (`:344`), `eventobackup.html:4449` (`:3484`).
2. **TSK-102 — `registroaforo.html` no tiene sesion.** Es el formulario **publico**: con la arquitectura decidida hoy ("JWT de sesion donde exista") su envio de correo **sigue sin poder autenticarse** y `enviarNotificacionesReg()` permanece el no-op de siempre (`emailAddr` siempre `null` en `:726` y `:860`; `:1006` hace `if (!emailAddr) return;`). **SIN DECIDIR**: la salida sobre el papel es la RPC `enviar_email_registro` de ADR-076, que no recibe credencial del llamador.
3. **TSK-103 — despliegue en 3 pasos:** (1) `supabase functions deploy send-ticket-email --no-verify-jwt`, (2) migrar los call sites, (3) `supabase functions deploy send-ticket-email`.
4. **TSK-104 — aplicar las 3 migraciones** desde el SQL Editor con `service_role`, con dry-run y en orden **ADR-073 -> ADR-074 -> ADR-076** (ADR-074 requiere ADR-073 aplicada). **CERRADA 2026-10-03 (Fase 2A):** aplicadas y verificadas las 3, en ese orden. Detalle en la seccion "Cierre de TSK-104 y TSK-106 (Fase 2A)" al final de este archivo.
5. **TSK-105 (D1) — recorte del `select *` anonimo.** **No puede hacerse antes de migrar los call sites**: quitarlo sin migrar `registroaforo.html:908`, `eventobackup.html:3635` y `scanner.html:394` deja el formulario de registro caido. Nota de revision de este cierre: existe un **cuarto** `select *` en `scanner.html:803` (por `.eq('qr_code', code)`) que no figura en la lista del ADR-076; D1 debe incluirlo o dejar por escrito que queda excluido.
6. **TSK-106 — auto-afirmacion ASCII falsa en ADR-076:** el archivo declaraba 0 bytes > 127 "incluidos los comentarios" y tenia **11 bytes > 127 en 3 lineas de comentario** (`:549`, `:557`, `:1100`). Solo afectaba comentarios, no la ejecucion del SQL. **CERRADA 2026-10-03 (Fase 2A):** los 3 comentarios fueron corregidos y el archivo real hoy da **0 bytes > 127**; la afirmacion del header es ahora **VERDADERA**. El mismo pase de ASCII-safety llevo `adr074_config_recordatorios.sql` de 21.256 a 24.991 bytes y `adr076_enviar_email_seguro.sql` de 70.428 a 71.173 bytes, ambos con **0 bytes > 127** y dollar-quotes balanceadas.

#### Lo que se escribio (4 artefactos, SIN commit, SIN aplicar, SIN desplegar)

1. `supabase/functions/send-ticket-email/index.ts` — 760 lineas, 28.733 bytes, 0 bytes > 127. Versiona la Edge Function que antes solo se invocaba por URL. Dual autenticacion (`X-Service-Token` en tiempo casi constante, o JWT de sesion con firma HMAC-SHA256 y `BLOCKED_ROLES`); anti-injection, allowlist anti-SSRF de `ticketUrl`, `MAX_TICKET_BYTES` (2 MB), `TICKET_FETCH_TIMEOUT_MS`, CORS con `ALLOWED_ORIGINS` (nunca `*` si la variable esta definida), idempotencia en memoria con TTL, adjunto **fail-open**, respuestas `{ ok, id?, error? }` sin stack traces ni claves.
2. `migrations/adr073_eventos_evento_inicio.sql` — 415 lineas, 0 bytes > 127. Columna calculable `eventos.evento_inicio timestamptz`, backfill fail-closed con 2 formatos por regex, `NULL` + DUDOSA en cualquier otro caso, zona `America/Bogota`, sin reescribir `fecha`/`hora`, sin borrar filas, sin tocar RLS.
3. `migrations/adr074_config_recordatorios.sql` — 452 lineas, 0 bytes > 127. `config_recordatorios` de dos niveles (el especifico gana), default global **56 h** (decision de negocio), CHECK de horas `> 0 AND <= 720`, CHECK de `canal` limitado a `email`, indice unico parcial + `INSERT` global con `WHERE NOT EXISTS` + resolucion determinista (por el detalle de PostgreSQL de que en un UNIQUE los NULL no chocan entre si), 100% idempotente, RLS activa sin politicas (fail-closed). **NO crea cron, ni trigger de envio, ni Edge Function.**
4. `migrations/adr076_enviar_email_seguro.sql` — 1.494 lineas (el mas grande). Cierra 2 hallazgos: (a) 5 HTML hacen POST a la funcion con la **anon key embebida**, credencial PUBLICA = relay de correo autenticado desde el dominio del proyecto; (b) `select *` anonimo sobre `inscritos` devolviendo nombre, cedula, telefono, email, `qr_code` y `used` de TODOS los asistentes. Resuelve todo aditivo: `public.email_envios_log` (cola + traza con llave unica de idempotencia, le dice al cron futuro a quien ya se aviso), RPC `enviar_email_registro(...)` SECURITY DEFINER que **NO recibe credencial del llamador** (secreto del operador en Supabase Vault / `app.settings.*`; si no existe, **falla CERRADO con excepcion**), y RPC `obtener_inscrito_por_cedula(...)` SECURITY DEFINER que reemplaza el `SELECT *` (campos minimos, exige `(cedula, evento_id)`, nunca el email de terceros, `telefono` solo si el llamador lo aporta). **Deliberadamente NO hace:** no cambia ninguna politica RLS existente, no toca los `SELECT` de `registroaforo.html:908` / `eventobackup.html:3635` / `scanner.html:394` (quitar el `select *` sin migrarlos deja el formulario caido: es D1), no aplica el `REVOKE SELECT` por columnas de ADR-068, y **no aplica** `adr068_inscritos_unique_cedula_evento.sql`, que sigue escrito y sin aplicar.

#### Decisiones del usuario (2026-10-03)

(a) Tier de la sesion **FREE** (`opencode/big-pickle`). (b) **Gate de `AGENTS.md` §2 AUTORIZADO** para aplicar las 3 migraciones y desplegar la Edge Function, pero el alcance elegido fue SOLO cierre documental, asi que **nada se ejecuto**. (c) Arquitectura del canal: **"JWT de sesion donde exista"**, con la consecuencia de TSK-102. Las 3 migraciones estan **escritas y revisadas**, **no validadas contra la base de datos real**.

#### Verificacion de cierre (por script, 0 tokens de agente)

`node scripts/express_check.js` -> **PASS 29 / FAIL 0**; `node scripts/smoke_qa_asserts.js` -> **PASS 49 / FAIL 0**; `git diff --numstat` de los 4 archivos de docs -> **solo `+N/-0`**. Las 3 rutas de migracion siguen **sin aplicar** y la funcion **sin desplegar**. Detalle en `NEXT.md` hito -39 y en `errores/TRACE-bitacora.md` (TRACE del 2026-10-03).

### Cierre de TSK-104 y TSK-106 — FASE 2A DEL CANAL DE CORREOS (2026-10-03) — COMPLETA

> Seccion **agregada** (nada de lo anterior se reescribe, Cero Borrado Oro #2/#3). Alcance real ejecutado: **aplicacion de 3 migraciones en la base de datos + correccion de ASCII en 2 de ellas + documental**. **0 deploys de la Edge Function**, **0 cambios en los 5 call sites**, **0 commit**. Ruta **FREE** (`opencode/big-pickle`). Gate de `AGENTS.md` §2 (esquema): AUTORIZADO por Direccion el 2026-10-03.

#### TSK-104 — APLICADA. Las 3 migraciones aplicadas y verificadas (2026-10-03)

1. **Prerrequisito:** extension **`pg_net` instalada, version 0.20.0**. Sin ella no hay envio HTTP desde SQL y la RPC de ADR-076 cae en `estado=error` con `motivo=pg_net_no_disponible`.
2. **Orden real ejecutado:** **ADR-073 -> ADR-074 -> ADR-076** (la dependencia dura se respeta: ADR-074 usa `eventos.evento_inicio`, que crea ADR-073). Las 3 quedaron **aplicadas y verificadas una por una** (su bloque de VERIFICACION comentado se ejecuto y dio lo esperado).
3. **Fallo real encontrado y corregido durante la aplicacion (ADR-074):** el dry-run fallo con **`42804: foreign key constraint "config_recordatorios_evento_id_fkey" cannot be implemented`** porque la columna se declaro `uuid` y **`eventos.id` es `text`** en produccion. La causa no es la COINCIDENCIA de nombres sino la **COINCIDENCIA de tipos**. Correccion aplicada en el archivo: `config_recordatorios.evento_id` paso a **`text UNIQUE`** (`:86`) y el BLOQUE 3 de la FK ahora **compara los dos tipos en el catalogo ANTES de tocar nada** (`v_tipo_config` / `v_tipo_eventos`), con `WARNING` explicito si no coinciden y sin FK cuando `eventos` no tiene PK/UNIQUE sobre `id` (`:143-216`). El resolver quedo alineado: **`public.fn_horas_recordatorio(p_evento_id text)`** (`:352`).
4. **Fallo real encontrado y corregido durante la aplicacion (ADR-076):** las firmas de las 2 RPC no coincidian con los tipos reales. Correccion aplicada: **`enviar_email_registro` paso de 12 a 13 parametros** y quedo alineada como **`text` x12 + `boolean`** (firma `:731-745`); **`obtener_inscrito_por_cedula` quedo como `text` x3** (firma `:1137-1141`). Los `uuid` que quedan en el cuerpo son **solo** `v_log` y `v_prev` (`v_req` es `bigint`, porque es el `pg_net_request_id`). Los `COMMENT ON FUNCTION`, los `REVOKE`/`GRANT` y el bloque de VERIFICACION se actualizaron a las firmas nuevas (`:1074`, `:1234`, `:1266-1295`, `:1390-1499`).
5. **Verificacion post-aplicacion (favorable):** las 3 migraciones quedaron aplicadas y **sin efectos colaterales** — 0 filas borradas, 0 politicas RLS existentes modificadas, 0 politicas nuevas sobre tablas existentes, 0 vistas materializadas y 0 funciones preexistentes alteradas. `eventos.fecha`/`hora` intactas (ADR-073 solo anade `evento_inicio`); `config_recordatorios` con RLS activa y **0 politicas** (fail-closed, por decision de ADR-074); `email_envios_log` con RLS activa y permisos de tabla restringidos a `service_role`.
6. **Smoke de las RPC ejecutado DENTRO de un `ROLLBACK` — por diseno no persiste nada.** Resultado = comportamiento esperado: (a) `enviar_email_registro` **falla CERRADO** sin secreto del operador en Vault ni en `app.settings`; (b) la **validacion de email** rechaza formatos invalidos; (c) `obtener_inscrito_por_cedula` de una cedula inexistente devuelve **`no_encontrado`** sin filtrar datos; (d) la **idempotencia y el encolado via `pg_net` no persisten** al terminar el smoke, porque el `ROLLBACK` deshizo la traza. **Consecuencia honesta: el smoke prueba la LOGICA, no el ENVIO de correo.** Nadie ha visto todavia un correo salir por esta ruta. >> **SUPERADO 2026-10-03 (ver "Cierre documental 2026-10-03 - remitente + cron"): SI salio un correo real por Resend (id `01a103e4-b89e-73c8-b2f0-0d818f80d7c2`); resta el smoke end-to-end por RPC -> Function -> Resend (B9).**

#### TSK-106 — CERRADA. ASCII-safety real y verificada

7. Los **3 comentarios no-ASCII** de `adr076_enviar_email_seguro.sql` fueron corregidos. El archivo real hoy: **0 bytes > 127**, verificado byte a byte. **La auto-afirmacion del header (`:65-66`) ahora es VERDADERA**, que era exactamente lo que la tarea pedia cerrar.
8. **Cifras reales de los 3 archivos verificadas hoy contra el disco (ADR-006 — prevalece el archivo), que DESAFASAN las cifras de la seccion de cierre documental anterior:**

| Archivo | Lineas | Bytes | Bytes > 127 | Nota |
|---|---|---|---|---|
| `migrations/adr073_eventos_evento_inicio.sql` | 415 | 18.581 | **0** | sin cambios en la Fase 2A |
| `migrations/adr074_config_recordatorios.sql` | **515** (antes 452) | **24.991** (antes 21.256) | **0** | `evento_id text` + guard de tipos + 63 lineas nuevas |
| `migrations/adr076_enviar_email_seguro.sql` | **1.504** (antes 1.494) | **71.173** (antes 70.428) | **0** | firmas alineadas + 3 comentarios purificados |

9. **Dollar-quotes balanceadas** en los 3 archivos (verificado por conteo de delimitadores). En `adr076` el delimitador real es `$fn$` (10 ocurrencias, balanceadas); el unico `$$` del archivo esta **dentro de un comentario** (`:59`), no abre ningun cuerpo SQL.

#### Lo que NO se hizo en la Fase 2A (deliberado)

10. **La Edge Function NO se desplego** (0 deploys). La ruta de correo por `send-ticket-email` sigue como estaba: la funcion existe **en el repo** pero **no en el gateway**.
11. **Los 5 call sites NO se migraron** (0 cambios de HTML): `admin.html:8153`, `registro.html:678`, `registroaforo.html:1010`, `serie.html:994`, `eventobackup.html:4449` siguen mandando la anon key. **TSK-101 abierta.**
12. **El secreto del operador NO se configuro** (`send_ticket_email_service_token` en Supabase Vault / `app.settings.service_token`): sin el, la RPC falla cerrado por diseno. **Sin Vault el smoke lo demostro.**
13. **No se toco ninguna politica RLS existente** y **no se aplico** `adr068_inscritos_unique_cedula_evento.sql` (sigue escrita y sin aplicar). El recorte del `SELECT *` anonimo sigue siendo la iteracion **D1 / TSK-105**, bloqueada por TSK-101.
14. **Ninguna afirmacion de esta seccion es una afirmacion de correo entregado.** La Fase 2A abre la posibilidad, no la entrega.

#### Cierre verificado y que sigue

15. **Verificacion de cierre (por script, 0 tokens de agente):** `git diff --stat` de los 4 archivos de docs -> **solo `+N/-0`** (Cero Borrado documental intacto). Los 3 `.sql` **NO se editaron en este cierre documental** (los 2 que aparecen con `M` en `git status` traian los cambios de la sesion de aplicacion, ya aplicados). Conteo de bytes > 127 y de lineas re-hecho **contra el disco**, no copiado de otro documento.
16. **Que sigue = FASE 2B (pendiente, ver `NEXT.md` hito -40):** `supabase functions deploy send-ticket-email --no-verify-jwt` -> migrar los 5 call sites al **JWT de sesion** (`session.access_token`) o `X-Service-Token` -> `supabase functions deploy send-ticket-email`. Ademas: decidir TSK-102 (`registroaforo.html` es publico y no tiene sesion; salida sobre el papel = la RPC de ADR-076), configurar el secreto del operador, y **documentar `ADR-075`**, que hoy es un **hueco de numeracion declarado y sin asignar** (no rellenarlo por completitud).

### Cierre de FASE 2B — gateway unico de correo (2026-10-03) — EJECUTADA Y VERIFICADA (lote completo)

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Tier **PAGO**. Commit `5ca58d8` ("canal de correos fase 2b", 13 archivos). Baseline = archivo real (ADR-006): los 5 call sites re-verificados contra el disco, cada uno con `rpc('enviar_email_registro')` y **0** ocurrencias de `send-ticket-email` (la unica restante es `admin bacup.html:4774`, backup). Este bloque **actualiza el estado**: lo antes marcado "DIFERIDO/PENDIENTE" (B5/B6) quedo **HECHO**; se conserva el historial de la entrada previa mas abajo.

#### HECHOS VERIFICADOS — B5, B6 y lote B10

1. **B5 HECHO:** secreto `send_ticket_email_service_token` creado en Supabase Vault; verificado `public.fn_adr076_secreto('send_ticket_email_service_token') is not null = true`.
2. **B6 HECHO:** Edge Function `send-ticket-email` re-desplegada desde el repo con `--no-verify-jwt`; ahora **VERSION 6 ACTIVE** (antes v4). Auth verificada por HTTP: sin token -> **401**; token correcto + body invalido -> **400**; token incorrecto -> **401** (sin relay abierto). Secret `SERVICE_SHARED_TOKEN` creado en Edge Functions con **el mismo valor** que el Vault.
3. **B10 HECHO (lote completo, orden `eventobackup`->`admin`->`registro`->`registroaforo`, tras el piloto `serie.html`):** los **5 call sites** migrados a RPC. En cada archivo: `send-ticket-email` = **0**, `rpc('enviar_email_registro')` = **1**, `node --check` OK, balance de `<div>` identico a HEAD, Cero Borrado, sin `Authorization` con anon key. **Escudo GOLD PASS 6/6.** `registro.html` usa `p_tipo='bienvenida'`; `registroaforo.html` conserva el **early-return** (email `null`) para no cambiar comportamiento.
4. **Smoke parcial:** RPC alcanzable via PostgREST con `anon`; email invalido -> **`22023`** (sin envio). Falta smoke de **envio real** (requiere destinatario de prueba) -> **B9 PENDIENTE**.

#### PENDIENTES / HALLAZGOS (2B)

5. **D1 (TSK-105):** recorte del `select *` anonimo en `inscritos`, **sigue pendiente**.
6. **Gap `p_tipo`:** `admin.html` **no mapea** la fila "Tipo" de ticket a `p_tipo` (se pierde en 2B).
7. **`p_inscrito_id` va NULL** en todos los call sites (los INSERT no hacen `.select('id')`).
8. **`admin bacup.html:4774`** conserva la **anon key hardcodeada** en el `Bearer` (limpieza pendiente).
9. **Hallazgo `MAIL_FROM`:** la Function lee `env("MAIL_FROM")` (`index.ts:660`), pero el secret existente se llama **`FROM_EMAIL`** (valor de 64 chars, no es email). Se usa el remitente por defecto **`Hostal Terraza <no-reply@hostalterraza.com>`** (verificar dominio verificado en Resend).
10. **`ADR-075` sigue NO asignado** (hueco); **`ADR-077` existe**.
11. **Seguridad:** rotar el **PAT de Supabase** usado en la sesion.

---

### Cierre documental de FASE 2B — gateway unico de correo (2026-10-03) — PILOTO HECHO, LOTE PENDIENTE (historial)

> Entrada **conservada intacta** por Cero Borrado (Oro #2/#3): describe el estado ANTES de ejecutar B5/B6 y el lote. El estado REAL ejecutado y verificado esta en el bloque superior. Tier **PAGO**. En este cierre **no se toco codigo**: la migracion B3 (`serie.html`) es de la sesion de implementacion. Baseline = archivo real (ADR-006).

#### B1 — Hallazgo ADR-006: la firma del brief NO existe

1. La descripcion de parametros del brief de FASE 2B (`p_email_dest`, `p_apellidos`, `p_tipo_ticket`, `p_cantidad`, `p_qr_url`, `p_origen_ip`) **NO EXISTE en el repo**. La **firma real** es `migrations/adr076_enviar_email_seguro.sql:731-745`: `p_email, p_nombre, p_qr_code, p_evento_nombre, p_evento_fecha, p_evento_hora, p_evento_lugar, p_idempotency_key, p_tipo DEFAULT 'registro', p_cedula DEFAULT NULL, p_evento_id DEFAULT NULL, p_inscrito_id DEFAULT NULL, p_bypass_rate_limit boolean DEFAULT false` (**text x12 + boolean**). Re-verificado contra el disco en este cierre.
2. **Cifra desfasada (ADR-006):** el documento previo citaba `send-ticket-email/index.ts` = 760 lineas / 28.733 bytes; el archivo real hoy es **775 lineas / 29.689 bytes** (versionado/tracked; `git status` limpio para ese path). Prevalece el archivo.

#### B4 — ADR-077 (decision gateway A)

3. `@architect-review` emitio la DECISION **gateway A**: la RPC `enviar_email_registro` es el **camino unico** desde el cliente; la Edge Function deja de ser gateway de cliente y pasa a **transporte server-to-server** (invocada por la RPC con `X-Service-Token`). Escrito en `decisiones/ADR-077-gateway-de-correo-de-los-5-call-sites-rpc-como-camino-unico.md` + fila de indice en `DECISIONS.md:91`.
4. **Coherencia de indice/numeracion (verificada):** `ADR-077` existe (`decisiones/ADR-077*`, untracked al cierre); **`ADR-075` sigue NO asignado** (0 archivos `decisiones/ADR-075*`, 0 `migrations/adr075*`). Nota de numeracion en `DECISIONS.md:95-97` coherente.

#### B3 — PILOTO HECHO (1/5): `serie.html`

5. `enviarNotificacionesSerie` (`serie.html:985`) migrada de `fetch` con anon key a `SB.rpc('enviar_email_registro', {...})` (`:994-1006`, `p_tipo='registro'`, `p_idempotency_key='serie-registro:'+qr`). **Verificado 5/5 + Escudo GOLD 5/5 PASS.** La anon key deja de ser credencial de envio en ese sitio.

#### LOTE PENDIENTE — 4 call sites + limpieza (HISTORIAL: ya ejecutado, ver bloque superior)

6. `admin.html:8153` (`enviarQREmail`, anon key hardcodeada en el `Bearer`), `registro.html:678` (**bienvenida**; migrara con `p_tipo='bienvenida'`, best-effort), `registroaforo.html:1009` (publico sin sesion, **TSK-102**), `eventobackup.html:4449`. **HECHO en 2B (B10): los 5 migrados a RPC.**
7. `admin bacup.html:4779` trae la **anon key hardcodeada** en el `Bearer` (la URL en `:4774`); **limpieza PENDIENTE**. Nota: el cierre FASE 2A citaba `registroaforo.html:1010`; el archivo real dice `:1009` (ADR-006).

#### Bloqueador operativo y TSK-102 (HISTORIAL: resueltos)

8. **B5** (secreto Vault `send_ticket_email_service_token`) y **B6** (deploy Edge Function) quedaron **DIFERIDOS a Direccion** = **BLOQUEADOR OPERATIVO**. Sin secreto, la RPC **falla cerrado**. >> **RESUELTOS en 2B: B5 y B6 HECHOS (v6 ACTIVE, auth HTTP verificada).**
9. **TSK-102** (`registroaforo.html` publico sin sesion): **estrategia RESUELTA** por el gateway A (la RPC no necesita credencial del llamador; rate limit 3/cedula+evento/10 min + 10/IP/h + idempotencia), **IMPLEMENTADA en 2B** conservando el early-return.
10. **Decisiones de producto confirmadas por Direccion:** la fila "Tipo" de `admin.html` es **prescindible en 2B** (gap `p_ticket_tipo` futuro); el correo de bienvenida de `registro.html` va por RPC con `p_tipo='bienvenida'` (best-effort).

### Cierre documental FASE 2B — nota de actualizacion (2026-10-03)

> **Totales (linea agregada):** las cifras anteriores se conservan. `TSK-101` pasa a **5/5 HECHO**; `TSK-102` implementada; `TSK-103` (B6) HECHO. Nuevos pendientes de 2B sin ID propio: smoke de envio real (**B9**), gap `p_tipo`, `p_inscrito_id` NULL, `MAIL_FROM`/`FROM_EMAIL`, limpieza de anon key en `admin bacup.html`, rotacion del PAT. `D1`/`TSK-105` sigue abierta. Commit `5ca58d8`.

---

### Cierre documental 2026-10-03 — remitente + cron (commits f3863fb/bbf3f33)

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Tier **PAGO**. Commits **`bbf3f33`** ("Update index.ts") y **`f3863fb`** ("recordatorios automaticos y remitente verificado"). Baseline = archivo real (ADR-006).

#### HECHOS (remitente verificado)

1. **Remitente de correo MIGRADO y VERIFICADO:** `MAIL_FROM = Taquilla Directa <no-reply@tickets.taquilladirecta.com>`. DNS en Vercel: **MX** `send.tickets` -> `feedback-smtp.sa-east-1.amazonses.com` (10); **TXT SPF** `v=spf1 include:amazonses.com ~all`; **TXT DKIM** `resend._domainkey.tickets`; **TXT DMARC** `_dmarc.tickets` = `v=DMARC1; p=none; rua=mailto:dmarc@taquilladirecta.com`. **Dominio verificado en Resend.**
2. **`RESEND_API_KEY` anterior era un DIGEST invalido** (no el valor real); reemplazada por la key real. Se **ENVIO un correo REAL** a `brsk84@gmail.com` (**id Resend `01a103e4-b89e-73c8-b2f0-0d818f80d7c2`**), **entregado OK**. **Esto INVALIDA** la afirmacion de hitos -41/-42 "nadie ha visto salir un correo" (ver `NEXT.md` hito -43, correccion (b)).
3. **`supabase/functions/send-ticket-email/index.ts` actualizado:** fallback/Default de remitente ahora `Taquilla Directa <no-reply@tickets.taquilladirecta.com>` (**L28** comentario, **L660** `from: env("MAIL_FROM") || "..."`). Re-desplegada.

#### HECHOS (cron de recordatorios — ADR-078)

4. **ADR-078 APLICADO:** `CREATE EXTENSION pg_cron` (**1.6.4**) + `public.fn_enviar_recordatorios_pendientes()` (SECURITY DEFINER, solo `service_role`) + job **`recordatorios-horarios`** schedule **`5 * * * *`** **ACTIVE**. Dry-run: `{"eventos":0,"enviados":0,"omitidos":0,"errores":0}`. **CORRECCION (ADR-006):** el lugar viene de **`eventos.ubicacion`** (`eventos.lugar` NO existe -> error `42703`). Commit `f3863fb` = migracion `migrations/adr078_cron_recordatorios.sql` + ADR-078 + fila en `DECISIONS.md:92`.
5. **TSK-003 CERRADA por ADR-078** (ver TRACE bajo TSK-003 en este archivo).

#### PENDIENTES QUE SIGUEN ABIERTOS (NO cerrados)

6. **B9:** smoke de envio REAL por el flujo **RPC -> Function -> Resend** (falta un evento de prueba a ~56 h).
7. **TSK-105/D1** (recorte del `SELECT *` anonimo); **gap `p_tipo`** admin; **`p_inscrito_id` NULL**; **anon key en `admin bacup.html:4779`**; **rotacion del PAT de Supabase**; **`FROM_EMAIL` obsoleto** (no borrado, Cero Borrado; decision pendiente de Direccion).
8. **Seguridad:** rotar el **PAT de Supabase** usado en la sesion.

#### Hallazgos/correcciones (ver `ERRORES_HISTORICOS.md` E30)

9. Los hallazgos A-E del 2026-10-03 (digest vs valor en `supabase secrets list`, mismatch `MAIL_FROM`/`FROM_EMAIL`, `eventos.lugar` inexistente, `supabase db query --linked` requiere link, credenciales en claro fuera del repo) quedan registrados como **E30** en `ERRORES_HISTORICOS.md`.

#### Verificacion de cierre

10. `git log` confirma `f3863fb` y `bbf3f33`; `Select-String` de `MAIL_FROM`/remitente en `supabase/functions/send-ticket-email/index.ts` (L28/L660); **ADR-078 en `DECISIONS.md:92` = 1** con estado `APLICADO Y VERIFICADO`; TSK-003 con TRACE. `nadie ha visto salir un correo` en `NEXT.md` queda marcado como **SUPERADO**.

---

### Cierre de TSK-107 — Check-in multi-punto con override por ticket (ADR-079) (2026-10-07) — COMPLETADA

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Feature **implementada, mergeada y pusheada en `main`**. Baseline = archivo real (ADR-006): migracion, scripts y codigo re-verificados contra el disco en este cierre.

#### Que se hizo (alcance REAL ejecutado)

1. **Override por ticket (pieza central):** columna nueva `inscritos.puntos_acceso` (jsonb). `NULL` o `[]` = el ticket **hereda** `eventos.puntos_acceso`; un array no vacio lo **sobreescribe**. Regla efectiva en `scanner.html:846-860`: `allowed = (Array.isArray(override) && override.length > 0) ? override : (Array.isArray(base) ? base : [])`. El multi-punto basico previo (`eventos.puntos_acceso` jsonb + `scanner_tokens.punto_acceso` + `logs.punto_acceso`) se conserva; el mismo QR seguia siendo valido en cada punto distinto del evento.
2. **Trazabilidad de `logs`:** columnas nuevas `logs.evento_id` y `logs.inscrito_id` (text, FK **ON DELETE SET NULL** a `eventos(id)` e `inscritos(id)`). Antes `logs` solo guardaba el NOMBRE (`logs.evento`, text) y no tenia relacion con el inscrito.
3. **Migracion `migrations/adr079_multi_punto_override.sql` APLICADA a produccion** (Supabase `ctgyvydzshueemlelkzv`) por `@data-migration`, gate de `AGENTS.md` §2 autorizado (2026-10-07). Archivo real: **260 lineas / 12.700 bytes / 0 bytes > 127**. Incluye indice `idx_logs_qr_punto (qr_code, punto_acceso)` y backfill de `logs.evento_id` por match de nombre **exacto y no ambiguo** (**44/66** filas); `inscrito_id` **no** backfilleable (**0/18**).
4. **Bugs corregidos en el mismo ciclo:** `scanQR` seleccionaba columna inexistente (dedup offline filtraba `logs.evento` = nombre y daba 0); undo por punto (no por resultado, `scanner.html:1082`); backticks en la plantilla de `undo-btn`; `logsCache` obsoleto (ahora poblado en `cargarCache:399-404`); dedup offline por `evento_id`; `denyEntry` ahora pobla ids (`scanner.html:1119`); `_crearSerie` propaga `puntos_acceso` (`admin.html:7852`).
5. **UI admin:** editor rapido de puntos del evento post-creacion (`#mod-puntos-ev`, `admin.html:2607`), selector de puntos permitidos en el registro manual, editor por inscrito (`openPuntosInscrito`, `admin.html:6753`; boton "Puntos", `:9903`) y badge de puntos en la tarjeta.
6. **Smoke de regresion:** `scripts/smoke_checkin_multipunto.js` (268 lineas) -> **PASS 27 / FAIL 0** (ejecutado en este cierre; analisis estatico sin red).

#### Decision y artefactos

7. **ADR-079** creado: `Sistema QR desarrollo/decisiones/ADR-079-checkin-multi-punto-con-override-por-ticket.md` (ASCII-safe, 0 bytes > 127) + fila de indice en `DECISIONS.md` (bajo ADR-078).
8. **Commits en `main`:** `a1a1fe1` (multi-punto configurable y fixes de escaneo), `e7be4ea` (migracion adr079), `13efe7c` (override por ticket y trazabilidad), `eee3fec` (dedup offline por evento_id, denyEntry, union en editor), `7468ed6` (smoke de regresion + UX de herencia). Feature **mergeada y pusheada**.

#### Deuda residual registrada (hoy con ID: **TSK-108..TSK-111**; ver ADR-079 y `NEXT.md` hito -44)

9. **(R1)** La RLS anonima de `logs` con las columnas nuevas **NO se verifico en vivo**.
10. **(R2)** `logs.evento_id` **no backfilleable en 22/66 filas** (sin match exacto por nombre); `inscrito_id` historico **100% NULL**.
11. **(R3)** El override **no esta disponible** en los registros publicos (`registroaforo.html`, `evento-app.html`) — por diseno.
12. **(R4)** `openPuntosInscrito` muestra la **union base+override** (no perder puntos), pero oculta cual es herencia y cual es propio.

#### Verificacion de cierre (por archivo real, ADR-006)

13. `git log` confirma los 5 commits; `git show --stat` confirma `admin.html` y `scanner.html` en `a1a1fe1`/`13efe7c`/`eee3fec`/`7468ed6`, y `migrations/adr079_multi_punto_override.sql` en `e7be4ea`; `node scripts/smoke_checkin_multipunto.js` -> **PASS 27 / FAIL 0**; migracion re-contada contra el disco (**260 / 12.700 / 0 no-ASCII**). **Este cierre es documental: 0 cambios de codigo, 0 migraciones nuevas, 0 commits** (los hace el orquestador).


