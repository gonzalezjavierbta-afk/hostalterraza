---
doc: ADR-008
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L47-51 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L47-51 del original).

#### ADR-008: Protocolo de Blindaje de Assets (Silent Fallback)
* **ID:** ADR-008 | **Fecha:** Julio 2026 | **Estado:** Aprobado.
* **Decisión:** Obligatoriedad del atributo `onerror="this.src='path/to/fallback.png';"` en etiquetas `<img>` dinámicas[cite: 1].
* **Justificación:** Evita la visualización de iconos de imagen rota si Supabase falla o la URL del artista es inaccesible[cite: 1].

