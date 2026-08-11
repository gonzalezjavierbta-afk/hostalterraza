# PRESENTACIÓN PROFUNDA — Sistema QR Hostal Terraza

**Fecha:** 11 de agosto de 2026 · **Estado auditado:** v1.6.4-FIX / Contrato v112 · **Autor:** Auditoría de ingeniería (análisis de código real + documentación ADR)

**Producto:** Plataforma Web SaaS multi-tenant de gestión de eventos, ticketing y control de aforo.
**Stack:** HTML5/CSS3/Vanilla JS (sin build tools) · Supabase (PostgreSQL + RLS + Auth + Edge Functions) · Resend (email) · Vercel CDN.
**URL producción:** https://hostalterraza.vercel.app · **Repo:** github.com/gonzalezjavierbta-afk/hostalterraza

---

## 1. CÓMO ESTÁ CONSTRUIDO EL SISTEMA (Arquitectura Real)

### 1.1 Componentes y su rol real

| Archivo | Rol documentado | Rol real verificado |
|---|---|---|
| `admin.html` (~8.000 líneas) | System Admin SaaS | Dashboard multi-tenant: Auth por roles, Wizard de 4 pasos (ADR-021), historial de eventos (ADR-022), invitadores con referidos, QR Links con tracking geo, panel de analítica con 4 pestañas (ADR-023), gestión de usuarios, separación Master Admin (ADR-025) |
| `evento3.html` (822 líneas) | "El Cerebro" (orquestador) | **Motor de landing**: lee `template_id`/`categoria_slug` de Supabase → inyecta CSS scoped `.tpl-{id}` con bypass de caché (`?v=Date.now()`); renderiza los átomos desde `config_landing`. Su formulario de registro es **stub** (solo campo nombre; pestaña "Recuperar" es un `alert` placeholder) |
| `evento.html` (6.073 líneas) | — | **Motor de registro real**: detecta theme por *palabras del slug* (arthouse, premiere-gold, neon-cult-cine, interactive-cine…), genera QR con `qr-creator`, valida aforo, ticket descargable con html2canvas. **NO lee `template_id`** |
| `serie.html` (1.021 líneas) | Motor de series | Registro multi-sesión con selector de fecha/sesión, aforo por sesión y QR propio (usa `qrcodejs`, no `qr-creator`) |
| `scanner.html` (1.016 líneas) | Puerta/Staff | Escáner con BarcodeDetector + jsQR fallback, modos cámara/manual/lista, verificación de identidad (cédula), anti-duplicado, multi-punto, tokens staff expirables, cola offline **en memoria** |
| `registro.html` | Onboarding SaaS | Alta de organizaciones en 3 pasos (nombre+slug, credenciales, plan) con auto-login y email de bienvenida |
| `qr.html` (116 líneas) | Marketing | Redirect tracker: captura dispositivo/SO/navegador + geo (ipapi.co) y registra en `qr_scans` |
| `index.html` | — | Motor de invitación **legacy** (redirige a `evento.html` si el evento tiene slug) |
| `evento2.html`–`evento7.html`, `eventobackup.html`, `eventovenezuela.html` | — | Motores alternativos/experimentales; `eventovenezuela` = campaña b5 con Lógica Dual-Phase (Fase 1 INSERT + Fase 2 UPDATE in-place) |

### 1.2 Flujo funcional del QR

```
Wizard admin (4 pasos) → INSERT en eventos (template_id, categoria_slug, captura_pura, config_landing)
   ↓ genera link público
evento.html?slug=... → registro del asistente → inscritos{qr_code:'QR-XXXXXXXX'} → ticket con QR (qr-creator)
   ↓                                              ↓
scanner.html?token=... → puerta: verificación de cédula → used=true + log (cola offline en memoria)
   ↓
Panel admin → analítica (KPIs, rankings, heatmaps, tabla de asistentes)
```

### 1.3 Base de datos

**Tablas (10+):** `organizaciones`, `perfiles`, `eventos`, `series`, `inscritos`, `clientes`, `invitadores`, `qr_links`, `qr_scans`, `logs`, `scanner_tokens`.

