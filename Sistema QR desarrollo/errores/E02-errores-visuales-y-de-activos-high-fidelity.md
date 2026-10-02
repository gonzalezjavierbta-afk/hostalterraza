---
doc: E02 (ERRORES_HISTORICOS.md §2)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L21-34 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §2 · [INDEX](../INDEX.md). Texto original íntegro debajo (L21-34 del original).

## 2. Errores Visuales y de Activos (High-Fidelity)

### 🚨 Corrupción por Filtros CSS (v107-Legacy)
* **Problema:** El uso de `filter: brightness(0) invert(1)` sobre imágenes sin canal alfa real (como favicons) convirtió los logos en "recuadros blancos" sólidos[cite: 2].
* **Impacto:** Ruptura de la estética premium de $10,000[cite: 2].
* **Blindaje:** No aplicar filtros de inversión sin confirmar transparencia total. Usar colores originales en "Debug Mode" ante la duda[cite: 2].

### 🚨 Desconexión Visual Multimedia (v1.5.8)
* **Problema:** El video se percibía "lejos" de la fecha y el reloj (Countdown/Meta)[cite: 2].
* **Causa:** La regla global de secciones inyectaba un respiro superior de `5rem` por defecto[cite: 2].
* **Blindaje (ADR-010):** Forzar `padding-top: 0 !important` en `#mod-video` dentro de cada silo visual[cite: 2].

---

