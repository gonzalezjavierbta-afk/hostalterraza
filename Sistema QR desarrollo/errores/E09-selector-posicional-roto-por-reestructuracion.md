---
doc: E09 (ERRORES_HISTORICOS.md §9)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L119-127 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §9 · [INDEX](../INDEX.md). Texto original íntegro debajo (L119-127 del original).

## 9. Selector Posicional Roto por Reestructuración de Pestañas (Sesión ADR-022 — Reorganización de Admin)

### 🚨 `#pg-admin > .wrap > .card` Dejó de Coincidir Tras Envolver la Card en un Tab
* **Problema:** `aplicarRestriccionesAdminEvento()` ocultaba la card "Nuevo evento" para el rol `admin_evento` usando el selector posicional `#pg-admin > .wrap > .card` (primer hijo directo `.card` de `.wrap`). Al reorganizar Admin en pestañas (ADR-022), esa card se envolvió en `<div data-adm-tab="crear">` — pasó de ser **hija directa** de `.wrap` a **nieta**. El selector, al depender de la posición exacta en el árbol y no de un identificador propio, dejó de coincidir silenciosamente: sin error de consola, sin white screen, el Wizard de creación simplemente habría quedado visible/accesible para un rol que no debería poder crear eventos.
* **Causa:** Mismo patrón de raíz que ADR-007 (contenedores flex que colapsan por depender de comportamiento posicional/estructural implícito) y ADR-010 (padding dependiente de la posición del bloque anterior) — código que depende de "dónde vive" un elemento en el árbol en vez de "qué es" (un ID o atributo propio), frágil ante cualquier refactor estructural futuro, incluso uno que no toca esa card directamente.
* **Blindaje (ADR-022):** Se corrigió el selector para apuntar por atributo (`[data-adm-pill="crear"]` / `[data-adm-tab="crear"]`) en vez de por posición. Auditoría recomendada para futuras sesiones: antes de envolver o reordenar HTML existente (incluso con el patrón de envoltura in-situ ya establecido en ADR-021/022), buscar en todo el archivo selectores `querySelector`/`querySelectorAll` que referencien esa región por posición (`>`, `:nth-child`, `:first-child`) en vez de por ID/atributo — son los que se rompen silenciosamente ante una reestructuración, mientras que los selectores por ID sobreviven sin cambios.

---