**Aislamiento:** RLS por `org_id = get_org_id()` con políticas `*_org`. **⚠️ Conviven políticas legacy permisivas que anulan el aislamiento en la práctica (TSK-026).**

**Edge Functions:** `send-ticket-email` (Resend) en uso. `wompi-webhook` documentada pero **no implementada**.

---

## 2. ANÁLISIS — FORTALEZAS

1. **Costo casi cero**: $0/ticket, $0/evento (solo infraestructura Supabase/Vercel). La competencia cobra $10–$50/mes o ~$2–3/ticket.
2. **Diferenciales reales frente al mercado** (ver `analisis/COMPARATIVO competencia.md`): verificación por cédula (últimos 4 dígitos), tokens de staff por punto de acceso con expiración, referidos/invitadores con tracking, QR links con analítica geo, marca blanca por organización, operación offline, check-in multi-punto.
3. **Disciplina de ingeniería documentada**: 25 ADRs, Contrato de Datos (21 átomos soberanos), protocolo "Cero Borrado", scoped CSS por silo (`.tpl-{id}`), Escudo de Auditoría GOLD (INFO/DEBUG/LINK/TRACE/TIME/ERROR). Nivel de trazabilidad profesional.
4. **Carga instantánea y portabilidad**: Vanilla JS sin framework → adecuado para móviles de gama baja y eventos con mala cobertura.
5. **SaaS multi-tenant ya operativo**: onboarding, roles (superadmin/admin_evento/portero), aislamiento por org, panel de sistema global.

---

## 3. PROBLEMAS CRÍTICOS DETECTADOS (por severidad)

### 🔴 CRÍTICOS — Seguridad y datos

1. **TSK-026 — Fuga cross-tenant por RLS**: políticas legacy permisivas en `eventos` ("Admins escriben eventos", ALL sin org_id), `clientes` (ALL sin chequeo) y `perfiles` (`is_superadmin()` sin acotar + update sin `WITH CHECK` que permite auto-escalación de rol) conviven (OR, no reemplazo) con las políticas `_org` correctas. Cualquier usuario autenticado puede leer/escribir datos de otras organizaciones. Riesgo #1.
2. **TSK-025 — Migración sin ejecutar**: `adr025_master_admin_separation.sql` es un runbook guiado pendiente. Desplegar `admin.html` (que ya asume `is_master_org`) sin ejecutarlo deja a la org maestra sin Panel de Sistema. Además, las nuevas políticas `insert_organizaciones` (superadmin de org maestra) **romperían el auto-registro de `registro.html`** (inserta la org antes de crear el usuario con key anon).
3. **Claves hardcodeadas en ~19 archivos**, incluidos backups dentro del repo (`admin bacup.html`, `eventobackup.html`, `eventovenezuela backup.html`). El JWT anon está en un repo público; rotarlo rompería todo el frontend → sin estrategia de rotación segura.
4. **XSS endémico**: interpolación directa de datos de BD en `innerHTML` en scanner, index, cliente, evento y evento3.

### 🔴 CRÍTICOS — El producto no hace lo que se promete

5. **TSK-017 — El Wizard persiste el template pero el link NO lo usa**: `admin.html` genera links a `evento.html`, que detecta theme por palabras del slug (solo themes de cine). El motor que sí lee `template_id` (`evento3.html`) no está enlazado. **Resultado: elegir "Tropical Hostel f1" o "Emergencia b5" en el Wizard no tiene efecto visual en el link compartido.** Contradicción de arquitectura más grave.
6. **TSK-016 — `captura_pura` se persiste pero ningún motor la consume**: el toggle "Evento sin QR / Captura pura" del Wizard no hace nada aún (requiere consumo en el motor público: omitir QR y mostrar agradecimiento).
7. **TSK-018 — Columnas sin confirmar en Supabase real**: `template_id`, `categoria_slug`, `captura_pura` (`adr021_eventos_columns.sql` idempotente sin ejecutar). Si no existen, los INSERTs de `admin.html` fallan.

