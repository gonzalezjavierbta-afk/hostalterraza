---
doc: ADR-012
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L68-74 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L68-74 del original).

#### ADR-012: Conversión de Emergencia y Transición al Contrato v110
* **ID:** ADR-012 | **Fecha:** Julio 2026 | **Estado:** Aprobado y En Producción.
* **Problema:** Necesidad de implementar un flujo de alta conversión para ayuda humanitaria que permita capturar datos de perfilamiento sin perder al usuario mediante redirecciones externas[cite: 1].
* **Decisión:** Evolucionar al **Contrato de Datos v110** (20 átomos potenciales) e implementar la lógica Dual-Phase en `eventovenezuela.html`[cite: 1].
* **Justificación:** El sistema previo era monolítico en su respuesta de éxito. El nuevo estándar permite un INSERT (Fase 1) seguido de un UPDATE in-place (Fase 2) sobre el mismo registro[cite: 1].
* **Impacto:** Requiere validación de esquema en Supabase (columnas `whatsapp`, `tipo_ayuda`, `autorizacion`) y activa 4 nuevos componentes aditivos: `#meta-magnitud`, `#mod-mapa-crisis`, `#mod-como-ayudar` y `#mod-impacto-historico`[cite: 1].

