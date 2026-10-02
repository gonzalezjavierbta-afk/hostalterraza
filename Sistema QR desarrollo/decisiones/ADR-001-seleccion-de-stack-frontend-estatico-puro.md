---
doc: ADR-001
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L7-13 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L7-13 del original).

#### ADR-001: Selección de Stack Frontend Estático Puro (Vanilla JS)
* **ID:** ADR-001 | **Fecha:** Mayo 2026 | **Estado:** Aprobado y En Producción.
* **Problema:** Necesidad de desplegar una plataforma portable, de carga instantánea en móviles y sin costos operativos de servidor para eventos en vivo[cite: 1].
* **Opciones evaluadas:** 1) React/Next.js, 2) Vue.js, 3) HTML5/CSS3/JavaScript puro (Vanilla JS).
* **Decisión:** Adoptar HTML5/CSS3/Vanilla JS sin herramientas de compilación (build tools) ni dependencias de node_modules.
* **Justificación:** Los archivos estáticos permiten cambios instantáneos vía Vercel CDN, depuración directa en DevTools y ejecución fluida en navegadores móviles limitados[cite: 1].

