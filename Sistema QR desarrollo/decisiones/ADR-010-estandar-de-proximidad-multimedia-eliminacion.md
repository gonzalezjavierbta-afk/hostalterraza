---
doc: ADR-010
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L57-61 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L57-61 del original).

#### ADR-010: Estándar de Proximidad Multimedia (Eliminación de Respiros)
* **ID:** ADR-010 | **Fecha:** Julio 2026 | **Estado:** Aprobado (f1 Certified).
* **Problema:** Sensación de desconexión visual entre el countdown y el video debido a paddings globales de sección[cite: 1].
* **Decisión:** Forzar `padding-top: 0 !important` en el módulo de video dentro del CSS del template para integrarlo físicamente con el bloque superior[cite: 1].

