---
doc: ADR-009
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L52-56 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L52-56 del original).

#### ADR-009: Prioridad de Grid sobre Flujo (Layout Management)
* **ID:** ADR-009 | **Fecha:** Julio 2026 | **Estado:** Certificado v1.6.0.
* **Decisión:** La organización jerárquica de módulos se gestionará exclusivamente vía `grid-template-areas` en el CSS de cada silo[cite: 1].
* **Justificación:** Permite reordenar visualmente secciones (como subir el video o bajar el formulario) manteniendo el HTML de `evento3.html` inamovible (Contrato de Datos v107)[cite: 1].

