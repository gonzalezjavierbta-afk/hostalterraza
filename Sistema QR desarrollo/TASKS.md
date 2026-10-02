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
| [TSK-089](TASKS-DETALLE.md#tsk-089) | Direccion (con soporte `@frontend-tpl`/`@docs-keeper`) | COMMIT + PUSH + ADR de la frontera dura | Modulo Guest List (card de beneficio) en el silo F9B… | L106-107 |
| [TSK-081 (c)](TASKS-DETALLE.md#tsk-081-c) | Direccion (con soporte `@sql-security` - PRO, es seguridad/endpoint) | DEUDA ASOCIADA, ya representada por TSK-003: el envio de correo depende de la Edge Function `send-ticket-email`, que NO vive en este… | Formulario de entrega y recuperacion de QR en… | L110-110 |
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
| **TSK-099** | Lead Developer (ADM) + Chief Architect (ADR) | **Permitir invocar los 16 subagentes desde `free-plan`/`free-build` sin cambiar de tier** — pendiente para la proxima sesion | Gobernanza de tier (ADR-069) | Ver nota completa al final del documento. **Hallazgo verificado 2026-10-02:** la allow-list de `permission.task` en `.opencode/agent/free-build.md` y `free-plan.md` es IDENTICA y autoriza 7 de 16 subagentes; quedan en `deny` (via `"*": deny`) los 9 de riesgo: `admin-dev`, `architect-review`, `architect`, `backend-dev`, `data-migration`, `renderer-dev`, `research-agent`, `seo-dev`, `sql-security`. **Aclaracion importante: en la sesion del 2026-10-02 los subagentes SI se invocaron sin error de permiso** (`explore` x2, `js-silo-dev`, `frontend-tpl` x2, `qa-auditor`, `docs-keeper` = 7 despachos, 7 informes recibidos); el fallo fue de PRESUPUESTO DE TURNOS, no de permiso. La correccion sigue siendo necesaria para delegar dominios de riesgo, pero NO explica los 3 agotamientos. |

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

## TSK-099 — Habilitar los 16 subagentes en ruta FREE (nota para la proxima sesion, 2026-10-02)

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


