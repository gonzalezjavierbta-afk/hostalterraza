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
> **Delta por ADR-080 (2026-10-07, linea agregada, sin reescribir las de arriba):** **+1 entrada / +1 cerrada = TSK-112** (Paleta de color de evento) y **+1 abierta = TSK-113** (Fase 2: consumo de los 4 slots derivados en los silos). Feature **implementada** en `admin.html` (Wizard, creacion + edicion) y verificada con Escudo GOLD (`node scripts/smoke_paleta_evento.js` -> **20 PASS / 0 FAIL**). Deuda tecnica declarada en ADR-080 (Decision 5). Cifras absolutas NO recontadas en este cierre (ADR-006): se declaran como delta. Las lineas de totales anteriores se conservan intactas por Cero Borrado documental (Oro #2/#3).
> **Delta por ADR-081 (2026-10-07, linea agregada, sin reescribir las de arriba):** **+1 entrada / +1 cerrada = TSK-114** (Puntos de escaneo por evento + autorizacion por punto). Feature **implementada** en `admin.html`/`scanner.html` y **migracion `adr081_puntos_none_semantica.sql` APLICADA** (121 inscritos, 0 con `[]`, no-op). Verificada: `node scripts/smoke_checkin_multipunto.js` -> **28 PASS / 0 FAIL**; `node scripts/smoke_puntos_adr081.js` -> **30 PASS / 0 FAIL**; `node scripts/express_check.js` -> **35 PASS / 0 FAIL**. Cifras absolutas NO recontadas en este cierre (ADR-006): se declaran como delta. Las lineas de totales anteriores se conservan intactas por Cero Borrado documental (Oro #2/#3).

> **Delta por rediseno del HERO del silo f14 (2026-11-01, linea agregada, sin reescribir las de arriba):** **+4 entradas = TSK-116 (cerrada) + TSK-117 / TSK-118 / TSK-119 (abiertas)**. Delta efectivo: **+1 cerrada / +3 abiertas**. TSK-116 (rediseno del HERO del evento `vinilos-inversos-c8yu`) nace y cierra en el mismo ciclo: **1 archivo, CSS-only** (`css/templates/fiesta/f14.css`, `git diff --numstat` = **+290 / -59**, 47.483 bytes, 0 bytes > 127, llaves 168/168), `node scripts/smoke_f14_vinilos.js` -> **PASS 38 / FAIL 0**. Cifras absolutas NO recontadas en este cierre (ADR-006): se declaran como delta. Las lineas de totales anteriores se conservan intactas por Cero Borrado documental (Oro #2/#3).

> **Delta por TSK-117 (2026-11-01, linea agregada, sin reescribir las de arriba):** **+1 cerrada = TSK-117** (contador del landing en zona horaria de Bogota + cleanup del `setInterval`) y **+3 deudas NUEVAS sin ID propio** (declaradas en el cierre de TSK-117 y en ADR-084). Delta efectivo del corte: **+1 cerrada / +3 abiertas**. TSK-117 es **motor compartido** (`evento-app.html`, 14 silos): `git diff --numstat` = **+86 / -19** y `scripts/smoke_countdown_tz.js` (NUEVO, 11.142 bytes); **0 cambios en CSS/JS/admin/API/SQL**. Verificado: `smoke_countdown_tz.js` -> **PASS 36 / FAIL 0**; sin regresion (`smoke_f14_vinilos` 38/0, `smoke_hero_contract` 64/0, `smoke_qa_asserts` 64/0); Escudo GOLD OK. Cifras absolutas NO recontadas en este cierre (ADR-006): se declaran como delta. Las lineas de totales anteriores se conservan intactas por Cero Borrado documental (Oro #2/#3).

> **Delta por boleteria de tarifa unica + PLAYLIST del silo f14 (2026-11-01, linea agregada, sin reescribir las de arriba):** **+2 entradas / +2 cerradas = TSK-122 (motor: ADR-087) + TSK-123 (silo f14 v1.2)**, ambas nacen y cierran en el mismo ciclo. Delta efectivo: **+2 cerradas / 0 abiertas**. TSK-122 toca el **motor compartido** (`evento-app.html`, segmento boleteria `:2575-2610`, v1.15.0 + `js/i18n.js` 3 tablas, clave nueva `landing.boletos_entrada_general`); TSK-123 es **CSS-only** (`css/templates/fiesta/f14.css`, v1.2 del silo). **Evento afectado:** `vinilos-inversos-c8yu` (`template_id='f14'`, theme `vinilos`). **Smokes:** `smoke_f14_vinilos` **38/38**, `smoke_qa_asserts` **70/70**, `smoke_hero_contract` **64/64**, `smoke_paleta_evento` **20/20** (0 FAIL). Queda **1 pendiente de verificacion en PRODUCCION** (alto del iframe del playlist en movil < 360 px), declarado en el cierre. Cifras absolutas NO recontadas en este cierre (ADR-006): se declaran como delta. Las lineas de totales anteriores se conservan intactas por Cero Borrado documental (Oro #2/#3).

> **Delta por reacomodo del layout del silo f14 v1.3 (2026-11-01, linea agregada, sin reescribir las de arriba):** **+0 entradas / +0 cerradas**. No nace un TSK nuevo: es un **addendum al cierre de TSK-123** (`css/templates/fiesta/f14.css` **v1.3**, CSS-only) y asi queda documentado al final de su seccion de cierre. `git show --numstat 0e46e51` -> `f14.css` **+104 / -2** y `scripts/smoke_f14_vinilos.js` **+10 / -2**; **0 cambios** en el kernel (`evento-app.html`), `admin.html`, `api/*.js`, SQL/RLS y los otros 13 silos. Smokes: `smoke_f14_vinilos` -> **PASS 59 / FAIL 0**. Cifras absolutas NO recontadas en este cierre (ADR-006): se declaran como delta. Las lineas de totales anteriores se conservan intactas por Cero Borrado documental (Oro #2/#3).

> **Delta por ajuste visual del silo f14 v1.4 (2026-11-01, linea agregada, sin reescribir las de arriba):** **+0 entradas / +0 cerradas**. Tampoco nace un TSK: es el **segundo addendum al cierre de TSK-123** (`css/templates/fiesta/f14.css` **v1.4**, CSS-only, commit `e3b99a3`), documentado al final de su seccion de cierre. Rotulo `#mod-playlist::before` compacto **solo** en `@media (min-width: 767px)` (`clamp(1.5rem, 2.4vw, 2.4rem)`, `letter-spacing: 0.08em`, `-webkit-text-stroke: 1px`) y caja del playlist al **100%** de su columna 50/50 (se anulan `max-width:1100px` / `margin:0 auto` heredados del wrapper del kernel; sombra del marco a **6px** en esa media). En movil (`< 767px`) el rotulo grande y los altos 400px / 352px quedan intactos; el reparto **sigue 50/50**. **0 cambios** en el kernel (`evento-app.html`), `admin.html`, `api/*.js`, SQL/RLS y los otros 13 silos. Smoke: `smoke_f14_vinilos` -> **PASS 61 / FAIL 0** (2 asserts nuevos). Cifras absolutas NO recontadas en este cierre (ADR-006): se declaran como delta. Las lineas de totales anteriores se conservan intactas por Cero Borrado documental (Oro #2/#3).

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
| [TSK-111](#tsk-111) | Frontend (`@admin-dev` / `@frontend-tpl`) | **R4** — `openPuntosInscrito` muestra la union base+override; distinguir herencia vs. propio | Check-in multi-punto (ADR-079) | resuelto (ADR-081, tri-state en `openPuntosInscrito`; ver cierre TSK-114) |

#### 🟠 DEUDA RESIDUAL ADR-080 — paleta de color de evento (1 item NUEVO, 2026-10-07)

> Item nacido del cierre de ADR-080. Estado: **PENDIENTE**. No bloquea la feature (el contrato y el render minimo de `accent` ya funcionan). Requiere un ADR de amendment para definir los bridges `--master-secondary/tertiary/surface/background` y su `--tpl-*`, mas la inyeccion en `evento-app.html` (Decision 5 de ADR-080). Detalle en `DECISIONS.md` ADR-080 y `NEXT.md` hito -45.

| ID | Responsable | Título | Bloque | Detalle |
|---|---|---|---|---|
| [TSK-113](#tsk-113) | Chief Architect + Frontend (`@architect` / `@admin-dev` / `@renderer-dev`) | **Fase 2 (opcional)** — consumir los 4 slots derivados (`secondary`/`tertiary`/`surface`/`background`) en los silos: hoy se persisten en el JSONB pero ningun CSS los lee (solo `accent` pinta via `--master-accent`) | Paleta de color de evento (ADR-080) | pendiente |

#### 🟠 REDISENO DEL HERO DEL SILO F14 + DEUDAS ABIERTAS (3 items NUEVOS, 2026-11-01)

> Items nacidos del rediseno del HERO del evento `vinilos-inversos-c8yu` (theme `vinilos`, `template_id='f14'`), implementado y verificado el 2026-11-01 (**TSK-116, cerrada**; ver seccion de cierre al final). **Ninguno de estos 3 se ejecuto en ese ciclo:** el alcance fue CSS-only sobre `f14.css` (0 cambios de HTML/JS, 0 migraciones).

| ID | Responsable | Título | Bloque | Detalle |
|---|---|---|---|---|
| [TSK-117](#tsk-117) | `@renderer-dev` + `@qa-auditor` (**PAGO obligatorio** + gate `AGENTS.md` §2: es el motor compartido `evento-app.html`) | **Contador con zona horaria real y `setInterval` con cleanup** — `parseSpanishDate()` (`evento-app.html:720-730`) construye `new Date("YYYY-MM-DDTHH:mm")` en la zona del DISPOSITIVO, no en `America/Bogota`; el `setInterval` (`:1424-1431`) nunca se limpia | Motor compartido (afecta a los 14 silos) | **CERRADA 2026-11-01** (ver cierre al final) |
| [TSK-118](#tsk-118) | Direccion (wizard del admin / Supabase; **sin codigo**) | **Datos del evento `vinilos-inversos-c8yu`** — (a) **sede ausente**: `eventos.ubicacion` = `"Kr 4 # 19-56"` y no existe columna de nombre de sede (campo vivo: `#ev-ubic`, `admin.html:896`; ver correccion ADR-006 en el cierre de TSK-116); (b) `config_landing.colors` conserva la paleta vieja f9 (`accent: #c9a84c`) con `template_id='f14'` (oxido `#E35925`); (c) `config_landing.content.subtitulo` = `"DRUMN AND BASS REGGAE HIP-HOP"` (typo "DRUMN", sin separadores; la maqueta dice `DRUM N BASS - REGGAE - HIP-HOP`) | Silo F14 "Vinilos Inversos" | **ALTA** — (a) **RESUELTO 2026-11-01**: `eventos.ubicacion` ya es `"Klandestino, Kr 4 # 19-56"` (verificado por REST). (b)(c) **BLOQUEADOS por diseno (2026-11-01)**: la anon key no puede hacer UPDATE sobre `eventos` (RLS: el PATCH devuelve 2xx pero con 0 filas afectadas, verificado leyendo el valor antes y despues) y `admin.html` escribe con la sesion del usuario (`SB.from('eventos').update(payload).eq('id', id)`). Se aplican **desde el admin, sin codigo**: (b) paleta -> `accent #E35925 / secondary #EA580C / surface #131313 / tertiary #DBC8A8 / background #0E0E0E` + `color_primario #E35925` (invariante ADR-080); (c) subtitulo -> `DRUM N BASS · REGGAE · HIP-HOP`. Nota: en f14 `--tpl-accent` solo esta declarado y no se consume, asi que (b) es higiene de datos sin efecto visual |
| [TSK-119](#tsk-119) | `@renderer-dev` (OPCIONAL — dominio de riesgo: es el formateador del motor, no el silo) | **`#meta-hora` en formato 12 h** — hoy muestra `20:00 HRS`; la maqueta pide `8:00 PM` | Silo F14 "Vinilos Inversos" | **CERRADA 2026-11-01** — `__hora12()` (v125) reutiliza `__horaA24`; `ev.hora='20:00'` -> `8:00 PM`; el texto libre legacy (ej. `11:56 AM / 7:34 AM`) cae al formato previo con `T('landing.hrs')`. `evento-app.html` +18/-1. Verificacion en el cierre de TSK-117 (seccion final) |
| [TSK-120](#tsk-120) | `@frontend-tpl` (**FREE**: CSS del silo, 0 runtime, 0 JS) + `@renderer-dev` (**gate §2 confirmado** para la fecha) | **Meta del hero en 2 columnas y titulo del evento sobre el line up** — la maqueta `referentes/hero.jpg` pide `[cal] 20 NOVIEMBRE / 8:00 PM  \|  [pin] KLANDESTINO / KRA 4 # 19-56` y el nombre del evento presidiendo la grilla de artistas de la seccion de abajo | Silo F14 "Vinilos Inversos" | **CERRADA 2026-11-01** — `f14.css` **+147/-18** (CSS-only) + `evento-app.html` **+6/-5** y `scripts/smoke_hero_contract.js` **+4/-4**: `__esMeta2Lineas()` agrega `'tpl-f14'` a la allowlist, asi que la fecha pasa de ISO (`2026-11-20`) a `VIERNES 20` / `NOVIEMBRE DE 2026`. Gate `AGENTS.md` §2 confirmado por el usuario el 2026-11-01 |
| [TSK-121](#tsk-121) | `@frontend-tpl` (**FREE**: CSS del silo, 0 runtime, 0 JS) | **Tipografia de cartel (condensada + contorno cafe), meta pegado al subtitulo y rotulo LINE UP con tagline** — la maqueta `referentes/hero.jpg` pide un titulo condensado muy pesado con borde cafe, y el meta debe subir hasta el subtitulo en 2 columnas (`NOVIEMBRE 20 / 8:00 P.M` \| `KLANDESTUNO BAR / KRA 4 # 19-54 (PISO 4)`); en `#mod-lineup` el rotulo pasa de `VINILOS INVERSOS` a `LINE UP` con el subtitulo `una noche para vibrar con los mejores sonidos` | Silo F14 "Vinilos Inversos" | **CERRADA 2026-11-01** — `f14.css` **+64/-28**, CSS-only. Stack condensado medido con sonda (Impact 368 px vs 'Arial Narrow' 551 px = fallback) y hero guiado por contenido (hueco subtitulo->meta 26 px desktop / 25 px movil). **Deuda declarada:** los textos del meta y del subtitulo son DATOS; el `PATCH` directo a Supabase fue rechazado por RLS (200 + `[]`), hay que aplicarlos en el admin |

#### 🟣 BOLETERIA DE TARIFA UNICA (MOTOR) + PLAYLIST DEL SILO F14 (2 items NUEVOS, 2026-11-01)

> Items del ciclo del 2026-11-01 sobre el evento `vinilos-inversos-c8yu` (theme `vinilos`, `template_id='f14'`). **TSK-122** es **motor compartido** (afecta a los 14 silos) y **TSK-123** es **CSS-only del silo**. Ambos nacen y cierran en el mismo ciclo; el alcance REAL ejecutado esta en la seccion de cierre al final del documento.

| ID | Responsable | Titulo | Bloque | Detalle |
|---|---|---|---|---|
| [TSK-122](#tsk-122) | `@renderer-dev` (**ruta de riesgo / gate `AGENTS.md` §2**: es el motor compartido `evento-app.html`) + `@js-silo-dev` (i18n) | **Regla general de boleteria de tarifa unica (ENTRADA GENERAL, ADR-087)** — la rama generica de `#mod-boletos` pintaba siempre 2 tarjetas (PREVENTA / TAQUILLA) y la que no tenia dato caia al relleno `POR DEFINIR`; con UNA tarifa real se pinta UNA tarjeta `ENTRADA GENERAL` | Motor compartido (afecta a los 14 silos) | **CERRADA 2026-11-01** — `evento-app.html` v1.15.0 `:2575-2610` + `js/i18n.js` (3 idiomas: `:230` ES / `:607` FR / `:984` EN). Verificacion y evidencia en la seccion de cierre al final |
| [TSK-123](#tsk-123) | `@frontend-tpl` (**FREE**: CSS del silo, 0 runtime, 0 JS) | **Modulo PLAYLIST encendido en f14 (v1.2 del silo)** — el kernel apaga todas las `section` por IoC (`section, header, footer { display:none }`) y f14 nunca encendia `#mod-playlist`, asi que el embed de Spotify (`content.playlist_url`) se inyectaba en el DOM pero invisible; ademas el `<iframe height="100%">` colapsaba porque el contenedor solo tenia `min-height` | Silo F14 "Vinilos Inversos" | **CERRADA 2026-11-01** — `css/templates/fiesta/f14.css` (CSS-only, v1.2). Verificacion y evidencia en la seccion de cierre al final |

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

---

### Cierre de TSK-112 - Paleta de color de evento (ADR-080) (2026-10-07) - COMPLETADA

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Feature **implementada** (Fases 0-I-II); alcance REAL verificado contra el archivo real (ADR-006). Este cierre es **documental: 0 cambios de codigo, 0 migraciones nuevas, 0 commits** (los hace el orquestador).

#### Que se hizo (alcance REAL ejecutado)

1. **Contrato de datos (ADR-080, Fase 0):** `eventos.config_landing.colors = { accent, secondary, tertiary, surface, background }` (5 slots nombrados, hex `#rrggbb`, se escriben SIEMPRE, nunca `null`; default canonico unico `#c9a84c`; **sin array `palette`**). **Invariante:** `eventos.color_primario === colors.accent` en todo guardado real. 0 DDL, 0 endpoints, 0 RLS; es una clave JSONB (patron ADR-064).
2. **`admin.html` (Wizard, SOLO Paso 1b):** 5 slots de color. `#ev-color`/`#ev-color-hex` **se conservan como Slot 1 (`accent`)**; los slots 2-5 son `#ev-color-2..5` + `-hex` (`admin.html:893-913`). Barra de **Combinaciones Sugeridas** + boton **"Aplicar sugerencia completa"** (`#ev-color-apply`, `:926`). Previews de paleta en vivo.
3. **Motor cromatico HSL puro (Vanilla JS):** `_evHexToHsl` (`:3940`), `_evHslToHex` (`:3961`), `_evGenerarSugerenciasHSL` (`:3981`) + `_evSetSlotColor`/`_evResetPaleta`/`_evRenderSugerencias`/`_evActualizarPreview`. **Se retira la dependencia TinyColor2** (CDN + `renderColorHarmony`): 0 referencias `tinycolor`/`TinyColor` en el archivo.
4. **Persistencia (`_buildConfigLanding`, `:4843-4849`):** las 5 claves se emiten en el literal de `cfg.colors` (si falta una se borra en silencio al re-guardar: overwrite total, clase BUG-016). **Invariante aplicado** en `guardarEventoWizard` (`:6620-6622`) y `_crearEventoUnico` (`:7933-7935`): `payload.color_primario = config_landing.colors.accent`.
5. **Round-trip en edicion:** `openEditMod` lee los 5 slots (`:5915`, fallback a `color_primario` y al default `#c9a84c`).
6. **Resets en 3 circuitos:** `_evResetPaleta('#c9a84c')` en `_limpiarWizardCompleto` (`:6172`), `_crearEventoUnico` (`:7946`) y `_crearSerie` (`:8046`).
7. **`evento-app.html` NO se toca:** `--master-accent` se sigue pintando desde `ev.color_primario` (`evento-app.html:1121`) con 0 cambios en el kernel publico (render minimo).

#### Verificacion (Escudo GOLD independiente `@qa-auditor`, ADR-006)

8. Balance de `<div>` de `admin.html` **diff = 3 = baseline preexistente** (delta de la feature = 0); **ASCII JS = 0 bytes > 127**; `<script>` inline compilan; **0 referencias tinycolor**.
9. **`scripts/smoke_paleta_evento.js` (NUEVO, 0 dependencias, invocacion MANUAL):** `node scripts/smoke_paleta_evento.js` -> **PASS 20 / FAIL 0**. Cubre literal de las 5 claves, invariante, round-trip `openEditMod`, los 3 resets (`_evResetPaleta` x3), HSL complementario `(h+180)%360`, round-trip identidad `#c9a84c` (maxDelta 0) y 5 sugerencias hex validas.

#### Deuda tecnica declarada (NO cerrada; ver TSK-113)

10. **(a)** Los 4 slots `secondary`/`tertiary`/`surface`/`background` **se persisten pero NO se consumen** en render: los silos solo conocen `--master-accent`. Cerrarlo exige amendment de ADR (bridges `--master-*` + `--tpl-*` + inyeccion en `evento-app.html`). **(b)** Las ramas tempranas de `_buildConfigLanding` (solo-formulario `:4794-4804`; sin-landing `:4784-4789`) **no emiten `colors`** — fuera de alcance. **(c)** `eventobackup.html` es consumidor **LEGACY excluido** (lee `colors.accent` como string; no se rompe).

#### Correccion ADR-006 (baseline = archivo real)

11. La implementacion **NO retiro `syncColor`** como planeaba el Anexo de ADR-080: la **conserva y la reescribe para 5 slots** (`function syncColor(hex, slot)`, `admin.html:11335`; 5 `oninput` en el HTML). No es un bug (TinyColor2 si se retiro), pero se registra para no afirmar un alcance no ejecutado.

---

### Cierre de TSK-114 - Puntos de escaneo por evento + autorizacion por punto (ADR-081) (2026-10-07) - COMPLETADA

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Feature **implementada** y **migracion DML aplicada en produccion**; alcance REAL verificado contra el archivo real (ADR-006). Este cierre documental **no introduce** cambios de codigo ni migraciones adicionales (los del feature ya estan en el working tree); los **commits los hace el orquestador**.

#### Que se hizo (alcance REAL ejecutado)

1. **Semantica nueva de `inscritos.puntos_acceso` (jsonb):** `NULL` = **hereda TODOS** los puntos del evento (dinamico); `[]` = **ninguno explicito** (el ticket no vale en ningun punto); array no vacio = **override** (solo esos nombres). Cierra el agujero de ADR-079 (autoautorizacion de puntos nuevos a quien heredaba y colapso de "ninguno" a "hereda"). El scanner pasa a decidir por **presencia de la clave** (`scanner.html:850`: `const hasOwn = Array.isArray(data.puntos_acceso);`, con `motivo` "esta entrada"/"este evento").
2. **Migracion `migrations/adr081_puntos_none_semantica.sql` APLICADA a produccion** (Supabase `ctgyvydzshueemlelkzv`) por `@data-migration`, gate de `AGENTS.md` §2 autorizado. `UPDATE ... SET puntos_acceso = NULL WHERE puntos_acceso = '[]'::jsonb`. **Resultado en produccion: 121 inscritos, 0 con `[]` (no-op), ejecutada OK.** Idempotente, 0 DDL, 0 endpoints, 0 RLS, sin DROP/DELETE/TRUNCATE.
3. **`admin.html` - vista "Puntos" (nueva):** tab `data-pnl-pill="puntos"` (`:1702`, `onclick="pnlGoTab('puntos');pnlPuntosRefrescar()"`) y bloque `data-pnl-tab="puntos"` (`:1949-1982`). Motor `_pp*`/`pnlPuntos*` (`:10332-10584`): seleccion de evento + punto, chips base, **seleccion masiva** (marcar/desmarcar el punto activo a N invitados) y **paginacion** (`_ppPage`/`_ppPageSize=50`). Estado tri-state por invitado via `_ppEstado` (`:10364`): Hereda / Ninguno / Override.
4. **`admin.html` - propagacion al editar los puntos del EVENTO:** `_puntosEventoCambiaron` (`:6933`) y `propagarPuntosEvento` (`:6941`) se invocan en `guardarPuntosEvento` (`:6992`) y en `guardarEventoWizard` (`:6692-6693`). Regla: herederos (`NULL`) no se tocan; override no vacio `O` -> `O INTERSECT N` por NOMBRE (interseccion vacia -> `[]`, no `NULL`); `[]` no se toca. Best-effort (no revierte el guardado del evento).
5. **`admin.html` - modal por invitado tri-state:** `openPuntosInscrito` (`:7062-7117`) ramifica por `Array.isArray(ins.puntos_acceso)`: radio `heredar`/`explicito`, aviso "Override activo"/"Sin puntos"/"Sin override (hereda)", y lista con tags `(hereda)`/`(base + propio)`/`(solo propio)`/`(base)`. `guardarPuntosInscrito` (`:7125-7147`) persiste `heredar ? null : sel` (`[]` si explicito y sin marcas). **Resuelve TSK-111/R4** (union base+override ya distinguida).
6. **CSV de 3 estados:** `i.puntos_acceso==null ? 'Hereda' : (Array.isArray(i.puntos_acceso) ? (i.puntos_acceso.length ? ... : 'Ninguno') : ...)` (`admin.html:10710`).
7. **`scanner.html`:** regla `hasOwn` (`:850-855`), sin otros cambios. `evento-app.html`, `registroaforo.html`, `eventobackup.html`, `api/*.js` y `css/templates/*` **NO se tocan**.

#### Decision y artefactos

8. **ADR-081** creado: `Sistema QR desarrollo/decisiones/ADR-081-semantica-null-vs-vacio-y-propagacion-de-puntos-de-escaneo.md` (ASCII-safe, 0 bytes > 127) + fila de indice en `DECISIONS.md` (bajo ADR-080). Referencia a la migracion conciliada a `adr081_puntos_none_semantica.sql`.

#### Deuda declarada (NO cerrada)

9. **Rename de un punto = quitar + agregar:** el nombre viejo sale de todos los overrides (interseccion) y el nuevo NO se agrega a ningun override (solo lo reciben los herederos). Limite aceptado y documentado en ADR-081 (re-vincular por identidad exigiria IDs de punto; Opcion B rechazada). No es un bug.

#### Verificacion de cierre (por archivo real, ADR-006)

10. `node scripts/smoke_checkin_multipunto.js` -> **PASS 28 / FAIL 0**; `node scripts/smoke_puntos_adr081.js` -> **PASS 30 / FAIL 0**; `node scripts/express_check.js` -> **PASS 35 / FAIL 0**; `grep` confirma `hasOwn` en `scanner.html:850`, tab/bloque `data-pnl-*="puntos"`, motor `_pp*`/`propagarPuntosEvento` y tri-state en `admin.html`. Migracion real: `migrations/adr081_puntos_none_semantica.sql` presente (5550 bytes, 0 no-ASCII). **Este cierre documental no introduce cambios de codigo/migraciones adicionales; commits a cargo del orquestador.**

### Cierre de TSK-115 - Silo F14 "Vinilos Inversos" (theme `vinilos`) + 4 cambios aditivos de kernel + contrato `boletos.link|url` (ADR-082) (2026-10-29) - COMPLETADA

#### Entregables

1. **Silo NUEVO real** `css/templates/fiesta/f14.css`: 40.075 bytes, 1.396 lineas, 143 reglas, 5 at-rules, **0 bytes > 127**, doble notacion `.tpl-f14`/`.Tpl-F14` (166 ocurrencias), **0 selectores fuera de scope**, **0 clases/IDs fantasma**. Paleta modo oscuro + kraft + oxido (`#0E0E0E`, `#131313`, `#E35925`, `#EA580C`, `#DBC8A8`, `#EAE0D0`, `#F5F5F5`, `#A3A3A3`, `#262626`), tokens `--f14-*` + puente `--tpl-accent: var(--master-accent, #E35925)`. Grid de 1 columna en mobile y areas `hero/countdown/meta/ctas/lineup/cartel/video/boletos/faq/ubicacion/form` **sin area footer** (la pagina termina en boleteria + comunidad). Breakpoints 640/767/992/1279 + `prefers-reduced-motion`.
2. **Volcado previo respaldado:** `css/templates/fiesta/f14-volcado-tailwind.bak.css` (38.082 bytes de HTML+Tailwind que ocupaban el nombre del silo; incidente registrado en `ERRORES_HISTORICOS.md` sec. 32 / E32).
3. **Tipografia:** stack de sistema con peso 900. **Cero `@import`, cero `@font-face`, cero requests a Google Fonts** (patron f12/f13/f9b); el efecto fanzine se resuelve con forma (cinta kraft rotada), no con fuente manuscrita.
4. **4 cambios aditivos en `evento-app.html`:** FAQ accesible (`:2273`, `role`/`tabindex`/`aria-expanded`/`onkeydown`, el estilo sigue siendo `.active`); anchor "VER EN MAPA" `hidden` por defecto y gateado por `__esF14Silo()` (`:220`, `:2314-2321`, `:2336-2350`, gate `:1939-1942`); `renderSocialIcons()` por extract-method (`:1916-1942`) + `div#db-form-social` (`:325`) bajo gate; `data-ticket-url` desde la constante unica `__ticketDataUrl` (`:2429-2436`, `:2444`).
5. **Contrato de datos NUEVO opt-in:** `config_landing.content.boletos.link|url` (solo `http(s)`; ruta relativa NO soportada; invalido o ausente -> fallback silencioso al `wa.me` previo). Sin migracion, sin DDL, sin RLS.
6. **Registro en `admin.html`** (6 puntos, nace visible por ADR-040): card `:600-603`, `_THEME_TYPE` `:3352-3353`, `_THEME_TPL` `:3374-3377`, `_THEME_MODULES` `:3430-3445`, `_THEME_FICHA` `:3675-3681`, `names` del badge `:3818`.
7. **Smoke NUEVO** `scripts/smoke_f14_vinilos.js` (33 asserts, exit code 0/1).
8. **ADRs:** `ADR-082` creado en `decisiones/ADR-082-silo-f14-vinilos-inversos-kernel-y-contrato-boletos-link.md` + fila de indice en `DECISIONS.md`. **Nota de numeracion:** el brief preveia `ADR-072`, ya asignado a la atribucion del link de invitador; se usa el siguiente libre tras ADR-081 (`ADR-075` sigue siendo hueco y no se rellena).

#### Deuda declarada (NO cerrada)

9. **El wizard no captura `boletos.link|url`:** el contrato existe en el kernel pero no hay campo de UI que lo alimente; hasta agregarlo, el override es inoperante en la practica (todo cae al `wa.me`).
10. **`_THEME_TITULO_2_LINEAS`** (`admin.html:3859`) no incluye `vinilos` -> f14 con `metaDosLineas:false` y fuera de `__esTitulo2Lineas()`. Ampliarlo exige tocar admin **y** kernel en el mismo cambio (invariante ADR-070).
11. **Comentario desactualizado** en `admin.html:3855` (cabecera de `_THEME_TITULO_2_LINEAS` no lista f14). Sin efecto funcional.
12. **f13 sigue sin theme ni card** en el catalogo de admin (deuda previa, no de esta tarea).

#### Verificacion de cierre (por archivo real, ADR-006)

13. `node scripts/smoke_f14_vinilos.js` -> **PASS 33 / FAIL 0 / exit 0**; `node scripts/express_check.js` -> **PASS, FAIL 0**; balance de divs en baseline preexistente (`evento-app.html` 102/101, `admin.html` 1605/1602); `node --check` de los bloques `<script>` de `evento-app.html` OK. Contraste WCAG: 17.71 / 11.80 / 14.77 / 5.26 / 7.65, y el par no-AA (`#F5F5F5`/`#E35925` = 3.37) **no se usa como texto**. Archivos temporales del QA eliminados de la raiz. **Cambios de codigo en working tree; commit a cargo de Direccion.**

#### Addendum (misma sesion, 2026-10-29): deudas saldadas + tooling de medicion

14. **`f13` registrado** como theme `noche-avalon` (6 puntos del catalogo): card `admin.html:604-607`, `_THEME_TYPE :3361`, `_THEME_TPL :3387`, `_THEME_MODULES :3459`, `_THEME_FICHA :3698`, `names :3837`. Nombre y paleta derivados de la cabecera real de `f13.css` ("Noche Avalon"); modulos deducidos de sus `#mod-*`. Se descarto `ld-mod-cartel` porque **no existe como checkbox** (el `#mod-cartel` lo gobierna el silo).
15. **El wizard captura la URL de ticketera:** input `#ld-boletos-link` (`:801`), escritura como `content.boletos.link` solo con prefijo `http(s)` (`:5039-5048`), read-back (`:6468`) y reset (`:6294`). La clave se emite siempre (`null` si no aplica) para no perderse en el overwrite total de `config_landing` (clase BUG-016 / ADR-080). El contrato del kernel queda alimentable desde la UI.
16. **Comentario del catalogo corregido:** `admin.html:3873-3877` ahora lista f13/f14 y advierte que mapear el template **no** habilita las 2 lineas de titulo.
17. **Tooling de medicion (Mandato #20) reparado:** `scripts/usage_report.js` y `scripts/session_close.js` leian el esquema **V1** (`session`/`message`/`part`, 2.037 sesiones) mientras el runtime escribe **V2** (`session_v2`/`session_message`, 2.442): el reporte del dia devolvia **0 sesiones**. Ahora detectan el esquema, resuelven `--tree`/`--root` por `parent_id` y cuentan turnos por `session_message.type='assistant'`. Verificado: `--summary` del dia lista las 11 sesiones reales (~11,6M tokens, 76,5% cache_read); `node --check` OK en ambos scripts.
18. **Verificacion tras el addendum:** `node scripts/smoke_f14_vinilos.js` -> **PASS 38 / FAIL 0**; `node scripts/express_check.js` -> **PASS 39 / FAIL 0**; balance de divs `admin.html` en baseline (1605/1602); sintaxis de los 2 bloques `<script>` inline de `admin.html` OK.
19. **Siguen abiertas:** `_THEME_TITULO_2_LINEAS` no incluye `vinilos` ni `noche-avalon` (f14/f13 con `metaDosLineas:false`); `f13.css` sigue estilizando `.faq-q` inexistente.

---

### Cierre de TSK-116 - Rediseno del HERO del silo f14 (evento VINILOS INVERSOS) (2026-11-01) - COMPLETADA

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Cambio **CSS-only** en un unico archivo, implementado y verificado contra el archivo real (ADR-006). Este cierre es **documental: 0 cambios de codigo, 0 migraciones, 0 commits** (el commit de `f14.css` lo hace el orquestador).

#### Que se hizo (alcance REAL ejecutado)

1. **Archivo unico modificado:** `css/templates/fiesta/f14.css` — `git diff --numstat` -> **+290 / -59**; archivo final **47.483 bytes / 1.626 lineas**; **0 bytes > 127**; llaves **168/168**. **Cero cambios en HTML/JS** (ni `evento-app.html` ni `admin.html`).
2. **Causa raiz del bug:** `#mod-hero` **no declaraba `background-size` en todo el silo**, y el fondo se inyecta por JS como `background-image` inline (`evento-app.html:1564`); el navegador pintaba la foto (1671x941) a tamano nativo desde `0% 0%` -> a 1440 px desbordaba **231 px** y cortaba al artista; a 2560 px dejaba **889 px** vacios.
3. **Solucion:** `background-size: cover !important` (`f14.css:259`), `background-position: 100% 0% !important` (`:260`) y `no-repeat`; alto guiado por ancho `clamp(600px, 43vw, 880px)` (`:253`) y movil `clamp(540px, 80svh, 680px)` (`:1517`) con `background-position: 82% 0%` en `<=767px` (`:1518`).
4. **Composicion sin tocar el DOM** (contrato v210, atomos hermanos): `#mod-hero` (`:131-135`), `#unified-frame` (`:137-142`) y `#mod-hero-meta` (`:144-149`) comparten la celda `grid-area: hero` y se apilan con `align-self`. Orden visual resultante: organizador -> titulo -> subtitulo -> meta -> contador.
5. **Piezas nuevas:** tokens `--f14-cd-h: 106px` (movil 74 px, `:1496`) y `--f14-pad-x` (`:40-41`); scrim `#mod-hero::before` (`:266-267`); atomo `.hero-subtitle` (`:336-337`, antes **sin CSS en ningun silo**); franja de contador a sangre (`:383-385`); meta en linea con iconos kraft; `#i18n-sw` a la esquina superior derecha del hero en `absolute` (`:350-354`) para no tapar contador ni CTA.
6. **Breakpoints:** nuevos `<=1199px` y `<=767px`; retirados el hero `88vh` de `>=992px` y el padding del contador de `>=640px`. Log de versiones del archivo actualizado a **v1.1** (`f14.css:1609-1625`).

#### Verificacion (por archivo real, ADR-006)

7. `node scripts/smoke_f14_vinilos.js` -> **PASS 38 / FAIL 0** (ejecutado en este cierre). Balance de llaves **168/168**; **0 selectores fuera de scope**; **ASCII-safety 0 bytes > 127** (medido con `[System.IO.File]::ReadAllBytes`). Capturas headless Chrome a 1920/1440/768/390 confirman `scrollWidth == viewport` (cero scroll horizontal), rostro intacto a la derecha y jerarquia de la maqueta `referentes/hero.jpg`.
8. **Leccion reutilizable (registrada en ADR-083):** en este proyecto el fondo del hero se inyecta por JS (`evento-app.html:1564`); **cualquier silo que no declare `background-size`/`background-position` hereda el default `auto`/`0% 0%`** y recorta de forma distinta en cada resolucion.

#### Correcciones ADR-006 al brief de la tarea (baseline = archivo real)

9. El brief declaraba **+281 / -59** lineas: el real es **+290 / -59** (`git diff --numstat`). Diferencia de 9 lineas; no cambia el alcance.
10. El brief ubicaba `parseSpanishDate()` en `evento-app.html:727-729`: la funcion real vive en **`:720-730`** (los dos `new Date(...)` si estan en `:727` y `:729`); el `setInterval` real es **`:1424-1431`** (el brief decia `:1423-1431`, que es la linea del `parseSpanishDate(...)` que lo precede).
11. El brief pedia escribir la sede en `#ld-ubicacion-val` (`admin.html:777`): ese campo **existe en el DOM pero esta RETIRADO del formulario** por **ADR-056 (fila 9)** (`admin.html:4320-4323`; `modMap` ya no lo mapea, aunque su lectura legacy se conserva). La fuente canonica que escribe `eventos.ubicacion` es **`#ev-ubic`** (Paso 1, `admin.html:896`; lectura `:6041`, escritura `:6624`). **TSK-118 se abre con esa correccion.**

---

### Cierre de TSK-117 - Contador del landing en zona horaria de Bogota (UTC-5 fijo) y cleanup del `setInterval` (ADR-084) (2026-11-01) - COMPLETADA

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Alcance REAL ejecutado y verificado contra el archivo real (ADR-006). Es el **motor compartido** `evento-app.html` (14 silos), por lo que exigio **PAGO obligatorio** y **gate `AGENTS.md` §2 confirmado por el usuario el 2026-11-01**. Este cierre es **documental: 0 cambios de codigo, 0 migraciones, 0 commits** (el commit lo hace el orquestador).

#### Que se hizo (alcance REAL ejecutado)

1. **Archivos:** `evento-app.html` -> `git diff --numstat` = **+86 / -19**; y `scripts/smoke_countdown_tz.js` (**NUEVO**, 11.142 bytes). **Cero cambios en CSS / JS de silos / `admin.html` / `api/*.js` / SQL.**
2. **Causa raiz 1 (zona horaria):** `parseSpanishDate()` construia `new Date('YYYY-MM-DDTHH:mm')` **sin sufijo de zona**, asi que el motor del navegador lo interpretaba en la zona del **DISPOSITIVO**. Medido contra `v123` (`git show HEAD`): en **UTC** el contador iba **5 h adelantado** en el tiempo (fecha objetivo 5 h antes), en **Asia/Tokyo 14 h antes** y en **Europe/Madrid 6 h antes**. **En Bogota coincidia**, y por eso el defecto era **invisible en pruebas locales**.
3. **Causa raiz 2 (fuga de intervalo):** el `setInterval` nunca se limpiaba y el loader se re-ejecuta al cambiar idioma -> **un intervalo por pasada** sobre el mismo DOM; al vencer, el ultimo quedaba vivo pintando el **valor congelado**.
4. **Solucion v124:** `__CO_OFFSET_MIN = -300` (Colombia, UTC-5 **fijo**, sin horario de verano) + helper `__horaA24(timeStr)` + `parseSpanishDate()` con `Date.UTC(y, mo-1, d, hh, mm) - (__CO_OFFSET_MIN * 60000)` -> **epoch absoluto**, identico en cualquier dispositivo. Contador reescrito con `__cdTarget` / `__cdPaint` / `__cdTick`, `clearInterval(window.__cdTimer)` **antes** de crear el nuevo, ceros al vencer, auto-detencion (`__cdDone` -> `__cdTimer = null`) y guarda `isFinite()` que impide escribir `NaN`.
5. **Contrato preservado:** `parseSpanishDate(dateStr, timeStr) -> Date`, con los **mismos 2 llamadores** (contador y gate de fase `proximamente`). **Cero Borrado: 0 IDs / 0 modulos / 0 atomos tocados.**
6. **Fallbacks:** fecha invalida -> `new Date(NaN)` (antes el DOM recibia el literal `NaN`); sin hora -> `00:00` de Bogota; hora embebida `YYYY-MM-DDTHH:mm` -> se usa si `eventos.hora` viene vacia.

#### Verificacion (por archivo real, ADR-006)

| Comprobacion | Resultado |
|---|---|
| `node scripts/smoke_countdown_tz.js` (extrae el motor REAL del HTML) | **PASS 36 / FAIL 0** |
| 4 sondas de `TZ` en proceso hijo (UTC / Asia-Tokyo / America-Bogota / Europe-Madrid) | epoch identico **1795222800000** en las 4 |
| Assert duro contra el signo invertido del offset | OK |
| `node scripts/smoke_f14_vinilos.js` (sin regresion) | **PASS 38 / FAIL 0** |
| `node scripts/smoke_hero_contract.js` | **PASS 64 / FAIL 0** |
| `node scripts/smoke_qa_asserts.js` | **PASS 64 / FAIL 0** |
| Escudo GOLD: `node --check` de los 2 `<script>` inline (167.413 bytes) | exit **0** |
| Lineas agregadas con bytes > 127 | **0** |
| Nuevas `display: none` | **0** |
| Balance de `<div>` antes/despues (`git show HEAD`) | **102 / 101**, identico (preexistente) |
| Harness de timers: 3 pasadas del loader | **1 intervalo vivo** |
| Harness de timers: al vencer | **0 intervalos**, `window.__cdTimer = null`, pinta `00:00:00:00` |
| Harness de timers: fecha invalida | **0 intervalos**, **0 escrituras DOM** |

#### Deudas NUEVAS registradas (declaradas, NO ejecutadas)

7. **[CODIGO - baja] `evento-app.html:2770`:** `new Date(__tFase).getFullYear()` lee en la zona del DISPOSITIVO el ano del centinela de campana (2099). **No se corrigio** porque solo alimenta `__yearFase >= 2090` y el otro brazo de la condicion (`__tFase <= Date.now()`) es absoluto: la decision de fase **no cambia**. Cosmetico.
8. **[CODIGO - deuda] `eventovenezuela.html:787` y `eventologs.html:304`:** conservan el patron v123 (**2 ocurrencias cada uno**). Son **paginas legacy**, no el motor de los 14 silos. No se tocaron.
9. **[DATOS - aceptado] `2026-02-30`:** desborda a marzo via `Date.UTC` (`2026-03-03T01:00Z`). **Aceptado:** `eventos.fecha` es ISO y la escribe el admin con selector de fecha.
10. **[REUTILIZACION]** TSK-119 (`#meta-hora` `20:00 HRS` -> `8:00 PM`) **puede reutilizar `__horaA24()`**; no se ejecuto en este ciclo.

---

### Cierre de TSK-120 - Meta del hero en 2 columnas y titulo del evento sobre el line up (2026-11-01) - COMPLETADA

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Alcance REAL ejecutado y verificado contra el archivo real (ADR-006). **Tier FREE** (`AGENTS.md` §0, decidido por el usuario el 2026-11-01) y alcance **solo silo f14** (decidido por el usuario en la misma consulta): **0 cambios en `evento-app.html`**, 0 migraciones, 0 JS.

#### Que se hizo (alcance REAL ejecutado)

1. **Archivos:** `css/templates/fiesta/f14.css` **+147 / -18** (fase 1, tier FREE) y, ya con el **gate §2 confirmado por el usuario**, `evento-app.html` **+6 / -5** + `scripts/smoke_hero_contract.js` **+4 / -4** (fase 2, fecha localizada). **Cero cambios en `admin.html`, `api/*.js`, SQL y los otros 13 silos.**
2. **Meta en 2 columnas sin tocar el DOM:** `#mod-hero-meta` pasa de `flex` a `display: grid !important` (el `!important` es obligatorio porque la activacion atomica de la seccion 3 del mismo archivo fija `display:flex !important`; el ocultamiento del kernel sigue ganando porque es **inline** `!important`). `grid-template-columns: auto minmax(0, 1fr)` + `grid-template-rows: auto auto` y colocacion por `:nth-child`:
   * `:nth-child(1)` = **fecha** -> columna 1, fila 1, tipografia grande (`clamp(1.05rem, 1.7vw, 1.55rem)`, peso 900).
   * `:nth-child(2)` = **hora** -> columna 1, fila 2; **se oculta su icono de reloj** (la maqueta usa un solo icono de calendario para las dos lineas) y el `padding-left: calc(clamp(20px, 2.2vw, 26px) + 0.5rem)` la alinea bajo el texto de la fecha.
   * `:nth-child(3)` = **lugar + direccion** -> columna 2, `grid-row: 1 / span 2`, `align-self: stretch` y `border-left: 1px solid rgba(219, 200, 168, 0.32)` => el divisor vertical cubre la altura de las dos filas, como en la maqueta.
3. **Robustez del lugar:** `min-width: 0` + `max-width: 26ch` + `overflow-wrap: anywhere` en el `span` del lugar, para que envuelva sin desbordar en pantallas estrechas (medido a 500 px: `scrollWidth == clientWidth`).
4. **Titulo del evento sobre el line up:** `#mod-lineup::before { content: "VINILOS INVERSOS"; ... }` con tipografia display kraft, `clamp(1.9rem, 5.6vw, 4.2rem)` y subrayado naranja oxido. Va en CSS porque `#mod-lineup` **no tiene encabezado propio en el DOM** (tocar el HTML seria Cero Borrado + gate de motor). El silo f14 es **exclusivo** del evento `vinilos-inversos-c8yu` (verificado por REST: **1 de 13** eventos usa `template_id='f14'`), asi que el rotulo no contamina otros silos.
5. **Responsive:** el bloque `@media (max-width: 767px)` se reescribio para el grid (antes ponia `flex-direction: column`, que en grid se ignora): columnas con `gap 0.9rem`, `minmax(0, 1fr)` y escala tipografica reducida. Se corrigio tambien el `gap` del `@media (min-width: 1279px)` (era `0.7rem 1.4rem`, ajeno al grid) a `0.12rem clamp(1.1rem, 2.6vw, 2.4rem)`.
6. **Soporte `.meta-line` en el silo:** `display: block` para los dos spans del formateador de fecha del kernel. Regla **inerte** hoy (el motor solo habilita 2 lineas en f9/f9b) y lista si se autoriza el gate.

#### Verificacion (por archivo real, ADR-006)

| Comprobacion | Resultado |
|---|---|
| Balance de llaves del CSS | **0** (minimo 0) |
| Lineas agregadas con bytes > 127 | **0** |
| `node scripts/smoke_f14_vinilos.js` | **PASS 38 / FAIL 0** |
| `node scripts/smoke_all.js` | **11 PASS / 1 FAIL** (`smoke_f9b_mistico_nocturno`, deuda preexistente verificado con `git stash`) |
| Harness visual local (1440 px, 2 variantes de fecha) | 2 columnas, divisor y jerarquia correctos; sin solapes |
| Harness a 500 px y 767 px | `scrollWidth == clientWidth`; sin desbordamiento horizontal |
| `git diff --numstat` | `css/templates/fiesta/f14.css` (+147/-18), `evento-app.html` (+6/-5), `scripts/smoke_hero_contract.js` (+4/-4) |
| Gate de la fecha (prueba funcional del helper real) | `tpl-f9`/`tpl-f9b`/`tpl-f14`/`Tpl-F14` -> `true`; `tpl-f13`/`tpl-f14x`/vacio -> `false` (sin fuga por prefijo) |
| `__formatoFechaLarga('2026-11-20')` | `{l1:"Viernes 20", l2:"noviembre de 2026"}`; texto libre -> `null` |
| Escudo GOLD `node --check` de los 2 `<script>` inline | exit **0** (56 y 168.497 bytes) |
| Balance de `<div>` del motor | 102/101 (delta 1 **preexistente**) |

#### Deuda declarada (NO cerrada)

11. **[DATOS + CODIGO - RESUELTA 2026-11-01] Fecha del hero en ISO:** `__metaSet('meta-fecha', __metaDerive(ev.fecha, true), __metaData.fecha, true)` solo entraba a la rama de fecha localizada si `__esMeta2Lineas()` devolvia `true`, y esa allowlist era literal `['tpl-f9','tpl-f9b']` (`evento-app.html:919-926`), asi que en f14 el hero pintaba **`2026-11-20`**. **Gate `AGENTS.md` §2 confirmado por el usuario el 2026-11-01.** Fix aplicado: `'tpl-f14'` agregado a la allowlist (`evento-app.html` **+6/-5**, incluido el comentario del contrato) y `scripts/smoke_hero_contract.js` **+4/-4** (asserts S2 actualizados a `f9,f9b,f14`; el invariante pasa a ser "solo los silos con CSS para `.meta-line`"). La fecha se pinta ahora `VIERNES 20` / `NOVIEMBRE DE 2026` con el CSS que el silo ya tenia. **Nota de coherencia:** `__esFamiliaF9()` (`:886`) conserva `['tpl-f9','tpl-f9b']` **a proposito** — f14 no puede heredar las subconmutaciones ni el contenido editorial de RASTRO MC. El comentario de `admin.html:3872` sigue citando solo f9/f9b: es documentacion, no logica (deuda cosmetica).
12. **[DATOS - baja] Lugar en una sola linea:** la maqueta separa `KLANDESTINO` / `KRA 4 # 19-56` / `BOGOTA D.C.`; `eventos.ubicacion` es un unico string y el DOM del meta no admite salto de linea. Se ve bien en una linea; para replicar el 3-lineas hace falta override `content.meta.lugar` (gateado por el mismo allowlist) o un campo nuevo.
13. **[ERROR HISTORICO - preexistente]** `smoke_f9b_mistico_nocturno.js` falla el assert `subconmutacion 1 (__esF9Meta / meta 2 lineas) usa __esFamiliaF9` (PASS 102 / FAIL 1). Verificado con `git stash` que tambien falla en HEAD sin estos cambios. **No bloquea** el despliegue del silo.

---

### Cierre de TSK-121 - Tipografia de cartel, hero compacto y rotulo LINE UP (2026-11-01) - COMPLETADA

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Alcance REAL ejecutado y verificado contra el archivo real (ADR-006). **Tier FREE** (`AGENTS.md` §0, decidido por el usuario el 2026-11-01) y **solo silo f14**.

#### Que se hizo (alcance REAL ejecutado)

1. **Archivo:** `css/templates/fiesta/f14.css` -> **+64 / -28**. Cero cambios en `evento-app.html`, `admin.html`, `api/*.js`, SQL y los otros 13 silos.
2. **Titulo de cartel:** token `--f14-poster` con stack condensado **elegido por sonda medida** (Impact 368 px, Haettenschweiler 274 px, Franklin Gothic Medium 410 px, `'Arial Narrow'` **551 px = fallback**, `system-ui` 491 px). `Arial Narrow` se descarto porque no resuelve en Chrome y `font-stretch: condensed` porque no cambia el ancho (551 -> 551). Tamano: `clamp(2.6rem, 9.6vw, 9rem)`.
3. **Contorno cafe:** token `--f14-cafe: #4A2E1B` + `-webkit-text-stroke: clamp(1.2px, 0.32vw, 4.4px)` + `paint-order: stroke fill`; se retiro el `text-shadow` plano (relieve sucio) y se dejo una sombra corta.
4. **Meta pegado al subtitulo:** la causa era el **alto fijo** del hero (ADR-083), no el margen del meta. El hero pasa a ser **guiado por contenido** (`min-height: clamp(360px,26vw,560px)` + `padding-bottom: calc(var(--f14-cd-h) + 6rem)`) y los tres breakpoints se recalcularon con la misma aritmetica (1199 / 767). Medido en el harness: hueco subtitulo->meta **26 px** (1440) y **25 px** (500), antes **123 px** y **158 px**; meta->contador 24/16 px.
5. **Rotulo del line up:** `#mod-lineup::before` = `LINE UP` con la tipografia de cartel; la tagline `una noche para vibrar con los mejores sonidos` va en **`.lineup-grid::before`** (el `::after` de la seccion renderiza DESPUES de la grilla) y el wrapper se fuerza a `display:block !important`.

#### Verificacion (por archivo real, ADR-006)

| Comprobacion | Resultado |
|---|---|
| Balance de llaves del CSS | **0** (minimo 0) |
| Lineas agregadas con bytes > 127 | **0** |
| `node scripts/smoke_f14_vinilos.js` | **PASS 38 / FAIL 0** |
| `node scripts/smoke_hero_contract.js` | **PASS 64 / FAIL 0** |
| Harness visual local (1440 / 767 / 500 px) | sin solapes ni desborde horizontal (`scrollWidth == clientWidth`) |
| `git diff --numstat` | solo `css/templates/fiesta/f14.css` (+64/-28) |

#### Deuda declarada (NO cerrada: son DATOS, no codigo)

14. **[DATOS - bloqueada por RLS] Textos del meta y del subtitulo.** Pedido: `content.subtitulo = "DRUM N BASS - REGGAE - HIP HOP"` y
    `content.meta = { fecha:{l1:"NOVIEMBRE 20"}, hora:{l1:"8:00 P.M"}, lugar:{l1:"KLANDESTUNO BAR", l2:"KRA 4 # 19-54 (PISO 4)"} }`.
    **Se intento el `PATCH` directo** a `eventos?slug=eq.vinilos-inversos-c8yu` con la clave anon del motor: **200 + `[]`** (0 filas) y read-back sin cambios -> RLS lo rechaza, igual que TSK-118. No hay `SUPABASE_SERVICE_ROLE_KEY` local ni `.env`. **Se aplica desde el admin** (`Configuracion de landing > content`); el CSS del silo ya pinta los overrides (`meta-line` en bloque). Sin ellos, el hero sigue mostrando `VIERNES 20` / `NOVIEMBRE DE 2026`, `8:00 PM` y `KLANDESTINO, KR 4 # 19-56`.
15. **[COSMETICA - preexistente]** El comentario de `admin.html:3872` sigue citando solo `f9`/`f9b` para `.meta-line`; es documentacion, no logica.
16. **[ERROR HISTORICO - preexistente]** `smoke_f9b_mistico_nocturno.js` sigue fallando el assert de la subconmutacion 1; verificado con `git stash` que tambien falla en HEAD. **No bloquea.**



### Cierre de TSK-122 - Regla general de boleteria de tarifa unica / ENTRADA GENERAL (ADR-087) (2026-11-01) - COMPLETADA

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Alcance REAL ejecutado y verificado contra el archivo real (ADR-006). **Ruta de riesgo `AGENTS.md` §2** (motor compartido `evento-app.html`). **Evento que lo disparo:** `vinilos-inversos-c8yu` (`template_id='f14'`, theme `vinilos`).

#### Que se hizo (alcance REAL ejecutado)

1. **Motor:** `evento-app.html` v1.15.0, segmento boleteria (`:2575-2610`). La rama generica (todos los silos salvo la familia f9) pintaba **siempre** dos tarjetas, PREVENTA y TAQUILLA, y la que no tenia dato caia al relleno `landing.pendiente_def` (`POR DEFINIR`).
2. **Criterio de conteo:** `__tarifasReales` = 1 por cada fuente **REAL** entre `content.boletos.preventa`, `content.boletos.taquilla` y la **fuente legacy `content.tickets_info`**; cada una excluye vacio y el centinela `landing.pendiente_def`.
3. **Comportamiento nuevo:** con **exactamente 1** tarifa real -> **UNA** tarjeta con rotulo `landing.boletos_entrada_general` en el slot `#db-boletos-taquilla`, y `#db-boletos-preventa` queda vacio. Con **0 o 2+** tarifas -> comportamiento previo intacto (incluye el auto-ocultamiento `v307` cuando no hay ningun dato).
4. **Regla GENERAL, no gate por silo:** aplica a todos los silos, no solo a f14 (decision del usuario el 2026-11-01). **Fuera de contrato:** familia f9/f9b (`__esF9Boletos`, rama propia sin cambios) y silo f8 (`__esF8Boletos`: ahi `preventa`/`taquilla` significan INDIVIDUAL/PAREJA y conservan su rotulo). `__esFamiliaF9()` no se toca.
5. **Cero Borrado:** solo se vacia el `innerHTML` del slot; los atomos `#db-boletos-preventa` y `#db-boletos-taquilla` **siguen en el DOM**; 0 IDs eliminados y 0 `display:none` nuevos.
6. **i18n:** clave nueva `landing.boletos_entrada_general` en las 3 tablas de `js/i18n.js` -> `ENTRADA GENERAL` / `ENTREE GENERALE` / `GENERAL ADMISSION`.

#### Verificacion (por archivo real, ADR-006)

| Comprobacion | Resultado |
|---|---|
| `node scripts/smoke_f14_vinilos.js` | **PASS 38 / FAIL 0** |
| `node scripts/smoke_qa_asserts.js` | **PASS 70 / FAIL 0** |
| `node scripts/smoke_hero_contract.js` | **PASS 64 / FAIL 0** |
| `node scripts/smoke_paleta_evento.js` | **PASS 20 / FAIL 0** |
| Caso real `vinilos-inversos-c8yu` (`boletos = { preventa: null, taquilla: "$15.000" }`) | 1 tarjeta `ENTRADA GENERAL` / `$15.000`; `#db-boletos-preventa` vacio pero presente |

#### Pendiente declarado (NO cerrado)

17. **[PRODUCCION] Verificacion visual del alto del iframe del playlist en movil < 360 px** (heredado de TSK-123): el `iframe` se fija a 352 px en movil, pero el ancho de pantalla mas estrecho no se probo en dispositivo real. Se revisa junto con la boleteria en `https://taquilladirecta.com/evento.html?slug=vinilos-inversos-c8yu` (ver `NEXT.md` hito -53).

### Cierre de TSK-123 - Modulo PLAYLIST encendido en el silo f14 (v1.2 del silo) (2026-11-01) - COMPLETADA

> Seccion **agregada** (nada anterior se reescribe, Cero Borrado Oro #2/#3). Alcance REAL ejecutado y verificado contra el archivo real (ADR-006). **Tier FREE / CSS-only**: 1 archivo, `css/templates/fiesta/f14.css`.

#### Que se hizo (alcance REAL ejecutado)

1. **Causa raiz (IoC del kernel):** el kernel oculta todas las `section` (`section, header, footer { display:none }`) y cada silo **enciende** sus modulos. `f14.css` nunca encendia `#mod-playlist`, asi que el embed de Spotify (`content.playlist_url` -> `#db-spotify-embed`) se inyectaba en el DOM pero quedaba **invisible**.
2. **Causa raiz (colapso del alto):** el `<iframe height="100%">` no tenia contra que resolver el alto porque el contenedor solo declaraba `min-height`.
3. **Activacion:** `#mod-playlist` entra en el bloque de activacion del silo; `playlist` se agrega a las **3** `grid-template-areas` (base, `min-width: 767`, `max-width: 767`) con su regla `grid-area: playlist` (`f14.css:181-183`).
4. **Estetica:** seccion **12b** con rotulo tipografico `PLAYLIST` en `::before` (mismo lenguaje de cartel que `#mod-lineup::before`, ADR-085/086), marco kraft/naranja del embed, `iframe` a **400 px** (352 px en movil) y estilizado del enlace `a.spotify-open-link` (incluye `:hover` y `:focus-visible`).
5. **Cabecera del archivo:** se documenta `v1.2 - 2026-11-01 - Modulo PLAYLIST (#mod-playlist) encendido y estilizado` (`f14.css:1906`).

#### Verificacion (por archivo real, ADR-006)

| Comprobacion | Resultado |
|---|---|
| `node scripts/smoke_f14_vinilos.js` | **PASS 38 / FAIL 0** |
| `node scripts/smoke_hero_contract.js` | **PASS 64 / FAIL 0** (sin regresion del hero) |
| `node scripts/smoke_qa_asserts.js` | **PASS 70 / FAIL 0** |
| Selectores fuera de scope `.tpl-f14` / `.Tpl-F14` | **0** |
| `evento-app.html` / `admin.html` / `api/*.js` / SQL | **sin cambios** |

#### Deuda declarada

18. **[PRODUCCION - visual] Alto del iframe en movil < 360 px:** verificado por CSS y en harness de escritorio/movil, **no** en dispositivo real de 320-359 px. Si el embed se recorta, el ajuste es CSS del silo (352 px -> `height: clamp(...)`).

#### Addendum v1.3 - reacomodo CARTEL + PLAYLIST + VIDEO (2026-11-01, mismo dia)

> Linea **agregada** al cierre de TSK-123 (nada anterior se reescribe, Cero Borrado Oro #2/#3). Continuacion del mismo dia de ADR-087 / TSK-122-123, ya dentro del hito `-53` de `NEXT.md` (no se crea hito ni TSK nuevo): **0 entradas nuevas**. Alcance REAL verificado contra el archivo real (ADR-006), **CSS-only** en `css/templates/fiesta/f14.css` **v1.3**: **0 cambios en el kernel** (`evento-app.html`), **0 cambios de base de datos** (0 DDL, 0 RLS, 0 migraciones).

(a) **PLAYLIST al lado del CARTEL en una sola fila** (`@media (min-width: 767px)`): la rejilla pasa de `"cartel cartel"` + `"playlist playlist"` (dos filas) a **`"cartel playlist"`** en una sola fila (`f14.css:1634`); el resto de filas y su orden quedan igual. En movil (`<=767px`) siguen **apilados** a ancho completo. Se anaden `align-self: stretch` en `#mod-cartel` / `#mod-playlist` (`:1657-1660`, `:1680-1683`).

(b) **Embed de Spotify estirado al alto de la fila del poster:** cadena de altura completa `#mod-playlist > div` -> `#db-spotify-embed` (`flex: 1 1 auto`, `min-height: 480px !important`, `:1685-1698`) -> `iframe` (`height: 100% !important`, `:1700-1705`), con **especificidad extra** (`#mod-playlist #db-spotify-embed ...`) para ganar en el limite exacto de **767 px**; el anchor `Abrir en Spotify` queda `flex: 0 0 auto` centrado. El poster se limita a **`max-height: 640px`** con `object-fit: contain` (`:1671-1678`) y define el alto de la fila; `.cartel-inner` pasa a flex centrado con `max-width: 100%`.

(c) **Caja del player de video oculta SOLO cuando esta vacia:** `.tpl-f14 #db-video-content:empty { display: none !important }` (`:914-917`) + `#mod-video:has(#db-video-content:empty) #db-gallery-grid { margin-bottom: 0 !important }` (`:920-923`). Motivo: el kernel solo apaga `#mod-video` cuando **no hay galeria**, y en `vinilos-inversos-c8yu` hay galeria (3 fotos) con `video_url = null`, asi que quedaba un **rectangulo negro 16:9 vacio**. **Cero Borrado:** el atomo sigue en el DOM y reaparece cuando el kernel le inyecte contenido (`:empty` deja de aplicar).

**Verificacion (ADDENDUM v1.3, ejecutada en este cierre):** `node scripts/smoke_f14_vinilos.js` -> **PASS 59 / FAIL 0** (antes 38), con asserts nuevos para la fila `"cartel playlist"` (`f14.css:1634`), el estiramiento (`min-height: 480px !important` + `height: 100% !important`) y el ocultamiento de la caja vacia; ademas se **corrigio un falso positivo previo** que contaba `"playlist playlist"` sobre el **LOG DE VERSIONES** del archivo (`f14.css:1987`) en lugar del CSS vivo. Cabecera del archivo actualizada a **`v1.3 - 2026-11-01 - Reacomodo del layout CARTEL + PLAYLIST + VIDEO`** (`f14.css:1996-2020`). `git show --numstat 0e46e51` -> `f14.css` **+104 / -2**, `smoke_f14_vinilos.js` **+10 / -2**; archivo final **63.194 bytes / 1.824 lineas**. **Pendiente heredado:** el chequeo visual en PRODUCCION (767 / 1024 / 1440 y movil < 360 px) sigue abierto en `NEXT.md` hito `-53`.

#### Addendum v1.4 - rotulo PLAYLIST compacto y embed al 100% de su columna (2026-11-01, mismo dia)

> Linea **agregada** al cierre de TSK-123 (nada anterior se reescribe, Cero Borrado Oro #2/#3). Continuacion del mismo dia, dentro del hito `-53` de `NEXT.md` (**0 entradas nuevas, 0 TSK nuevos**). Alcance REAL verificado contra el archivo real (ADR-006), **CSS-only** en `css/templates/fiesta/f14.css` **v1.4** (commit `e3b99a3`): **0 cambios en el kernel** (`evento-app.html`), **0 cambios de base de datos** (0 DDL, 0 RLS, 0 migraciones) y **0 cambios** en `admin.html`, `api/*.js` y los otros 13 silos. El reparto de columnas **sigue 50/50**.

(a) **Rotulo `PLAYLIST` compacto en escritorio (max 38 px):** el `clamp(2.4rem, 8vw, 6rem)` de la base (hasta **96 px**) competia con el ancho de la columna 50/50 y empujaba el rotulo fuera del marco. Dentro de `@media (min-width: 767px)` pasa a `font-size: clamp(1.5rem, 2.4vw, 2.4rem)`, `letter-spacing: 0.08em` y `-webkit-text-stroke: 1px var(--f14-cafe)` (`f14.css:1685-1695`). **En movil (`< 767px`) el rotulo grande queda intacto:** la regla vive solo en la media, no en la base.

(b) **Caja del playlist al 100% de su celda:** el wrapper que inyecta el kernel trae `max-width:1100px; margin:0 auto` **en linea** y `#db-spotify-embed` tenia el mismo tope, asi que en la columna 50/50 la caja quedaba **mas angosta que su columna**. Dentro de la media 767 se anulan ambos topes (`width: 100%` / `max-width: 100% !important` / `margin: 0 !important` en `#mod-playlist > div`, `f14.css:1697-1709`, y en `#mod-playlist #db-spotify-embed`, `:1711-1724`). De forma **preventiva**, la sombra del marco baja de `8px 8px 0` a **`6px 6px 0`** en esa misma media, para que el desplazamiento no se recorte en el limite exacto de **767 px**.

(c) **Sin cambios de comportamiento:** la cadena de estiramiento del alto se conserva con **una sola ocurrencia** (`min-height: 480px !important` en `#db-spotify-embed` -> `iframe` `height: 100% !important`, `f14.css:1716` y `:1729`), el **50/50 queda intacto** y los **altos moviles 400 px / 352 px no se tocaron**. La seccion solo **anade ancho**, no reescribe la logica del addendum v1.3.

**Verificacion (ADDENDUM v1.4, ejecutada en este cierre):** `node scripts/smoke_f14_vinilos.js` -> **PASS 61 / FAIL 0** (antes 59), con **2 asserts nuevos**: `silo: rotulo PLAYLIST compacto en escritorio` y `silo: embed ocupa el 100% de su columna`. Cabecera del archivo actualizada a **`v1.4 - 2026-11-01 - Ajuste visual del modulo PLAYLIST en escritorio`** (`f14.css:2047`). **Pendiente heredado y actualizado:** el chequeo visual en PRODUCCION (767 / 1024 / 1440 y movil < 360 px) sigue abierto en `NEXT.md` hito `-53`, ahora con dos comprobaciones nuevas (rotulo compacto y caja al borde de su columna).

#### Addendum v1.5 - Seccion de PATROCINADORES activada (2026-11-01, mismo dia)

> Linea **agregada** al cierre de TSK-123 (nada anterior se reescribe, Cero Borrado Oro #2/#3). Continuacion del mismo dia, dentro del hito `-53` de `NEXT.md` (**0 entradas nuevas, 0 TSK nuevos**; totales de TASKS.md intactos). Alcance REAL verificado contra el archivo real (ADR-006), **CSS-only** en `css/templates/fiesta/f14.css` **v1.5** (commit `eb9bbdc`): **0 cambios en el kernel** (`evento-app.html`), **0 cambios de base de datos** (0 DDL, 0 RLS, 0 migraciones) y **0 cambios** en `admin.html`, `api/*.js` y los otros 13 silos. `git show --numstat eb9bbdc` -> `f14.css` **+112 / -0**, `scripts/smoke_f14_vinilos.js` **+12 / -0**; archivo final **69.923 bytes**.

(a) **Causa raiz:** el silo `f14` **no tenia ninguna regla de sponsor** y `#mod-sponsors` no estaba ni en la **lista de activacion IoC** ni en las **`grid-template-areas`**. Como el kernel apaga toda `<section>` (`section { display:none }`) y cada silo enciende sus modulos, la banda **nunca se mostraba** aunque `content.sponsors` ya trae **2 logos reales** (Ancestral y Klandestino, PNG en Supabase Storage).

(b) **Activacion y layout:** `#mod-sponsors` entra en la lista IoC con `display:block !important` (`f14.css:109-110`) y recibe `grid-area: sponsors` (`:199-202`). La banda es de **ancho completo** y va **entre la fila `faq|ubicacion` y la fila `boletos|form`** en los **3** bloques de areas: base de 1 columna (**11 filas**, `:124-135`), `@media (min-width: 767px)` (**8 filas**, `:1704-1712`) y `@media (max-width: 767px)` (**11 filas**, `:1924-1935`). Las tres incluyen la fila `sponsors`.

(c) **Estilos replicados del silo f9b** (evento de referencia `lanzamiento-mistico-64k6`, **sin rotulo**, logos sueltos): seccion centrada con `border-top` y `padding: 3.2rem 1.5rem !important` (`:1638-1644`; el kernel trae `padding:4rem 0` inline), lista `#db-sponsors-list` flex centrada con `gap: 2.6rem !important` (`:1647-1656`; el kernel trae `gap:4rem` inline), `.sponsor-item` **sin marco ni fondo** (`:1658-1667`) y `.sponsor-img` con `height:42px; width:auto; max-width:180px; object-fit:contain; opacity:0.72` (`:1671-1680`) + hover `opacity:1 + scale(1.06) + brightness(1.12)` (`:1682-1687`). En `<=767px`: `gap:1.4rem` (`:1946-1949`) y logos de **32 px** con `max-width:140px` (`:1951-1955`). La altura fija se debe a que los logos reales llegan en **proporciones distintas** y sin tope crecian a su tamano natural.

(d) **Seguro anti-resurreccion (Cero Borrado):** `#mod-sponsors[data-hidden="true"] { display:none !important }` (`:1692-1695`), para que el `display:block !important` de la activacion **no reviva la banda** cuando el kernel la apaga por falta de patrocinadores (`__hideEmptyModule` escribe `display:none !important` **en linea** + `data-hidden="true"`).

(e) **Sin cambios de comportamiento:** ningun modulo, atomo ni ID se elimina; los patrocinadores viven en `#db-sponsors-list` que sigue siendo del kernel. El cambio solo **anade** activacion, area y estilos.

**Verificacion (ADDENDUM v1.5, ejecutada en este cierre):** `node scripts/smoke_f14_vinilos.js` -> **PASS 68 / FAIL 0** (antes 61), con **7 asserts nuevos** de patrocinadores; CSS de produccion verificado (**69.923 bytes**) con las areas `sponsors` en los 3 bloques, la entrada IoC, los logos de **42 px / 32 px**, `border:none` en `.sponsor-item`, el selector `[data-hidden="true"]` y el log **v1.5** del archivo (`:2151-2172`). **Pendiente heredado y actualizado:** el chequeo visual en PRODUCCION sigue abierto en `NEXT.md` hito `-53`, ahora con la banda de patrocinadores como comprobacion adicional.

#### Addendum v1.6 - Reorden de rejilla y FOOTER encendido (2026-11-01, mismo dia)

> Linea **agregada** al cierre de TSK-123 (nada anterior se reescribe, Cero Borrado Oro #2/#3). Continuacion del mismo dia, dentro del hito `-53` de `NEXT.md` (**0 entradas nuevas, 0 TSK nuevos**; totales de TASKS.md intactos). Alcance REAL verificado contra el archivo real (ADR-006), **CSS-only** en `css/templates/fiesta/f14.css` **v1.6** (commit `dcb1a58`): **0 cambios en el kernel** (`evento-app.html`), **0 cambios de base de datos** (0 DDL, 0 RLS, 0 migraciones) y **0 cambios** en `admin.html`, `api/*.js` y los otros 13 silos. `git show --numstat dcb1a58` -> `f14.css` **+80 / -8**, `scripts/smoke_f14_vinilos.js` **+15 / -0**; archivo final **72.810 bytes**.

(a) **Orden nuevo de secciones (pedido de Direccion):** `hero` -> `ctas` -> `LINE UP` -> `cartel + playlist` -> `boleteria + formulario` -> `galeria` (vive dentro de `#mod-video`) -> `faq + ubicacion` -> `patrocinadores` -> `footer`. Se aplica en los **3** bloques de `grid-template-areas` del silo: base de 1 columna (**12 filas**, `f14.css:126-140`), `@media (min-width: 767px)` (**9 filas**, con `"cartel playlist"` y `"boletos form"` pareados, `:1756-1768`) y `@media (max-width: 767px)` (**12 filas**, `:1977-1990`). El `row-gap` sigue en **0** en la base.

(b) **FOOTER encendido (nunca lo estuvo en f14):** el kernel ya trae `<footer id="mod-footer">` **dentro** de `<main id="main-content-flow">` (`evento-app.html:65`, footer en `:351`) con marca, enlaces, redes y contacto, pero su **IoC global apaga `section, header, footer`** (`evento-app.html:38`), asi que cada silo debe encenderlo. Se agrego: `#mod-footer` en la **lista de activacion IoC** (`display: block !important`, `f14.css:113-114`), `grid-area: footer` (`:217-219`) y estilos de **franja de cierre** con el patron **f8/f9b** (`:1714-1745`): `padding: 1.8rem 1.5rem`, `background-color: var(--f14-bg-2)`, `border-top: 2px solid var(--f14-line)`, `.footer-bottom` centrado a `max-width:900px` sin borde superior.

(c) **`.footer-inner` oculto y `#footer-copy` con tipografia de cartel (Cero Borrado):** `.footer-inner` (marca, columnas, redes, contacto) se apaga con `display:none !important` (`:1723-1724`) porque el kernel **no trae estilos globales** para esas columnas y mostrarlas apiladas rompia el cierre; **el nodo queda intacto en el DOM**, ningun ID se elimina. El dato real del evento se pinta en `#footer-copy` (`:1737-1748`) con `var(--f14-display)`, kraft (`var(--f14-kraft)`) al **78%** de opacidad, mayusculas y `letter-spacing: 0.22em`.

**Verificacion (ADDENDUM v1.6, ejecutada en este cierre):** `node scripts/smoke_f14_vinilos.js` -> **PASS 74 / FAIL 0** (antes 68), con **6 asserts nuevos**: activacion del footer, `grid-area: footer`, footer presente en las **3** rejillas, `.footer-inner` oculto, `#footer-copy` estilizado y un **assert de ORDEN** que compara las posiciones de las **9 filas** del breakpoint 767. CSS de produccion verificado (**72.810 bytes**): **12 / 9 / 12** filas, orden correcto y `footer` en los 3 bloques. Cabecera del archivo actualizada al log **`v1.6 - 2026-11-01 - Reorden de la rejilla y FOOTER encendido`** (`f14.css:2228-2243`). **Pendiente heredado:** el chequeo visual en PRODUCCION sigue abierto en `NEXT.md` hito `-53`, ahora con el orden nuevo y el footer como comprobaciones adicionales.

#### Addendum v1.7 - Footer completo y cierre en f1 / f11 (2026-11-01, mismo dia)

> Linea **agregada** al cierre de TSK-123 (nada anterior se reescribe, Cero Borrado Oro #2/#3). Continuacion del mismo dia, dentro del hito `-53` de `NEXT.md` (**0 entradas nuevas, 0 TSK nuevos**; totales de TASKS.md intactos). Alcance REAL verificado contra el archivo real (ADR-006), **CSS-only** en `css/templates/fiesta/f14.css` (**v1.7**, commit `64c1de4`) y en `css/templates/fiesta/f1.css` + `css/templates/fiesta/f11.css` (commit `ff83793`): **0 cambios en el kernel** (`evento-app.html`), **0 cambios de base de datos** (0 DDL, 0 RLS, 0 migraciones) y **0 cambios** en `admin.html`, `api/*.js`, `b5.css` y los otros silos. `git show --numstat 64c1de4` -> `f14.css` **+149 / -10**, `scripts/smoke_f14_vinilos.js` **+1 / -1**; `git show --numstat ff83793` -> `f1.css` **+201 / -3**, `f11.css` **+181 / -4**.

(a) **f14 v1.7 - el footer pasa de franja minima a footer completo de 4 columnas (commit `64c1de4`):** `.footer-inner` **ya no se oculta** (antes `display:none !important` en el addendum v1.6) y se pinta en rejilla `1.5fr 1fr 1fr 1fr` con `max-width:1100px` (`f14.css:1723-1729`): **marca al doble** + enlaces + redes + contacto. La marca `#footer-org-name` usa la tipografia de cartel kraft del silo con trazo cafe (`:1732-1744`); los titulos de columna van en `--f14-fuego` (`:1754-1763`); los iconos de red pasan a **caja de 34 px** con borde `--f14-line`; `#db-footer-contacto` se reparte en **dos lineas** (`:1824-1832`); `.footer-bottom` lleva `border-top` con `#footer-copy` **centrado** (`:1834-1851`); en `<=767px` el footer pasa a **una columna centrada** (`:2120-2130`). Los anchors del fallback `[href="#mod-historia"]` y `[href="#mod-impacto"]` **se ocultan** porque f14 no enciende esos modulos, pero **siguen en el DOM** (Cero Borrado, `:1789-1796`). Log de versiones del propio archivo: **`v1.7 - 2026-11-01 - Footer completo de 4 columnas (antes solo la franja)`** (`:2371+`).

(b) **f1 - el silo no tenia NINGUNA regla de footer (commit `ff83793`):** se agrego la activacion (`display:block !important`), `grid-area: footer` (`f1.css:118`) y la **fila `footer`** en sus **3** listas de `grid-template-areas`: base de **12 filas** (`:88-100`), `@media (min-width:1024px)` de **12 filas** (`:124-137`) y `@media (max-width:1023px)` de **12 filas** (`:905-917`), mas el mismo bloque de **4 columnas** adaptado a su paleta (seccion 16, `:942+`). En `>=1024px` la fila es **`"hero footer"`** (no a todo el ancho) **a proposito**: el hero es un panel fijo de **38vw** con `z-index` alto y un footer de ancho completo quedaria por debajo (`:134-137`). f1 es el **silo de respaldo**: hay **3 eventos sin `template_id`**.

(c) **f11 - el silo APAGABA el footer a proposito (commit `ff83793`):** `#mod-footer` estaba en su lista de "Ocultos" con `display:none !important`. Se saco de esa lista, se agrego la activacion + `grid-area: footer` (`f11.css:155-162`) y la fila **`"footer footer"`** en su **unica** lista de areas, que pasa de **9 a 10 filas** (`:190-200`), mas el bloque de **4 columnas** adaptado a su paleta **neon** (seccion de footer, `:1606+`). El archivo **no tiene log de versiones propio** (no existe esa seccion), por eso la fecha va en el comentario de cabecera de la seccion (**v1.2 del silo, 2026-11-01**).

(d) **Exclusiones explicitas:** **`b5` NO se toca** - oculta el footer con el comentario *mandato explicito de Direccion* (`css/templates/campana/b5.css:505-517`). Los **3 eventos sin `template_id`** quedan como estan por decision del usuario. Ningun ID se elimina y ningun nodo sale del DOM: solo cambia que se enciende y como se pinta.

**Verificacion (ADDENDUM v1.7, ejecutada en este cierre):** `node scripts/smoke_f14_vinilos.js` -> **PASS 74 / FAIL 0** (mismo conteo que v1.6, sin asserts nuevos: el cambio de footer de 4 columnas se valido contra el archivo real). Comprobado por `grep`/`Select-String` en este turno: `f14.css` con `grid-template-columns: 1.5fr 1fr 1fr 1fr` (`:1726`) + `max-width:1100px` (`:1728`) + log **v1.7** (`:2371`); `f1.css` con `grid-area: footer` (`:118`) y `footer` en las **3** listas de areas (`:100`, `:137`, `:917`); `f11.css` con `#mod-footer` fuera de la lista de apagado, activado (`:158-161`) y la fila `"footer footer"` (`:200`). `git status -sb` -> `main...origin/main`. **Pendiente heredado y actualizado:** el chequeo visual en PRODUCCION sigue abierto en `NEXT.md` hito `-53`, ahora con el footer de 4 columnas de f14 y una pasada en un evento `f1` y uno `f11`.

**DEUDA HEREDADA del addendum v1.6 (footer "en todas las paginas", estado actualizado en v1.7):** Direccion pidio el footer en **todas** las paginas. Inventario de partida: **16 silos** lo tienen encendido; de los templates **EN USO** (`eventos.template_id`) faltaban **(1) `f1`** (ninguna regla de `#mod-footer`, hay que activarlo + `grid-area` + fila `footer` en sus areas), **(2) `f11`** (`#mod-footer` aparece solo en la lista de **apagado** con `display:none !important`, `f11.css:163-175`: hay que sacarlo de ahi, activarlo y darle area) y **(3) `f12`**: **corregido contra el archivo real (ADR-006)** - `f12` **si esta completo**: fila `"footer footer"` en sus areas (`f12.css:299-310`), `grid-area: footer` (`:324`), activacion `display:block !important` (`:252-256`), estilos de franja (`:1716+`) y `order: 15 !important` en movil (`:1961`); **no requiere trabajo**. **`b5`** (`css/templates/campana/b5.css`) oculta el footer de forma **explicita** con comentario de *mandato explicito de Direccion* (`:505-517`): **NO tocarlo sin decision**. Ademas hay **3 eventos sin `template_id`** que replantearan el alcance cuando se asignen.

**Estado de la deuda tras el addendum v1.7 (mismo dia):** **`f14`**, **`f1`** y **`f11`** quedan **RESUELTOS** (f14 v1.7 commit `64c1de4`; f1 y f11 commit `ff83793`), todos con footer completo de 4 columnas, `grid-area` y fila en sus areas. **Solo quedan abiertos** `b5` (excluido por *mandato explicito de Direccion*, no se toca sin decision) y los **3 eventos sin `template_id`**, que replantearan el alcance al asignarse. El plan sugerido (una sola pasada CSS por silo + verificacion visual conjunta, sin tocar el kernel) se cumplio para f1/f11.







