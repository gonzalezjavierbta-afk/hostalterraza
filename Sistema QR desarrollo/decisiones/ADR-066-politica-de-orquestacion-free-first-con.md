---
doc: ADR-066
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L1626-1649 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L1626-1649 del original).

#### ADR-066: Politica de orquestacion free-first con escalado y contrato de retorno de subagentes

* **ID:** ADR-066 | **Fecha:** Octubre 2026 | **Estado:** Aprobado (por Direccion; gobernanza documental).
* **Autor:** Chief Architect (GOBIERNO). Detalle operativo en las skills `eficiencia-recursos` y `anti-absorcion`; cierre documental a `@docs-keeper`.
* **Nota de baseline (ADR-006):** verificado contra el archivo real al 2026-10-01, el ultimo ADR numerado de este documento es **ADR-064**; el **ADR-065 fue declinado de forma expresa** en el ANEXO del ADR-064 (el fix de cableado de `registroaforo.html` se anexo alli y no creo ADR nuevo). Por eso esta decision toma el numero **066** sin rellenar el 065 y sin alterar el historial existente (Cero Borrado documental / Mandato 12).
* **Problema / Contexto (medicion REAL, no estimada):** en la feature **Guest List** el orquestador (`build`) concentro el **78,1% del costo total por contexto acumulado**: **67 turnos, 5.196.654 tokens** = **77.562 tokens/turno**, con **`cache_read` 89,4%**. El costo real es **relectura de contexto**, no trabajo nuevo: cada turno relee el system prompt (`AGENTS.md` ~8.1k tokens), los briefs y el historial, mientras el trabajo productivo (output) es marginal.
* **Opciones evaluadas:**
    1. **No intervenir / documentar el costo:** se conoce el gasto, pero se mantiene el patron (sesiones largas, handoffs verbosos, orquestador absorbiendo trabajo).
    2. **Gobernar por politica (ELEGIDA):** contrato de retorno de subagentes + presupuesto de turnos + anti-absorcion + free-first con escalado + watchdog + cierre medido + ajuste de compactacion, sin tocar esquema, endpoints ni runtime.
    3. **Hard-cap de tokens en el runtime:** rechazada por ahora; requiere cambios de plataforma fuera del repositorio.
* **Decision:**
    1. **Contrato de retorno de subagentes:** todo `task` exige retorno compacto (**max ~600 tokens**: STATUS, ARCHIVOS con rangos de linea, VERIFICACION con comando y resultado N/N, BLOQUEADORES, SIGUIENTE) y prohibe volcar archivos completos, diffs extensos o narrar lo leido.
    2. **Presupuesto de 25-30 turnos por sesion con fragmentacion por fase:** una sesion = una fase; al agotar el presupuesto se emite resumen de estado y se abre sesion nueva (podar contexto es mas barato que relecturas).
    3. **Anti-absorcion dura:** el orquestador que supere **>20-25 llamadas directas** (read/grep/glob) se detiene y delega a `@explore`.
    4. **Free-first con escalado automatico a PRO:** para trabajo mecanico/repetitivo/bajo riesgo se intenta primero la ruta FREE; si falla, devuelve partial/blocked o no pasa la verificacion, escala AUTOMATICAMENTE a PRO del dominio sin pedir permiso. Los dominios de riesgo de runtime o seguridad (backend, renderer, admin, sql-security, arquitectura) van directo a PRO. Prohibido desdoblar pro+free en paralelo.
    5. **Watchdog de subagentes:** un subagente que supere **25 turnos o 50.000 tokens/turno** se aborta y se re-planifica; nunca se re-despacha el mismo perfil (regla anti-colgado).
    6. **Cierre medido obligatorio:** toda sesion de implementacion CIERRA con balance detallado de gasto (total, turnos, cache_read/turno, desglose por agente), contrastado estimado vs real (Mandato 19), 1-3 aprendizajes y consejos de mejora, con `scripts/usage_report.js` y `scripts/session_close.js`.
    7. **Ajuste de compactacion:** la compactacion de contexto se trata como palanca de primera clase (podar antes de ampliar la sesion), no como remedio de ultima hora.
* **Justificacion:** (1) el costo crece **~cuadraticamente con los turnos de una misma sesion** (cada turno re-lee todo el contexto acumulado); (2) **fragmentar y podar contexto reduce 35-60%** el gasto medido; (3) el **peaje fijo** (`AGENTS.md` ~8.1k re-leido por turno) y los **handoffs verbosos** son evitables con el contrato de retorno; (4) free-first con escalado conserva el ahorro sin exponer runtime/seguridad, que van directo a PRO.
* **Consecuencias:** (1) **cambio de baseline medido**: la referencia de costo deja de ser tokens totales sueltos y pasa a ser **`cache_read`/turno** y turnos por fase; (2) **seguimiento** obligatorio de `cache_read`/turno en cada cierre; (3) las skills **`eficiencia-recursos`** y **`anti-absorcion`** se actualizan como **detalle operativo** de esta politica; (4) sin impacto en esquema, endpoints ni runtime (decision de PROCESO/GOBIERNO). Codificado en `AGENTS.md` (Reglas transversales 12-14) y en los 4 orquestadores (seccion "Contrato de retorno y free-first").
* **Referencias:** ADR-058 (Gobernanza de Eficiencia de Recursos; `costo = turnos x contexto`), ADR-031 (anti-absorcion y reglas de delegacion), ADR-052 (permisos y `default_agent`), ADR-006 (baseline contra el archivo real), Mandato 19 / Reglas de Oro #19-20, `AGENTS.md` (Reglas transversales 12-14), `.opencode/agent/{plan,build,free-build,hybrid-build}.md`, skills `eficiencia-recursos` y `anti-absorcion`, `scripts/usage_report.js` y `scripts/session_close.js`.

---

