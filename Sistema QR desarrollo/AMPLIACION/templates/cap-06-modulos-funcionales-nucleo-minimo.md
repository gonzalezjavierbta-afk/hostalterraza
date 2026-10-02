---
doc: TEMPLATES.md — 6
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L162-180 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L162-180 del original).

## 6. Módulos Funcionales (Núcleo Mínimo Encendido)

> **Decisión de Dirección (zanjada):** todo silo debe dejar encendidos como mínimo estos módulos, salvo justificación explícita por línea de negocio (evento de captura pura, campaña, prelanzamiento):

1. `#mod-hero` (título)
2. `#mod-hero-meta` (metadata)
3. `#mod-hero-ctas` (llamados a la acción) **o apagado con justificación**
4. Descripción — `#mod-descripcion` (átomo nuevo ADR-041) o el módulo que aporte el texto descriptivo del evento
5. `#mod-form` (formulario de inscripción)
6. `#mod-footer` (cierre)

- La **campaña** (módulos de historia/objetivo/impacto) nace **apagada por defecto** (`display:none`); solo se enciende cuando el silo la declara explícitamente.
- En eventos de **captura pura** (Mandato 15 "Regla #11"), la pantalla final muestra mensaje de éxito/agradecimiento en lugar de ticket QR.
- **Fecha centinela** `2099-12-31` desactiva el countdown público en campañas (Mandato 16 "Regla #12").

**ADRs citados:** ADR-015 (contrato de campos), ADR-013 (átomo actualizaciones), ADR-041. **Reglas citadas:** Mandatos 15 y 16.

---

