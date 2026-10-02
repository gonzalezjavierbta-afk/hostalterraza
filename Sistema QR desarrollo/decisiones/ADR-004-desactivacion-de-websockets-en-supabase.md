---
doc: ADR-004
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L26-30 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L26-30 del original).

#### ADR-004: Desactivación de Websockets en Supabase Realtime
* **ID:** ADR-004 | **Fecha:** Mayo 2026 | **Estado:** Aprobado y En Producción.
* **Problema:** Desconexiones intermitentes por cobertura móvil deficiente en recintos de eventos congelaban la UI[cite: 1].
* **Decisión:** Desactivar Realtime (`realtime: { enabled: false }`) en el cliente de Supabase y usar polling explícito por timers si es necesario[cite: 1].

