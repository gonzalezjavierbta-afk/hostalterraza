# Plan: Template F9 "Místico" — Arreglo y Organización

**Fecha:** 2026-09-15
**Solicitante:** Usuario (evento prelanzamiento-mistico-9t39)
**Estado:** COMPLETADO — iteración v1 (reescritura del silo) + iteración v2 (átomo `#mod-descripcion`, meta 2 líneas, boletería, theme `mistico`). Ambas certificadas con Gold Shield. Ver `Sistema QR desarrollo/DECISIONS.md` ADR-041.

---

## Iteración v2 (2026-09-15) — COMPLETADO

> Segunda pasada de arreglo y organización sobre F9. Documentada como ADR-041 en `Sistema QR desarrollo/DECISIONS.md`. Working tree modificado, **sin commit** al momento del cierre documental.

**Archivos tocados:** `css/templates/fiesta/f9.css` (log de versiones v1.1.0), `evento.html`, `admin.html`.

**Cambios:**
- **`f9.css` (v1.1.0):** se apagan los módulos de campaña que no aplican a un prelanzamiento (`#mod-historia`, `#mod-objetivo`, `#mod-impacto`, `#mod-info-tecnica` — IDs intactos en el HTML, Cero Borrado) y se enciende en su lugar el átomo nuevo `#mod-descripcion`. Hero meta a 2 líneas (`.meta-line` / `.meta-line--2`). Lineup de escritorio (≥992px): headliner en columna izquierda + 6 artistas en 2 filas de 3; 1 columna por debajo. Grid desktop con `cartel|playlist` pareados. Footer minimal (base f8) en dorado con sello `- rastro mc`. `.form-tabs` centrado. Breakpoints portados de f8: 1279/991/767/640.
- **`evento.html`:** átomo nuevo `#mod-descripcion` (HTML + render) con fuente `effContent.descripcion || ev.descripcion` y fallback editorial del prelanzamiento del disco Místico de octubre (**fix H-1**). Hero meta 2 líneas vía `__metaSet`, solo `tpl-f9` (con fallback de 1 línea en los demás silos — **fix H-2**). FAQ fallback de 5 ejemplos solo para `tpl-f9`. Boletería f9: solo taquilla con precio real; preventa solo con precio real (oculta si vacía); módulo oculto si ninguna. WhatsApp sin número en el texto (**cambio GLOBAL** aprobado por el usuario; el `href` `wa.me` no cambia). Headliner del lineup marcado por NOMBRE (`RASTRO MC`).
- **`admin.html`:** card seleccionable `data-theme="mistico"` (P13) en el grupo Fiesta; `_THEME_TYPE['mistico']='fiesta'`; `_THEME_TPL['mistico']='f9'`; label en `names` (`P13 · Mistico`); inputs de `content.meta` (fecha/hora/lugar con `l1`/`l2`) + persistencia en `_buildConfigLanding()`, precarga en `_poblarContenidoWizard()` y limpieza en `_limpiarWizardCompleto()`.

**Contrato de datos nuevo (opcional y aditivo):** `config_landing.content.meta = { fecha:{l1,l2}, hora:{l1,l2}, lugar:{l1,l2} }`.

**Decisiones del usuario (v2):**
| Decisión | Elección |
|---|---|
| Cambio de WhatsApp | Sin número en el texto visible (aplica a TODOS los silos) |
| Módulos de campaña en F9 | Apagados (`historia`/`objetivo`/`impacto`/`info-tecnica`); reemplazados por `#mod-descripcion` |
| Boletería F9 | Solo tarifas reales; nunca tarjetas "POR DEFINIR" |
| FAQ F9 sin configurar | Fallback editorial de 5 preguntas (solo `tpl-f9`) |
| Meta del hero | 2 líneas configurables, con fallback a 1 línea |
| ADR-040 (cuenta master) | Solo diseño, NO implementado (queda pendiente en TSK-030) |

**QA (Escudo GOLD):** PASS en sintaxis JS (`node --check`), ASCII-safety de código, balance de divs/llaves/comentarios, Cero Borrado y grid. H-1/H-2 corregidos. **H-3** (FAQ de ejemplo hardcodeado para cualquier evento f9) y **H-4** (`formatWaPhone()` sin uso) quedan como observaciones aceptadas = deuda técnica TSK-031.

**Pendiente:** commit por Dirección; implementar ADR-040 (TSK-030); cargar fotos de artistas en `config_landing.content.dj_lineup`.

---

## Resultado (2026-09-15) — iteración v1

