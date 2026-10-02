---
doc: TEMPLATES.md — Anexo C
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L374-503 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L374-503 del original).

## Anexo C. Inventario del DOM Real de evento.html (~81 IDs)

> ⚠️ **Líneas aproximadas a la fecha 2026-09-16** (ADR-006): el archivo puede moverse con cada entrega. Verificar SIEMPRE con `grep` antes de usar un selector; las líneas citadas son orientativas. El kernel real es v214+ (interno v222, ~81 IDs, 1630 líneas aprox.).
>
> **Reconciliado 2026-09-22 (ADR-048):** el archivo real de este inventario es **`evento-app.html`** en el repositorio (1724 lineas; `evento.html` es solo el link publico reescrito por Vercel hacia `/api/evento-og`). Hechos clave del kernel real: **`#db-gallery-grid` (L148) vive DENTRO de `#mod-video` (L147)** — un silo que apague `#mod-video` oculta la galeria; `#mod-hero-ctas` (L84, con ancla `--lineup` hacia `#mod-lineup` L86) nace con `display:none !important` (L33) y exige encendido explicito via CSS del silo.

### BLOQUE A — Hero / título / meta / countdown / ctas (~L55-87)

| ID | Función |
|---|---|
| `#main-content-flow` | `<main>` grid único: TODOS los módulos `#mod-*` son hermanos planos, reordenables vía `grid-area` |
| `#mod-hero` | Header del hero (sección principal) |
| `#org-name-badge` | Insignia del nombre de la organización (esquina superior) |
| `#event-title` | Título del evento (átomo del contrato) |
| `#unified-frame` | Frame unificado: countdown (y reutilizado por video en algunos silos) |
| `#cd-days` / `#cd-hours` / `#cd-mins` / `#cd-secs` | Dígitos del countdown (00 por defecto) |
| `#mod-hero-meta` | Meta del hero (fecha/hora/lugar) |
| `#meta-fecha` / `#meta-hora` / `#meta-lugar` | Valores de la meta (2 líneas soportadas: `.meta-line`, `.meta-line--2`) |
| `#mod-hero-ctas` | CTAs del hero — **nace oculto por el kernel** (solo lo enciende `tpl-f6` vía CSS) |
| `#f6-hero-wa` | CTA WhatsApp del hero ("COMPRA ENTRADAS AHORA", `hero-cta-btn--wa`) |

### BLOQUE B — Historia / Descripción / Objetivo / Impacto (~L90-138)

| ID | Función |
|---|---|
| `#mod-historia` | Módulo de historia (campaña) |
| `#db-historia-titulo` | Título de la historia |
| `#db-historia-img` | Imagen de la historia (fallback: `onerror` oculta) |
| `#db-historia-texto` | Texto de la historia |
| `#mod-descripcion` | Átomo NUEVO (ADR-041, silo f9): descripción del evento |
| `#db-descripcion-titulo` / `#db-descripcion-texto` | Título y texto de la descripción |
| `#mod-objetivo` | Módulo de objetivo/recaudo (campaña) |
| `#db-objetivo-recaudado` / `-meta` / `-donantes` | Stats del objetivo |
| `#db-objetivo-barra` / `#db-objetivo-pct` | Barra de progreso y porcentaje |
| `#mod-impacto` | Módulo de impacto (campaña) |
| `#db-impacto-grid` | Grid de tarjetas de impacto (`.impacto-card`, `.impacto-card--metrica`, `.impacto-card--donacion`) |

### BLOQUE C — Video / Galería / Cartel / Lineup / Playlist / Info-técnica (~L140-195)

| ID | Función |
|---|---|
| `#mod-video` | Módulo de video (miniature HD, ADR-005 — prohibido iframe; excepto la excepción acotada ADR-060, solo silo f9b, click-to-play youtube-nocookie con fallback externo) |
| `#db-gallery-grid` | Grid de galería (N abierto; `.gallery-item` + `.lightbox-trigger`) |
| `#db-video-content` | Contenedor del video 16:9 (min-height 400px en playlist) |
| `#mod-cartel` | Cartel/póster del evento |
| `#db-poster-img` | Imagen del póster (con `lightbox-trigger` agregado por JS) |
| `#mod-lineup` | Lineup de artistas |
| `#db-lineup` | Lista de artistas (`.artist-card`, `.artist-card.headliner`, `.artist-photo`, `.artist-overlay`, `.artist-name`, `.artist-hora`, `.artist-resena`, `.artist-social`, `.artist-social-icon`) |
| `#mod-playlist` | Playlist de Spotify |
| `#db-spotify-embed` | Contenedor del embed |
| `#mod-info-tecnica` | Datos técnicos (Dresscode, Guest, Aforo, Ticket) — Geist 900 + drop-shadow (Mandato 8) |
| `#db-dress-val` / `#db-guest-val` / `#db-aforo-val` / `#db-ticket-val` | Valores de la info técnica (`.card-item`, `.data-cards-container`) |

### BLOQUE D — FAQ / Ubicación (~L197-206)

| ID | Función |
|---|---|
| `#mod-faq` | Preguntas frecuentes |
| `#db-faq-list` | Lista de FAQs (`.faq-item`, `.faq-answer`, `.faq-icon-circle`; toggle `active` por click) |
| `#mod-ubicacion` | Ubicación del evento |
| `#db-mapa-container` | Contenedor del mapa (height 380px inline) |

### BLOQUE E — Boletos / Experiencias / WhatsApp / Sponsors (~L208-257)

