---
doc: ADR-005
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L31-36 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L31-36 del original).

#### ADR-005: Sustitución de Iframe por Miniatura en Videos (YouTube)
* **ID:** ADR-005 | **Fecha:** Mayo 2026 | **Estado:** Certificado v1.6.0.
* **Problema:** El "Error 153" en navegadores in-app de Instagram/Facebook bloqueaba la visualización de trailers mediante iframes[cite: 1].
* **Decisión:** Extraer el ID del video e inyectar una miniatura HD con link externo `target="_blank"`.
* **Justificación:** Erradica el bloqueo en móviles y mejora la tasa de conversión en el registro público[cite: 1].