- `css/templates/fiesta/f9.css`: reescrito de 224 a ~2048 lineas. Paleta dorada "Mistico", activacion IoC de 20 modulos, grid desktop/mobile, lineup de fotografia predominante, REFLOW, responsive. ASCII 0 bytes >127, llaves balanceadas, 0 `:has()` anidados, 0 selectores muertos.
- `evento.html`: (1) segmento EXPERIENCIAS ampliado a `tpl-f9`; (2) headliner del lineup marcado por NOMBRE (`RASTRO MC`) con clase `.headliner` + `indexOf` robusto.
- Verificado contra Supabase: el evento `prelanzamiento-mistico-9t39` tiene `template_id='f9'`, `categoria_slug='fiesta'`, `color_primario='#c9a84c'`. 7 artistas en `dj_lineup`. El motor carga `f9.css` automaticamente.
- **Pendiente de datos (usuario):** cargar fotos de cada artista en `config_landing.content.dj_lineup` (hoy solo tienen `nombre`; sin foto cae al avatar por defecto y se pierde la predominancia fotografica).

---

## Objetivo

Reescribir `css/templates/fiesta/f9.css` (224 líneas actuales → ~1000+ líneas) para que:
1. Los selectores CSS coincidan con el DOM real de `evento.html`
2. Se activen todos los módulos que F9 necesita (el kernel IoC oculta todo)
3. El lineup use **fotografía predominante** (fotos grandes, no avatares circulares)
4. El headliner se identifique **por posición** (primer artista del lineup)
5. Se añadan hooks JS en `evento.html` para features F9-específicas
6. Se mantenga la paleta dorado oscuro "Místico"

---

## Decisiones del usuario (confirmadas)

| Decisión | Elección |
|---|---|
| Identificación de headliner | **Por posición** (`.artist-card:first-child`) — Opción A |
| Estilo de lineup | **Fotografía predominante** (fotos grandes, sin avatares circulares) |
| Evento en Supabase | **Ya existe** con slug `prelanzamiento-mistico-9t39` |
| Redes sociales del evento | Manejar en el lineup |

---

## Diagnóstico: F9.css actual vs DOM real

| Selectores en F9.css (224 líneas) | Problema | Selectores correctos en DOM |
|---|---|---|
| `#event-description` (línea 71) | **NO existe** en HTML | Eliminar — no hay equivalente |
| `.meta-bar` (línea 80) | No existe como clase padre | `#mod-hero-meta` es el contenedor; `.meta-item` sí existe |
| `.lineup-card` (línea 114) | **NO existe** | Genérico: `.artist-card` (evento.html línea 1181) |
| `[data-artist*="RASTRO MC"]` (línea 130) | **NO existe** `data-artist` | Usar `.artist-card:first-child` (posición) |
| `#mod-footer-brand` (línea 208) | **NO existe** | Footer usa `#footer-copy` (línea 1097) |
| Sin activación de display | Kernel IoC oculta todo | Patrón F5: declarar `display:flex/block` por módulo |
| Sin layout grid | `#main-content-flow` sin grid | Definir grid desktop/mobile |
| Sin countdown styling | `#unified-frame` sin estilos F9 | Estilos dorados |
| Sin info-técnica/FAQ/ubicación/sponsors/WhatsApp | Módulos sin estilos | Cobertura completa |
| Sin breakpoints responsive | Solo 1 media query | Responsive completo (768px, 480px) |
| Sin REFLOW rules | F8 usa `:has(#id[data-hidden])` | Añadir REFLOW |

---

## Inventario de módulos del DOM (evento.html)

| Línea | Sección ID | Clases | Contenido clave |
|---|---|---|---|
| 60 | `#mod-hero` | `.hero` | `#event-title`, `#org-name-badge`, `background-image` |
| 68 | `#unified-frame` | `.unified-countdown-frame` | `#cd-days/hours/mins/secs` |
| 77 | `#mod-hero-meta` | `.hero-meta` | `#meta-fecha`, `#meta-hora`, `#meta-lugar` (clase `.meta-item`) |
| 84 | `#mod-hero-ctas` | `.hero-ctas` | `#f6-hero-wa` |
| 101 | `#mod-historia` | `.historia-inner` | `#db-historia-titulo`, `#db-historia-img`, `#db-historia-texto` |
| 137 | `#mod-video` | — | `#db-gallery-grid`, `#db-video-content` |
| 147 | `#mod-cartel` | `.cartel-inner` | `#db-poster-img` |
| 153 | `#mod-lineup` | `.lineup-grid` | `#db-lineup` → `.artist-card[data-idx]` |
| 160 | `#mod-playlist` | — | `#db-spotify-embed` |
| 166 | `#mod-info-tecnica` | `.data-cards-container` | `#db-dress-val`, `#db-guest-val`, `#db-aforo-val`, `#db-ticket-val` |
| 188 | `#mod-faq` | — | `#db-faq-list` |
| 194 | `#mod-ubicacion` | — | `#db-mapa-container` |
| 206 | `#mod-boletos` | `.boleto-inner` | `#db-boletos-preventa`, `#db-boletos-taquilla` |
| 229 | `#mod-experiencias` | `.exp-inner` | `#db-experiencias-list` |
| 237 | `#mod-whatsapp` | `.whatsapp-inner` | `#db-whatsapp-btn`, `#db-whatsapp-text` |
| 247 | `#mod-sponsors` | — | `#db-sponsors-list` |
| 250 | `#mod-form` | `.form-master-box` | `#master-reg-form`, `#tab-new/tab-old` |
| 293 | `#mod-footer` | — | `#footer-copy` |

