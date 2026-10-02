---
doc: E12 (ERRORES_HISTORICOS.md §12)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L148-160 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §12 · [INDEX](../INDEX.md). Texto original íntegro debajo (L148-160 del original).

## 12. Orden Flexbox Incompleto en el Hero Mobile del Silo F11 (2026-09-16 — CORRECCIÓN MOBILE v3.2.0)

### 🚨 Elementos del Hero por Encima del Título en Mobile (countdown, meta, botón sobre el título)
* **Problema:** En mobile (≤767px) el hero del silo f11 "CYBERPUNK FOSFORESCENTE" (`css/templates/fiesta/f11.css`) mostraba arriba los elementos countdown (`#unified-frame`), meta (`#mod-hero-meta`) y botón (`#mod-hero-ctas`), y abajo el título (`#mod-hero`) — el orden visual inverso al aprobado (título → countdown → meta → botón). Reportado por el usuario.
* **Causa:** En la media query `@media (max-width: 767px)` solo `#mod-hero` recibía `order: 1`; los 3 hermanos `#unified-frame` (countdown), `#mod-hero-meta` y `#mod-hero-ctas` quedaban con `order: 0` (default flexbox) → el navegador los colocaba antes que el título. Mismo patrón de raíz que la Sección 5 (reglas que dependen del comportamiento posicional/estructural implícito): un reordenamiento parcial de hermanos sin renumerar el resto deja que el layout dependa del default del motor — invisible a simple vista, sin error de consola, solo un orden visual incorrecto.
* **Blindaje (f11 v3.2.0, T1 + T2 del plan aprobado por el usuario):**
   1. **T1 — Orden explícito de los 4 hermanos del hero en la media query 767px** con doble notación `.tpl-f11` + `.Tpl-F11` (aislamiento atómico): `#mod-hero`=1, `#unified-frame`=2, `#mod-hero-meta`=3, `#mod-hero-ctas`=4, y re-numeración explícita del resto de bloques (5-15) para que ningún hijo dependa del `order` default. Resultado: título → countdown → meta → botón.
   2. **T2 — Hero completo en UNA sola pantalla** (proporción 60/40 aprobada): `#mod-hero` con `min-height: 60svh` (fallback `60vh`), título `clamp(2.6rem, 11vw, 4.2rem)` en 767px y versión escalada `clamp(2.2rem, 10vw, 3.4rem)` en 480px, `background-position: center center` en mobile (conservando `background-size: cover`), paddings/gaps compactados (countdown + meta + botón comprimidos en el ~40% restante del viewport, sin scroll vertical en el hero).
   3. **`css/templates/fiesta/f11gemini.css` NO fue tocado** (decisión explícita del usuario: "no tocar ese archivo").
* **Verificación (Escudo GOLD):** balance de llaves 213/213 (diff 0), ASCII-safety (bytes >127 solo en comentarios históricos, no en reglas activas), desktop `min-height: 85vh !important` intacto, breakpoint 992-1279px intacto, sin media queries nuevas, Cero Borrado (sin IDs del Contrato de Datos v112 eliminados). Único archivo tocado: `css/templates/fiesta/f11.css` (1544 → 1554 líneas, cabecera v3.2.0). Lección: al reordenar bloques en un contenedor flex, renumerar TODOS los hermanos con `order` explícito — nunca dejar que algunos dependan del default mientras otros reciben `order` propio.

---

