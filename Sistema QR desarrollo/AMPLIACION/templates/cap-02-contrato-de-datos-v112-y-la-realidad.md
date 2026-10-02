---
doc: TEMPLATES.md — 2
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L71-90 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L71-90 del original).

## 2. Contrato de Datos v112 y la Realidad del DOM (21 Átomos vs 81 IDs)

> **Decisión de Dirección (zanjada):** el Contrato de Datos vigente es **v112 / 21 Átomos Soberanos** (BLUEPRINT.md v1.6.2, Sección 4). Se tratan como inamovibles. PERO el archivo real `evento.html` es **"Master Orchestrator v214"** con comentarios internos hasta v222 y **~81 IDs** propios más `unified-frame` y `#mod-*`. Se deja v112 como línea base de validación y se documenta la brecha como **discrepancia conocida**, no como bug.

⚠️ **ADVERTENCIA CRÍTICA (ADR-006 / AGENTS.md):** solo **8 de los 21 Átomos** existen hoy con su id exacto vendido en BLUEPRINT (`event-title`, `meta-fecha`, `meta-hora`, `meta-lugar`, `mod-video`, `mod-lineup`, `mod-ubicacion`, `mod-form`). Los 12 "faltantes" (`mod-galeria`, `mod-patrocinadores`, `mod-entradas`, `mod-faqs`, `mod-contacto`, `mod-reglas`, `mod-itinerario`, `mod-redes`, `mod-comentarios`, `mod-encuesta`, `mod-descargas`, `mod-sponsors-vip`, `mod-actualizaciones`) fueron **renombrados o reestructurados** en v214+ — `#mod-hero`, `#mod-historia`, `#mod-objetivo`, `#mod-equipo`, `#mod-experiencias`, `#mod-cartel`, `#mod-playlist`, `#mod-whatsapp`, `#mod-cta-final`, `#mod-info-tecnica`, `#mod-footer`, `#mod-boletos`, `#mod-faq`, `#mod-sponsors`, entre otros. **`event-description` no existe en ninguna forma** (`#mod-descripcion` fue creado como átomo nuevo en ADR-041, silo f9).

**Regla práctica:** NO reportes como "faltante" ni "bug" ninguno de los 12 átomos clásicos ausentes. Antes de tocar un selector, verifica contra `evento.html` real con `grep` (ADR-006). Si un módulo fue renombrado, usa el nombre real del DOM.

> **NOTA de reconciliacion (ADR-048, 2026-09-22):** el archivo real descrito en este capitulo como `evento.html` es en el repositorio **`evento-app.html`** (1724 lineas, "Master Orchestrator v214" — ver banner al inicio del documento). La ruta publica `/evento.html` la reescribe `vercel.json` hacia `/api/evento-og`, que sirve `evento-app.html`. Ademas, verificado en `evento-app.html`: `#db-gallery-grid` (L148) vive **DENTRO** de `#mod-video` (L147) — apagar `#mod-video` oculta la galeria; `#mod-hero-ctas` (L84) nace con `display:none !important` (L33) y exige encendido explicito.

| Entregables | Evidencia |
|---|---|
| Lista de IDs kernel que el silo estiliza | grep de `id=` en `evento-app.html` |
| Átomos del contrato realmente presentes | Comparativa 21 vs ~81 (reporte) |
| Justificación si un átomo clásico no aplica | Anexo de ADR del silo |

**Reglas de Oro citadas:** Mandato 1 (Data-First), Mandato 2 (Cero Borrado). **ADRs:** ADR-006 (veracidad), ADR-011 (dual-phase; aplica a Cero Borrado de módulos). **Errores históricos:** §1 (violación v100-v104), §7 (comentario que no reflejaba el código).

---

