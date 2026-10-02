---
doc: E03 (ERRORES_HISTORICOS.md §3)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L35-53 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §3 · [INDEX](../INDEX.md). Texto original íntegro debajo (L35-53 del original).

## 3. Errores de Lógica y Mapeo (Cerebro JS)

### 🚨 Omisión de Propiedades Globales (v110-v113)
* **Problema:** Se perdió el margen del título porque se asumió que el Master lo gestionaría, cuando el silo externo lo requería explícitamente[cite: 2].
* **Impacto:** Desalineación visual de 1px entre el entorno de pruebas (Silo) y producción (Master)[cite: 2].
* **Blindaje:** Protocolo de "Prueba de Carga Dual" obligatoria antes de cada entrega[cite: 2].

### 🚨 Pérdida de Interactividad (Eventos Inline)
* **Problema:** El FAQ y las pestañas del formulario dejaron de funcionar al copiar el código al Master[cite: 2].
* **Causa:** Se omitieron los atributos físicos `onclick` en los elementos inyectados[cite: 2].
* **Blindaje:** El JS del Master DEBE inyectar el atributo `onclick` físicamente en el `innerHTML` o el `map`[cite: 2].

### 🚨 Referencia Indefinida en Directorio (loadDirectorio)
* **Problema:** Error "q is not defined" en consola al buscar en el directorio[cite: 2].
* **Causa:** Una refactorización movió la variable de búsqueda fuera del scope de la función[cite: 2].
* **Blindaje:** Auditoría obligatoria de logs TRACE para asegurar que las variables de filtro se declaren dentro del ámbito de ejecución[cite: 2].

---

