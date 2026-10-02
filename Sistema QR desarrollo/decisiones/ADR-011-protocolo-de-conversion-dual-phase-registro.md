---
doc: ADR-011
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L62-67 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L62-67 del original).

#### ADR-011: Protocolo de Conversión Dual-Phase (Registro & Perfilamiento In-Place)
* **ID:** ADR-011 | **Fecha:** Julio 2026 | **Estado:** Aprobado v1.10.
* **Problema:** Alta tasa de abandono en formularios extensos de registro para campañas y emergencias (b5)[cite: 1].
* **Decisión:** Implementar la lógica de doble fase: Fase 1 (INSERT rápido para captura mínima) y Fase 2 (UPDATE in-place sobre el registro activo sin recarga de página)[cite: 1].
* **Justificación:** Maximiza la conversión de usuarios en entornos de alta fricción o emergencia operativa[cite: 1].

