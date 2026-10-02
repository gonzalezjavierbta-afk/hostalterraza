---
doc: TEMPLATES.md — 8
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L208-240 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L208-240 del original).

## 8. Inyección y Puente Cromático (Cómo se Monta el Silo)

> **Decisión de Dirección (zanjada):** el silo NO se monta por hoja `<link>` estática en el HTML; lo inyecta el kernel de `evento.html` en runtime. Documentado del código REAL (ADR-006):

> **NOTA de reconciliacion (ADR-048, 2026-09-22):** los numeros de linea de este capitulo (L598-638, L677-681, L692-694, L701-752) corresponden al archivo real **`evento-app.html`** (motor publico; `evento.html` no existe como archivo — ver banner del documento). El texto original se conserva intacto (Cero Borrado); desde este ADR todo `evento.html` kernel se lee como `evento-app.html`.

1. **Propósito:** `injectAtomicCSS(cat, tplId)` (≈`evento.html` L598-638) construye el path `css/templates/{categoria_slug}/{template_id}.css?v={Date.now()}` y lo inyecta en un `<link data-template-css>` (≈L601) — el bypass de caché `?v=timestamp` certifica con latido LINK del Escudo GOLD (Mandato 4).
2. **Timeout:** 5000 ms; ante fallo, el kernel muestra el texto de error del i18n (`landing.css_error`, ≈L687) — fallback de idioma incluido.
3. **Clase de ámbito — DOBLE NOTACIÓN DE CASING (⚠️ leer con el AVISO NORMATIVO de arriba + ADR-057):** el kernel escribe en `document.body` DOS clases (`evento-app.html:998-1000`): `tpl-{template_id}` (tal cual viene en `eventos.template_id` — p.ej. `tpl-Mistico` o `tpl-f9b`) y `tpl-{id}` (en minúsculas — p.ej. `tpl-mistico` o `tpl-f9b`). **Nunca capitaliza.** **Por qué existe la doble notación:** algunos eventos traen `template_id` en mayúsculas ("F10") y otros en minúsculas ("f10"); el JS del kernel usa `document.body.className.includes('tpl-f8')` / `.indexOf('tpl-f9')` con minúsculas para activar sus subconmutaciones. **Regla (norma del hub, Cero Borrado):** todo selector de silo declara la doble forma `.tpl-fXX, .Tpl-FXX`. **⚠️ REALIDAD MEDIDA (ADR-057, 2026-09-26):** la forma `.Tpl-{id}` **NUNCA matchea en produccion** (el kernel no emite `Tpl-`); es **código muerto** y se conserva por Cero Borrado hasta resolver el ADR-057. Un silo que solo tenga `.Tpl-*` estaria **apagado**; un silo que solo tenga `.tpl-*` funciona. En `f9b.css`: 369 `.tpl-f9b` (vivos) + 365 `.Tpl-F9b` (muertos).
4. **Acento maestro:** `--master-accent` se deriva de `ev.color_primario || content.color_primario || content.accent_color` (≈L677-681) y el silo la consume para CTAs/accentos.
5. **Puente cromático HSL:** las funciones `__hexToHsl`/`__hslToHex` (≈L701-752) permiten derivar variantes armónicas; f8 (TropiLove) y f9 (Místico) las usan para subconmutaciones de paleta derivada.
6. **Subconmutaciones JS del kernel (REALES, checks sobre `document.body.className` con `includes`/`indexOf`):**
   - **`tpl-f6`** (≈L793): título en 2 líneas físico (`hero-title-line1` / `hero-title-line2`).
   - **`tpl-f8`** (≈L731, L843, L1152, L1265, L1552): paleta neón derivada; tab del formulario; footer con marca "Chokoflow" en `#footer-copy`; boletos preventa "INDIVIDUAL" / taquilla "PAREJA"; lineup Maqueta B; experiencias (L1338 comparte con f9).
   - **`tpl-f9`** (≈L817, L1235, L1377, L1559): meta del hero en 2 líneas (`meta-line`/`meta-line--2`); headliner marcado por NOMBRE ("RASTRO MC"); FAQ fallback editorial cuando el evento no trae FAQ; boletería por tarifa real (sin "POR DEFINIR"); experiencias (L1338).
   - **POLÍTICA:** una subconmutación nueva NO se implementa en la entrega del silo — es cambio de kernel de `evento.html` y se escala al Plan (nuevo ADR/TSK). El silo solo estiliza las subconmutaciones que el kernel ya activa.
7. **Prohibido:** iframe de YouTube (ADR-005; excepto la excepción acotada ADR-060, solo silo f9b, click-to-play youtube-nocookie con fallback externo); `<img>` sin `onerror` fallback (ADR-008); `invert`/`brightness` en logos sin alfa.
8. **VISTA PREVIA (`?preview=1`) — CONTRATO (ADR-056, 2026-09-26).** El wizard de `admin.html` puede renderizar el silo elegido **sin publicar y sin tocar Supabase**: escribe el borrador en `sessionStorage['ht_preview_payload']` (`admin.html:5694`) y monta `evento-app.html?preview=1` en un iframe (`admin.html:5713`) o en una pestaña (`:5721`). El kernel lo lee con `__evDesdePreview()` (`evento-app.html:891-911`), una funcion **pura de lectura** que viste el JSON con la MISMA forma de una fila de `eventos` y reutiliza integro el render. **Contrato del payload (estable):** `{ ev, content, theme, template_id, categoria_slug, effects }`. **REGLA DE FIDELIDAD (ADR-057): `preview == produccion`.** El adaptador pasa el `template_id` **SIN capitalizar**; el body del preview lleva **exactamente** la misma clase que produccion (`tpl-f9b tpl-f9b`). Prohibido reintroducir un override de casing `Tpl-` en el preview: introduciria una divergencia preview≠produccion. El fallback de error (`__renderPreviewError`, `evento-app.html:917-930`) usa `createElement` (no `innerHTML`) para no tocar el balance de divs y evitar inyeccion.

### Trampa: el kernel inyecta estilos INLINE

Los nodos de inyección de `evento-app.html` traen `style` inline propio
(p.ej. `#db-lineup` = `display:flex; flex-direction:column; gap:2.5rem`).
Regla: cualquier propiedad que el kernel declare inline y que el silo quiera
cambiar DEBE ir con `!important`, o el inline gana. Caso real: la tira
horizontal del lineup se veía apilada (como móvil) porque el silo declaraba
`flex-direction: row` sin `!important`.
Verificación previa obligatoria: `grep -n 'id="<nodo>"' evento-app.html`.

**ADRs citados:** ADR-005, ADR-008, ADR-006, ADR-010, **ADR-056 (lectura con fallback + preview), ADR-057 (capital-T / preview == produccion)**. **Reglas citadas:** Mandato 4 (Escudo GOLD), Mandato 13 (armonía HSL).

---

