---
doc: ADR-007
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L42-46 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L42-46 del original).

#### ADR-007: Regla de Diagramación "Bloque sobre Flex"
* **ID:** ADR-007 | **Fecha:** Julio 2026 | **Estado:** Aprobado (Fix Estructural).
* **Problema:** Los contenedores multimedia (#mod-video, #mod-lineup) colapsaban a 0px al usar `display: flex` en el nodo raíz tras la inyección dinámica de datos[cite: 1].
* **Decisión:** Obligar el uso de `display: block !important` en módulos que dependan del patrón `max-width + margin: auto` para su centrado[cite: 1].

