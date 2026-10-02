---
doc: TEMPLATES.md — 3
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L91-113 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L91-113 del original).

## 3. Estructura del Silo (8 Pilares Técnicos)

> **Decisión de Dirección (zanjada):** un "silo" es un archivo `css/templates/{categoria}/{id}.css` autocontenido, montado por el kernel vía `<link data-template-css>` y `injectAtomicCSS`. El silo canónico de referencia es **`f10.css` v2.0.0 (ADR-042)**. Soft-limit: **~2000 líneas por silo** (si se excede, justificar por segmentos — Mandato 3).

Los 8 pilares que todo silo debe cumplir:

| # | Pilar | Requisito |
|---|---|---|
| 1 | Cabecera de versión | Bloque `# ====` con nombre del silo, vX.Y.Z, estado (p.ej. `v2.0.1 NEON TRIADA` en f10) |
| 2 | Log de versiones en el pie | Tabla `| vX.Y.Z | Fecha | Autor | Descripción |` actualizada en cada entrega (ámbito documental del paquete) |
| 3 | Alcance atómico | Todo selector con prefijo `.tpl-f{id}` o `.Tpl-F{id}` (kernel escribe AMBAS clases en `body.className`; mandato de Aislamiento Atómico) |
| 4 | Cero selectores muertos | Cada selector debe coincidir con un nodo real del DOM kernel de `evento.html` (ADR-006; ERRORES §5/§8/§12) |
| 5 | Grid por áreas | Layout de módulos con `grid-template-areas` sobre el HTML inamovible (Mandato 10) |
| 6 | Fallback de assets | `onerror="this.src='...'"` (Silent Fallback ADR-008) y prohibido `invert`/`brightness` en logos sin alfa |
| 7 | Paleta por armonía HSL | Colores nacen de armonía matemática HSL (60-30-10; contraste WCAG AA 4.5:1; Mandato 13 "Regla #9") — nunca hex hardcodeado fuera de armonía |
| 8 | Mobile nativo | Diseñado móvil-first con breakpoints normativos (Cap. 5); Afterglow/120 FPS (Mandato 14 "Regla #10") |

**Deuda técnica aceptada:** en ADR-041 se aceptaron hallazgos H-3/H-4 como deuda (TSK-031). Cualquier pilar incumplido nuevo debe registrarse en el ADR del silo, no silenciarse.

**ADRs citados:** ADR-041, ADR-042, ADR-043, ADR-008, ADR-010. **Errores históricos:** §5 (selectores fantasma f1 v2.1.0-v2.3.0; edge-to-edge sin breakpoint), §8 (columnas documentadas nunca escritas por el INSERT), §12 (f11 hero mobile v3.2.0).

---

