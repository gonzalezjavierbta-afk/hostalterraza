---
doc: ADR-020
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L169-181 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L169-181 del original).

#### ADR-020: Refactorización de Sincronía Visual v2.2.0, Colapso a Columna Única a 1024px e Inyección Dinámica de Caché v1.3.56
* **ID:** ADR-020
* **Fecha:** Agosto 2026
* **Estado:** Aprobado y En Producción.
* **Problema:** Inestabilidad responsiva en viewports intermedios (iPads / Tablets 768px-1024px) y desbordamiento horizontal (scroll) en dispositivos móviles pequeños (iPhone SE) causado por grillas anidadas rígidas, falta de ordenamiento explícito y persistencia de CSS en el caché del navegador[cite: 1, 2].
* **Decisión:**
  1. Implementar la **Refactorización de Sincronía Visual v2.2.0** aplicando un mapeo de secuencia total mediante `order` explícito para los 14 módulos estructurales.
  2. Establecer el colapso a columna única total desde los **1024px** para eliminar la inestabilidad en iPads y tablets en modo landscape o portrait.
  3. Activar el mecanismo de **Bypass de Caché v1.3.56** mediante el uso del parámetro dinámico `?v=${Date.now()}` en la función `injectAtomicCSS` para forzar la reevaluación atómica de hojas de estilo.
  4. Consolidar el reset global `.tpl-b5, .tpl-b5 * { box-sizing: border-box !important; }` para evitar fugas de abstracción en el modelo de caja.
* **Justificación:** Previene los cortes de pantalla, asegura la descarga inmediata de activos CSS actualizados en producción y estandariza la jerarquía de apilamiento visual sin alterar el marcado HTML de la base.
* **Impacto:** Aplica a `b5.css`, `eventovenezuela.html` y establece el patrón de inyección para futuros silos atómicos.

