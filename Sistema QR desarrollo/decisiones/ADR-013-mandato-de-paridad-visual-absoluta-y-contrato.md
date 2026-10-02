---
doc: ADR-013
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L75-81 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L75-81 del original).

#### ADR-013: Mandato de Paridad Visual Absoluta y Contrato v111
* **ID:** ADR-013 | **Fecha:** Julio 2026 | **Estado:** Aprobado y En Producción.
* **Problema:** `eventovenezuela.html`/`b5.css` no alcanzaban paridad visual con `landing-escritorio.jpg`: sin insignias numeradas de sección, Historia e Impacto Histórico apilados en filas independientes en vez de en columnas, Galería y Video apilados en vez de en columnas, sin módulo de Actualizaciones, formulario en pestañas verticales en vez de una fila horizontal de 1100px. Además, auditoría de datos reveló 3 bugs reales: `#event-description` nunca se inyectaba (Incidencia 01 de `ERRORES_HISTORICOS.md`, nunca blindada realmente), `#meta-fecha` seguía comentada, y `#db-gallery-grid` no tenía ningún segmento de JS que la poblara[cite: 1].
* **Decisión:** (1) Nuevo componente `.b5-num-eyebrow[data-num]` para las 8 cabeceras numeradas (02-09). (2) `grid-template-areas` empareja `historia`+`impactohist` en una fila de 2 columnas. (3) `#mod-video` pasa de "bloque forzado" (ADR-007) a Grid de 2 columnas fijas (`1fr 1fr`), separando Galería (06) y Video (07) sin reintroducir el colapso de ADR-007 — el patrón de pistas `fr` fijas no se comporta como Flex ante hijos vacíos. (4) Se extiende el Contrato de Datos a v111 (21 átomos) con `#mod-actualizaciones`, un carrusel de noticias genérico y reutilizable. (5) Se eliminan las pestañas del formulario (`#form-ya`, `switchForm()`) y se lleva `#fase1-fields` a un Grid horizontal de 3 columnas dentro de una caja de 1100px. (6) Se corrigen los 3 bugs de datos detectados[cite: 1].
* **Justificación:** El mandato de Dirección autorizó explícitamente flexibilizar Cero Borrado y Aislamiento Atómico para esta tarea si la estructura interfería con la paridad visual; se ejerció esa autoridad de forma mínima — ningún átomo del Contrato v110 fue eliminado, solo ocultado vía `.tpl-b5` donde un nuevo contenedor aditivo lo reemplaza (ver `#db-historia-lista` en `BLUEPRINT.md` §3b)[cite: 1].
* **Impacto:** `b5.css` y `eventovenezuela.html` quedan actualizados y listos para producción. Pendiente para una sesión futura: assets reales de galería/actualizaciones (hoy usan Silent Fallback / contenido de referencia), y el menú hamburguesa mobile del nav (fuera de alcance de este mandato)[cite: 1].

