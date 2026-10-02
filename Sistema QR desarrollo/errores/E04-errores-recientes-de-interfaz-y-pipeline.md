---
doc: E04 (ERRORES_HISTORICOS.md §4)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L54-67 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §4 · [INDEX](../INDEX.md). Texto original íntegro debajo (L54-67 del original).

## 4. Errores Recientes de Interfaz y Pipeline (Sesión de Auditoría v1.6.0)

### 🚨 Hardcodeo Estructural y Neutralización del Orquestador (Incidencia 01)
* **Problema:** El texto descriptivo del sismo se encontraba hardcodeado directamente en el HTML de `eventovenezuela.html` (`#event-description`) y se neutralizó el orquestador JavaScript comentando la línea de inyección, provocando que el contenido no se visualizara correctamente en el navegador[cite: 2].
* **Hipótesis de Ingeniería (Colisión de Capas):** Se identificó un conflicto visual de texto blanco sobre fondo blanco debido a la carga diferida de la imagen Hero[cite: 2].

### 🚨 Bloqueo Total (White Screen) por Reconfiguración de Módulo (Incidencia 02)
* **Problema:** Al intentar reconfigurar el Módulo 04 para pasar de un diseño de pestañas (vertical) a una fila única horizontal (Estándar $10,000), la página sufrió un bloqueo total (White Screen), exigiendo una reversión inmediata a la versión estable[cite: 2].
* **Hipótesis de Ingeniería (Referencia Fantasma):** Invocación de funciones de pestañas (`switchForm`) previamente eliminadas del HTML que interrumpen abruptamente la ejecución del script maestro[cite: 2].
* **Hipótesis de Ingeniería (Falla de Parser):** Desbalance de llaves `{ }` en la sección Hero del archivo `b5.css` que invalida las reglas críticas de visibilidad[cite: 2].
* **Blindaje Atómico:** Toda modificación de diseño en módulos interactivos debe aislarse bajo el selector atómico correspondiente (`.tpl-b5`) y verificar la integridad de las funciones vinculadas antes del despliegue[cite: 2].

---