---

## Estructura del nuevo F9.css (~1000+ líneas)

```
1.  Variables Scoped y Reset
2.  Kernel IoC: Activación de Display (patrón F5)
3.  Layout Grid (#main-content-flow)
4.  Animaciones (f9FadeUp)
5.  Hero Section (#mod-hero)
6.  Countdown (#unified-frame)
7.  Metadata Bar (#mod-hero-meta)
8.  Hero CTAs (#mod-hero-ctas)
9.  Historia (#mod-historia)
10. Video & Galería (#mod-video)
11. Cartel (#mod-cartel)
12. Lineup — FOTOGRAFÍA PREDOMINANTE (#mod-lineup)
13. Playlist (#mod-playlist)
14. Info Técnica (#mod-info-tecnica)
15. FAQ (#mod-faq)
16. Ubicación (#mod-ubicacion)
17. Boletos (#mod-boletos)
18. Experiencias (#mod-experiencias)
19. WhatsApp (#mod-whatsapp)
20. Sponsors (#mod-sponsors)
21. Formulario (#mod-form)
22. Footer (#mod-footer / #footer-copy)
23. Breakpoints Responsive (768px, 480px)
24. REFLOW Rules (:has(#mod-X[data-hidden]))
```

---

## Tareas

| # | Tarea | Agente | Archivos | Dep. | Detalle |
|---|---|---|---|---|---|
| **T1** | Explorar selectores DOM | `@explore-free` | `evento.html` | — | Leer líneas 55-300 para mapear selectores exactos |
| **T2** | Reescribir f9.css completo | `@frontend-tpl-free` | `css/templates/fiesta/f9.css` | T1 | ~1000+ líneas. Paleta dorado oscuro. Fotografía predominante en lineup. Selectores corregidos. Display activation. Grid layout. Responsive. REFLOW. |
| **T3** | Añadir hooks JS para F9 | `@frontend-tpl-free` | `evento.html` | T2 | Extender condición título 2 líneas (línea 782: `tpl-f6 \|\| tpl-f8` → `tpl-f6 \|\| tpl-f8 \|\| tpl-f9`). Footer F9. Tab rename. |
| **T4** | Gold Shield f9.css | `@qa-auditor` | `css/templates/fiesta/f9.css` | T2 | Verificar selectores, ASCII-safety, syntax |
| **T5** | Gold Shield evento.html | `@qa-auditor` | `evento.html` | T3 | Verificar balance divs, ASCII-safety |

---

## Orden de ejecución

```
T1 (explorar) → T2 (reescribir f9.css) → T3 (hooks JS) → T4 + T5 (Gold Shield)
```

---

## Paleta F9 "Místico" (confirmada)

```css
--f9-bg: #0c0a08;
--f9-card-bg: #14110e;
--f9-gold: #d4af37;
--f9-gold-muted: #8c7323;
--f9-text: #f3f3f1;
--f9-muted: #a89f91;
--f9-border: rgba(212, 175, 55, 0.25);
```

---

## Lineup: Estilo Fotografía Predominante

- **Headliner**: `.artist-card:first-child` — foto grande a pantalla completa o casi, nombre dorado grande, posición destacada
- **Artistas normales**: fotos grandes (no avatares circulares), grid de 2-3 columnas desktop, 1 columna mobile
- **Sin glow**: `text-shadow/box-shadow/filter: none !important` (mantener estética sobria)
- **Animación**: `f9FadeUp` suave (ya definida)

---

## Criterios de éxito

1. `https://hostalterraza.vercel.app/evento.html?slug=prelanzamiento-mistico-9t39` carga con paleta dorado oscuro
2. Todos los módulos visibles tienen estilos F9 (no heredan defaults feos)
3. El lineup muestra fotos grandes con headliner destacado en dorado
4. El formulario, countdown, info-técnica, FAQ, ubicación, boletos, WhatsApp, sponsors, footer están estilizados
5. Responsive funciona en mobile (768px, 480px)
6. Gold Shield pass en ambos archivos
7. Cero regresiones en F8 y F6 (no se tocan selectores existentes)
