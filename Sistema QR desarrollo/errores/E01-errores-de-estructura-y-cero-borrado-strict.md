---
doc: E01 (ERRORES_HISTORICOS.md §1)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L7-20 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §1 · [INDEX](../INDEX.md). Texto original íntegro debajo (L7-20 del original).

## 1. Errores de Estructura y Cero Borrado (STRICT)

### 🚨 Violación del Contrato de Datos (v100-v104)
* **Problema:** Durante la simplificación del código para insertar patrocinadores, se eliminaron elementos físicos del HTML[cite: 2].
* **Impacto:** Se perdieron los SVGs de las tarjetas de datos y el indicador "+" del FAQ, degradando la interfaz premium[cite: 2].
* **Blindaje:** Prohibición absoluta de borrar IDs del Contrato v107. Si un módulo no se desea, se usa `display: none`[cite: 2].

### 🚨 Colapso de Contenedores Flex (v1.5.12)
* **Problema:** Al usar `display: flex` en el nodo raíz de módulos multimedia (#mod-video, #mod-lineup), los contenedores colapsaban visualmente a 0px tras la inyección dinámica de JS[cite: 2].
* **Causa:** El patrón `max-width + margin: auto` requiere que el div se comporte como bloque. Flex convertía el contenido en ítems que se encogían al estar inicialmente vacíos[cite: 2].
* **Blindaje (ADR-007):** Uso mandatorio de `display: block !important` en contenedores de inyección masiva[cite: 2].

---

