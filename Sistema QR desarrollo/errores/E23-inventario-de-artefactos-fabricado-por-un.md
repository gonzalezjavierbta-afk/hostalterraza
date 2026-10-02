---
doc: E23 (ERRORES_HISTORICOS.md §23)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L317-323 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §23 · [INDEX](../INDEX.md). Texto original íntegro debajo (L317-323 del original).

## 23. Inventario de Artefactos Fabricado por un Subagente: una sonda reporto un `js/registroaforo.js` que NO existe en el repo (2026-09-30 - cierre documental ADR-064)

### El diagnostico se construyo sobre un `js/registroaforo.js` inexistente (`BUCKET_TICKETS`, `dibujarTicket()`) y sobre una semilla de 1080x1920 que en realidad es 941x1672
* **Problema:** una sonda CORS (subagente) reporto haber leido `js/registroaforo.js` "con constantes, funciones de subida y un bucket" (`BUCKET_TICKETS`) y lo cito como fuente de "multiples referencias". **Ese archivo NO existe en el repo** (0 coincidencias por nombre; el motor publico real es `registroaforo.html`, 1083 lineas). Lo que la sonda llamo "referencias" era su propia suposicion de como deberia estar escrito el modulo. En el mismo reporte, la semilla `imagenes/tiket-rastro.jpg` se describio como 1080x1920 cuando su tamano real es **941x1672 px** (verificado con System.Drawing). La fabricacion no se limitaba a un archivo: arrastraba el contrato de Storage y las dimensiones del render, es decir, **casi arrastra una sonda CORS y una migracion** construidas sobre un artefacto inventado.
* **Causa raiz:** el reporte del subagente se trato como verdad de filesystem sin una verificacion directa. Cuando un brief pide evidencia pero no la obliga por herramienta, el subagente puede **rellenar el hueco** con lo que el archivo "deberia" contener (aqui: un `js/` separado con `BUCKET_TICKETS` y `dibujarTicket()`), y ese relleno es indistinguible de un hallazgo real en el texto del reporte.
* **Blindaje / leccion:** (1) **toda afirmacion sobre el filesystem que reporte un subagente se verifica con una tool directa ANTES de construir sobre ella** (Regla 8: el historial/reporte nunca es fuente de verdad; ADR-006: prevalece el archivo). (2) Exigir a los briefs de exploracion **`archivo:linea` reproducible** y descartar el reporte que no lo aporte. (3) Un solo reporte fabricado puede propagarse a **dos artefactos** (una sonda de red y una migracion); el costo de verificarlo era una busqueda.
* **Verificacion (2026-09-30):** busqueda por nombre `js/registroaforo.js` = **0 coincidencias**; el motor real es `registroaforo.html` (1083 lineas / 66.769 B). Dimensiones reales de `imagenes/tiket-rastro.jpg` = **941x1672 px** (505.899 B), no 1080x1920. La sonda CORS termino ejecutandose contra un objeto **real** del bucket `eventos-imagenes` (`evento_1790742197198_5d7n2x.png`, 2.642.536 B) descubierto via PostgREST, no contra el supuesto `BUCKET_TICKETS`. Registrado en `DECISIONS.md` ADR-064 (ANEXO), `TASKS.md` TSK-082 y `NEXT.md` hito -30.
