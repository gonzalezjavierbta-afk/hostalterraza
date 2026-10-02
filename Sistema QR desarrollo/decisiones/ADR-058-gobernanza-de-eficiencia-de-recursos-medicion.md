---
doc: ADR-058
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L1172-1194 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L1172-1194 del original).

#### ADR-058: Gobernanza de Eficiencia de Recursos (medición de uso + consolidación de fases)

* **ID:** ADR-058 | **Fecha:** 2026-09-27 | **Estado:** APROBADO por Direccion (2026-09-27)
* **Autor:** Chief Architect / `@architect-free` (GOBIERNO). Verificación y cierre documental a `@docs-keeper`.
* **Problema / Contexto (medición REAL, no estimada):** se midió la DB `opencode.db` de la sesión de banners del silo `f9b` con `scripts/usage_report.js`: **16 sesiones, ~32.2M tokens totales**. Desglose: input fresco 2.16M (6.7%), output 0.28M (0.9%), reasoning 0.22M (0.7%), **`cache_read` ~29.5M (91.7%)**, `cache_write` 0. Costo real **$0.0747** (14 sesiones en tier gratuito, 2 en pago); tiempo de reloj **5.7 h**. El `cache_read` equivale a **50.000-76.000 tokens POR TURNO** (el contexto completo se relee cada turno); `AGENTS.md` (**8.123 tokens**) se releyó en CADA turno de CADA agente, ~6.5M tokens (20% del total) solo en relecturas del system prompt. **Incidente:** `qa-auditor-free` consumió **3.31M tokens en 50 turnos y ~2.9 h** y **devolvió un resultado VACÍO**; hubo que repetir la verificación con otro agente (**+2.17M**), ~5.5M tokens (17%) en una verificación duplicada. Además: **35 mutaciones de test en una sola tarea** y **6 pasadas de verificación sobre los mismos archivos**. **Hallazgo estructural:** el costo real es `turnos × contexto acumulado`, NO el output.
* **Opciones evaluadas:**
    1. **No intervenir / documentar solo el costo:** se conoce el gasto, pero se mantiene el patrón (relecturas masivas, verificación por agentes cuando un script basta, re-despacho de perfiles que fallan).
    2. **Gobernar por mandato (ELEGIDA):** normas incondicionales (Mandatos 17-18) + una herramienta de medición de cierre (`scripts/usage_report.js`) + regla anti-colgado + consolidación de fases, sin cambiar la arquitectura de datos ni el runtime.
    3. **Limitar por hard-cap de tokens en el runtime:** rechazada por ahora; requiere cambios de plataforma fuera del repositorio y no hay contrato de ejecución donde fijarlo.
* **Decisión:**
    1. **Mandato 17 (Eficiencia de Recursos y Contexto, modelo `costo = turnos × contexto`)** agregado a `Reglas de Oro QR.md` (v128-MASTER): unidad de costo, regla "un archivo, un lector", verificación mecánica por script, regla anti-colgado, mutation testing acotado (5-8), prohibición de leer archivos >200 KB completos, no-absorción del orquestador y medición obligatoria de cierre con `node scripts/usage_report.js`.
    2. **Mandato 18 (Consolidación de Fases y Agentes)** agregado: máximo 1 agente de exploración + 1 de implementación por dominio + 1 de verificación por sesión; prohibido re-despachar un perfil que ya falló o devolvió vacío; presupuesto orientativo de ~15M tokens / ~3 h de reloj por feature sin justificación escrita (PLACEHOLDER hasta N >= 5 sesiones medidas; recalibrar a ~1.5-2x la mediana).
    3. **`scripts/usage_report.js`:** herramienta de medición de uso; su contrato queda **CONGELADO** (modos `--summary`/`--sessions`/`--tree`/`--json`/`--csv`; filtros `--since`/`--until`/`--project`/`--agent`/`--root <sessionId>`/`--db`; detalle `--detail`/`--with-content`/`--max-chars N`; salida `--out <ruta>`/`--top N`/`-h|--help`; abre la DB en **readOnly** y NUNCA lee `account`/`control_account`/`credential`, y `--with-content` redacta secretos).
    4. **Regla anti-colgado:** un subagente que devuelve vacío o excede el tiempo límite NO se re-despacha con el mismo perfil; se cambia de estrategia y se registra el incidente.
* **Justificación:** (1) la medición demuestra que el gasto está en las relecturas del contexto (`cache_read` >90%) y en los turnos, no en el output; gobernar el número de turnos y el volumen releído ataca la causa raíz. (2) La verificación mecánica desplaza a los agentes donde un script certifica a 0 tokens de agente. (3) El incidente de `qa-auditor-free` (vacío tras 2.9 h) no debe repetirse re-despachando; la regla anti-colgado corta un bucle costoso ya observado. (4) Consolidar fases acota el fan-out de agentes, que multiplica turnos y relecturas. (5) Frente a hard-caps de plataforma, el mandato + la medición son la única palanca implementable dentro del repositorio.
* **Impacto:** documental y operativo (no toca esquema, endpoints ni runtime). Reglas de Oro `v128-MASTER` (+2 mandatos), `AGENTS.md` (sección `Eficiencia de recursos (v128)` + punto 8 de Reglas transversales), `DECISIONS.md` (este ADR) y `ERRORES_HISTORICOS.md` (incidente registrado). Nueva evidencia: `scripts/usage_report.js` (contrato congelado).
* **Riesgos:** (1) **menos redundancia de verificación:** consolidar a 1 verificador reduce la doble comprobación; se mitiga exigiendo que la verificación sea por script cuando aplique y que el brief dirigido sea preciso. (2) **Sesiones que exceden el presupuesto:** el límite ~15M/3 h es orientativo (placeholder hasta N >= 5 mediciones); se exige justificación escrita, no se bloquea. (3) **Abuso de `--with-content`:** mitigado por readOnly y redacción de secretos.
* **Rollback:** revertir las adiciones documentales (Mandatos 17-18, sección de `AGENTS.md`, este ADR, entrada de `ERRORES_HISTORICOS.md`); no hay cambio de código que revertir.
* **Referencias:** `Sistema QR desarrollo/Reglas de Oro QR.md` v128-MASTER (Mandatos 17-18), `AGENTS.md` (`Eficiencia de recursos (v128)`, Reglas transversales punto 8), ADR-031 (reglas anti-absorción), ADR-006 (baseline contra el archivo real), `scripts/usage_report.js` (contrato congelado).
* **Nota de medición (caveat):** las cifras de este ADR (~32.2M tokens / 16 sesiones) son una **medición intermedia** de una sesión que seguía creciendo (a la medición posterior iba en ~37M tokens / 20 sesiones). El número crece con la propia sesión, por lo que NO se debe tratar como cifra canónica absoluta, sino como evidencia del orden de magnitud del patrón de costo (`cache_read` >90% y `turnos × contexto`).

---

