# PRESENTACIÓN PROFUNDA — Sistema QR Hostal Terraza

**Fecha:** 07 de septiembre de 2026 · **Estado auditado:** v307 / Contrato v112 · **Autor:** Re-auditoría de ingeniería (código real 07-sep-2026 + documentación ADR)

**Producto:** Plataforma Web SaaS multi-tenant de gestión de eventos, ticketing y control de aforo.
**Stack:** HTML5/CSS3/Vanilla JS (sin build tools) · Supabase (PostgreSQL + RLS + Auth + Edge Functions) · Resend (email) · Vercel CDN.
**URL producción:** https://hostalterraza.vercel.app · **Repo:** github.com/gonzalezjavierbta-afk/hostalterraza

---

## 1. CÓMO ESTÁ CONSTRUIDO EL SISTEMA (Arquitectura Real)

### 1.1 Componentes y su rol real (07-sep-2026)

| Archivo | Rol documentado | Rol real verificado |
|---|---|---|
| `admin.html` (~8.000 líneas) | System Admin SaaS | Dashboard multi-tenant: Auth por roles, Wizard de 4 pasos (ADR-021), historial de eventos (ADR-022), invitadores con referidos, QR Links con tracking geo, panel de analítica (ADR-023), gestión de usuarios, separación Master Admin (ADR-025). Persiste `template_id`, `categoria_slug`, `captura_pura` y `config_landing` (content/modules/colors). Incorpora campos nuevos de ADR-030 (sistema dual), ADR-031 (tipo_interesado) y ADR-034 (cabezote). |
| `evento.html` (~6.200 líneas) | "El Cerebro" real (landing + registro) | Motor definitivo del landing. Lee `ev.template_id` + `ev.categoria_slug` → `injectAtomicCSS()` inyecta el CSS scoped `.tpl-{id}` con bypass de caché (`?v=Date.now()`) y fija la clase `tpl-{id}` en `<body>` (TSK-017 relacionado). Renderiza los átomos desde `config_landing`. Registro con **captura dual ADR-030** (comunidad WhatsApp); **boletería v303** (compra por WhatsApp); **gamas cromáticas v305** (paleta derivada del color del evento, f8); **módulos vacíos ocultos v306**; **reflow de grillas v307**; QR con `qr-creator`; ticket descargable con html2canvas. |
| `serie.html` (1.021 líneas) | Motor de series | Registro multi-sesión con selector de fecha/sesión, aforo por sesión y QR propio. **Sigue usando `qrcodejs`** (violación ADR-002; pendiente migrar a `qr-creator`). |
| `scanner.html` (~1.016 líneas) | Puerta/Staff | Escáner con BarcodeDetector + jsQR fallback, modos cámara/manual/lista, verificación de identidad (cédula), anti-duplicado, multi-punto, tokens staff expirables y **cola offline en memoria** (pendiente persistir en localStorage). |
| `registroaforo.html` | Formulario público de registro/aforo | Página "Registro · Hostal Terraza", enlazada desde `config_landing.content.form_solo.url` (`?slug=...`). Usa la misma arquitectura de módulos (`#main-content-flow`, `#mod-hero`, `cabezote-*`). Es el formulario externo para eventos configurados en modo formulario singular. |
| `registro.html` | Onboarding SaaS | Alta de organizaciones en 3 pasos (nombre+slug, credenciales, plan) con auto-login y email de bienvenida. |
| `qr.html` (116 líneas) | Marketing / redirect tracker | Captura dispositivo/SO/navegador + geo (ipapi.co) y registra en `qr_scans`. |
| `index.html` (~984 líneas) | Homepage pública — cartelera y presentación | Presenta el sistema (hero con propuesta "Registra invitados con WhatsApp…", sección #sistema "Tres pasos. Una puerta sin filas", features chips), cartelera filtrable por categoría/estado con datos reales, sección #landings con mockups de plantillas (f8 TropiLove, c1 Noche de estreno, b5 Campaña), CTA y stats. Ya no es solo el motor de invitación legacy. |
| `eventologs.html` | Trazabilidad / visor de logs | "Master Orchestrator v21x", Escudo de Grano (v47): visor de logs (INFO/DEBUG/LINK/TRACE/TIME/ERROR) del sistema. |
| `cliente.html` | Auto-gestión del asistente | Consulta/edición del invitado (tags, VIP, nota, Instagram). Pendiente guard contra `data.nombre.split` null (regresión ADR-024). |
| `evento2.html`–`evento7.html`, `eventobackup.html`, `eventovenezuela*.html`, backups | Motores alternativos/experimentales | Mantenidos como archivo/respaldo. Riesgo: editar el archivo equivocado. |
| ~~`evento3.html`~~ | ~~"El Cerebro"~~ | **No existe en el repo** (nunca trackeado ni eliminado vía git). La documentación legada lo menciona; sus responsabilidades fueron absorbidas por `evento.html`. |

### 1.2 Flujo funcional actual del QR

```
Wizard admin (4 pasos) → INSERT en eventos (template_id, categoria_slug, captura_pura, config_landing)
   ↓ genera link público
evento.html?slug=...
   → injectAtomicCSS(categoria_slug, template_id) → clase .tpl-{id} en <body> + CSS de silo scoped
   → paleta cromática del evento (v305): gamas derivadas de --master-accent del evento (f8)
   → módulos sin contenido se ocultan (v306) y el grid de 2 columnas se reordena (v307)
   → registro del asistente → inscritos{qr_code:'QR-XXXXXXXX'}
   → opción "Únete a la comunidad de WhatsApp" (ADR-030): redirige a la comunidad O guarda solo en BD
   → boletería preventa/taquilla → compra cerrada por WhatsApp (v303)
   → ticket con QR (qr-creator) + descarga
   ↓                                              ↓
scanner.html?token= → puerta: verificación de cédula → used=true + log (cola offline en memoria)
   ↓
Panel admin → analítica (KPIs, rankings, invitadores, geo, clicks data-track ADR-032 en landing)
```

### 1.3 Base de datos

**Tablas (10+):** `organizaciones`, `perfiles`, `eventos`, `series`, `inscritos`, `clientes`, `invitadores`, `qr_links`, `qr_scans`, `logs`, `scanner_tokens`.

**Aislamiento:** RLS por `org_id = get_org_id()` con políticas `*_org`. **⚠️ Conviven políticas legacy permisivas que anulan el aislamiento en la práctica (TSK-026 — sigue abierto).**

**Migraciones presentes en `migrations/`:** `adr030_sistema_dual_csv.sql`, `adr031_inscritos_tipo_interesado.sql`, `adr032_landing_analytics.sql`, `adr033_modo_publico.sql`, `adr034_cabezote_formulario.sql`.

**Estado de las migraciones del informe anterior:** las columnas `template_id`, `categoria_slug` y `captura_pura` (ADR-021) están claramente **en uso** (evento.html y admin.html las leen/escriben) → verificadas en la práctica. `adr024` (auditoría de nulls) y `adr025` (separación master admin) → **estado por confirmar** (no están en la carpeta `migrations/`; `admin.html` ya asume `is_master_org`).

---

## 2. ANÁLISIS — FORTALEZAS

1. **Costo casi cero**: $0/ticket, $0/evento (solo infraestructura Supabase/Vercel). La competencia cobra $10–$50/mes o ~$2–3/ticket.
2. **Diferenciales reales frente al mercado** (ver `analisis/COMPARATIVO competencia.md`): verificación por cédula (últimos 4 dígitos), tokens de staff por punto de acceso con expiración, referidos/invitadores con tracking, QR links con analítica geo, marca blanca por organización, operación offline, check-in multi-punto.
3. **Disciplina de ingeniería documentada**: 30+ ADRs, Contrato de Datos, protocolo "Cero Borrado", scoped CSS por silo (`.tpl-{id}`), Escudo de Auditoría GOLD (INFO/DEBUG/LINK/TRACE/TIME/ERROR). Nivel de trazabilidad profesional.
4. **Carga instantánea y portabilidad**: Vanilla JS sin framework → adecuado para móviles de gama baja y eventos con mala cobertura.
5. **SaaS multi-tenant ya operativo**: onboarding, roles (superadmin/admin_evento/portero), aislamiento por org, panel de sistema global.
6. **Landing verdaderamente por evento (mejoras 08-09/2026)**:
   - El template elegido en el Wizard **se aplica al link compartido** (vía `template_id` → `.tpl-{id}`, TSK-017 resuelto).
   - **Paleta cromática del evento** (v305): f8/TropiLove deriva sus gamas neón (pinky/purple/yellow/blue, glows, aurora) del `--master-accent` del evento (complementario/análogos/tríada) vía utilidad propia hex↔HSL + `color-mix()`.
   - **Módulos vacíos ocultos** (v306): las secciones sin contenido se ocultan sin inyectar fallbacks demo (cartel, videos, playlist, sponsors, FAQ, experiencias, boletería…).
   - **Reflow de grillas** (v307): en escritorio/tablet, cuando un módulo oculto comparte fila con otro (cartel|playlist, boletos|form, faq|ubicacion, video|playlist…), el compañero se expande a la fila completa (`data-hidden` + `:has()`). Aplicado a f8, f6, f3 y b4.
   - **Captura dual (ADR-030)**: el formulario permite elegir "Únete a la comunidad de WhatsApp" (redirección `wa.me`) o guardar el registro sin redirección.
   - **Boletería por WhatsApp** (v303): preventa/individual y taquilla/pareja con compra cerrada por chat.
   - **Landing analytics** (ADR-032): clicks de boletería, artistas, FAQ, galería, sponsors y WhatsApp medidos (`data-track`).
   - **Analítica de visitas y logs**: `eventologs.html` como visor de trazabilidad GOLD.
7. **Formulario singular de aforo** (`registroaforo.html`, ADR-034): cabezote y registro externo para eventos configurados con `form_solo`.

---

## 3. PROBLEMAS PENDIENTES (por severidad) — estado 07-sep-2026

### 🔴 CRÍTICOS — Seguridad y datos

1. **TSK-026 — Fuga cross-tenant por RLS [ABIERTO]**: políticas legacy permisivas en `eventos`, `clientes` y `perfiles` conviven (OR, no reemplazo) con las políticas `_org` correctas. Riesgo #1. Requiere nuevo Context Package para retirarlas auditando antes cada flujo público.
2. **TSK-025 — Migración sin confirmar [POR VERIFICAR]**: `adr025_master_admin_separation.sql` no está en `migrations/`. `admin.html` ya asume `is_master_org` → sin la migración, la org maestra queda sin Panel de Sistema. Además, nuevas políticas insert_organizaciones podrían romper el auto-registro de `registro.html`.
3. **Claves hardcodeadas en ~19 archivos**, incluidos backups dentro del repo. El JWT anon está en un repo público; rotarlo rompería todo el frontend → sin estrategia de rotación segura.
4. **XSS endémico [ABIERTO]**: interpolación directa de datos de BD en `innerHTML` en scanner, index, cliente y evento. `cliente.html` aún hace `data.nombre.split` sin guard contra null (regresión ADR-024).

### 🟠 ALTOS — Fiabilidad operativa

5. **Cola offline NO persiste en localStorage [ABIERTO]**: `offlineQueue` es un array solo en memoria (`scanner.html`). Se pierde al recargar; y si la página carga ya offline, la caché queda vacía → el modo offline falla en el caso crítico.
6. **Bugs concretos en scanner.html [ABIERTO]**:
   - Selector `'undo-btn-${ins.id}'` como string literal (no template literal) → el botón nunca se encuentra → nunca se auto-oculta ni se deshabilita correctamente.
   - `undoCheckinScanner` borra logs con `resultado='Ingreso'` exacto, pero en multi-punto el log se inserta como `'Ingreso · <punto>'` → el log no se elimina y el QR queda bloqueado para ese punto.
   - `tipoMap` con clave `frecuente` duplicada.
   - Branding `document.querySelector('.brand')` apunta a un selector inexistente (`scanner-brand` es el real) → `data-org` nunca se aplica.
7. **`serie.html` sigue usando `qrcodejs` [ABIERTO]**: violación ADR-002 (CSP). Pendiente migrar a `qr-creator` (mismo estándar que el resto).
8. **TSK-016 — `captura_pura` sin consumo en el motor público [ABIERTO]**: el toggle "Evento sin QR / Captura pura" del Wizard no hace nada aún (requiere omitir QR y mostrar agradecimiento en `evento.html`).
9. **Cuatro motores de registro coexistiendo [PARCIAL]**: `evento.html`, `serie.html` y backups con lógica divergente. `evento3.html` ya no existe (el "Cerebro" documentado era el ruido). Pendiente consolidar `serie.html` y retirar backups.
10. **ADRs del informe anterior**: `adr024`/`adr025` sin localizar en `migrations/` → ejecución por confirmar.

### 🟡 MEDIOS

11. **Realtime deshabilitado** (ADR-004) → polling de 30s: contador de aforo del scanner con latencia de hasta 30s.
12. **Código muerto/duplicado en repo**: `evento2–7.html`, 3 backups, `b5 - copia.css`, `f1 - copia.css`, variantes `c1 *.css`. Riesgo de editar el archivo equivocado.
13. **Edge Function `send-ticket-email`** invocada con key anon en header `Authorization: Bearer` (debería usar `service_role` de servidor o validación de origen); el email de bienvenida de `registro.html` envía `qrCode: base + '/admin.html'` (semántica incorrecta).
14. **QR de 8 caracteres alfanuméricos** (`QR-XXXXXXXX` ≈ 2.8×10¹³ combos — aceptable pero no ideal para gran escala); logo base64 corrupto en `index.html`; lugar hardcodeado "Hostal R10" en tickets legacy.
15. **Monetización inexistente [ABIERTO]**: Wompi solo se menciona en `f7.html`; sin pasarela, sin wallet, sin POS, sin app nativa, sin PWA (no hay `manifest.json`/Service Worker).

---

## 4. PROS Y CONTRAS (Resumen Ejecutivo, 07-sep-2026)

| PROS | CONTRAS |
|---|---|
| Costo marginal $0 (vs $2–3/ticket de la competencia) | Riesgo de fuga de datos multi-tenant activo (TSK-026) |
| **El template del Wizard ya se aplica al link compartido** (template_id → .tpl-{id}) | 3+ motores de registro duplicados = mantenimiento frágil |
| Landing por evento: paleta del evento, módulos vacíos ocultos, reflow desktop (v305–v307) | Deuda de seguridad: XSS, claves expuestas, Edge Function sin protección |
| Captura dual (comunidad WhatsApp) y boletería por WhatsApp operativas | Cola offline en memoria (no persistida) + bugs en undo del scanner |
| Trazabilidad ADR de nivel profesional (30+ decisiones documentadas) | Migraciones viejas (adr024/025) por confirmar |
| Carga instantánea, sin framework ni node_modules | Monetización inexistente (Wompi sin integrar) |
| Verificación de identidad por cédula = anti-fraude real | Serie.html usa qrcodejs (violación ADR-002) |
| Operación offline y check-in multi-punto operativos | Sin Wallet, sin auto-check-in, sin POS/taquilla, sin PWA/app nativa |

---

## 5. OPCIONES DE MERCADO (posicionamiento)

Según `analisis/COMPARATIVO competencia.md`, tres rutas viables:

1. **Modelo Universe / TicketGenerator (recomendado)**: gratis y sin comisión en eventos free; comisión solo cuando hay venta. Baja fricción, captura volumen, compite con Eventbrite local.
2. **Suscripción por volumen (modelo Peewah / Darkaa)**: desde ~$28–63/mes. Referencia Colombia: Peewah PRO desde $115.000 COP/mes, BoletaOficial Básico $134.900 / Profesional $254.900 COP/mes. El sistema propio equivale al núcleo de esos productos a costo cero.
3. **Licenciamiento / marca blanca B2B a hostales y recintos**: la ventaja estructural (hostal = eventos recurrentes propios) se vende como SaaS de "control de acceso a eventos de huéspedes" a otros hostales/hoteles de Bogotá.

**Faltantes que la competencia monetiza y el sistema propio no**: venta con pasarela (PSE/Wompi), certificados PDF, Wallet/PDF premium, auto check-in self-service, POS/taquilla en sitio, app nativa. Son los ítems que justifican cobrar.

**Comparativa de precio clave (2026):**

| Plataforma | Modelo | Valor |
|---|---|---|
| Ticket Tailor | $0/mo + fee | ~$2.70/ticket |
| TicketSpice | Por orden/ticket | $0.99 + 2.5% o $1.24/ticket |
| Eventbrite | % + fee | 2.5% + $0.99 |
| Universe | Por ticket | $1.49 + 4.5% (pagado) |
| Pretix Hosted | % o por ticket free | 2.5% (máx €15) / €0.50 por ticket free |
| Peewah (CO) | Suscripción | gratis ≤60 asistentes; PRO ~$115.000 COP/mes |
| BoletaOficial (CO) | Suscripción | Básico $134.900 COP/mes |
| **Sistema propio** | **Infraestructura** | **$0 por ticket / $0 por evento** |

---

## 6. GUÍA DE TRABAJO A SEGUIR (Plan de Mejora Priorizado, 07-sep-2026)

### ✅ Completado (08–09/2026)
1. **TSK-017 (resuelto)**: el template del Wizard ahora se aplica al landing (`evento.html` consume `template_id` → `.tpl-{id}`; CSS scoped con bypass de caché).
2. **Landing por evento (v305–v307)**: paleta cromática derivada del color del evento; módulos vacíos ocultos; reflow de grillas escritorio/tablet en f8, f6, f3, b4.
3. **Captura dual ADR-030** en el formulario de registro (comunidad WhatsApp) + migración `adr030_sistema_dual_csv`.
4. **Boletería por WhatsApp (v303)** y etiquetas INDIVIDUAL/PAREJA para f8.
5. **Analítica de landing (ADR-032)** con clicks medidos (`data-track`).
6. **Formulario singular de aforo** (`registroaforo.html`, ADR-034) y cabezote configurable.
7. **Homepage pública** (`index.html`) que presenta el sistema y la cartelera.

### Fase 0 — Estabilizar el piso (sin código nuevo)
1. Ejecutar/confirmar migraciones: localizar `adr024_audit_nulls_inscritos.sql` y `adr025_master_admin_separation.sql` (no están en `migrations/`); verificar integridad de columnas `template_id`/`categoria_slug`/`captura_pura`.
2. **TSK-026**: nuevo Context Package para retirar políticas RLS legacy (auditando antes cada flujo público: registro, scanner, página de evento, panel).
3. Plan de secreto: mover claves a Vercel env vars y sacar backups del repo (gitignore) para permitir rotación futura de la anon key.

### Fase 1 — Consolidar el motor único y el modo público
4. **TSK-016**: consumir `captura_pura` en `evento.html` (mensaje de agradecimiento sin QR).
5. **ADR-033 — Modo público**: operativizar la migración en el motor público.
6. Consolidar la generación de QR en **qr-creator** (único estándar CSP-safe), incluyendo `serie.html` (eliminar `qrcodejs`).

### Fase 2 — Blindar scanner y offline (1–2 días)
7. Persistir `offlineQueue` en `localStorage` con reintento en el evento `online`; cargar caché incluso si se inicia offline.
8. Corregir los 3 bugs de scanner (undo-btn, undo multi-punto, tipoMap) + el branding `.brand` → `scanner-brand` + sanitizar `innerHTML` con función de escape.
9. **TSK-005**: dashboard contextual del portero (contador vs aforo + últimos 5 ingresos) ya especificado en TASKS.

### Fase 3 — Higiene del repo (medio día)
10. Archivar/eliminar: `evento2–7.html`, 3 backups, `b5 - copia.css`, `f1 - copia.css`, variantes `c1 *.css`. Actualizar PROJECT.md/BLUEPRINT.md para declarar **evento.html como "El Cerebro" vigente** (borrar referencias a `evento3.html`).

### Fase 4 — Monetización y conversión (sprint siguiente)
11. **TSK-001/002**: Widget Wompi en `registro.html`/renovación + Edge Function `wompi-webhook` con firma HMAC (hoy solo mención en `f7.html`).
12. **TSK-003**: pg_cron para recordatorios 24h antes vía `send-ticket-email`.
13. **TSK-006**: PWA (manifest.json + Service Worker) para scanner instalable.
14. **TSK-004**: lista de espera para eventos con aforo completo.

### Fase 5 — Diferenciales comerciales (backlog)
15. **TSK-009**: tickets digitales Wallet Apple/Google (.pkpass).
16. Auto check-in self-service, POS/taquilla en sitio, certificados PDF.

### Protocolo de verificación de cada entrega (Reglas de Oro #12)
- Escudo de Auditoría GOLD: logs INFO / DEBUG / LINK / TRACE / TIME / ERROR.
- Parser HTML5 con pila de elementos (detectar desbalance de anidación, lección ADR-021 §8).
- `node --check` sobre el JS.
- Prueba de Carga Dual (mobile + desktop, fidelidad de 1px).
- Auditoría contra `DECISIONS.md` / `BLUEPRINT.md` antes de escribir código (Fase de Interrogación Prioritaria).

---

*Documento re-auditado el 07-sep-2026 a partir de código real (admin.html, evento.html, scanner.html, index.html, serie.html, registro.html, registroaforo.html, cliente.html, qr.html, eventologs.html), migraciones (adr030–034), documentación ADR y las mejoras v302/v303/v305/v306/v307 del motor landing. Complementa a `analisis/COMPARATIVO competencia.md`.*