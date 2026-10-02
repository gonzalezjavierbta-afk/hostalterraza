---
doc: ADR-046
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L716-734 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L716-734 del original).

#### ADR-046: Hub Normativo `AMPLIACION/TEMPLATES.md` y Skill Puente `templates` (Entrega 3)
* **ID:** ADR-046 | **Fecha:** 16 de septiembre de 2026 | **Estado:** Aprobado y entregado (QA APTO). DOS archivos documentales/skill nuevos: `Sistema QR desarrollo/AMPLIACION/TEMPLATES.md` (v1.3.0, 438 lineas) y `.opencode/skills/templates/SKILL.md` (skill puente). Cero cambios de codigo de aplicacion.
* **Autor:** Documentation Specialist / `@docs-keeper-free` (contenido normativo del hub en colaboracion con `@free-build`/`@free-plan`; este ADR es cierre documental).
* **Problema:** El conocimiento normativo de los silos CSS de `evento.html` estaba disperso entre `PROJECT.md` §6, `DECISIONS.md` (ADR-041/042/043), `ERRORES_HISTORICOS.md` y `BLUEPRINT.md` — sin un hub unico, cada sesion de template debia re-descubrir las reglas, y la discrepancia conocida Contrato v112 vs. DOM real (~81 IDs) hacia que agentes auditores reportaran como "faltantes" atomos que en realidad fueron renombrados/reestructurados. Se necesitaba una puerta de entrada unica y reproducible para crear/editar/auditar un silo.
* **Diagnostico verificado (contra el archivo real del repositorio, ADR-006):**
   1. **`Sistema QR desarrollo/AMPLIACION/TEMPLATES.md` real (438 lineas, v1.3.0, 2026-09-16):** hub normativo con **10 capitulos + 2 secciones de flujo** (9-bis Brief obligatorio, 9-ter Metodologia de creacion en 8 pasos) + **Anexo A** (versiones), **Anexo B** (mapa de referencia) y **Anexo C** (inventario del DOM real de `evento.html`, ~81 IDs). Audiencia declarada: `@frontend-tpl-free`, `@frontend-tpl`, `@free-build`, `@admin-dev-free`, `@docs-keeper-free`, `@qa-auditor`. Baseline declarado: archivos REALES del repositorio (ADR-006).
   2. **`.opencode/skills/templates/SKILL.md` real (38 lineas):** skill puente `name: templates` cuyo cuerpo remite obligatoriamente al HUB antes de tocar CSS; checklist de creacion en 8 pasos (resumen de HUB §9-ter), reglas criticas (doble notacion de casing `.tpl-fXX, .Tpl-FXX`, cero selectores fantasma, campaña apagada, ASCII-safety, subconmutaciones del kernel) y cierre documental (log de versiones + ADR + BUG-XXX + TASKS/NEXT, Mandato 12).
   3. **La advertencia Contrato v112 vs DOM real esta incluida en ambos:** solo 8 de los 21 Atomos Soberanos existen con id exacto en `evento.html`; los otros 12 fueron renombrados o reestructurados y NO deben reportarse como bug por `@qa-auditor` (misma advertencia que `AGENTS.md` seccion "Discrepancia conocida").
* **Decision (entregable real):**
   1. Crear el hub `Sistema QR desarrollo/AMPLIACION/TEMPLATES.md` como **unica puerta de entrada** normativa para tareas de silo (FASE I Data-First / FASE II Estetica, Cero Borrado, espejo exacto del DOM kernel, ASCII-safety, Aislamiento Atomico, Escudo GOLD 10/10).
   2. Crear la skill puente `.opencode/skills/templates/SKILL.md` para que cualquier agente que reciba una tarea de template cargue la skill y sea remitido al hub — sin duplicar la norma en la skill (el hub es la fuente).
   3. Declarar en el hub la advertencia de discrepancia Contrato v112 vs DOM real para que los agentes de auditoria no generen falsos positivos.
* **QA ejecutado (Escudo GOLD — QA APTO):** hub verificado en 438 lineas con los 10 capitulos + Brief + Metodologia 8 pasos + Anexos A/B/C presentes; skill verificada (frontmatter `name: templates`, descripcion de uso, remision al hub, 8 pasos, reglas criticas, cierre documental); advertencia v112 vs ~81 IDs presente en ambos; cero cambios a codigo de aplicacion (`admin.html`, `evento.html`, CSS, migraciones intactos). Los archivos de codigo NO fueron modificados por este cierre.
* **Impacto:** **2 archivos nuevos** (hub documental + skill), **0 archivos de codigo tocados**, **0 migraciones**, **0 endpoints**. El hub pasa a ser la fuente normativa para toda tarea de template futura (crear/editar/auditar/registrar theme en admin); complementa — no reemplaza — `PROJECT.md` §6 y los ADRs de silo. La skill `templates` aparece en el catalogo de skills disponibles de OpenCode.
* **Pendientes (no ejecutados):**
   1. Commit de la entrega por Direccion (working tree modificado, sin commit).
   2. Si Direccion lo autoriza: replicar la advertencia v112 vs DOM real en la configuracion de `@qa-auditor` (fuera del alcance de esta entrega; hoy se documenta en el hub y en `AGENTS.md`).
* **Referencias:** ADR-006 (baseline de verdad contra archivos reales: inventario del DOM del Anexo C), ADR-031 (universo `.opencode/` como operativo; la skill vive en `.opencode/skills/templates/`), Reglas de Oro v127-MASTER (16 mandatos citados en el hub — Mandato 1 Data-First, Mandato 2 Cero Borrado, Mandato 9 Aislamiento Atomico, Mandato 12 actualizacion documental), ADR-041/042/043 (patron de cierre documental de silos citado en la skill), `AGENTS.md` (seccion "Discrepancia conocida" — fuente de la advertencia v112).

