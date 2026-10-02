---
doc: ADR-030
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L359-371 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L359-371 del original).

#### ADR-030: Módulo de Exportación de "Lista de Invitados" (Excel/PDF) en el Tab Asistentes de `admin.html`
* **ID:** ADR-030 | **Fecha:** 12 de septiembre de 2026 | **Estado:** Aprobado — código entregado en `admin.html` y verificado por el Escudo GOLD (qa-auditor) sin hallazgos. Sin cambios de esquema SQL (Cero Borrado y Contrato v112 intactos).
* **Problema:** Dirección solicitó un módulo de exportación de la lista de invitados a partir de `prompt lista.txt`, cuyo requerimiento asumía dos columnas inexistentes en el esquema (`tipo_asistente`, `invitador_codigo`). Además, la exportación debía convivir con los filtros ya existentes del tab Asistentes sin duplicar la lógica de filtrado ni agregar consultas a Supabase.
* **Decisión:**
  1. **Columnas del reporte:** SOLO `#`, `Nombre` y `Cédula` (decisión de Dirección) — los datos necesarios para la lista de invitados —, descartando las columnas supuestas por el prompt original que no existen en `inscritos`.
  2. **Alcance:** respetar los filtros visibles del panel (vista evento/serie/general + período + búsqueda/tipo/estado/categoría) reutilizando la cache `_pnAllList` ya cargada por `renderTabla()`. **No se agregaron consultas a Supabase.** Se añadió un filtro adicional "Solo asistencia" (`used=true`).
  3. **PDF:** reutilizar el patrón ya existente de `generarInforme()` — ventana auxiliar vía `window.open()` + HTML imprimible + `window.print()` — **sin introducir jsPDF** (evita una dependencia nueva y respeta la restricción CSP de Vercel documentada en `NEXT.md` §4).
  4. **Anti-duplicidad (Regla de No-Duplicidad):** extraer `_leerFiltrosPanel()` / `_filtrarInscritosPanel()` (compartidos por la tabla y las exportaciones), refactorizar `_renderTablaPagina()` para consumirlos y hacer que `_xlsxInscritos()` reutilice `_applyXlsxRowStyle()`. Nuevas funciones: `_etiquetaContextoPanel()`, `_buildInvitadosRows()`, `_generarXLSXInvitados()`, `_generarPDFInvitados()` y `exportarListaInvitados()`.
* **Correcciones post-auditoría (qa-auditor):** marca "Hostal Terraza" en el PDF; fallback de etiqueta de contexto para el rol `admin_evento` (M-1); tilde unificada "Cédula" (M-2); log TRACE del Escudo GOLD en el PDF (R-1); `.filter(Boolean)` null-safety (R-2).
* **Justificación:** el prompt original describía columnas que no existen; en lugar de alterar el esquema o inventar datos, Dirección acotó el reporte a `#`/`Nombre`/`Cédula`. Reutilizar `_pnAllList` y los filtros visibles evita consultas redundantes y garantiza que el archivo exportado coincida con lo que el usuario ve en pantalla. El patrón PDF existente evita una dependencia nueva (jsPDF) y mantiene la restricción CSP ya vigente en el proyecto.
* **Verificación (Escudo GOLD — qa-auditor, LIMPIA):** `node --check` exit 0 en ambos `<script>` inline; balance de `<div>` HTML puro 831/831 (baseline 830/830); funciones sin duplicados; smoke 25/25 con entradas `NULL` (ADR-008/ADR-024/ADR-029); scope global correcto; multi-tenant correcto; Cero Borrado verificado contra `git show HEAD:admin.html` (ningún ID/función eliminado).
* **Pendientes:** TSK-028 — `generarInforme()` (~L7900) consulta `SB.from('inscritos').select('*')` sin `.eq('org_id', ORG_ID)` (sus vecinas `clientes`/`logs` sí filtran): riesgo preexistente de fuga cross-tenant, **fuera del alcance de este módulo y NO corregido**. Ver `NEXT.md` §4 (Riesgos Activos) y TSK-026.

