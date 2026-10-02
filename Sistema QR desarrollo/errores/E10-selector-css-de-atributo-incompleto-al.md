---
doc: E10 (ERRORES_HISTORICOS.md §10)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L128-136 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §10 · [INDEX](../INDEX.md). Texto original íntegro debajo (L128-136 del original).

## 10. Selector CSS de Atributo Incompleto al Reutilizar un Patrón con Namespace Distinto (Sesión ADR-023 — Reorganización de Panel)

### 🚨 `[data-adm-tab]{display:none}` No Cubría el Nuevo Atributo `data-pnl-tab`
* **Problema:** ADR-022 introdujo el patrón de pestañas ocultas-por-defecto vía CSS de atributo: `[data-adm-tab]{display:none}` + `.adm-visible{display:block}`. Al reutilizar el mismo patrón para Panel (ADR-023) con un namespace de atributo deliberadamente distinto (`data-pnl-tab`, para que Admin y Panel no interfirieran entre sí en el mismo DOM — ver ADR-023 punto 4), la regla CSS original no se amplió junto con el HTML/JS: seguía comprobando únicamente la presencia de `data-adm-tab`. Las 4 pestañas de Panel habrían quedado **todas visibles simultáneamente** — ninguna regla CSS las ocultaba — anulando visualmente el propósito completo de la reestructuración, pese a que el HTML (envoltura correcta) y el JS (`pnlGoTab()` alternando la clase `.adm-visible` correctamente) estaban ambos bien escritos.
* **Causa:** Reutilizar un nombre de clase de estado (`.adm-visible`) sin revisar que el selector de atributo que lo acompaña siga cubriendo el atributo nuevo. El bug es invisible en una revisión de HTML o de JS por separado — ambos están "correctos" en aislamiento; solo se manifiesta al verificar el comportamiento visual conjunto (o, como en este caso, al releer la regla CSS que los conecta antes de dar por cerrada la entrega).
* **Blindaje (ADR-023):** Corregido a `[data-adm-tab],[data-pnl-tab]{display:none}` con su contraparte `.adm-visible` ampliada igual. Auditoría recomendada para futuras sesiones: cuando un patrón de "namespace de atributo + clase de estado compartida" se reutiliza para una segunda página/módulo, grepear explícitamente el selector CSS que depende del nombre del atributo (no solo el nombre de la clase) para confirmar que cubre todos los namespaces en uso, no solo el original.

---

