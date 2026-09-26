# 🛡️ PROJECT.md — Sistema QR Hostal Terraza (v1.6.5-FIX)

## 1. Información General
*   **Nombre del Proyecto:** Sistema QR Hostal Terraza.
*   **Tipo de Producto:** Plataforma Web de Gestión de Eventos, Ticketing y Control de Aforo (SaaS Multi-tenant).
*   **Ubicación de Referencia:** Bogotá, Colombia.
*   **Estado del Sistema:** **v1.6.5-FIX** — Piloto Oficial de AI-DOS v1.2 / Baseline f1 Certified. Wizard Inteligente de Creación (ADR-021), navegación en pestañas de Admin (ADR-022) y Panel (ADR-023), fix "Null Pointer Regression" en el panel (ADR-024) y Separación Master Admin/Barrio R10 (ADR-025, código entregado, SQL de producción pendiente de ejecución — ver TSK-025) entregados en `admin.html`. **ADR-048 (2026-09-22):** silo f12 "Kande" (`css/templates/fiesta/f12.css` v1.0.0) entregado + theme `kande` registrado en el Wizard (6 puntos) + **reconciliación estructural: `evento.html` NO existe como archivo — el motor real es `evento-app.html`** (ver Sección 6 y `TEMPLATES.md`). **ADR-054/055/056/057 (2026-09-25/26):** silo **f9b "Mistico Nocturno"** (NUEVO e INDEPENDIENTE de f9; `css/templates/fiesta/f9b.css` v1.0.0, 2922 lineas, parallax premium) + theme `mistico-nocturno` (6 puntos) + canal de efectos `fx-*` + consolidación de los 15 solapamientos del formulario + **el conteo de themes curados sube a 20 (ADR-048 decía 19)** + **ADR-057: el bloque `.Tpl-*` está muerto en producción en todos los silos** (el kernel solo emite `tpl-` minúscula). Revisión arquitectónica APROBADO (0 bloqueantes) y QA APTO (`express_check` 12/0, smoke f9b 61/0); semilla pendiente de Dirección (TSK-070).
*   **Framework de Coordinación:** **AI-DOS v1.2 (PM Hub Engine)**.
*   **Estándar de Calidad:** Calidad Percibida de **$10,000** (Fidelidad de 1px, Afterglow visual, Geist 900).
*   **URL Producción:** [https://hostalterraza.vercel.app](https://hostalterraza.vercel.app).
*   **Repositorio Oficial:** [GitHub - Hostal Terraza](https://github.com/gonzalezjavierbta-afk/hostalterraza).

## 2. Visión y Objetivos
### 2.1 Objetivo Funcional
Construir una infraestructura modular e independiente para la gestión digital de eventos, eliminando la dependencia de procesos manuales (listas de papel) y automatizando el control de acceso y monetización en tiempo real.

### 2.2 Objetivo Metodológico (Piloto Oficial AI-DOS v1.2)
Validar el framework **AI-DOS v1.2** en un entorno de producción real, certificando la eficiencia de la **Dirección Agéntica** y el uso de **Context Packages** para el desarrollo asistido por múltiples IAs.

## 3. Stack Tecnológico y de Mando
*   **Cerebro PM & Knowledge Layer:** **NotebookLM** (Vinculado dinámicamente a Google Drive).
*   **Frontend:** HTML5, CSS3, JavaScript puro (Vanilla JS) sin herramientas de compilación para portabilidad absoluta y carga instantánea.
*   **Backend / DB:** **Supabase** (PostgreSQL, Edge Functions, Auth, Storage, RLS).
*   **Email Engine:** **Resend**.
*   **Hosting:** **Vercel CDN**.

## 4. Gobernanza de Roles (Matrix v1.2)
| Rol | Implementación | Especialidad |
| :--- | :--- | :--- |
| **Project Manager Hub** | **NotebookLM** | Centralización de la verdad y generación de órdenes técnicas. |
| **Chief Architect** | **Claude** | Lógica estructural, ADRs y validación de fidelidad de 1px. |
| **Lead Developer** | **Gemini / Cursor** | JS, SQL, Integración de APIs (Wompi) y despliegue. |
| **Creative Director** | **Open Design** | UI/UX Premium y CSS Atómico Scoped. |
| **QA Specialist** | **Claude** | Auditoría de integridad y Escudo GOLD. |

## 5. Reglas de Oro Irrenunciables (v127-MASTER)
1.  **Prioridad Estructural (Data-First):** Certificar el flujo de datos (Logs TRACE) antes de aplicar cualquier estilo visual.
2.  **Protocolo de "Cero Borrado":** Prohibido eliminar IDs del **Contrato de Datos v110** (#event-title, #db-lineup), incluso si no son visibles.
3.  **Aislamiento Atómico (Scoped CSS):** Todo el CSS debe encapsularse bajo el selector `.tpl-{template_id}` para evitar colisiones entre silos.
4.  **Regla de Bloque sobre Flex:** Los contenedores de módulos masivos (video, lineup) deben usar `display: block !important` para garantizar el centrado y expansión total.
5.  **Silent Fallback de Activos:** Todo elemento `<img>` dinámico debe incluir `onerror` para evitar íconos de imagen rota si la URL de Supabase falla.
6.  **Eliminación de Respiros Multimedia:** El módulo de video debe usar `padding-top: 0 !important` para integrarse visualmente con el bloque superior (Countdown/Meta).

## 6. Arquitectura Modular y Biblioteca de Silos (v1.6.0-GOLD)
El sistema ha evolucionado de un modelo monolítico a un modelo de **Categorías y Templates Independientes (Silos Atómicos)**.

### 🎬 Silos Operativos Validados
*   **Cinematografía (`cine`):** c1 (Arthouse) y c2 (Premiere Gold).
*   **Fiesta (`fiesta`):** **f1 (Tropical Hostel)** ✅ Certificado v1.6.0 (Selina Style, verde selva y madera) y f2 (Rooftop Sunset). Silos adicionales verificados en `css/templates/fiesta/` al 15/09/2026: f3, f5 (Afromango), f6 (Afromango Editor), f7 (Tropical Brutalism - motor independiente `f7.html`), f8 (TropiLove), f9 (Mistico - ADR-041) y **f10 (Rico - Cyberpunk Fosforescente, v2.0.0 - ADR-042, evento `rico-5mw5` en produccion)** y **f11 (Cyberpunk Fosforescente, v3.3.3 / 1595 lineas reales - ADR-043 fix mobile hero + ADR-044 registro del theme `fosforescente` en el Wizard)** y **f12 (Kande - Tropical Noir Brutalista - ADR-048, v1.0.0 / 1563 lineas, silo NUEVO `css/templates/fiesta/f12.css`, theme `kande` registrado en el Wizard - 6 puntos: card L606 + `_THEME_TYPE` L2830 + `_THEME_TPL` L2844 + `_THEME_MODULES` L2875 + `_THEME_FICHA` L3103-3104 + `names` L3235; 19 tarjetas `.ld-theme-card` totales **en 2026-09-22** — **corregido a 20 tarjetas / 20 themes en 2026-09-26 con la entrada de f9b "Mistico Nocturno" (ADR-054)**; 14 modulos ON / 9 OFF; hero sin 100vh; lista para evento `kande-musica-tradicional-del-caribe-colombiano-kk4c`, D1 plantilla pendiente en Supabase - TSK-045)** y **f9b (Mistico Nocturno - Dorado Antiguo / Profundidad Suave - ADR-054/055/056/057, v1.0.0, silo NUEVO e INDEPENDIENTE de f9 `css/templates/fiesta/f9b.css`, 2922 lineas, 17 modulos ON / 10 OFF, parallax premium + paleta dorada calida + profundidad suave; theme `mistico-nocturno` registrado en el Wizard - 6 puntos: card L627 + `_THEME_TYPE` L3001 + `_THEME_TPL` L3021 + `_THEME_MODULES` L3073 + `_THEME_FICHA` L3307-3308 + `names` L3439; el reset "cero brillo" de f9 NO se hereda; semilla `seed_f9b_mistico_nocturno_prueba.sql` versionada y pendiente de Direccion - TSK-070)**. **RECONCILIACION ESTRUCTURAL (ADR-048, 2026-09-22):** **`evento.html` NO existe como archivo en el repo — el motor publico real es `evento-app.html`** (1724 lineas, "Master Orchestrator v214"); `vercel.json` reescribe `/evento.html` → `/api/evento-og` y ese endpoint sirve `evento-app.html`; `injectAtomicCSS` (L598-638) inyecta `css/templates/{categoria}/{template_id}.css` (L600-601); doble clase `tpl-{id}`/`tpl-{lower}` al body (L691-693); `#db-gallery-grid` (L148) dentro de `#mod-video` (L147); `#mod-hero-ctas` nace `display:none !important` (L33); sin override `?tpl=`/`?cat=`; `MODULE_IDS` ausente en v214. Las citas previas a `evento.html` como archivo/unico motor en este documento se conservan (Cero Borrado) y se leen desde este ADR como el link publico reescrito por Vercel. **Hub normativo de silos:** `Sistema QR desarrollo/AMPLIACION/TEMPLATES.md` (**v1.4.0, 2026-09-22 — banner de reconciliacion + silo f12 + registro corregido a 6 puntos con `abrirFichaTheme`**, v1.3.0 de 438 lineas en ADR-046) + skill puente `.opencode/skills/templates/SKILL.md` (ADR-046). **Catálogo curado por la cuenta master (ADR-040/045):** la cuenta master puede ocultar/reordenar el catalogo de plantillas del Wizard para todas las organizaciones via `config_global` (tabla de fila unica + RLS + RPC `fn_config_global_merge`; contrato `{version:2, hidden, order}`); migracion `migrations/adr040_config_global_templates.sql` **pendiente de ejecucion manual por Direccion** (TSK-035) — sin ella el front degrada a fail-open (todo visible). **ADR-049 (2026-09-22):** el silo f12 recibio un ciclo de iteracion visual **100% CSS-only** (v1.3.0 -> v1.9.0; `f12.css` real en HEAD = 2423 lineas / 86600 bytes / 22 IDs `#mod-*` intactos) desplegado en `main`/Vercel; el contenido visible del hero/meta/CTA/footer quedo temporalmente fijado en CSS con plan de migracion a datos (D1-D6 / TSK-051..TSK-056). Ver `DECISIONS.md` ADR-049. **Ciclo hero movil (2026-09-23):** el hero movil de f12 recibio el ciclo express v1.13.0 -> v1.13.3 (titulo ~75vw, cinta de subtitulo 54% -> 67%, letra de cinta mayor, ceja/titulo bajados hasta 5vh); **v1.13.3** agrega una **salvaguarda anti-solape** en anchos de tablet/landscape (**481-767px**) que limita el titulo por ALTURA (`--f12-title-size: clamp(3rem, min(24vw, calc(20vh - 4rem)), 11.5rem)`) y recorta el badge a `3vh`, sin afectar telefonos (`<=480px`). Commits `f45f651` (v1.13.0), `daa1755` (v1.13.1), `1fbd8a6` (v1.13.2), `8209af2` (v1.13.3 + docs). Patron registrado en `AMPLIACION/TEMPLATES.md` Cap. 5 (v1.5.0); deuda preexistente del hero (`min-height:100vh/100svh` en movil) registrada como TSK-063.
*   **Campaña (`campana`):** b1 (Solidario Moderno), b4 (Vintage & Orgánico) y b5 (Emergencia Crítica).

## 7. Evolución del Contrato de Datos (v110) y Funcionalidad
*   **Expansión de Átomos (20 Átomos Soberanos):** Incorporación de componentes clave de campaña e impacto: `#meta-magnitud`, `#mod-mapa-crisis`, `#mod-como-ayudar` y `#mod-impacto-historico`.
*   **Innovación Funcional (Lógica Dual-Phase):** Implementada en `eventovenezuela.html` (Registro ➔ Perfilamiento in-place) como el estándar de alta conversión del sistema.
*   **Catálogo de Plantillas Curado por la Cuenta Master (ADR-040 → IMPLEMENTADO, ADR-044/045/046):** la cuenta master puede **ocultar y reordenar** el catálogo de plantillas del Wizard para todas las organizaciones. Fuente de verdad: `public.config_global` (fila única `id='default'`, columna `templates jsonb`, `updated_at`, `updated_by`) creada por `migrations/adr040_config_global_templates.sql` (idempotente, aditiva, RLS SELECT authenticated / escritura solo master vía helper `is_master_org_user()` SECURITY DEFINER, y **RPC `fn_config_global_merge(jsonb)`** con merge JSONB server-side + `updated_by=auth.uid()` + validación ERRCODE 42501). Contrato vigente: `{"version": 2, "hidden": [slugs], "order": [slugs]}`. UI: sub-tab **"Plantillas"** en `pg-globaladmin` (`gaTab('plantillas')`) con MOSTRAR/OCULTAR/REORDENAR, bloqueo duro de catálogo en cero y aviso suave por categoría. Ocultar es **curación de catálogo/UX, NO seguridad** (la página pública no consulta `hidden`; no hay allowlist en el guardado; eventos con template oculto conservan su `template_id` al editarse — revelación legacy no persistente). **Pendiente:** ejecutar la migración en Supabase (TSK-035) — sin la tabla el front degrada a fail-open (todo visible), no bloquea.

## 8. Gobernanza y Calidad ($10,000 Standard)
*   Uso mandatorio de tipografía **Geist 900** y efectos **Afterglow** como identidad visual técnica.
*   Obligatoriedad del **Escudo de Auditoría GOLD** (INFO, DEBUG, LINK, TRACE, TIME) para cada nueva "Cara" visual entregada.

## 9. Roadmap Inmediato
*   **TSK-016/017/018 (ADR-021, prioridad inmediata):** Cerrar el Wizard Inteligente de Creación — consumir `captura_pura` en `evento.html`, reconciliar `evento.html` vs. `evento3.html` como motor público vigente, y ejecutar la migración SQL de `template_id`/`categoria_slug`/`captura_pura`.
*   **TSK-SQL:** Migración masiva de nomenclatura en Supabase (P# -> c#/f#/b#).
*   **TSK-001:** Integración del widget de pagos **Wompi** en `registro.html`.
*   **TSK-002:** Edge Function `wompi-webhook` para activación automática de organizaciones.
*   **TSK-V03:** Despliegue de miniaturas YouTube (ADR-005) en los templates existentes.

---
*Este documento constituye la **Única Fuente de Verdad** estratégica del proyecto (Consolidado sin pérdida bajo Mandato v127).*