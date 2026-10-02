---
doc: E05 (ERRORES_HISTORICOS.md §5)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L68-81 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §5 · [INDEX](../INDEX.md). Texto original íntegro debajo (L68-81 del original).

## 5. Errores Recientes de Selectores y Breakpoints (Sesión de Refactorización f1 — v1.7.0)

### 🚨 Referencia Fantasma en Selectores CSS (f1, v2.1.0–v2.3.0)
* **Problema:** Tres parches consecutivos de expansión edge-to-edge (`#modulo-lineup`, `#modulo-gallery`, `.media-grid`, `.poster-main-img`, `.spotify-container`) no tuvieron ningún efecto visual pese a estar correctamente escritos en CSS[cite: 2].
* **Causa:** Los selectores asumían una estructura HTML pre-split (una sección "gallery" unificada con video+playlist). El DOM real, desde v1.4.6, usa 3 `<section>` hermanas independientes (`#mod-video`, `#mod-lineup`, `#mod-playlist`) y el póster es `<img id="db-poster-img">`, no `.poster-main-img`[cite: 2].
* **Blindaje:** Antes de escribir un parche CSS de expansión estructural, verificar el HTML real de `evento3.html` (no solo `BLUEPRINT.md`) para confirmar IDs/clases vigentes, especialmente tras un split documentado en el changelog del propio `.css` del silo[cite: 2].

### 🚨 Regla Edge-to-Edge sin Alcance de Breakpoint Rompe Desktop (f1, v2.3.0)
* **Problema:** `.tpl-f1 #mod-lineup > div { max-width:100% !important }` se escribió para liberar el ancho en móvil, pero al no llevar `@media`, también anuló el tope inline de `1100px + margin:0 auto` en escritorio, descentrando visualmente el póster y estirando el grid a todo el ancho de la sección[cite: 2].
* **Causa:** Toda regla de expansión "edge-to-edge" debe declarar explícitamente su alcance de breakpoint. Una regla sin `@media` puede reparar un breakpoint y romper otro de forma silenciosa (sin error en consola, sin white screen, solo desalineación visual difícil de atribuir a simple vista)[cite: 2].
* **Blindaje:** Auditar cada `!important` de ancho/margen añadido a un módulo compartido entre breakpoints, confirmando explícitamente si el fix debe ser universal o exclusivo de un rango de pantalla, y documentarlo en el propio comentario CSS[cite: 2].

---

