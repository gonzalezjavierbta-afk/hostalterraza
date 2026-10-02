---
doc: E16 (ERRORES_HISTORICOS.md §16)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L220-229 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §16 · [INDEX](../INDEX.md). Texto original íntegro debajo (L220-229 del original).

## 16. Errores de Gobernanza de Recursos (Sesión de banners f9b — 2026-09-27)

### 🚨 Verificación Delegada que Devolvió Vacío tras 2.9 h y 3.31M Tokens (`qa-auditor-free`)
* **Problema:** en la sesión de banners del silo `f9b`, la verificación final se delegó a `qa-auditor-free`; el subagente consumió **3.31M tokens en 50 turnos (~2.9 h de reloj, 68 tool calls)** y **devolvió un resultado VACÍO**. La verificación no quedó certificada y hubo que repetirla con otro agente, que consumió **+2.17M tokens**. Costo total del incidente: **~5.5M tokens (17% de la sesión de 32.2M)**.
* **Causa raíz:** (1) el perfil del agente no garantiza una salida no vacía; el fallo fue silencioso (ni error de consola ni excepción: simplemente no devolvió informe). (2) El gasto se explica por el modelo real de costo — `turnos × contexto acumulado`: cada turno relee el contexto completo (`cache_read` = 91.7% del total medido) y `AGENTS.md` (8.123 tokens) se relee en cada turno. Un agente que "no converge" acumula turnos y, con ellos, `cache_read`, hasta colgarse. (3) No existía una regla que prohibiera re-despachar el mismo perfil tras un fallo, por lo que la recuperación se hizo re-despachando (otro agente, el mismo trabajo).
* **Blindaje (Mandato 17, regla anti-colgado + Mandato 18 / ADR-058):** (a) si un subagente devuelve vacío o excede el tiempo límite, **NO se re-despacha el mismo perfil**; se cambia de estrategia (script, otro dominio o brief dirigido mínimo) y se registra el incidente; (b) **un archivo, un lector** — no releer con varios agentes lo que un brief dirigido resuelve; (c) **verificación mecánica = script, no agente** (`scripts/express_check.js`, `scripts/smoke_*.js`, 0 tokens de agente); (d) consolidar fases: máx. 1 exploración + 1 implementación por dominio + 1 verificación por sesión.
* **Verificación:** medido con `scripts/usage_report.js` sobre `opencode.db` (16 sesiones, ~32.2M tokens, `cache_read` 91.7%, $0.0747, 5.7 h). Incidente y reglas cerradas en `DECISIONS.md` ADR-058 y `Reglas de Oro QR.md` v128-MASTER (Mandatos 17-18).

---