### 🟠 ALTOS — Fiabilidad operativa

8. **Cola offline NO persiste en localStorage**: es un array solo en memoria (`offlineQueue`). Se pierde al recargar la página; y si la página carga ya estando offline, `cargarCache()` retorna temprano → cache vacío → el modo offline no funciona en el caso más crítico. Contradice lo documentado ("cola de sincronización localStorage").
9. **Bugs concretos en scanner.html**:
   - Selector `'undo-btn-${ins.id}'` con string literal (líneas 905 y 947) → nunca encuentra el botón → nunca se auto-oculta.
   - `undoCheckinScanner` borra logs con `resultado='Ingreso'` exacto, pero en multi-punto el log se inserta como `'Ingreso · <punto>'` → el log no se elimina y el QR queda bloqueado para ese punto.
   - `tipoMap` con clave `frecuente` duplicada.
   - Branding `document.querySelector('.brand')` apunta a un selector inexistente en el DOM (`scanner-brand` es el real).
10. **Cuatro motores de registro coexistiendo** (`evento.html`, `serie.html`, `index.html`, `evento3.html`) con lógica divergente: anti-duplicado no atómico (TOCTOU), aforo inconsistente (index.html no lo verifica), librerías QR distintas (qrcodejs en serie/index vs qr-creator en el resto).
11. **Formulario de `evento3.html` es stub**: el "Cerebro" documentado no puede registrar a nadie (pestaña "Recuperar" = alert placeholder).

### 🟡 MEDIOS

12. **TSK-023** — patrón de null-pointer sin auditar en `renderEventos()`/`renderInvitadoresPerfil()` (mismo bug que ya tumbó el Panel para Barrio R10, ADR-024).
13. **Realtime deshabilitado** (ADR-004) → polling de 30s: contador de aforo del scanner con latencia de hasta 30s.
14. **Código muerto/duplicado en repo**: `evento2–7.html`, 3 backups, `b5 - copia.css`, `f1 - copia.css`, `c1 gemini/notepad/bigpickle/opencode.css`. Riesgo de editar el archivo equivocado.
15. **Edge Function `send-ticket-email`** invocada con key anon en header `Authorization: Bearer` (debería usar `service_role` de servidor o validación de origen); además el email de bienvenida de `registro.html` envía `qrCode: base + '/admin.html'` (semántica incorrecta: no es un QR).
16. **Vulnerabilidades funcionales menores**: QR de 8 caracteres alfanuméricos (`QR-XXXXXXXX` ≈ 2.8×10¹³ combos — aceptable pero no ideal para eventos de gran escala); logo base64 corrupto en index.html; lugar hardcodeado "Hostal R10" en tickets de index.html.
17. **`cliente.html`**: updates (tags, VIP, nota, Instagram) sin try/catch ni verificación de respuesta → fallan en silencio; `data.nombre.split` sin guard contra null (regresión ADR-024).

---

## 4. PROS Y CONTRAS (Resumen Ejecutivo)

| PROS | CONTRAS |
|---|---|
| Costo marginal $0 (vs $2–3/ticket de la competencia) | Riesgo de fuga de datos multi-tenant activo (TSK-026) |
| Diferenciales que nadie ofrece completos: cédula + tokens por punto + referidos + tracking geo + marca blanca + offline | El template elegido en el Wizard no se aplica al link compartido (TSK-017) |
| Trazabilidad ADR de nivel profesional (25 decisiones documentadas) | 4 motores de registro duplicados = mantenimiento frágil |
| Carga instantánea, sin framework ni node_modules | Deuda de seguridad: XSS, claves expuestas, Edge Function sin protección |
| SaaS multi-tenant operativo (auth por roles, aislamiento, panel global) | Monetización inexistente (Wompi sin integrar, TSK-001/002/008) |
| Verificación de identidad por cédula = anti-fraude real | Sin Wallet, sin auto-check-in, sin POS/taquilla, sin app nativa |
| Panel de analítica completo (KPIs, rankings, heatmaps, export) | 4 migraciones SQL pendientes de ejecución manual |
| Operación offline y check-in multi-punto operativos | Cola offline en memoria (no persistida) + bugs en undo |

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

