---
name: templates
description: Crea, edita o audita un template/silo CSS de evento.html (plantillas visuales de eventos: css/templates/{categoria}/{id}.css). Usalo cuando se pida crear un template/silo nuevo, modificar colores/tipografia/layout de un silo, registrar su theme en admin, o auditar que cumple el patron normativo. NO usar para CSS de admin.html/scanner.html ni para paginas dinamicas de destino.
---

# Templates — Silos Visuales de evento.html

Skill puente. **La norma completa vive en el HUB:** `Sistema QR desarrollo/AMPLIACION/TEMPLATES.md` (10 capítulos + Brief 9-bis + Metodología 9-ter + Anexo C con inventario del DOM real). Este archivo solo orienta: lee el HUB ANTES de tocar CSS.

## Cuándo usar

- Crear un template/silo nuevo (css/templates/{categoria}/{id}.css).
- Modificar colores, tipografía o layout de un silo existente (f1, f3, f5-f11 fiesta; b2-b5 campaña; c1, c4 cine — ojo: f2, c2, b1 documentados pero SIN archivo real).
- Registrar el theme del silo en admin.html.
- Auditar que un silo cumple el patrón normativo.

## Checklist de creación (8 pasos — detalle en HUB §9-ter)

1. **Diagnóstico del DOM real:** grep los `#mod-*` y clases JS en `evento.html` (Anexo C). NUNCA usar el BLUEPRINT como mapa (v112 ≠ DOM real v214+/v222).
2. **Brief + tokens + paleta:** responder el Brief de HUB §9-bis; paleta derivada de `--master-accent` (o fija justificada); tokens `--fXX-*`; contraste WCAG AA ≥ 4.5:1.
3. **Reset scoped + puente cromático:** bloque raíz `.tpl-fXX, .Tpl-FXX` con `--tpl-accent: var(--master-accent, #fallback)`; prohibido `@import` y `:root` global.
4. **Activación atómica:** `display:flex/block !important` (encendidos) y `display:none !important` (apagados); IDs intactos (Cero Borrado).
5. **Grid + secciones en orden DOM:** grid en `#main-content-flow` + `grid-template-areas`; secciones en orden del Anexo C; Reflow `:has([data-hidden])`.
6. **Breakpoints + reduced-motion:** 640/767/992/1279 (768 solo `:has()`, 480 opcional) + `prefers-reduced-motion`.
7. **Escudo GOLD:** checklist 10/10 del HUB §10 (CSS válido, ASCII 0 bytes>127, doble notación, cero fantasma, Cero Borrado, núcleo mínimo, accesibilidad, smoke, admin, cero colateral).
8. **Registro en admin:** `.ld-theme-card` + `_THEME_TYPE` + `_THEME_TPL` (nace visible; curado por master vía `config_global`, ADR-040).

## Reglas críticas (no negociables)

- **Doble notación de casing:** el kernel escribe en `body` `tpl-{template_id}` (mayúsc, ej. `tpl-F10`) Y `tpl-{id}` (minúsc, ej. `tpl-f10`). Todo selector: `.tpl-fXX, .Tpl-FXX`.
- **Subconmutaciones:** son del kernel (checks sobre `body.className`), no del silo (ver HUB §8.6: f6 título 2 líneas; f8 paleta neón/tab form/footer Chokoflow/boletos indiv-pareja/lineup Maqueta B; f9 meta 2 líneas/headliner RASTRO MC/FAQ fallback/boletería tarifa real). Una subconmutación nueva = cambio de kernel → escala al Plan.
- **Cero selectores fantasma:** solo selectores que existen en el DOM real (ERRORES §5/§8/§12).
- **Campaña apagada:** `#mod-historia`, `#mod-objetivo`, `#mod-impacto`, `#mod-info-tecnica`, `#mod-whatsapp`, `#mod-sponsors` ocultos en silo de fiesta (IDs intactos).
- **ASCII-safety:** 0 bytes > 127 en css/templates/**/*.css (los .md pueden llevar acentos).

## Cierre documental

- Log de versiones en el pie del silo + ADR en `DECISIONS.md` (patrón ADR-041/042/043) + si hubo falla BUG-XXX en `ERRORES_HISTORICOS.md` + `TASKS.md`/`NEXT.md` (Mandato 12).