---
doc: ADR-067
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L1650-1666 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L1650-1666 del original).

## ADR-067: Consolidacion del roster a 20 agentes, retiro de la ruta hibrida y compuerta de seleccion de tier

**Fecha:** 2026-10-01

**Autor:** @architect

**Estado:** Aceptado

**Problema:** El roster activo contenia 22 archivos de agente con tres rutas solapadas (FREE, HYBRID, PAGO). Los gemelos *-free ya habian sido podados, de modo que free-plan, free-build, hybrid-plan y hybrid-build referenciaban agentes inexistentes. No habia un criterio unico y verificable para elegir tier, y el texto vigente permitia un escalado automatico a PAGO sin consentimiento del usuario.

**Contexto:** Presupuesto de Vercel Hobby y de cuota de modelos acotado. ADR-006 establece que la verdad es el archivo real del repo. La poda ADR-059 ya habia retirado agentes redundantes. Las skills declaradas en AGENTS.md incluian seis inexistentes en disco (agentes-roster, modelos-verificados, gemini-research, ingest-eventos, batch-create, reglas-de-oro).

**Decision:** Roster unico de 20 agentes: 4 primarios (plan/build en PAGO; free-plan/free-build en FREE con opencode/big-pickle) y 16 subagentes especialistas, un unico agente por dominio. Se retira la ruta hibrida. Toda tarea inicia con la compuerta 0: el orquestador pregunta al usuario, una vez por tarea y con la herramienta question, si usa FREE (costo 0) o PAGO. Sin respuesta no se ejecuta. Los dominios de riesgo (RLS/esquema y migraciones, motor de produccion evento-app.html, y arquitectura/ADR) exigen ademas confirmacion explicita del usuario antes de ejecutar, incluso en ruta PAGO. La ruta FREE opera aislada y no invoca subagentes PAGO salvo escalado confirmado.

**Consecuencias:** Se eliminan hybrid-plan.md y hybrid-build.md. free-plan y free-build dejan de referenciar agentes inexistentes. AGENTS.md se reescribe con las secciones 0 a 4 coherentes. opencode.json pasa a default_agent=build con permission.question=allow. Las seis skills fantasma quedan marcadas como pendientes de creacion y no deben declararse existentes. Los dominios de riesgo no pueden ejecutarse sin confirmacion explicita.

**Impacto:** Bajo en runtime (solo gobierno de agentes y documentacion); alto en claridad operativa y control de costo.