## 6. GUÍA DE TRABAJO A SEGUIR (Plan de Mejora Priorizado)

### Fase 0 — Estabilizar el piso (1–2 días, sin código nuevo)
1. Ejecutar migraciones en orden: `adr021_eventos_columns.sql` → `adr025_master_admin_separation.sql` (runbook guiado con pasos manuales de Dashboard) → verificar integridad con `adr024_audit_nulls_inscritos.sql`.
2. **TSK-026**: nuevo Context Package para retirar políticas RLS legacy (auditando antes cada flujo público que depende de ellas: registro, scanner, página de evento, panel).
3. Plan de secreto: mover claves a Vercel env vars y sacar backups del repo (gitignore) para permitir rotación futura de la anon key.

### Fase 1 — Cerrar la contradicción de arquitectura (TSK-016/017/018)
4. **TSK-017**: decidir motor público único.
   - **Recomendación A**: `evento3.html` como motor de landing (ya consume `template_id`) + `evento.html` como capa de registro con un solo archivo unificado.
   - **Recomendación B**: trasladar la lógica de registro/ticket de `evento.html` a `evento3.html` y desactivar `evento.html`.
   - Actualizar `admin.html` para enlazar al motor correcto (hoy enlaza a `evento.html`).
5. **TSK-016**: consumir `captura_pura` en el motor elegido (mensaje de agradecimiento sin QR).
6. Consolidar la generación de QR en **qr-creator** (único estándar CSP-safe) y eliminar `qrcodejs`.

### Fase 2 — Blindar scanner y offline (1–2 días)
7. Persistir `offlineQueue` en `localStorage` con reintento en el evento `online`; cargar cache incluso si se inicia offline.
8. Corregir los 3 bugs de scanner (undo-btn, undo multi-punto, tipoMap) + sanitizar `innerHTML` con función de escape.
9. **TSK-005**: dashboard contextual del portero (contador vs aforo + últimos 5 ingresos) — ya especificado en TASKS.

### Fase 3 — Higiene del repo (medio día)
10. Archivar/eliminar: `evento2–7.html`, 3 backups, `b5 - copia.css`, `f1 - copia.css`, variantes `c1 *.css`. Actualizar PROJECT.md/BLUEPRINT.md para declarar cuál es "El Cerebro" vigente.

### Fase 4 — Monetización y conversión (sprint siguiente)
11. **TSK-001/002**: Widget Wompi en `registro.html`/renovación + Edge Function `wompi-webhook` con firma HMAC.
12. **TSK-003**: pg_cron para recordatorios 24h antes vía `send-ticket-email`.
13. **TSK-006**: PWA (manifest.json + Service Worker) para scanner instalable.
14. **TSK-004**: lista de espera para eventos con aforo completo.

### Fase 5 — Diferenciales comerciales (backlog)
15. **TSK-009**: tickets digitales Wallet Apple/Google (.pkpass) — alto valor percibido.
16. Auto check-in self-service, POS/taquilla en sitio, certificados PDF.

### Protocolo de verificación de cada entrega (Reglas de Oro #12)
- Escudo de Auditoría GOLD: logs INFO / DEBUG / LINK / TRACE / TIME / ERROR.
- Parser HTML5 con pila de elementos (detectar desbalance de anidación, lección ADR-021 §8).
- `node --check` sobre el JS.
- Prueba de Carga Dual (mobile + desktop, fidelidad de 1px).
- Auditoría contra `DECISIONS.md` / `BLUEPRINT.md` antes de escribir código (Fase de Interrogación Prioritaria).

---

*Documento elaborado el 11-ago-2026 a partir de auditoría de código real (admin.html, evento.html, evento3.html, serie.html, scanner.html, registro.html, index.html, cliente.html, qr.html), documentación ADR (v1.15-GOLD) y comparativa de mercado. Complementa a `analisis/COMPARATIVO competencia.md`.*
