---
doc: ADR-002
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L14-19 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L14-19 del original).

#### ADR-002: Reemplazo por Cumplimiento de CSP (qrcodejs -> qr-creator)
* **ID:** ADR-002 | **Fecha:** Mayo 2026 | **Estado:** Aprobado y En Producción.
* **Problema:** La librería qrcodejs ejecutaba `new Function()`, violando la Content Security Policy (CSP) de Vercel[cite: 1].
* **Decisión:** Eliminar qrcodejs y estandarizar el uso de qr-creator en todas las páginas.
* **Justificación:** qr-creator opera de forma nativa mediante la Canvas API de HTML5, siendo 100% compatible con CSP[cite: 1].

