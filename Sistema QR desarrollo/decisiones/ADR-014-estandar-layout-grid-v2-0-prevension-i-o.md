---
doc: ADR-014
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L82-88 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L82-88 del original).

#### ADR-014: Estándar Layout & Grid v2.0 (Prevensión I/O Async Supabase)
* **ID:** ADR-014 | **Fecha:** Julio 2026 | **Estado:** Aprobado y En Producción (v1.2.5).
* **Problema:** Desincronizaciones de entrada/salida (I/O) durante la carga asíncrona de Supabase generaban reordenamientos o colapsos a `0px` en contenedores inyectados al renderizar el DOM antes de recibir la respuesta de la base de datos[cite: 1].
* **Decisión:** Extender ADR-007 y ADR-013 eliminando Flexbox en contenedores de medios inyectados (`#mod-video`, `#mod-galeria`) y obligando el uso de CSS Grid con pistas fijas explícitas (`grid-template-columns: 1fr 1fr`)[cite: 1].
* **Justificación:** Las pistas explícitas de Grid reservan el espacio estructural en el layout desde el primer render, impidiendo el colapso visual o el parpadeo (CLS) previo a la inyección asíncrona de datos desde Supabase[cite: 1].
* **Impacto:** Aplica a todos los templates activos (`f1`, `b5`) y futuros desarrollos dentro del Kernel CSS[cite: 1].

