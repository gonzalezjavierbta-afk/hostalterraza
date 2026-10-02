---
doc: TEMPLATES.md — 4
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L114-138 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L114-138 del original).

## 4. Arquitectura Molecular (Átomos de UI del Silo)

> **Decisión de Dirección (zanjada):** el silo se compone de componentes moleculares estándar, definidos con variables prefijadas del silo (`--f10-*`, `--f9-*`, etc.), nunca en `:root` global (prohibido por Mandato 9).

Moléculas que cada silo puede declarar (y las clases kernel reales que estilizan):

| Molécula | Selectores kernel reales (verificados) | Notas |
|---|---|---|
| **Hero** | `#mod-hero`, `#mod-hero-meta` (meta en 2 líneas ok, ADR-041), `#mod-hero-ctas` | `#mod-hero-ctas` nace con `display:none` y solo lo enciende `tpl-f6` por contrato; en silos que lo usan debe liberarse |
| **Countdown** | `#unified-frame` + `#cd-days/#cd-hours/#cd-mins/#cd-secs` | Mismo frame que el video; Mandato 5 (sincronización 1:1) |
| **Video** | `#mod-video` (miniature HD, ADR-005, prohibido iframe; excepto la excepción acotada ADR-060, solo silo f9b, click-to-play youtube-nocookie con fallback externo) | `padding-top: 0 !important` si se integra con el bloque superior (ADR-010) |
| **Lineup** | `.artist-card`, `.artist-photo`, `.artist-overlay`, `.artist-name`, `.artist-hora`, `.artist-resena`, `.artist-social`, `.artist-social-icon`, `.artist-card.headliner` | Selectores kernel de f8/f9/f10 (ADR-042: f10 v1 estilizaba `.f10-lc-*` inexistentes → reescritura) |
| **Galería** | `#db-gallery-grid` + `.gallery-item` | N abierto de espacios (nth-child cíclico prohibido, ADR-042) |
| **Boletos** | `#mod-boletos` + `.boleto-card-row` (con `.boleto-icon`, `.boleto-tipo`, `.boleto-precio`, `.boleto-desc`, `.boleto-arrow`) | Clase real generada por el kernel JS (≈L1522-1542); prohibido pintar "POR DEFINIR" (ADR-041); tarifas reales |
| **Form / CTA** | `#mod-form`, `#unified-frame`, `#mod-whatsapp`, `#mod-cta-final` | Botón WhatsApp sin el número visible en el texto (ADR-041) |
| **Footer** | `#mod-footer`, `#mod-info-tecnica` | Datos técnicos con tipografía Geist 900 + drop-shadow (Mandato 8) |

> **Nota de salvaguarda (molecula Hero):** si el hero escala el titulo por ANCHO (`vw`) hasta su tope, validar el caso por **ALTURA** en bandas anchas (tablet/landscape) para evitar el solape titulo/cinta — ver la regla del **Cap. 5** (patron recomendado de salvaguarda por ALTURA, silo f12 v1.13.3) y la evidencia real `css/templates/fiesta/f12.css` L2217-2231. No duplicar aqui el texto completo.

**Entregables:** declaración de variables del silo; lista de moléculas usadas con sus clases kernel reales; vista previa del log TRACE de FASE I.

**Reglas de Oro citadas:** Mandato 5, 6, 7, 8, 10, 13 ("Regla #9"), 14 ("Regla #10"). **ADRs:** ADR-005, ADR-008, ADR-010, ADR-011, ADR-041, ADR-042.

---