| ID | Función |
|---|---|
| `#mod-boletos` | Boletería (preventa/taquilla, tabs) |
| `#db-boletos-preventa` | Tarjetas de preventa |
| `#db-boletos-taquilla` | Tarjetas de taquilla |
| `#mod-experiencias` | Experiencias del evento |
| `#db-experiencias-list` | Grid de experiencias (`.exp-card`, `.exp-titulo`, `.exp-tag`) |
| `#mod-whatsapp` | CTA WhatsApp |
| `#db-whatsapp-btn` / `#db-whatsapp-text` | Botón y texto de WhatsApp |
| `#mod-sponsors` | Patrocinadores |
| `#db-sponsors-list` | Lista de sponsors (`.sponsor-item`, `.sponsor-img`) |

### BLOQUE F — Formulario dual (~L259-279)

| ID | Función |
|---|---|
| `#mod-form` | Módulo del formulario (Dual-Phase, ADR-011) |
| `.form-master-box` | Caja maestra del formulario (max-width 550px inline) |
| `.form-tabs` / `.tab-btn` | Tabs "nuevo/ya" del formulario |
| `#tab-new` / `#tab-old` | Botones de pestaña (switchForm('nuevo'/'ya')) |
| `#form-nuevo` | Formulario de registro nuevo |
| `#master-reg-form` | Form maestro (inscripción comunidad) |
| `#reg-nombre` / `#reg-whatsapp` | Campos nombre + WhatsApp |
| `#reg-unir-comunidad-wrap` / `#reg-unir-comunidad` / `#reg-comunidad-msg` | Checkbox comunidad + mensaje |
| `#form-ya` | Formulario de recuperación |
| `#rec-cedula` | Campo cédula (verificación) |

### BLOQUE G — Equipo / CTA-final / Footer (~L281-325)

| ID | Función |
|---|---|
| `#mod-equipo` | Equipo organizador |
| `#db-equipo-grid` | Grid de equipo (`.equipo-item`, `.equipo-avatar`, `.equipo-nombre`, `.equipo-rol`) |
| `#mod-cta-final` | CTA final (donación) |
| `#db-cta-final-titulo` / `#db-cta-final-subtitulo` | Título y subtítulo del CTA |
| `#cta-final-btn` | Botón CTA final (scroll al form) |
| `#mod-footer` | Footer del evento |
| `#footer-org-name` / `#footer-tagline` | Nombre y tagline de la org |
| `#db-footer-links` | Links del footer |
| `#db-footer-social` | Redes sociales |
| `#db-footer-contacto` | Contacto |
| `#footer-copy` | Copy del footer (f8 lo sobrescribe con "Chokoflow") |
| `.htz-powered` | Badge "Powered by Hostal Terraza" (inyectado por JS, ≈L1167) |

### CLASES KERNEL generadas por JS (única fuente válida de selectores por clase)

| Familia | Clases |
|---|---|
| Lineup | `.artist-card`, `.artist-card.headliner`, `.artist-photo`, `.artist-overlay`, `.artist-name`, `.artist-hora`, `.artist-resena`, `.artist-social`, `.artist-social-icon` |
| Galería | `#db-gallery-grid .gallery-item`, `.lightbox-trigger` |
| Boletos | `.boleto-card-row`, `.boleto-icon`, `.boleto-tipo`, `.boleto-precio`, `.boleto-desc`, `.boleto-arrow` |
| Formulario | `.form-master-box`, `.form-tabs`, `.tab-btn`, `.btn-submit` |
| Impacto | `.impacto-card`, `.impacto-card--metrica`, `.impacto-card--donacion` |
| Sponsors | `.sponsor-item`, `.sponsor-img` |
| Equipo | `.equipo-item`, `.equipo-avatar`, `.equipo-nombre`, `.equipo-rol` |
| Experiencias | `.exp-card`, `.exp-titulo`, `.exp-tag` |
| FAQ | `.faq-item`, `.faq-answer`, `.faq-icon-circle` |
| Info-técnica | `.card-item`, `.data-cards-container` |

### MÓDULOS DE CAMPAÑA que un silo de fiesta debe APAGAR por defecto (IDs intactos)

`#mod-historia`, `#mod-objetivo`, `#mod-impacto`, `#mod-info-tecnica`, `#mod-whatsapp`, `#mod-sponsors` — se ocultan con `display:none !important`, NUNCA se borran (Cero Borrado). En el silo **b5** (campaña) además: `#mod-impacto-historico`, `#mod-mapa-crisis`, `#mod-como-ayudar` (átomos de campaña de v110, extensión del silo b5).

---

*Documento sellado bajo el estandar de calidad de $10,000. v1.7.0 - Template Hub Normativo (ADR-006: todos los datos verificados contra archivos reales del repositorio; ADR-048: reconciliacion del motor real `evento-app.html` y silo f12 "Kande" 2026-09-22; v1.5.0: patron recomendado de salvaguarda por ALTURA del hero movil f12, 2026-09-23; v1.6.0: silo f9b "Mistico Nocturno" (ADR-054/055/056) + AVISO NORMATIVO capital-T / mitad `.Tpl-*` muerta en produccion (ADR-057) + contrato de vista previa, 2026-09-26; v1.7.0: excepcion acotada ADR-060 (salvedad "prohibido iframe" solo silo f9b) + silo f9b v1.3.0 video full-bleed banner / meta centrada / click-to-play, 2026-09-29).*
