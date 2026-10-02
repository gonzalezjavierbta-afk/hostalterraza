---
doc: E07 (ERRORES_HISTORICOS.md §7)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L91-104 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §7 · [INDEX](../INDEX.md). Texto original íntegro debajo (L91-104 del original).

## 7. Errores de Coherencia de Breakpoints y Transcripción (Sesión de Auditoría Mobile v5.13.0 — b5)

### 🚨 Brecha entre el Breakpoint de Layout y el Breakpoint de Seguridad de un Mismo Átomo
* **Problema:** `#main-content-flow` colapsa a una columna en `max-width:991px` (ADR-018), pero la regla de seguridad de ancho/margen/box-sizing de `#mod-hero-meta` (la misma que corrigió el desborde en iPhone SE) se había quedado en `max-width:899px`. En la franja de 92px entre ambos valores, el layout ya está apilado a una columna pero `#mod-hero-meta` seguía recibiendo la regla íntegra de escritorio.
* **Causa:** Al subir el breakpoint del grid general en ADR-018, no se auditaron las reglas de seguridad puntuales de sus hijos que dependían implícitamente del mismo punto de quiebre.
* **Blindaje (ADR-019):** Al modificar el breakpoint de un contenedor de layout, listar explícitamente qué reglas de sus hijos asumen ese mismo punto de quiebre y moverlas en conjunto, no solo la regla del propio contenedor.

### 🚨 Comentario Documentando una Decisión que el Código No Implementaba
* **Problema:** `.historia-item--conimg` shippeaba `grid-template-columns: auto 50fr 50fr` (50/50) con un comentario inmediatamente arriba describiendo la proporción como "65% / 35%" — y `DECISIONS.md` (ADR-018) documentando textualmente la misma decisión de 65/35. El código nunca reflejó lo decidido.
* **Causa:** Bug de transcripción silencioso — sin error de consola, sin white screen, solo una proporción visual distinta a la ratificada, indistinguible a simple vista de un ajuste visual intencional posterior no documentado.
* **Blindaje (ADR-019):** Ante cualquier discrepancia entre un comentario/decisión documentada y el valor real shippeado, verificar cuál de los dos es el vigente contra `DECISIONS.md` antes de asumir que el código es la fuente de verdad — el código puede llevar una regresión silenciosa de un valor ya decidido.

---

