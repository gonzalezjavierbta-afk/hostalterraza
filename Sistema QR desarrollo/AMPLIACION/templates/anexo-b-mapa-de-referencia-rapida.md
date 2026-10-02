---
doc: TEMPLATES.md — Anexo B
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L352-373 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L352-373 del original).

## Anexo B. Mapa de Referencia Rápida

| Concepto | Archivo real | Referencia |
|---|---|---|
| **Motor publico (reconciliado ADR-048, 2026-09-22)** | **`evento-app.html`** (1724 lineas, "Master Orchestrator v214"); `vercel.json` reescribe `/evento.html` → `/api/evento-og` | Inyección: `injectAtomicCSS` L598-638; doble clase L691-693; `#mod-hero-ctas` oculto L33 + HTML L84 |
| Kernel IoC (`display:none` inicial) | `evento.html` | ≈L30 (section/header/footer), ≈L32 (`#mod-hero-ctas`) |
| Inyección del silo | `evento.html` | `injectAtomicCSS` ≈L598-638; `<link data-template-css>` ≈L601 |
| Fallback de carga CSS | `evento.html` | `landing.css_error` ≈L687 |
| Clase de ámbito en body | `evento.html` | ≈L692-694 (doble CASING: `tpl-{template_id}` + `tpl-{id}` minúscula — ver Cap. 8 punto 3) |
| Acento maestro | `evento.html` | ≈L677-681 (`--master-accent`) |
| Puente cromático HSL | `evento.html` | ≈L701-752 (`__hexToHsl`/`__hslToHex`) |
| Silos canónicos | `css/templates/fiesta/f9.css`, `f10.css`, `f11.css` | f9 ADR-041; f10 v2.0.0 ADR-042; f11 v3.2.0 ADR-043 |
| **Silo f12 "Kande" (ADR-048)** | `css/templates/fiesta/f12.css` | v1.0.0, 1563 lineas, 50294 bytes, ASCII limpio, 193/193 llaves, 0 `@import` reales, 14 modulos ON / 9 OFF, 5 media queries, hero sin 100vh; assets `assets/templates/f12/` (pendientes, fallback ADR-008) |
| **Silo f9b "Mistico Nocturno" (ADR-054/055; v1.3.0 ADR-060)** | `css/templates/fiesta/f9b.css` | **v1.3.0** (base v1.0.0), **2922 lineas**, **369 `.tpl-f9b` (vivos) + 365 `.Tpl-F9b` (muertos, ADR-057)**, 0 selectores fuera de scope, **17 modulos ON / 10 OFF**, canal `fx-*` (parallax ON por defecto), silo INDEPENDIENTE de `f9` (ambos VIVOS); silo sostenido solo por la mitad `.tpl-f9b`. **v1.3.0 (2026-09-29, ADR-060):** video `#db-video-content` **full-bleed banner** + `#mod-hero-meta .meta-line` **centrada en todos los breakpoints** + **click-to-play `youtube-nocookie` con fallback externo persistente** (excepción acotada ADR-005, solo f9b) |
| **Vista previa del silo (ADR-056 / ADR-057)** | `evento-app.html?preview=1` + `sessionStorage['ht_preview_payload']` | `admin.html:5694` (escribe) / `:5713` (iframe) / `:5721` (pestana); kernel `__evDesdePreview()` `evento-app.html:891-911`; **preview == produccion** (sin override `Tpl-`) |
| Registro de themes (6 puntos, patrón `abrirFichaTheme`) | `admin.html` | `.ld-theme-card` L606 (kande) · `_THEME_TYPE` ≈L2830 · `_THEME_TPL` ≈L2844 · `_THEME_MODULES` ≈L2858-2879 (19 themes, ADR-047) · `_THEME_FICHA` ≈L3075+ (kande L3103-3104) · `names` ≈L3235 · `config_global` ≈L2920+ (ADR-040/045) |
| Contrato de Datos | `BLUEPRINT.md` | Sección 4, v112, 21 Átomos Soberanos |
| Reglas de oro | `Reglas de Oro QR.md` | 16 Mandatos v127-MASTER |
| Inventario del DOM real | `evento-app.html` | **Anexo C** (inventario completo por bloque; nota: `#db-gallery-grid` L148 dentro de `#mod-video` L147) |

---

