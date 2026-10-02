---
doc: E06 (ERRORES_HISTORICOS.md §6)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L82-90 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §6 · [INDEX](../INDEX.md). Texto original íntegro debajo (L82-90 del original).

## 6. Errores de Layout y Asincronía Supabase (Sesión v1.2.5 — Contrato v111)

### 🚨 Colapso Estructural y Parpadeo Visual (CLS) por Carga Asíncrona I/O
* **Problema:** Al cargar datos asíncronos desde Supabase hacia contenedores multimedia (`#mod-video`, `#mod-galeria`), la falta de dimensiones fijas previas en el CSS provocaba un colapso visual momentáneo a `0px` o un salto brusco en la disposición de la página (Cumulative Layout Shift) cuando los datos terminaban de inyectarse.
* **Causa:** Uso de estructuras Flexbox o bloques sin reserva explícita de pistas antes del renderizado asíncrono. En Flexbox, los elementos hijos vacíos reducen su tamaño a cero hasta que el JS inserta el HTML recibido del backend.
* **Blindaje (ADR-014):** Obligatoriedad de implementar **CSS Grid con pistas explícitas (`grid-template-columns: 1fr 1fr`)** en contenedores multimedia e inyectados. El uso de pistas fijas en Grid obliga al navegador a reservar el espacio geométrico exacto desde la carga inicial del DOM, previniendo el colapso visual independientemente del tiempo de respuesta del servidor.

---

