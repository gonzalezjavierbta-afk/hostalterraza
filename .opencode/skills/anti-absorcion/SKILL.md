---
name: anti-absorcion
description: Reglas anti-absorcion (ADR-031) y KPIs de delegacion del orquestador. Cargar al planificar una sesion con subagentes.
---

# Reglas anti-absorción (ADR-031)

Cierran el hueco detectado el 2026-09-14: la regla transversal "Participante" del `AGENTS.md` original y `free-build.md` NO prohíben al agente principal hacer él mismo el trabajo (read/grep/glob/edit directos), lo que causa sesiones de absorción (el principal hace el trabajo del subagente). Aplican al agente principal y a los orquestadores (`@free-build`, `@hybrid-build`, `@build`, `@plan`, `@free-plan`, `@hybrid-plan` y cualquier agente que coordine subagentes):

1. **Delegación obligatoria antes de tocar:** toda implementación compleja se delega al subagente especializado (`*-free` en esquema gratuito; su par pro como respaldo) ANTES de que el principal toque el archivo. El principal no abre el archivo de la tarea delegada para "ver cómo está" mientras el subagente trabaja.
2. **Regla de No-Duplicidad:** el principal no duplica trabajo ya delegado. Si una tarea fue asignada a un subagente, el principal no la reimplementa, no la "mejora" ni la rehace después.
3. **Prohibido resolver lo delegado:** el principal tiene prohibido usar `read`/`grep`/`glob`/`webfetch`/`websearch` para resolver lo que ya delegó — su contexto es para orquestar, consolidar y decidir, no para operar.
4. **Verificación obligatoria antes de declarar completo:** ninguna tarea se da por "completa" sin el Escudo GOLD (`node --check`, ASCII-safety, balance de divs) o los smokes del proyecto (`npm run test` o smokes específicos) ejecutados sobre el archivo REAL (ADR-006).
5. **Respeto del Escudo GOLD:** en todo archivo de `api/*.js`, `admin.html`, `pagina-destino.js` o `index.html` entregado: sintaxis limpia (`node --check`), ASCII-safety (cero bytes > 127, cero dobles escapes, cero backticks en serverless) y balance de `<div>` en 0.
6. **Cierre con preguntas:** toda sesión de implementación cierra con las preguntas necesarias para completar la tarea de la mejor forma posible — nunca con afirmación de "todo listo" sin evidencia de verificación.
7. **KPIs de delegación medibles (target):** ratio de delegación ≥ 50% en sesiones de implementación; absorciones → 0. Baseline real del mes (2026-09-07): 12081 calls, 92 task (0.76%), 5931 exploración (49.1%), 2126 delegadas, ratio 35.8%, 20 sesiones de absorción de 151. Suma de 5 logs simples: 18784 calls, 158 task (0.84%), ratio 38.6%, 43 sesiones de absorción.
8. **Medidas anti-absorción cuando el principal supera el umbral:** si el contador de llamadas del principal supera **20-25 llamadas de herramienta directa** (read/grep/glob/edit/webfetch) en una sesión donde existan tareas delegables sin delegar, el principal DEBE detenerse, re-delegar las tareas pendientes y no continuar operando en su contexto.
9. **Auditoría periódica de KPIs:** `@explore-free` audita los KPIs de delegación con `scripts/usage_report.js` (`--summary`, `--sessions`, `--tree`, `--since`) y reporta a `@plan`/`@free-plan`; el resultado se registra en `NEXT.md` como parte del ciclo documental (AI-DOS Cap. 9.9). Los `.md` preexistentes de `logs/uso/` (último: 2026-09-07) son de un pipeline viejo que el script nuevo NO produce: quedan como LEGADO y dejan de ser la fuente de la auditoría.
10. **Handoff compacto:** el principal exige el contrato de retorno de cada subagente (máximo ~600 tokens: STATUS, ARCHIVOS con `ruta:rango`, VERIFICACION con comando y pass/fail N/N, BLOQUEADORES, SIGUIENTE) y **no reintroduce en su contexto el detalle del subagente** (no pide archivos completos ni narrativas). Ver `eficiencia-recursos`.
11. **Watchdog y free-first:** un subagente que supere **25 turnos** o **50.000 tokens/turno** se aborta y se re-planifica (nunca se re-despacha el mismo perfil); para lo mecánico se intenta primero FREE y se escala AUTOMÁTICAMENTE a PRO si falla, devuelve `partial`/`blocked` o no pasa la verificación. Detalle en `eficiencia-recursos` (secciones "Watchdog de subagentes" y "Free-first con escalado automático").

Relacionado: la skill `eficiencia-recursos` detalla las reglas anti-colgado, el contrato de retorno de subagentes, el presupuesto por fase, el watchdog, el free-first y la consolidación de fases (Mandatos 17-18), que refuerzan los puntos 8, 10 y 11.
